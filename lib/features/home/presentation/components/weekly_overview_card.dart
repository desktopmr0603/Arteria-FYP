import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:arteria/l10n/app_localizations.dart';

class WeeklyOverviewCard extends StatelessWidget {
  final List<Map<String, dynamic>> readings;

  const WeeklyOverviewCard({super.key, required this.readings});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final now = DateTime.now();
    final dailySystolic = <String, List<int>>{};
    final dailyDiastolic = <String, List<int>>{};

    for (final reading in readings) {
      final dateValue = reading['date'];
      DateTime readingDate;
      if (dateValue is DateTime) {
        readingDate = dateValue;
      } else if (dateValue is Timestamp) {
        readingDate = dateValue.toDate();
      } else {
        continue;
      }

      final dayKey = DateFormat('EEE').format(readingDate);
      if (!dailySystolic.containsKey(dayKey)) {
        dailySystolic[dayKey] = [];
        dailyDiastolic[dayKey] = [];
      }

      final systolic = reading['systolic'] as int?;
      final diastolic = reading['diastolic'] as int?;

      if (systolic != null) dailySystolic[dayKey]!.add(systolic);
      if (diastolic != null) dailyDiastolic[dayKey]!.add(diastolic);
    }

    // Show the last 7 days including today
    final List<String> last7Days = [];
    for (int i = 6; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      last7Days.add(DateFormat('EEE').format(d));
    }

    final formattedData = <Map<String, dynamic>>[];
    for (final day in last7Days) {
      final sValues = dailySystolic[day] ?? [];
      final dValues = dailyDiastolic[day] ?? [];

      if (sValues.isNotEmpty) {
        final sAvg = sValues.reduce((a, b) => a + b) ~/ sValues.length;
        final dAvg = dValues.isNotEmpty
            ? dValues.reduce((a, b) => a + b) ~/ dValues.length
            : 0;

        formattedData.add({
          'day': day,
          'sysAvg': sAvg,
          'diaAvg': dAvg,
          'count': sValues.length,
        });
      } else {
        formattedData.add({'day': day, 'sysAvg': 0, 'diaAvg': 0, 'count': 0});
      }
    }

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
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF3B82F6,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.analytics_rounded,
                            size: 22,
                            color: Color(0xFF3B82F6),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          AppLocalizations.of(context)!.weeklyThisWeek,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.weeklyReadings(
                          formattedData.fold<int>(
                            0,
                            (acc, d) =>
                                acc + ((d['count'] as num?)?.toInt() ?? 0),
                          ),
                        ),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF3B82F6),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildSimpleChart(formattedData, isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSimpleChart(List<Map<String, dynamic>> weeklyData, bool isDark) {
    final maxValue = weeklyData.fold<int>(0, (max, d) {
      final sys = d['sysAvg'] as int? ?? 0;
      return sys > max ? sys : max;
    });
    // Show from a baseline to emphasize variations in systolic pressure
    final minValue = maxValue > 0 ? (maxValue * 0.6).toInt() : 0;
    final range = maxValue - minValue > 0 ? maxValue - minValue : 1;

    return SizedBox(
      height: 100,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: weeklyData.map((data) {
          final sys = data['sysAvg'] as int? ?? 0;
          final count = data['count'] as int? ?? 0;
          final bool hasData = count > 0;
          final double heightPercent = hasData
              ? ((sys - minValue) / range).clamp(0.2, 1.0).toDouble()
              : 0.2;

          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (hasData)
                  Text(
                    '$sys',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF3B82F6),
                    ),
                  )
                else
                  const SizedBox(height: 16),
                const SizedBox(height: 4),
                Expanded(
                  child: Container(
                    width: 32,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: hasData
                            ? [const Color(0xFF3B82F6), const Color(0xFF60A5FA)]
                            : [
                                const Color(0xFF3B82F6).withValues(alpha: 0.2),
                                const Color(0xFF3B82F6).withValues(alpha: 0.1),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.bottomCenter,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      height: hasData ? 80 * heightPercent : 16,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  data['day'] as String,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.5)
                        : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
