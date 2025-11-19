import 'package:arteria/features/auth/domain/entities/app_user.dart';

abstract class AuthRepo {
  Future<AppUser?> loginWithEmailPassword(String email, String password);
  Future<AppUser?> registerWithEmailPassword(
    String name,
    String email,
    String password,
  );
  Future<void> logout();
  Future<AppUser?> getCurrentUser();
  Future<String> sendPasswordResetEmail(String email);
  Future<void> addUserDetails(String firstName, String lastName, String email);
  Future<void> deleteAccount();
  Future<AppUser?> signInWithGoogle();
  Future<bool> isProfileComplete();
}
