import 'package:arteria/features/auth/domain/entities/app_user.dart';
import 'package:arteria/features/auth/domain/repo/auth_repo.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class FirebaseAuthRepo implements AuthRepo {
  final FirebaseAuth firebaseAuth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  static bool _isInitialized = false;

  /// Initialize Google Sign-In (call once at app startup or before first use)
  static Future<void> initGoogleSignIn() async {
    if (_isInitialized) return;

    try {
      print('Initializing Google Sign-In...');
      await _googleSignIn.initialize(
        // Android client ID
        clientId:
            "1074635639605-j99fu25no323fknidpcdeu6ogq3hlbe1.apps.googleusercontent.com",
        // server client ID for backend authentication
        serverClientId:
            "1074635639605-mt2uk705j8t6erllf8ln7ujgtn58tuvl.apps.googleusercontent.com",
      );

      // Listen to authentication events as recommended by latest documentation
      _googleSignIn.authenticationEvents
          .listen((event) {
            print('Google Sign-In Event: $event');
          })
          .onError((error) {
            print('Google Sign-In Stream Error: $error');
          });

      // Attempt lightweight authentication
      try {
        await _googleSignIn.attemptLightweightAuthentication();
      } catch (e) {
        print(
          'Lightweight authentication failed (normal if not signed in): $e',
        );
      }

      _isInitialized = true;
      print('Google Sign-In initialized successfully');
    } catch (e) {
      print('Google Sign-In initialization failed: $e');
      rethrow;
    }
  }

  @override
  Future<AppUser?> loginWithEmailPassword(String email, String password) async {
    final userCredential = await firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    final firebaseUser = userCredential.user;
    if (firebaseUser == null) return null;

    return AppUser(uid: firebaseUser.uid, email: firebaseUser.email ?? '');
  }

  @override
  Future<AppUser?> registerWithEmailPassword(
    String name,
    String email,
    String password,
  ) async {
    final userCredential = await firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final firebaseUser = userCredential.user;
    if (firebaseUser == null) return null;

    await firebaseUser.updateDisplayName(name);

    return AppUser(uid: firebaseUser.uid, email: firebaseUser.email ?? '');
  }

  @override
  Future<void> addUserDetails(
    String firstName,
    String lastName,
    String email,
  ) async {
    final user = firebaseAuth.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'firstName': firstName,
      'lastName': lastName,
      'fullName': '$firstName $lastName',
      'email': email,
      'createdAt': Timestamp.now(),
    });
  }

  @override
  Future<void> deleteAccount() async {
    try {
      final user = firebaseAuth.currentUser;
      if (user == null) throw Exception('No user is currently logged in');

      await user.delete();
      await logout();
    } catch (e) {
      throw Exception('Failed to delete account: $e');
    }
  }

  @override
  Future<AppUser?> getCurrentUser() async {
    final firebaseUser = firebaseAuth.currentUser;
    if (firebaseUser == null) return null;

    return AppUser(uid: firebaseUser.uid, email: firebaseUser.email ?? '');
  }

  @override
  Future<void> logout() async {
    await firebaseAuth.signOut();
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      // Google Sign-In might not be initialized, ignore
      print('Google sign-out: $e');
    }
  }

  @override
  Future<String> sendPasswordResetEmail(String email) async {
    try {
      await firebaseAuth.sendPasswordResetEmail(email: email);
      return "Password reset email sent! Check your inbox.";
    } catch (e) {
      return "An error occurred while sending reset email: $e";
    }
  }

  @override
  Future<AppUser?> signInWithGoogle() async {
    try {
      // Initialize Google Sign-In if not already done
      await initGoogleSignIn();

      print('Starting Google Sign-In flow...');

      // Check if platform supports authenticate method
      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        throw FirebaseAuthException(
          code: "platform-not-supported",
          message:
              "Google Sign-In authenticate is not supported on this platform.",
        );
      }

      // Trigger the Google Sign-In authentication flow
      late GoogleSignInAccount googleUser;
      try {
        print('Calling authenticate()...');
        googleUser = await _googleSignIn.authenticate();
        print('Google authenticate returned successfully');
      } catch (e) {
        print('Google authenticate threw error: $e');
        print('Error type: ${e.runtimeType}');
        rethrow;
      }

      print('Google authentication successful: ${googleUser.email}');

      // Get ID token from authentication
      late String? idToken;
      try {
        final auth = googleUser.authentication;
        print('GoogleSignInAuthentication: $auth');
        idToken = auth.idToken;
        print('idToken retrieved: ${idToken != null}');
      } catch (e) {
        print('Error getting authentication: $e');
        rethrow;
      }

      if (idToken == null) {
        throw FirebaseAuthException(
          code: "missing-id-token",
          message: "Failed to get Google ID token. Please try again.",
        );
      }

      // Get access token - try to authorize for basic scopes
      String? accessToken;
      try {
        final GoogleSignInClientAuthorization? auth = await googleUser
            .authorizationClient
            .authorizationForScopes(['email', 'profile']);
        accessToken = auth?.accessToken;
        print('Got access token: ${accessToken != null}');
      } catch (e) {
        print('Could not get access token (non-fatal): $e');
      }

      // Create Firebase credential from Google tokens
      print('Creating Firebase credential...');
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: accessToken,
        idToken: idToken,
      );

      // Sign in to Firebase with Google credential
      print('Signing in to Firebase with credential...');
      late UserCredential userCredential;
      try {
        userCredential = await firebaseAuth.signInWithCredential(credential);
        print('Firebase signInWithCredential succeeded');
      } catch (e) {
        print('Firebase signInWithCredential failed: $e');
        print('Error type: ${e.runtimeType}');
        rethrow;
      }

      final User? firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        throw FirebaseAuthException(
          code: "firebase-auth-failed",
          message: "Failed to sign in with Google. Please try again.",
        );
      }
      print('Firebase sign-in successful: ${firebaseUser.uid}');

      // Check if this is a new user (first time sign-in with Google)
      final bool isNewUser =
          userCredential.additionalUserInfo?.isNewUser ?? false;
      print('Is new user: $isNewUser');

      // Check if user document exists in Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(firebaseUser.uid)
          .get();

      // Create user document if it doesn't exist (new Google user)
      if (!userDoc.exists || isNewUser) {
        print('Creating Firestore document for new Google user...');

        // Extract name from Google profile
        final String displayName =
            firebaseUser.displayName ?? googleUser.displayName ?? '';
        final List<String> nameParts = displayName.split(' ');
        final String firstName = nameParts.isNotEmpty ? nameParts.first : '';
        final String lastName = nameParts.length > 1
            ? nameParts.sublist(1).join(' ')
            : '';

        // Create user document in Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(firebaseUser.uid)
            .set({
              'firstName': firstName,
              'lastName': lastName,
              'fullName': displayName,
              'email': firebaseUser.email ?? googleUser.email,
              'photoUrl': firebaseUser.photoURL,
              'createdAt': Timestamp.now(),
              'authProvider': 'google',
            }, SetOptions(merge: true));

        print('Firestore document created');
      }

      return AppUser(uid: firebaseUser.uid, email: firebaseUser.email ?? '');
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      print('Google Sign-In error: $e');
      print('Error type: ${e.runtimeType}');
      final String errorStr = e.toString().toLowerCase();

      // Check if this is a Credential Manager / Account reauth error
      if (errorStr.contains('account reauth failed') ||
          errorStr.contains('[16]') ||
          errorStr.contains('credmanprovservice') ||
          errorStr.contains('getcredentialresponse')) {
        print('Detected: Credential Manager / Account reauth error');
        throw FirebaseAuthException(
          code: "credential-manager-error",
          message:
              "Authentication configuration issue. Please ensure Google Sign-In is properly configured in Firebase Console with the correct SHA-1 fingerprint (21A41DACC7F84D5FB680631D904316C754D244AA).",
        );
      }

      // Check if user cancelled the sign-in
      if (errorStr.contains("canceled") ||
          errorStr.contains('cancelled') ||
          errorStr.contains('cancel') ||
          errorStr.contains('user declined') ||
          errorStr.contains('popup_closed') ||
          errorStr.contains('aborted') ||
          errorStr.contains('null')) {
        print('Detected: User cancelled');
        throw FirebaseAuthException(
          code: "sign-in-cancelled",
          message: "Google sign-in was cancelled.",
        );
      }

      // Check for network errors
      if (errorStr.contains('network') ||
          errorStr.contains('internet') ||
          errorStr.contains('connection')) {
        print('Detected: Network error');
        throw FirebaseAuthException(
          code: "network-error",
          message: "Network error. Please check your internet connection.",
        );
      }

      print('Throwing generic sign-in failed error');
      throw FirebaseAuthException(
        code: "google-sign-in-failed",
        message: "Google sign-in failed: ${e.toString()}",
      );
    }
  }

  @override
  Future<bool> isProfileComplete() async {
    final user = firebaseAuth.currentUser;
    if (user == null) return false;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!doc.exists) return false;

    final data = doc.data();
    if (data == null) return false;

    return data.containsKey('birthday') &&
        data.containsKey('age') &&
        data.containsKey('height') &&
        data.containsKey('weight');
  }
}
