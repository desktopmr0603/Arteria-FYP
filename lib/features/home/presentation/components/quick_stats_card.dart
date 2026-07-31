import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:arteria/l10n/app_localizations.dart';
import 'package:arteria/features/home/presentation/components/premium_dashboard_card.dart';

class QuickStatsCard extends StatelessWidget {
  final Map<String, dynamic>? latestReading;
  const QuickStatsCard({super.key, this.latestReading});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final systolic = latestReading?['systolic'] as int?;
    final diastolic = latestReading?['diastolic'] as int?;
    final readingDate = latestReading?['date'];
    final readingTimestamp = readingDate is Timestamp
        ? readingDate.toDate()
        : readingDate is DateTime
        ? readingDate
        : readingDate != null
        ? DateTime.parse(readingDate.toString())
        : null;

    final statusInfo = _getStatusInfo(context, systolic, diastolic);
    final statusColor = statusInfo['color'] as Color;
    final l10n = AppLocalizations.of(context)!;
    final dateText = readingTimestamp != null
        ? _formatDate(context, readingTimestamp)
        : l10n.quickStatsNoReadingsYet;

    return PremiumDashboardCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Decorative Background
            Positioned(
              top: -40,
              right: -40,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor.withValues(alpha: isDark ? 0.04 : 0.03),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
              child: Column(
                children: [
                  // Minimalist Header with tracking
                  Text(
                    l10n.quickStatsBloodPressure,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.2)
                          : const Color(0xFF94A3B8),
                      letterSpacing: 4.5,
                    ),
                  ),

                  const SizedBox(height: 48),

                  // Main Readings Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildBlock(
                        label: l10n.quickStatsSystolic,
                        value: systolic,
                        isDark: isDark,
                      ),

                      // Refined 'Slash' Divider
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          '/',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 72,
                            fontWeight: FontWeight.w200,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.1)
                                : Colors.black.withValues(alpha: 0.05),
                            height: 1.0,
                          ),
                        ),
                      ),

                      _buildBlock(
                        label: l10n.quickStatsDiastolic,
                        value: diastolic,
                        isDark: isDark,
                      ),
                    ],
                  ),

                  const SizedBox(height: 48),

                  // Footer with Refined Glass-Pill Status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // High-Definition Status Pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.25),
                            width: 1.2,
                          ),
                        ),
                        child: Text(
                          (statusInfo['label'] as String).toUpperCase(),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: statusColor,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),

                      // Last Checked Metadata
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            l10n.quickStatsLastRecorded,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.25)
                                  : const Color(0xFF64748B),
                              letterSpacing: 1.0,
                            ),
                          ),
                          Text(
                            dateText.toUpperCase(),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.6)
                                  : const Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlock({
    required String label,
    required int? value,
    required bool isDark,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: isDark
                ? Colors.white.withValues(alpha: 0.25)
                : const Color(0xFF94A3B8),
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${value ?? '--'}',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 68,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            height: 1.0,
            letterSpacing: -2.0,
          ),
        ),
        Text(
          'mmHg',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : const Color(0xFFCBD5E1),
          ),
        ),
      ],
    );
  }

  Map<String, dynamic> _getStatusInfo(
    BuildContext context,
    int? systolic,
    int? diastolic,
  ) {
    final sys = systolic ?? 0;
    final dia = diastolic ?? 0;
    final l10n = AppLocalizations.of(context)!;
    
    final age = latestReading?['age'] as int?;
    final isElderly = age != null && age >= 65;
    
    if (sys == 0) {
      return {
        'statusText': 'No Data',
        'label': l10n.statusPending,
        'color': const Color(0xFF94A3B8),
        'icon': Icons.history_rounded,
        'description': 'Take your first reading to see your health status.',
      };
    }

    if (sys >= 180 || dia >= 120) {
      return {
        'statusText': 'Critical Level',
        'label': l10n.statusHypertensiveCrisis,
        'color': const Color(0xFF9B2226), // Critical
        'icon': Icons.warning_amber_rounded,
        'description': 'Emergency! Seek medical attention immediately.',
      };
    } else if (sys >= 140 || dia >= 90) {
      return {
        'statusText': 'High Blood Pressure',
        'label': l10n.statusStage2Hypertension,
        'color': const Color(0xFFAE2012), // Stage 2
        'icon': Icons.arrow_upward_rounded,
        'description': 'Your readings are high. Consult your doctor.',
      };
    } else if (sys == 120 && dia == 80) {
       if (isElderly) {
         return {
           'statusText': 'Elevated',
           'label': l10n.statusElevated,
           'color': const Color(0xFFCA6702), // Elevated
           'icon': Icons.info_outline_rounded,
           'description': 'Blood pressure is considered elevated for your age.',
         };
       } else {
         return {
           'statusText': 'Normal Range',
           'label': l10n.statusNormal,
           'color': Colors.green, // Normal
           'icon': Icons.check_circle_rounded,
           'description': 'Your blood pressure is within the healthy range.',
         };
       }
    } else if ((sys >= 130 && sys <= 139) || (dia >= 80 && dia <= 89)) {
      return {
        'statusText': 'Slightly Elevated',
        'label': l10n.statusStage1Hypertension,
        'color': const Color(0xFFE85D04), // Stage 1
        'icon': Icons.trending_up_rounded,
        'description': 'You are in the Stage 1 hypertension range.',
      };
    } else if (sys >= 121 && sys <= 129 && dia < 80) { // Elevated (sys 121-129; 120 is Normal)
      return {
        'statusText': 'Elevated',
        'label': l10n.statusElevated,
        'color': const Color(0xFFCA6702), // Elevated
        'icon': Icons.info_outline_rounded,
        'description': 'Blood pressure is slightly high but not hypertensive.',
      };
    } else if (sys < 90 || dia < 60) { // Hypotension (Low): below 90/60
      return {
        'statusText': 'Low Blood Pressure',
        'label': l10n.bpCategoryLow,
        'color': const Color(0xFF2196F3), // Low (Hypotension) — blue
        'icon': Icons.arrow_downward_rounded,
        'description': 'Your blood pressure is low. Stay hydrated, stand up slowly, and consult your doctor if you feel dizzy or faint.',
      };
    } else {
      return {
        'statusText': 'Normal Range',
        'label': l10n.statusNormal,
        'color': Colors.green, // Normal
        'icon': Icons.check_circle_rounded,
        'description': 'Your blood pressure is within the healthy range.',
      };
    }
  }

  String _formatDate(BuildContext context, DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    final l10n = AppLocalizations.of(context)!;

    if (difference.inMinutes < 1) {
      return l10n.justNow;
    } else if (difference.inHours < 1) {
      return l10n.minAgo(difference.inMinutes);
    } else if (difference.inDays < 1) {
      return l10n.hAgo(difference.inHours);
    } else if (difference.inDays == 1) {
      return l10n.yesterday;
    } else {
      return DateFormat('MMM d, h:mm a').format(date);
    }
  }
}
