import 'package:arteria/Core/Theme/theme_cubit.dart';
import 'package:arteria/features/auth/data/firebase_auth_repo.dart';
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

  Future<void> _logout(BuildContext context) async {
    final repo = FirebaseAuthRepo();
    try {
      await repo.logout();
      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logout failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
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
                        "App & Health Settings",
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
                        title: "Measurement History & Export",
                        icon: Icons.history_outlined,
                        onTap: () => _showComingSoon(context),
                        darkMode: darkMode,
                      ),
                      const SizedBox(height: 10),

                      _buildTile(
                        context,
                        theme: theme,
                        title: "Reminder Settings",
                        icon: Icons.notifications_active_outlined,
                        onTap: () => _showComingSoon(context),
                        darkMode: darkMode,
                      ),
                      const SizedBox(height: 10),

                      _buildTile(
                        context,
                        theme: theme,
                        title: "Security & Privacy",
                        icon: Icons.lock_outline,
                        onTap: () => _showComingSoon(context),
                        darkMode: darkMode,
                      ),

                      const SizedBox(height: 28),

                      // App Settings
                      Text(
                        "App Settings",
                        style: GoogleFonts.montserrat(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ✅ FIXED: Instant Dark Mode Toggle
                      _buildSwitchTile(
                        context,
                        theme: theme,
                        title: "Dark Mode",
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
                        title: "Language",
                        icon: Icons.language_rounded,
                        onTap: () => _showComingSoon(context),
                        darkMode: darkMode,
                      ),
                      const SizedBox(height: 10),

                      _buildTile(
                        context,
                        theme: theme,
                        title: "FAQ / Help Center",
                        icon: Icons.help_outline_rounded,
                        onTap: () => _showComingSoon(context),
                        darkMode: darkMode,
                      ),

                      const SizedBox(height: 36),

                      Center(
                        child: TextButton.icon(
                          onPressed: () => _logout(context),
                          icon: const Icon(
                            Icons.logout,
                            color: Colors.redAccent,
                          ),
                          label: Text(
                            "Log Out",
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
              color: Colors.black.withOpacity(0.05),
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
            "Your Info",
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
            _infoRow("Email", email, textColor),
            _infoRow("Age", age, textColor),
            _infoRow("Height", "$height cm", textColor),
            _infoRow("Weight", "$weight kg", textColor),
            _infoRow("Gender", gender, textColor),
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
              color: textColor.withOpacity(0.7),
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
        activeColor: const Color(0xFFE57373),
        activeTrackColor: const Color(0xFFF9B7B7),
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
    return ListTile(
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
        color: theme.iconTheme.color?.withOpacity(0.6),
      ),
      onTap: onTap,
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Coming soon!')));
  }
}
