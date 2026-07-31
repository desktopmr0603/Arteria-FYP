import 'package:arteria/Core/Theme/theme_cubit.dart';
import 'package:arteria/features/auth/data/firebase_auth_repo.dart';
import 'package:arteria/features/auth/presentation/cubits/auth_cubits.dart';
import 'package:arteria/features/auth/presentation/components/custom_confirmdialog.dart';
import 'package:arteria/features/auth/presentation/components/custom_loading_dialog.dart';
import 'package:arteria/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  final FirebaseAuthRepo _authRepo = FirebaseAuthRepo();

  void _handleResetPassword() async {
    final user = await _authRepo.getCurrentUser();
    if (user == null) return;

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const CustomLoadingDialog(
        message: '...', // Generic loading since no specific string exists for sending
      ),
    );

    await _authRepo.sendPasswordResetEmail(user.email);

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // dismiss loading

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context)?.passwordResetSent ?? 'Password reset email sent!',
          style: GoogleFonts.openSans(fontWeight: FontWeight.w500),
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _handleDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => CustomConfirmDialog(
        title: AppLocalizations.of(context)!.deleteAccount,
        content: AppLocalizations.of(context)!.deleteAccountConfirmationMessage,
        cancelText: AppLocalizations.of(context)!.cancel,
        confirmText: AppLocalizations.of(context)!.deleteAccount,
      ),
    );

    if (confirmed != true || !mounted) return;

    final authCubit = context.read<AuthCubits>();
    final rootNav = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const CustomLoadingDialog(message: '...'),
    );

    try {
      await _authRepo.deleteAccount();
    } catch (e) {
      // Deletion failed — the account still exists and the user is still
      // authenticated, so leave AuthCubits untouched and stay on this screen.
      if (!mounted) return;
      rootNav.pop(); // dismiss loading
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to delete account: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // Account is deleted and signed out. Sync AuthCubits — the app's single
    // auth gate — to Unauthenticated so _AuthWrapper can no longer render the
    // homepage. Without this the cubit stayed Authenticated and the homepage
    // was reachable again via the back button from the login screen.
    await authCubit.logout();
    if (!mounted) return;

    rootNav.pop(); // dismiss loading
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          l10n?.accountDeleted ?? 'Account deleted successfully.',
        ),
        backgroundColor: Colors.green,
      ),
    );
    // Reset the stack to the auth gate ('/'). _AuthWrapper renders Onboarding
    // while unauthenticated, so the homepage cannot be re-entered.
    rootNav.pushNamedAndRemoveUntil('/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeCubit = context.watch<ThemeCubit>();
    final isDarkMode = themeCubit.isDarkMode;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black87;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.securityPrivacy,
          style: GoogleFonts.montserrat(
            color: textColor,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Account Security',
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 16),
              _buildSettingCard(
                context,
                theme: theme,
                title: AppLocalizations.of(context)!.resetPassword,
                subtitle: AppLocalizations.of(context)!.resetPasswordMessage,
                icon: Icons.lock_reset_rounded,
                iconColor: theme.colorScheme.primary,
                onTap: _handleResetPassword,
                isDarkMode: isDarkMode,
              ),
              const SizedBox(height: 32),
              Text(
                'Account Data',
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 16),
              _buildSettingCard(
                context,
                theme: theme,
                title: AppLocalizations.of(context)!.deleteAccount,
                subtitle: 'Permanently remove your account and data',
                icon: Icons.delete_forever_rounded,
                iconColor: Colors.redAccent,
                titleColor: Colors.redAccent,
                onTap: _handleDeleteAccount,
                isDarkMode: isDarkMode,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingCard(
    BuildContext context, {
    required ThemeData theme,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
    required bool isDarkMode,
    Color? titleColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            if (!isDarkMode)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: titleColor ?? theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.openSans(
                      fontSize: 13,
                      color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.iconTheme.color?.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}
