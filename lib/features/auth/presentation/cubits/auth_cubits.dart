import 'package:arteria/features/auth/domain/entities/app_user.dart';
import 'package:arteria/features/auth/domain/repo/auth_repo.dart';
import 'package:arteria/features/auth/presentation/cubits/auth_states.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
      // OWASP 2025: Use generic error messages for credential failures to prevent account enumeration attacks
      if (e.code == 'invalid-credential' ||
          e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-email') {
        // Generic message - don't reveal if email exists or password is wrong
        emit(
          AuthCredentialError(
            generalError: "Invalid email or password. Please try again.",
          ),
        );
      } else if (e.code == 'user-disabled') {
        // This is okay to reveal as it's an account status, not credential info
        emit(
          AuthCredentialError(
            generalError: "This account has been disabled. Contact support.",
          ),
        );
      } else if (e.code == 'too-many-requests') {
        emit(
          AuthCredentialError(
            generalError: "Too many failed attempts. Please try again later.",
          ),
        );
      } else {
        emit(
          AuthCredentialError(generalError: "Login failed. Please try again."),
        );
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
        _currentUser = user;
        // Check if profile is complete (has age, height, weight, etc.)
        final complete = await authRepo.isProfileComplete();
        if (complete) {
          emit(Authenticated(user));
        } else {
          // New user or profile not complete - redirect to profile setup
          emit(AuthenticatedNeedsProfileSetup());
        }
      } else {
        emit(AuthError("Google sign-in failed. Please try again."));
        emit(Unauthenticated());
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'sign-in-cancelled':
          // Don't show error for user-initiated cancellation
          emit(Unauthenticated());
          return;
        case 'google-auth-failed':
        case 'google-sign-in-failed':
        case 'firebase-auth-failed':
          errorMessage =
              e.message ?? "Google sign-in failed. Please try again.";
          break;
        case 'account-exists-with-different-credential':
          errorMessage =
              "An account already exists with the same email address but different sign-in credentials.";
          break;
        case 'network-request-failed':
          errorMessage =
              "Network error. Please check your internet connection.";
          break;
        default:
          errorMessage = "Google sign-in failed. Please try again.";
      }
      emit(AuthError(errorMessage));
      emit(Unauthenticated());
    } catch (e) {
      // Handle unexpected errors
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('canceled') ||
          errorStr.contains('cancelled') ||
          errorStr.contains('user_cancel')) {
        // User cancelled - don't show error
        emit(Unauthenticated());
        return;
      }
      emit(AuthError("Google sign-in failed. Please try again."));
      emit(Unauthenticated());
    }
  }
}
