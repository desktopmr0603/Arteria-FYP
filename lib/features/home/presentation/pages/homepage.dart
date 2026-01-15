import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:arteria/features/home/presentation/components/quick_stats_card.dart';
import 'package:arteria/features/home/presentation/components/medication_tracker_card.dart';
import 'package:arteria/features/home/presentation/components/emergency_alert_card.dart';
import 'package:arteria/features/home/presentation/components/family_circle_card.dart';
import 'package:arteria/features/home/presentation/components/health_tips_card.dart';
import 'package:arteria/features/home/presentation/components/weekly_overview_card.dart';
import 'package:arteria/features/home/presentation/pages/microphone_transcribe.dart';
import 'package:arteria/features/home/presentation/pages/settings/settings_screen.dart';
import 'package:arteria/features/trends/presentation/pages/trends_screen.dart';
import 'package:arteria/features/home/presentation/pages/Insights/insights_screen.dart';
import 'package:arteria/features/user%20data/user_bloc.dart';
import 'package:arteria/features/user%20data/user_event.dart';
import 'package:arteria/features/user%20data/user_state.dart';
import 'package:arteria/l10n/app_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> with TickerProviderStateMixin {
  Map<String, dynamic>? _latestReading;
  int _currentIndex = 0;
  late AnimationController _fadeController;
  late AnimationController _slideController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    context.read<UserBloc>().add(LoadUserData());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fadeController.forward();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    HapticFeedback.lightImpact();
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final List<Widget> pages = [
      DashboardContent(
        latestReading: _latestReading,
        fadeController: _fadeController,
        onRecordPressed: _openRecording,
      ),
      BlocBuilder<UserBloc, UserState>(
        builder: (context, state) {
          final userId =
              FirebaseAuth.instance.currentUser?.uid ?? 'default_user';
          final userAge = state is UserLoaded
              ? (state.latestReading?['age'] as int?)
              : null;
          return InsightsScreen(userId: userId, userAge: userAge);
        },
      ),
      const TrendsScreen(),
      const SettingsScreen(),
    ];

    return PopScope<Object?>(
      canPop: false,
      child: BlocListener<UserBloc, UserState>(
        listener: (context, state) {
          if (state is UserLoaded) {
            _slideController.forward(from: 0);
            setState(() => _latestReading = state.latestReading);
          } else if (state is UserError && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: const Color(0xFFEF4444),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          }
        },
        child: Scaffold(
          extendBody: true,
          backgroundColor: isDark
              ? const Color(0xFF0A0A0F)
              : const Color(0xFFF8FAFB),
          body: Stack(
            children: [
              _buildBackgroundDecorations(isDark),
              pages[_currentIndex],
            ],
          ),
          bottomNavigationBar: _buildFloatingNavBar(context, theme),
        ),
      ),
    );
  }

  Widget _buildBackgroundDecorations(bool isDark) {
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF6366F1).withValues(alpha: 0.15),
                    const Color(0xFF8B5CF6).withValues(alpha: 0.05),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 200,
            left: -150,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFEC4899).withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingNavBar(BuildContext context, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final items = [
      _NavItem(
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
        label: AppLocalizations.of(context)!.home,
      ),
      _NavItem(
        icon: Icons.psychology_outlined,
        activeIcon: Icons.psychology_rounded,
        label: AppLocalizations.of(context)!.insights,
      ),
      _NavItem(
        icon: Icons.history_rounded,
        activeIcon: Icons.history_rounded,
        label: AppLocalizations.of(context)!.history,
      ),
      _NavItem(
        icon: Icons.settings_outlined,
        activeIcon: Icons.settings_rounded,
        label: AppLocalizations.of(context)!.more,
      ),
    ];

    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return Container(
      margin: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomPadding),
      height: 72,
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E1E2E).withValues(alpha: 0.8)
            : Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(items.length, (index) {
                return _buildNavItem(
                  context,
                  items[index],
                  _currentIndex == index,
                  index,
                  theme,
                  isDark,
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    _NavItem item,
    bool isSelected,
    int index,
    ThemeData theme,
    bool isDark,
  ) {
    return GestureDetector(
      onTap: () => _onTabTapped(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark
                    ? const Color(0xFF6366F1).withValues(alpha: 0.2)
                    : const Color(0xFF6366F1).withValues(alpha: 0.1))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: isSelected ? 1.15 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              child: Icon(
                isSelected ? item.activeIcon : item.icon,
                size: 26,
                color: isSelected
                    ? const Color(0xFF6366F1)
                    : (isDark ? Colors.white60 : Colors.grey.shade600),
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: isSelected ? 11 : 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? const Color(0xFF6366F1)
                    : (isDark ? Colors.white60 : Colors.grey.shade600),
              ),
              child: Text(item.label),
            ),
          ],
        ),
      ),
    );
  }

  void _openRecording() async {
    final userBloc = context.read<UserBloc>();

    final result = await Navigator.push<Map<String, dynamic>?>(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const MicrophoneTranscribe(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: animation.drive(
                Tween(
                  begin: 0.8,
                  end: 1.0,
                ).chain(CurveTween(curve: Curves.easeOutCubic)),
              ),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );

    if (!mounted) return;

    if (result != null) {
      userBloc.add(
        SaveBPReading(
          systolic: result["systolic"],
          diastolic: result["diastolic"],
        ),
      );
    }
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

class DashboardContent extends StatelessWidget {
  final Map<String, dynamic>? latestReading;
  final AnimationController fadeController;
  final VoidCallback onRecordPressed;

  const DashboardContent({
    super.key,
    required this.latestReading,
    required this.fadeController,
    required this.onRecordPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return BlocBuilder<UserBloc, UserState>(
      builder: (context, state) {
        final l10n = AppLocalizations.of(context)!;
        final firstName = state is UserLoaded ? state.firstName : l10n.userDefault;
        final latest = state is UserLoaded ? state.latestReading : null;

        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: _HeaderDelegate(
                firstName: firstName,
                isDark: isDark,
                topPadding: MediaQuery.of(context).padding.top,
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 16),
                  QuickStatsCard(latestReading: latest),
                  const SizedBox(height: 12),
                  _buildRecordButton(
                    context,
                    isDark,
                    state is UserLoaded ? state.isFirstTimeUser : false,
                  ),
                  const SizedBox(height: 16),
                  const MedicationTrackerCard(),
                  const SizedBox(height: 16),
                  const EmergencyAlertCard(),
                  const SizedBox(height: 16),
                  WeeklyOverviewCard(
                    readings: state is UserLoaded ? state.weeklyReadings : [],
                  ),
                  const SizedBox(height: 16),
                  const FamilyCircleCard(),
                  const SizedBox(height: 16),
                  const HealthTipsCard(),
                  const SizedBox(height: 100),
                ]),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRecordButton(
    BuildContext context,
    bool isDark,
    bool isFirstReading,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final buttonText = isFirstReading ? l10n.takeFirstReading : l10n.recordNewReading;

    return GestureDetector(
      onTap: onRecordPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withValues(alpha: 0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.add_circle_outline_rounded,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 10),
            Text(
              buttonText.toUpperCase(),
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderDelegate extends SliverPersistentHeaderDelegate {
  final String firstName;
  final bool isDark;
  final double topPadding;

  _HeaderDelegate({
    required this.firstName,
    required this.isDark,
    required this.topPadding,
  });

  @override
  double get minExtent => 64 + topPadding;

  @override
  double get maxExtent => 120 + topPadding;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final progress = shrinkOffset / (maxExtent - minExtent);
    final clampedProgress = progress.clamp(0.0, 1.0);
    final hour = DateTime.now().hour;
    final l10n = AppLocalizations.of(context)!;
    String greeting;
    if (hour < 12) {
      greeting = l10n.greetingMorning;
    } else if (hour < 17) {
      greeting = l10n.greetingAfternoon;
    } else {
      greeting = l10n.greetingEvening;
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Glassmorphism background - only visible when scrolling
        if (shrinkOffset > 5)
          ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: 10 * clampedProgress,
                sigmaY: 10 * clampedProgress,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color:
                      (isDark
                              ? const Color(0xFF0A0A0F)
                              : const Color(0xFFF8FAFB))
                          .withValues(alpha: 0.8 * clampedProgress),
                  border: Border(
                    bottom: BorderSide(
                      color: (isDark ? Colors.white : Colors.black).withValues(
                        alpha: 0.05 * clampedProgress,
                      ),
                      width: 1,
                    ),
                  ),
                ),
              ),
            ),
          ),

        // Expanded State (Large Title)
        Positioned(
          left: 24,
          bottom: 16 + (clampedProgress * 12),
          child: Opacity(
            opacity: (1 - (clampedProgress * 2.5)).clamp(0.0, 1.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppLocalizations.of(context)!.healthDashboard,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.4)
                        : const Color(0xFF94A3B8),
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$greeting, $firstName',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    letterSpacing: -0.8,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Collapsed State (Small Title)
        Positioned(
          left: 24,
          top: topPadding + 16,
          child: Opacity(
            opacity: ((clampedProgress - 0.6) * 2.5).clamp(0.0, 1.0),
            child: Text(
              '$greeting, $firstName',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                letterSpacing: -0.4,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  bool shouldRebuild(covariant _HeaderDelegate oldDelegate) {
    return oldDelegate.firstName != firstName ||
        oldDelegate.isDark != isDark ||
        oldDelegate.topPadding != topPadding;
  }
}
