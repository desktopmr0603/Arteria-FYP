import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:arteria/l10n/app_localizations.dart';

class HealthTipsCard extends StatefulWidget {
  const HealthTipsCard({super.key});

  @override
  State<HealthTipsCard> createState() => _HealthTipsCardState();
}

class _HealthTipsCardState extends State<HealthTipsCard> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  List<HealthTip> _getTips(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return [
      HealthTip(
        title: l10n.healthTipMeasureTime,
        description: l10n.healthTipMeasureTimeDesc,
        icon: Icons.access_time_rounded,
        color: const Color(0xFFF76C5E),
      ),
      HealthTip(
        title: l10n.healthTipRestBefore,
        description: l10n.healthTipRestBeforeDesc,
        icon: Icons.self_improvement_rounded,
        color: const Color(0xFFF76C5E),
      ),
      HealthTip(
        title: l10n.healthTipWatchDiet,
        description: l10n.healthTipWatchDietDesc,
        icon: Icons.restaurant_rounded,
        color: const Color(0xFF10B981),
      ),
      HealthTip(
        title: l10n.healthTipStayActive,
        description: l10n.healthTipStayActiveDesc,
        icon: Icons.directions_run_rounded,
        color: const Color(0xFF3B82F6),
      ),
      HealthTip(
        title: l10n.healthTipManageStress,
        description: l10n.healthTipManageStressDesc,
        icon: Icons.spa_rounded,
        color: const Color(0xFFF59E0B),
      ),
      HealthTip(
        title: l10n.healthTipLimitAlcohol,
        description: l10n.healthTipLimitAlcoholDesc,
        icon: Icons.local_bar_rounded,
        color: const Color(0xFFEF4444),
      ),
      HealthTip(
        title: l10n.healthTipDontSkipMeds,
        description: l10n.healthTipDontSkipMedsDesc,
        icon: Icons.medication_rounded,
        color: const Color(0xFF14B8A6),
      ),
    ];
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1A1A24), const Color(0xFF12121A)]
              : [Colors.white, const Color(0xFFF8FAFB)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.lightbulb_rounded,
                      size: 22,
                      color: Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    AppLocalizations.of(context)!.healthTipsTitle,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 140,
              child: Builder(
                builder: (context) {
                  final tips = _getTips(context);
                  return PageView.builder(
                    controller: _pageController,
                    // Clamping (not the default bouncing) physics so this
                    // horizontal carousel doesn't run its own spring
                    // simulation that fights the parent vertical scroll's
                    // bounce when the user reverses direction over it — that
                    // gesture-arena hand-off was the bottom-of-page jitter.
                    // PageView still snaps; it just no longer rubber-bands.
                    physics: const ClampingScrollPhysics(),
                    onPageChanged: (page) {
                      setState(() => _currentPage = page);
                    },
                    itemCount: tips.length,
                    itemBuilder: (context, index) {
                      return _buildTipCard(tips[index], isDark);
                    },
                  );
                },
              ),
            ),
            _buildPageIndicator(_getTips(context).length),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildTipCard(HealthTip tip, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tip.color.withValues(alpha: 0.08),
            tip.color.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tip.color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  tip.color.withValues(alpha: 0.2),
                  tip.color.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(tip.icon, size: 26, color: tip.color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  tip.title,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  tip.description,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.6)
                        : const Color(0xFF64748B),
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator(int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        count,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: _currentPage == index ? 20 : 8,
          height: 8,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _currentPage == index
                  ? [const Color(0xFF10B981), const Color(0xFF059669)]
                  : [
                      const Color(0xFF10B981).withValues(alpha: 0.3),
                      const Color(0xFF10B981).withValues(alpha: 0.2),
                    ],
            ),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}

class HealthTip {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  HealthTip({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}
