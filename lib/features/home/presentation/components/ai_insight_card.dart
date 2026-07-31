import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:arteria/features/home/presentation/components/bp_color_extension.dart';

/// AI-generated insights card component
class AIInsightCard extends StatelessWidget {
  final String insight;
  final String? trend;
  final IconData icon;
  final Color iconColor;

  const AIInsightCard({
    super.key,
    required this.insight,
    this.trend,
    this.icon = Icons.lightbulb_outline,
    this.iconColor = const Color(0xFF1976D2),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bpColor = context.bpStatusColor;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  const Color(0xFF1E3A5F).withAlpha(150),
                  const Color(0xFF2C2C2C),
                ]
              : [
                  const Color(0xFFE3F2FD),
                  const Color(0xFFF5F7FA),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: bpColor.withValues(alpha: 0.6),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 24),
              const SizedBox(width: 12),
              Text(
                'AI Insights',
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: iconColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            insight,
            style: GoogleFonts.openSans(
              fontSize: 15,
              height: 1.5,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
          if (trend != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.green.shade900.withValues(alpha: 0.3)
                    : Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.green.shade400,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.trending_down,
                    size: 18,
                    color: Colors.green.shade700,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    trend!,
                    style: GoogleFonts.openSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
