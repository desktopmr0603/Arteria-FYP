import 'package:arteria/Core/Theme/theme_cubit.dart';
import 'package:arteria/features/auth/presentation/cubits/auth_cubits.dart';
import 'package:arteria/features/auth/presentation/cubits/auth_states.dart';
import 'package:arteria/features/auth/presentation/components/custom_confirmdialog.dart';
import 'package:arteria/features/auth/presentation/components/custom_loading_dialog.dart';
import 'package:arteria/features/export/export_screen.dart';
import 'package:arteria/features/FAQ/pages/faq_screen.dart';
import 'package:arteria/features/home/presentation/pages/settings/bloc/settings_bloc.dart';
import 'package:arteria/features/home/presentation/pages/settings/bloc/settings_event.dart';
import 'package:arteria/features/reminders/ui/reminder_settings_screen.dart';
import 'package:arteria/l10n/app_localizations.dart';
import 'package:arteria/features/home/presentation/pages/settings/pages/privacy_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Future<Map<String, dynamic>?> _userProfileFuture;

  @override
  void initState() {
    super.initState();
    // ✅ Cache the future so Firestore data isn't re-fetched on every rebuild
    _userProfileFuture = _fetchUserProfile();
  }

  Future<Map<String, dynamic>?> _fetchUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    return doc.data();
  }

  Future<void> _showLogoutConfirmation(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => CustomConfirmDialog(
        title: AppLocalizations.of(context)!.logOut,
        content: AppLocalizations.of(context)!.logoutConfirmationMessage,
        cancelText: AppLocalizations.of(context)!.cancel,
        confirmText: AppLocalizations.of(context)!.logOut,
      ),
    );
    if (confirmed != true || !context.mounted) return;
    _showLogoutLoading(context);
  }

  void _showLogoutLoading(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => CustomLoadingDialog(
        message: AppLocalizations.of(context)!.loggingOut,
      ),
    );
    _performLogout(context);
  }

  Future<void> _performLogout(BuildContext context) async {
    // SettingsScreen is a TAB inside Homepage, not a pushed route. When
    // AuthCubits emits Unauthenticated, _AuthWrapper swaps Homepage ->
    // OnboardingScreen and this State is disposed — `mounted` becomes false.
    // Capture rootNav/messenger up-front and dismiss the loading dialog
    // WITHOUT a mounted guard: the dialog route lives on the root Navigator
    // independently of this widget, and leaving it orphaned was the bug —
    // user saw OnboardingScreen stuck behind the spinner and had to press
    // back to dismiss it.
    final authCubit = context.read<AuthCubits>();
    final rootNav = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);

    await authCubit.logout();

    if (rootNav.canPop()) {
      rootNav.pop(); // dismiss the loading dialog
    }

    if (authCubit.state is! Unauthenticated) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Logout failed. Please try again.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
    // No pushNamedAndRemoveUntil needed: _AuthWrapper already renders
    // OnboardingScreen at '/' for Unauthenticated state, and SettingsScreen
    // was a tab (not a route) so there's nothing else to pop.
  }

  String _capitalizeName(String name) {
    return name
        .split(' ')
        .map(
          (word) => word.isEmpty
              ? ''
              : word[0].toUpperCase() + word.substring(1).toLowerCase(),
        )
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<ThemeCubit>(
      builder: (context, themeProvider, _) {
        final bool darkMode = themeProvider.isDarkMode;
        final Color bgColor = theme.scaffoldBackgroundColor;
        final Color textColor =
            theme.textTheme.bodyLarge?.color ?? Colors.black87;

        return Scaffold(
          backgroundColor: bgColor,
          body: SafeArea(
            child: FutureBuilder<Map<String, dynamic>?>(
              // ✅ Cached Future: prevents refetch/reload when toggling theme
              future: _userProfileFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final userData = snapshot.data ?? {};
                final name = _capitalizeName(userData['fullName'] ?? 'User');
                final email =
                    userData['email'] ??
                    FirebaseAuth.instance.currentUser?.email ??
                    '—';
                final age = userData['age']?.toString() ?? '—';
                final height = userData['height']?.toString() ?? '—';
                final weight = userData['weight']?.toString() ?? '—';
                final gender = userData['gender'] ?? '—';

                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Center(
                        child: Text(
                          name,
                          style: GoogleFonts.montserrat(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Your Info
                      _buildExpandableInfo(
                        context: context,
                        theme: theme,
                        darkMode: darkMode,
                        textColor: textColor,
                        email: email,
                        gender: gender,
                        age: age,
                        height: height,
                        weight: weight,
                      ),
                      const SizedBox(height: 28),

                      // App & Health Settings
                      Text(
                        AppLocalizations.of(context)!.appHealthSettings,
                        style: GoogleFonts.montserrat(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 12),

                      _buildTile(
                        context,
                        theme: theme,
                        title: AppLocalizations.of(
                          context,
                        )!.measurementHistoryExport,
                        icon: Icons.history_outlined,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ExportScreen(),
                          ),
                        ),
                        darkMode: darkMode,
                      ),
                      const SizedBox(height: 10),

                      _buildTile(
                        context,
                        theme: theme,
                        title: AppLocalizations.of(
                          context,
                        )!.reminderSettingsMenu,
                        icon: Icons.notifications_active_outlined,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const ReminderSettingsScreen(),
                          ),
                        ),
                        darkMode: darkMode,
                      ),
                      const SizedBox(height: 10),

                      _buildTile(
                        context,
                        theme: theme,
                        title: AppLocalizations.of(context)!.securityPrivacy,
                        icon: Icons.lock_outline,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const PrivacyScreen(),
                            ),
                          );
                        },
                        darkMode: darkMode,
                      ),

                      const SizedBox(height: 28),

                      // App Settings
                      Text(
                        AppLocalizations.of(context)!.appSettings,
                        style: GoogleFonts.montserrat(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 12),

                      _buildSwitchTile(
                        context,
                        theme: theme,
                        title: AppLocalizations.of(context)!.darkMode,
                        value: darkMode,
                        onChanged: (bool value) {
                          // 🔹 Instant theme update
                          Provider.of<ThemeCubit>(
                            context,
                            listen: false,
                          ).toggleTheme();
                        },
                        darkMode: darkMode,
                      ),
                      const SizedBox(height: 10),

                      _buildTile(
                        context,
                        theme: theme,
                        title: AppLocalizations.of(context)!.language,
                        icon: Icons.language_rounded,
                        onTap: () => _showLanguagePicker(context),
                        darkMode: darkMode,
                      ),
                      const SizedBox(height: 10),

                      _buildTile(
                        context,
                        theme: theme,
                        title: AppLocalizations.of(context)!.faqHelpCenter,
                        icon: Icons.help_outline_rounded,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const FaqScreen(),
                            ),
                          );
                        },
                        darkMode: darkMode,
                      ),

                      const SizedBox(height: 36),

                      Center(
                        child: TextButton.icon(
                          onPressed: () => _showLogoutConfirmation(context),
                          icon: const Icon(
                            Icons.logout,
                            color: Colors.redAccent,
                          ),
                          label: Text(
                            AppLocalizations.of(context)!.logOut,
                            style: GoogleFonts.montserrat(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  // --- UI Components ---

  Widget _buildExpandableInfo({
    required BuildContext context,
    required ThemeData theme,
    required bool darkMode,
    required Color textColor,
    required String email,
    required String gender,
    required String age,
    required String height,
    required String weight,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!darkMode)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          title: Text(
            AppLocalizations.of(context)!.yourInfo,
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: textColor,
            ),
          ),
          iconColor: textColor,
          collapsedIconColor: textColor,
          children: [
            const SizedBox(height: 6),
            _infoRow(AppLocalizations.of(context)!.email, email, textColor),
            _infoRow(AppLocalizations.of(context)!.age, age, textColor),
            _infoRow(
              AppLocalizations.of(context)!.height,
              "$height cm",
              textColor,
            ),
            _infoRow(
              AppLocalizations.of(context)!.weight,
              "$weight kg",
              textColor,
            ),
            _infoRow(AppLocalizations.of(context)!.gender, gender, textColor),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.openSans(
              fontSize: 14,
              color: textColor.withValues(alpha: 0.7),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile(
    BuildContext context, {
    required ThemeData theme,
    required String title,
    required bool value,
    required Function(bool) onChanged,
    required bool darkMode,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
        ),
        child: SwitchListTile(
          title: Text(
            title,
            style: GoogleFonts.openSans(
              color: theme.textTheme.bodyLarge?.color,
              fontWeight: FontWeight.w500,
            ),
          ),
          value: value,
          onChanged: onChanged,
          activeThumbColor: const Color(0xFFE63946),
          activeTrackColor: const Color(0xFFf28482),
        ),
      ),
    );
  }

  Widget _buildTile(
    BuildContext context, {
    required ThemeData theme,
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    required bool darkMode,
  }) {
    return Theme(
      data: Theme.of(context).copyWith(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        tileColor: theme.cardColor,
        leading: Icon(icon, color: theme.iconTheme.color),
        title: Text(
          title,
          style: GoogleFonts.openSans(
            fontWeight: FontWeight.w500,
            color: theme.textTheme.bodyLarge?.color,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: theme.iconTheme.color?.withValues(alpha: 0.6),
        ),
        onTap: onTap,
      ),
    );
  }

  void _showLanguagePicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.language, color: Color(0xFFE63946)),
            const SizedBox(width: 12),
            Expanded(
              // <-- prevents overflow & keeps size stable
              child: Text(
                AppLocalizations.of(context)!.selectLanguage,
                style: GoogleFonts.montserrat(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
                softWrap: true,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLanguageTile(
              emoji: '🇬🇧',
              text: AppLocalizations.of(context)!.english,
              onTap: () {
                context.read<SettingsBloc>().add(ChangeLocale(Locale('en')));
                Navigator.pop(dialogContext);
              },
            ),
            _buildLanguageTile(
              emoji: '🇫🇷',
              text: AppLocalizations.of(context)!.french,
              onTap: () {
                context.read<SettingsBloc>().add(ChangeLocale(Locale('fr')));
                Navigator.pop(dialogContext);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageTile({
    required String emoji,
    required String text,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Text(emoji, style: const TextStyle(fontSize: 32)),
      title: Text(
        text,
        style: GoogleFonts.openSans(fontSize: 16),
        softWrap: true,
      ),
      onTap: onTap,
    );
  }

}
