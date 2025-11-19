// lib/features/auth/presentation/cubits/auth_cubits.dart
import 'package:arteria/features/auth/domain/entities/app_user.dart';
import 'package:arteria/features/auth/domain/repo/auth_repo.dart';
import 'package:arteria/features/auth/presentation/cubits/auth_states.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Firebase exception
import 'package:flutter_bloc/flutter_bloc.dart';

class AuthCubits extends Cubit<AuthStates> {
  final AuthRepo authRepo;
  AppUser? _currentUser;

  AuthCubits({required this.authRepo}) : super(AuthInitial());

  // Get current user
  AppUser? get currentUser => _currentUser;

  // Check if user is authenticated
  void checkAuth() async {
    emit(AuthLoading());
    try {
      final AppUser? user = await authRepo.getCurrentUser();
      if (user != null) {
        final complete = await authRepo.isProfileComplete();
        _currentUser = user;
        if (complete) {
          emit(Authenticated(user));
        } else {
          emit(AuthenticatedNeedsProfileSetup());
        }
      } else {
        emit(Unauthenticated());
      }
    } catch (e) {
      emit(AuthError("Failed to check authentication. Please try again."));
      emit(Unauthenticated());
    }
  }

  // Login
  Future<void> login(String email, String pw) async {
    try {
      emit(AuthLoading());
      
      // Validate email format first
      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
      final isValidEmailFormat = emailRegex.hasMatch(email);
      
      final user = await authRepo.loginWithEmailPassword(email, pw);
      if (user != null) {
        final complete = await authRepo.isProfileComplete();
        _currentUser = user;
        if (complete) {
          emit(Authenticated(user));
        } else {
          emit(AuthenticatedNeedsProfileSetup());
        }
      } else {
        emit(Unauthenticated());
      }
    } on FirebaseAuthException catch (e) {
      // Validate email format for better error messages
      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
      final isValidEmailFormat = emailRegex.hasMatch(email);
      
      // Handle modern Firebase error codes
      if (e.code == 'invalid-credential') {
        // Modern Firebase returns this for both wrong email and wrong password
        // If email format is invalid, it's likely an email issue
        // If email format is valid, it's likely a password issue
        if (!isValidEmailFormat) {
          emit(AuthCredentialError(emailError: "Incorrect email"));
        } else {
          emit(AuthCredentialError(passwordError: "Incorrect password"));
        }
      } else if (e.code == 'user-not-found') {
        emit(AuthCredentialError(emailError: "Incorrect email"));
      } else if (e.code == 'invalid-email') {
        emit(AuthCredentialError(emailError: "Invalid email format"));
      } else if (e.code == 'wrong-password') {
        emit(AuthCredentialError(passwordError: "Incorrect password"));
      } else if (e.code == 'user-disabled') {
        emit(AuthCredentialError(emailError: "This account has been disabled"));
      } else if (e.code == 'too-many-requests') {
        emit(AuthCredentialError(generalError: "Too many failed attempts. Please try again later."));
      } else {
        final errorMessage = _getFriendlyErrorMessage(e);
        emit(AuthCredentialError(generalError: errorMessage));
      }
    } catch (e) {
      emit(AuthCredentialError(generalError: "An unexpected error occurred."));
    }
  }

  // Register
  Future<void> register(
    String firstName,
    String lastName,
    String email,
    String pw,
  ) async {
    try {
      emit(AuthLoading());
      String name = '$firstName $lastName';
      final user = await authRepo.registerWithEmailPassword(name, email, pw);
      if (user != null) {
        _currentUser = user;
        // Step 2: write user details to Firestore
        await authRepo.addUserDetails(firstName, lastName, email);
        final complete = await authRepo.isProfileComplete();
        if (complete) {
          emit(Authenticated(user));
        } else {
          emit(AuthenticatedNeedsProfileSetup());
        }
      } else {
        emit(Unauthenticated());
      }
    } on FirebaseAuthException catch (e) {
      final errorMessage = _getFriendlyErrorMessage(e);
      emit(AuthError(errorMessage));
      emit(Unauthenticated());
    } catch (e) {
      emit(AuthError("An unexpected error occurred. Please try again."));
      emit(Unauthenticated());
    }
  }

  // Logout
  Future<void> logout() async {
    emit(AuthLoading());
    try {
      await authRepo.logout();
      _currentUser = null;
      emit(Unauthenticated());
    } catch (e) {
      emit(AuthError("Failed to log out. Please try again."));
    }
  }

  // Forgot password
  Future<String> forgotPassword(String email) async {
    try {
      final message = await authRepo.sendPasswordResetEmail(email);
      return message;
    } on FirebaseAuthException catch (e) {
      return _getFriendlyErrorMessage(e);
    } catch (e) {
      return "Failed to send password reset email. Please try again.";
    }
  }

  // Delete account
  Future<void> deleteAccount() async {
    try {
      emit(AuthLoading());
      await authRepo.deleteAccount();
      _currentUser = null;
      emit(Unauthenticated());
    } on FirebaseAuthException catch (e) {
      final errorMessage = _getFriendlyErrorMessage(e);
      emit(AuthError(errorMessage));
      emit(Unauthenticated());
    } catch (e) {
      emit(AuthError("Failed to delete account. Please try again."));
      emit(Unauthenticated());
    }
  }

  // Helper to map FirebaseAuthException codes to user-friendly messages
  String _getFriendlyErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return "The email address is invalid.";
      case 'email-already-in-use':
        return "This email is already registered.";
      case 'weak-password':
        return "The password is too weak. Try a stronger one.";
      case 'user-not-found':
        return "No user found for that email.";
      case 'wrong-password':
        return "Incorrect password. Please try again.";
      case 'operation-not-allowed':
        return "This operation is not allowed.";
      case 'too-many-requests':
        return "Too many attempts. Please try again later.";
      default:
        return "Authentication error: ${e.message ?? 'Please try again.'}";
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      emit(AuthLoading());
      final user = await authRepo.signInWithGoogle();

      if (user != null) {
        final complete = await authRepo.isProfileComplete();
        _currentUser = user;
        if (complete) {
          emit(Authenticated(user));
        } else {
          emit(AuthenticatedNeedsProfileSetup());
        }
      } else {
        emit(Unauthenticated());
      }
    } catch (e) {
      emit(AuthError(e.toString()));
      emit(Unauthenticated());
    }
  }
}
