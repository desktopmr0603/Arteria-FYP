import 'package:arteria/features/auth/domain/entities/app_user.dart';
import 'package:arteria/features/auth/domain/repo/auth_repo.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class FirebaseAuthRepo implements AuthRepo {
  final FirebaseAuth firebaseAuth = FirebaseAuth.instance;
  static final GoogleSignIn googleSignIn = GoogleSignIn.instance;
  static bool isInitialize = false;

  static Future<void> initSignIn() async {
    if (!isInitialize) {
      await googleSignIn.initialize(
        serverClientId:
            "1074635639605-mt2uk705j8t6erllf8ln7ujgtn58tuvl.apps.googleusercontent.com",
      );
    }
    isInitialize = true;
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
    await googleSignIn.signOut();
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
      await initSignIn();
      final GoogleSignInAccount gUser = await googleSignIn.authenticate();
      final idToken = gUser.authentication.idToken;
      final authorizationClient = gUser.authorizationClient;
      GoogleSignInClientAuthorization? authorization = await authorizationClient
          .authorizationForScopes(['email', 'profile']);

      final accessToken = authorization?.accessToken;
      if (accessToken == null) {
        final authorization2 = await authorizationClient.authorizationForScopes(
          ['email', 'profile'],
        );

        if (authorization2?.accessToken == null) {
          throw FirebaseAuthException(code: "error", message: "error");
        }
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: accessToken,
        idToken: idToken,
      );

      final userCredential = await firebaseAuth.signInWithCredential(
        credential,
      );
      final firebaseUser = userCredential.user;
      if (firebaseUser == null) return null;

      return AppUser(uid: firebaseUser.uid, email: firebaseUser.email ?? '');
    } catch (e) {
      print('Google Sign-In failed: $e');
      return null;
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
