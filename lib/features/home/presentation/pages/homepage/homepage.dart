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
import 'package:arteria/features/home/presentation/components/insight_highlight_card.dart';
import 'package:arteria/features/microphone_transcribe/pages/microphone_transcribe.dart';
import 'package:arteria/features/home/presentation/pages/settings/pages/settings_screen.dart';
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
          return InsightsScreen(
            userId: userId,
            userAge: userAge,
            onNavigateToHome: () => _onTabTapped(0),
          );
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
    // RepaintBoundary isolates these static radial-gradient circles onto
    // their own cached layer. Without it, the gradients share a layer with
    // the scrolling content above them (same Stack) and get re-rasterized
    // every scroll frame — wasted GPU work that shows up as jitter during
    // the bottom bounce-overscroll. Cached once, they only composite.
    return Positioned.fill(
      child: RepaintBoundary(
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
        icon: Icons.more_horiz_outlined,
        activeIcon: Icons.more_horiz_rounded,
        label: AppLocalizations.of(context)!.more,
      ),
    ];

    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    // Note: this used to wrap content in BackdropFilter(sigma=10) for a
    // glassmorphism look. That blur recomputes every frame as the user
    // scrolls (it has to re-blur the content moving behind it) and was
    // the primary source of the bottom-of-page scroll stutter — most
    // visible when reversing direction at the bottom, since the nav bar
    // sits right where the user's eyes are. A slightly more opaque solid
    // bar (alpha 0.92) gives the same floating-above-content feel for
    // zero per-frame cost.
    final navBg = isDark
        ? const Color(0xFF1E1E2E).withValues(alpha: 0.92)
        : Colors.white.withValues(alpha: 0.92);
    // RepaintBoundary caches the bar (its blurRadius:20 drop shadow in
    // particular) onto its own layer. With extendBody:true the list scrolls
    // BEHIND this bar, so without isolation the shadow was re-rasterizing
    // every frame as content moved under it — the residual bottom-of-page
    // jitter left over after the BackdropFilter blur was removed. The bar
    // only repaints on tab change now, not on scroll.
    return RepaintBoundary(
      child: Container(
        margin: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomPadding),
        height: 72,
        decoration: BoxDecoration(
          color: navBg,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
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
      // The voice flow (MicrophoneTranscribeBloc) has already written this
      // reading to `readings`. Flag it so UserBloc computes the risk score and
      // reloads WITHOUT writing a second, duplicate document.
      userBloc.add(
        SaveBPReading(
          systolic: result["systolic"],
          diastolic: result["diastolic"],
          alreadyPersisted: true,
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
        final firstName = state is UserLoaded
            ? state.firstName
            : l10n.userDefault;
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
                  // Premium AI-driven insight card
                  const InsightHighlightCard(),
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
    final buttonText = isFirstReading
        ? l10n.takeFirstReading
        : l10n.recordNewReading;

    return GestureDetector(
      onTap: onRecordPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFF76C5E), Color(0xFFF76C5E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF76C5E).withValues(alpha: 0.3),
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
            // FittedBox(scaleDown) lets the label auto-shrink for long
            // translations (the French label is ~70% longer than English)
            // without forcing us to truncate medical copy with ellipsis.
            // English renders at full 14pt; French shrinks just enough to
            // sit on one line at the same button height.
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: Text(
                  buttonText.toUpperCase(),
                  maxLines: 1,
                  softWrap: false,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    letterSpacing: 1.0,
                  ),
                ),
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
        // Translucent header bar — fades in as the user scrolls. The
        // previous implementation wrapped this in a BackdropFilter whose
        // sigma animated with scroll progress; animated blur sigmas force
        // a full gaussian recompute every frame and were dropping frames
        // throughout the page (most visible at the bottom where blur was
        // at max sigma). A solid translucent bar gives the same "floats
        // above content" feel for zero per-frame cost.
        if (shrinkOffset > 5)
          Container(
            decoration: BoxDecoration(
              color: (isDark
                      ? const Color(0xFF0A0A0F)
                      : const Color(0xFFF8FAFB))
                  .withValues(alpha: 0.92 * clampedProgress),
              border: Border(
                bottom: BorderSide(
                  color: (isDark ? Colors.white : Colors.black)
                      .withValues(alpha: 0.05 * clampedProgress),
                  width: 1,
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

