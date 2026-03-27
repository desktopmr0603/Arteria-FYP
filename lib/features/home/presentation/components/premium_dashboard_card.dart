import 'package:flutter/material.dart';

/// A reusable base card that standardizes the dashboard layout and aesthetic.
/// 
/// Provides the premium charcoal/off-white surface, exact border radii, padding rhythms,
/// and the distinctive left-edge cyan accent glow consistently across the dashboard widgets.
class PremiumDashboardCard extends StatelessWidget {
  /// The content of the card.
  final Widget child;

  /// Internal padding for the card content. Defaults to `EdgeInsets.all(24)`.
  final EdgeInsetsGeometry padding;

  /// Optional tap callback.
  final VoidCallback? onTap;

  /// Whether to show the left accent stroke/glow. Defaults to true.
  final bool showAccent;

  const PremiumDashboardCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.onTap,
    this.showAccent = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Standard dashboard card radius
    const double outerRadius = 24.0;
    // The precise pixel width to expose the underlying gradient for the accent stroke
    final double leftAccentWidth = showAccent ? 3.0 : 0.0;

    // Deep rich charcoal for dark, premium off-white for light
    final Color surfaceColor =
        isDark ? const Color(0xFF1E1E24) : const Color(0xFFFAFAFC);
        
    final Color shadowColor =
        isDark ? Colors.black.withValues(alpha: 0.4) : Colors.black.withValues(alpha: 0.05);

    // The gradient that acts as our left edge line
    final accentGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: isDark
          ? [const Color(0xFF00E5FF), const Color(0xFF00BFA6)]
          : [const Color(0xFF00C4D6), const Color(0xFF00A29C)],
    );

    // Provide a subtle non-accented border if the accent is missing
    final subtleBorder = Border.all(
      color: isDark 
          ? Colors.white.withValues(alpha: 0.04) 
          : Colors.black.withValues(alpha: 0.03),
      width: 1,
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: showAccent ? null : surfaceColor,
          gradient: showAccent ? accentGradient : null,
          borderRadius: BorderRadius.circular(outerRadius),
          border: showAccent ? null : subtleBorder,
          boxShadow: [
            // Standard depth shadow
            BoxShadow(
              color: shadowColor,
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            // Specific soft glow pushing out of the left accent edge
            if (isDark && showAccent)
              BoxShadow(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
                blurRadius: 12,
                spreadRadius: 1,
                offset: const Offset(-2, 0),
              ),
          ],
        ),
        // Expose the left N pixels of the accent layer if enabled.
        child: Padding(
          padding: EdgeInsets.only(left: leftAccentWidth),
          child: Container(
            decoration: BoxDecoration(
              color: surfaceColor,
              // The inner radii account for the padding cut-in so they neatly nest.
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(outerRadius - leftAccentWidth),
                bottomLeft: Radius.circular(outerRadius - leftAccentWidth),
                topRight: const Radius.circular(outerRadius),
                bottomRight: const Radius.circular(outerRadius),
              ),
              border: showAccent ? subtleBorder : null,
            ),
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}
