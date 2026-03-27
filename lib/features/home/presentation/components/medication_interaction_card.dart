import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Medication Interaction Warning Card (Novel Feature)
/// 
/// Displays drug-drug and food-drug interaction warnings
/// with severity levels and recommendations.
class MedicationInteractionCard extends StatelessWidget {
  final List<InteractionWarning> warnings;
  final VoidCallback? onDismiss;
  final VoidCallback? onLearnMore;

  const MedicationInteractionCard({
    super.key,
    required this.warnings,
    this.onDismiss,
    this.onLearnMore,
  });

  @override
  Widget build(BuildContext context) {
    if (warnings.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasHighSeverity = warnings.any((w) => w.severity == InteractionSeverity.high);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: hasHighSeverity
              ? (isDark
                  ? [const Color(0xFF7F1D1D), const Color(0xFF1A1A2E)]
                  : [const Color(0xFFFEE2E2), Colors.white])
              : (isDark
                  ? [const Color(0xFF78350F), const Color(0xFF1A1A2E)]
                  : [const Color(0xFFFEF3C7), Colors.white]),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasHighSeverity
              ? const Color(0xFFEF4444).withValues(alpha: 0.5)
              : const Color(0xFFF59E0B).withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (hasHighSeverity 
                ? const Color(0xFFEF4444) 
                : const Color(0xFFF59E0B)).withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: hasHighSeverity
                  ? const Color(0xFFEF4444).withValues(alpha: 0.1)
                  : const Color(0xFFF59E0B).withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: hasHighSeverity
                        ? const Color(0xFFEF4444).withValues(alpha: 0.2)
                        : const Color(0xFFF59E0B).withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    hasHighSeverity ? Icons.warning_amber_rounded : Icons.info_outline,
                    color: hasHighSeverity 
                        ? const Color(0xFFEF4444) 
                        : const Color(0xFFF59E0B),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasHighSeverity 
                            ? 'Important Interaction Warning' 
                            : 'Medication Interaction',
                        style: GoogleFonts.montserrat(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: hasHighSeverity 
                              ? const Color(0xFFEF4444) 
                              : const Color(0xFFF59E0B),
                        ),
                      ),
                      Text(
                        '${warnings.length} interaction${warnings.length > 1 ? 's' : ''} detected',
                        style: GoogleFonts.openSans(
                          fontSize: 12,
                          color: theme.textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onDismiss != null)
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      size: 20,
                      color: theme.textTheme.bodySmall?.color,
                    ),
                    onPressed: onDismiss,
                  ),
              ],
            ),
          ),

          // Warnings List
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: warnings.map((warning) => _buildWarningItem(context, warning)).toList(),
            ),
          ),

          // Learn More Button
          if (onLearnMore != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: TextButton.icon(
                onPressed: onLearnMore,
                icon: const Icon(Icons.school_outlined, size: 18),
                label: Text(
                  'Learn More About Interactions',
                  style: GoogleFonts.openSans(fontSize: 13),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: hasHighSeverity 
                      ? const Color(0xFFEF4444) 
                      : const Color(0xFFF59E0B),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWarningItem(BuildContext context, InteractionWarning warning) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark 
            ? Colors.black.withValues(alpha: 0.2) 
            : Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: warning.severityColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Medication + Interacting item
          Row(
            children: [
              _SeverityBadge(severity: warning.severity),
              const SizedBox(width: 8),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: GoogleFonts.openSans(
                      fontSize: 13,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                    children: [
                      TextSpan(
                        text: warning.medication,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const TextSpan(text: ' + '),
                      TextSpan(
                        text: warning.interactingItem,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: warning.severityColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Effect
          Text(
            warning.effect,
            style: GoogleFonts.openSans(
              fontSize: 12,
              height: 1.4,
              color: theme.textTheme.bodyMedium?.color,
            ),
          ),
          
          // Recommendation
          if (warning.recommendation.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.tips_and_updates_outlined,
                    size: 16,
                    color: Color(0xFF3B82F6),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      warning.recommendation,
                      style: GoogleFonts.openSans(
                        fontSize: 11,
                        color: const Color(0xFF3B82F6),
                        fontWeight: FontWeight.w500,
                      ),
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

/// Data model for interaction warnings
class InteractionWarning {
  final String medication;
  final String interactingItem;
  final String type; // drug, food
  final InteractionSeverity severity;
  final String effect;
  final String recommendation;

  const InteractionWarning({
    required this.medication,
    required this.interactingItem,
    required this.type,
    required this.severity,
    required this.effect,
    this.recommendation = '',
  });

  Color get severityColor {
    switch (severity) {
      case InteractionSeverity.high:
        return const Color(0xFFEF4444);
      case InteractionSeverity.moderate:
        return const Color(0xFFF59E0B);
      case InteractionSeverity.low:
        return const Color(0xFF3B82F6);
    }
  }

  factory InteractionWarning.fromJson(Map<String, dynamic> json) {
    return InteractionWarning(
      medication: json['medication'] ?? '',
      interactingItem: json['interacting_item'] ?? '',
      type: json['type'] ?? 'drug',
      severity: InteractionSeverity.fromString(json['severity'] ?? 'moderate'),
      effect: json['effect'] ?? '',
      recommendation: json['recommendation'] ?? '',
    );
  }
}

enum InteractionSeverity {
  high,
  moderate,
  low;

  static InteractionSeverity fromString(String value) {
    switch (value.toLowerCase()) {
      case 'high':
        return InteractionSeverity.high;
      case 'moderate':
        return InteractionSeverity.moderate;
      case 'low':
        return InteractionSeverity.low;
      default:
        return InteractionSeverity.moderate;
    }
  }
}

class _SeverityBadge extends StatelessWidget {
  final InteractionSeverity severity;

  const _SeverityBadge({required this.severity});

  @override
  Widget build(BuildContext context) {
    final color = severity == InteractionSeverity.high
        ? const Color(0xFFEF4444)
        : severity == InteractionSeverity.moderate
            ? const Color(0xFFF59E0B)
            : const Color(0xFF3B82F6);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Text(
        severity.name.toUpperCase(),
        style: GoogleFonts.montserrat(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Compact chip for inline interaction warnings
class InteractionWarningChip extends StatelessWidget {
  final int warningCount;
  final bool hasHighSeverity;
  final VoidCallback? onTap;

  const InteractionWarningChip({
    super.key,
    required this.warningCount,
    this.hasHighSeverity = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (warningCount == 0) return const SizedBox.shrink();

    final color = hasHighSeverity 
        ? const Color(0xFFEF4444) 
        : const Color(0xFFF59E0B);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasHighSeverity ? Icons.warning_amber : Icons.info_outline,
              size: 14,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(
              '$warningCount interaction${warningCount > 1 ? 's' : ''}',
              style: GoogleFonts.openSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
