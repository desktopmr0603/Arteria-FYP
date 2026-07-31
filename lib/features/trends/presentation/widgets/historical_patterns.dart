import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;

import '../../../../l10n/app_localizations.dart';
import '../../../home/data/data_sources/bp_anomaly_remote_data_source.dart'
    as anomaly;
import '../../domain/entities/trend_data.dart';

/// 1. PATTERN DETECTION:
///    - Morning Spike:
///      Compares the average blood pressure (BP) from 6–9am
///      with the average for the rest of the day.
///      If the morning average is 8+ mmHg higher,
///      it marks this as a pattern.
///
///    - Weekend Relief:
///      Compares average BP on weekdays vs weekends.
///      If weekday BP is 5+ mmHg higher,
///      it suggests possible work-related stress.
///
///    - High Variability:
///      Measures how much BP readings go up and down.
///      If readings often change by 10+ mmHg,
///      it marks this as inconsistent.
///
/// 2. ANOMALY DETECTION (Using Statistical Limits):
///    - Compares each reading to the user’s normal average.
///    - Checks for sudden increases or drops between readings.
///    - Uses BPAnomalyRemoteDataSource (a statistics-based service, not AI).
///    - Flags readings that are far from the user’s usual range.
///
/// 3. VISUAL PRESENTATION:
///    - Displays detected patterns with severity labels
///      (positive, moderate, high).
///    - Shows recent unusual readings with explanations
///      (e.g., spike of X mmHg, deviation of Y).
///    - Gives helpful recommendations for each detected pattern.

class HistoricalPatterns extends StatefulWidget {
  final String userId;
  final anomaly.BPAnomalyRemoteDataSource anomalyService;
  final bool isDark;
  final List<TrendData> trendData;

  const HistoricalPatterns({
    super.key,
    required this.userId,
    required this.anomalyService,
    required this.isDark,
    required this.trendData,
  });

  @override
  State<HistoricalPatterns> createState() => _HistoricalPatternsState();
}

class _HistoricalPatternsState extends State<HistoricalPatterns>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _patternAnimationController;
  List<HistoricalPattern> _patterns = [];
  List<AnomalyEvent> _anomalies = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _patternAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _loadPatternData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _patternAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadPatternData() async {
    try {
      _patterns = _generatePatternsFromReadings(widget.trendData);
      _anomalies = _generateAnomaliesFromReadings(widget.trendData);
      _isLoading = false;
      _animationController.forward();

      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          _patternAnimationController.forward();
        }
      });

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error loading pattern data: $e');
      _isLoading = false;
      if (mounted) setState(() {});
    }
  }

  List<HistoricalPattern> _generatePatternsFromReadings(
    List<TrendData> readings,
  ) {
    if (readings.length < 5) return [];

    final sorted = [...readings]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    double mean(List<int> xs) => xs.reduce((a, b) => a + b) / xs.length;
    double std(List<int> xs) {
      final m = mean(xs);
      final v =
          xs.map((x) => (x - m) * (x - m)).reduce((a, b) => a + b) / xs.length;
      return math.sqrt(v);
    }

    final morning = sorted
        .where((r) => r.timestamp.hour >= 6 && r.timestamp.hour <= 9)
        .toList();
    final rest = sorted
        .where((r) => r.timestamp.hour < 6 || r.timestamp.hour > 9)
        .toList();

    final patterns = <HistoricalPattern>[];

    if (morning.length >= 3 && rest.length >= 3) {
      final morningAvg = mean(morning.map((e) => e.systolic).toList());
      final restAvg = mean(rest.map((e) => e.systolic).toList());
      final diff = morningAvg - restAvg;

      if (diff >= 8) {
        patterns.add(
          HistoricalPattern(
            type: HistoricalPatternType.morningSpike,
            frequency: PatternFrequency.daily,
            severity: diff >= 15
                ? PatternSeverity.high
                : PatternSeverity.moderate,
            occurrences: morning.length,
            icon: Icons.wb_sunny,
            color: diff >= 15
                ? const Color(0xFFEF4444)
                : const Color(0xFFF59E0B),
            data: {'diff': diff.round()},
          ),
        );
      }
    }

    final weekend = sorted
        .where(
          (r) =>
              r.timestamp.weekday == DateTime.saturday ||
              r.timestamp.weekday == DateTime.sunday,
        )
        .toList();
    final weekday = sorted
        .where(
          (r) =>
              r.timestamp.weekday >= DateTime.monday &&
              r.timestamp.weekday <= DateTime.friday,
        )
        .toList();

    if (weekend.length >= 3 && weekday.length >= 3) {
      final weekendAvg = mean(weekend.map((e) => e.systolic).toList());
      final weekdayAvg = mean(weekday.map((e) => e.systolic).toList());
      final diff = weekdayAvg - weekendAvg;

      if (diff >= 5) {
        patterns.add(
          HistoricalPattern(
            type: HistoricalPatternType.weekendRelief,
            frequency: PatternFrequency.weekly,
            severity: PatternSeverity.positive,
            occurrences: weekend.length,
            icon: Icons.weekend,
            color: const Color(0xFF10B981),
            data: {'diff': diff.round()},
          ),
        );
      }
    }

    // Variability pattern (day-to-day swings)
    final sys = sorted.map((e) => e.systolic).toList();
    final dia = sorted.map((e) => e.diastolic).toList();
    final sysStd = std(sys);
    final diaStd = std(dia);
    final variability = (sysStd + diaStd) / 2;
    if (variability >= 10) {
      patterns.add(
        HistoricalPattern(
          type: HistoricalPatternType.highVariability,
          frequency: PatternFrequency.variable,
          severity: variability >= 15
              ? PatternSeverity.high
              : PatternSeverity.moderate,
          occurrences: sorted.length,
          icon: Icons.show_chart,
          color: variability >= 15
              ? const Color(0xFFEF4444)
              : const Color(0xFF8B5CF6),
          data: {'diff': variability.round()},
        ),
      );
    }

    return patterns;
  }

  List<AnomalyEvent> _generateAnomaliesFromReadings(List<TrendData> readings) {
    if (readings.length < 2) return [];

    final sorted = [...readings]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final anomalies = <AnomalyEvent>[];

    for (int i = 0; i < sorted.length; i++) {
      final current = sorted[i];
      final prev = i > 0 ? sorted[i - 1] : null;

      final result = widget.anomalyService.detectAnomaly(
        systolic: current.systolic,
        diastolic: current.diastolic,
        previousSystolic: prev?.systolic,
        previousDiastolic: prev?.diastolic,
      );

      if (!result.isAnomaly ||
          result.riskLevel == anomaly.AnomalyRiskLevel.none) {
        continue;
      }

      final severity = switch (result.riskLevel) {
        anomaly.AnomalyRiskLevel.high => AnomalySeverity.high,
        anomaly.AnomalyRiskLevel.moderate => AnomalySeverity.moderate,
        anomaly.AnomalyRiskLevel.low => AnomalySeverity.low,
        anomaly.AnomalyRiskLevel.none => AnomalySeverity.low,
      };

      final type = result.anomalyTypes.contains(anomaly.AnomalyType.suddenSpike)
          ? AnomalyType.systolicSpike
          : result.anomalyTypes.contains(anomaly.AnomalyType.suddenDrop)
          ? AnomalyType.diastolicDrop
          : AnomalyType.heartRateVariability;

      final data = <String, dynamic>{};
      if (result.deviationValue != null) {
        data['deviation'] = result.deviationValue;
      }
      if (result.changeValue != null) data['change'] = result.changeValue;

      // An anomaly is "resolved" only if a later reading returned to the
      // normal range (systolic <130 and diastolic <85). If no such later
      // reading exists, the anomaly is still pending.
      final bool resolved = sorted
          .skip(i + 1)
          .any((later) => later.systolic < 130 && later.diastolic < 85);

      anomalies.add(
        AnomalyEvent(
          timestamp: current.timestamp,
          type: type,
          severity: severity,
          reading: '${current.systolic}/${current.diastolic} mmHg',
          resolved: resolved,
          data: data,
        ),
      );
    }

    anomalies.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return anomalies.take(6).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: widget.isDark
              ? [
                  const Color(0xFF1A1F36).withValues(alpha: 0.8),
                  const Color(0xFF0E1225).withValues(alpha: 0.8),
                ]
              : [
                  Colors.white.withValues(alpha: 0.9),
                  const Color(0xFFF8FAFF).withValues(alpha: 0.9),
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            if (_isLoading) ...[
              _buildLoadingState(),
            ] else if (widget.trendData.length < 5) ...[
              _buildInsufficientDataState(),
            ] else ...[
              _buildPatternsOverview(),
              const SizedBox(height: 24),
              _buildPatternList(),
              const SizedBox(height: 24),
              _buildRecentAnomalies(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.query_stats, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.historicalPatternsTitle,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: widget.isDark ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                l10n.historicalPatternsSubtitle,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: widget.isDark ? Colors.white60 : Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInsufficientDataState() {
    final need = 5 - widget.trendData.length;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: widget.isDark
            ? Colors.white.withValues(alpha: 0.04)
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.lock_outline,
                  size: 20,
                  color: Color(0xFF8B5CF6),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Pattern detection locked',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: widget.isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            need > 0
                ? 'Log $need more reading${need == 1 ? '' : 's'} to unlock '
                      'morning spike, weekend relief and variability analysis.'
                : 'Keep logging — patterns appear once we have enough data.',
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.5,
              color: widget.isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      height: 300,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(
                const Color(0xFF8B5CF6),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.historicalPatternsAnalyzing,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: widget.isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatternsOverview() {
    final l10n = AppLocalizations.of(context)!;
    final positivePatterns = _patterns
        .where((p) => p.severity == PatternSeverity.positive)
        .length;
    final moderatePatterns = _patterns
        .where((p) => p.severity == PatternSeverity.moderate)
        .length;
    final totalAnomalies = _anomalies.length;

    return Row(
      children: [
        Expanded(
          child: _buildOverviewCard(
            l10n.historicalPatternsPositivePatterns,
            positivePatterns.toString(),
            const Color(0xFF10B981),
            Icons.check_circle_outline,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildOverviewCard(
            l10n.historicalPatternsNeedsAttention,
            moderatePatterns.toString(),
            const Color(0xFFF59E0B),
            Icons.warning_amber_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildOverviewCard(
            l10n.historicalPatternsRecentAnomalies,
            totalAnomalies.toString(),
            const Color(0xFFEF4444),
            Icons.error_outline,
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewCard(
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: widget.isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: widget.isDark ? Colors.white60 : Colors.black54,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildPatternList() {
    return AnimatedBuilder(
      animation: _patternAnimationController,
      builder: (context, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Detected Patterns',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: widget.isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            ..._patterns.asMap().entries.map((entry) {
              final index = entry.key;
              final pattern = entry.value;
              final delay = index * 0.1;
              final animationValue = (_patternAnimationController.value - delay)
                  .clamp(0.0, 1.0);

              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                margin: const EdgeInsets.only(bottom: 12),
                transform: Matrix4.translationValues(
                  0,
                  (1 - animationValue) * 20,
                  0,
                ),
                child: Opacity(
                  opacity: animationValue,
                  child: _buildPatternItem(pattern),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildPatternItem(HistoricalPattern pattern) {
    final l10n = AppLocalizations.of(context)!;
    String title = '';
    String description = '';
    String recommendation = '';

    final diff = pattern.data['diff'] ?? 0;

    switch (pattern.type) {
      case HistoricalPatternType.morningSpike:
        title = l10n.patternMorningSpikeTitle;
        description = l10n.patternMorningSpikeDescription(diff);
        recommendation = l10n.patternMorningSpikeRecommendation;
        break;
      case HistoricalPatternType.weekendRelief:
        title = l10n.patternWeekendReliefTitle;
        description = l10n.patternWeekendReliefDescription(diff);
        recommendation = l10n.patternWeekendReliefRecommendation;
        break;
      case HistoricalPatternType.highVariability:
        title = l10n.patternHighVariabilityTitle;
        description = l10n.patternHighVariabilityDescription(diff);
        recommendation = l10n.patternHighVariabilityRecommendation;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pattern.color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: pattern.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(pattern.icon, color: pattern.color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: widget.isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _buildFrequencyBadge(pattern.frequency),
                        _buildSeverityBadge(pattern.severity),
                        Text(
                          '${pattern.occurrences} ${l10n.historicalPatternsOccurrences}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: widget.isDark
                                ? Colors.white60
                                : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: widget.isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: pattern.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline, size: 14, color: pattern.color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    recommendation,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: pattern.color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFrequencyBadge(PatternFrequency frequency) {
    final l10n = AppLocalizations.of(context)!;
    Color color;
    String text;

    switch (frequency) {
      case PatternFrequency.daily:
        color = const Color(0xFFEF4444);
        text = l10n.historicalPatternsDaily;
        break;
      case PatternFrequency.weekly:
        color = const Color(0xFFF59E0B);
        text = l10n.historicalPatternsWeekly;
        break;
      case PatternFrequency.variable:
        color = const Color(0xFF8B5CF6);
        text = l10n.historicalPatternsVariable;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildSeverityBadge(PatternSeverity severity) {
    final l10n = AppLocalizations.of(context)!;
    Color color;
    String text;

    switch (severity) {
      case PatternSeverity.positive:
        color = const Color(0xFF10B981);
        text = l10n.historicalPatternsPositive;
        break;
      case PatternSeverity.moderate:
        color = const Color(0xFFF59E0B);
        text = l10n.historicalPatternsModerate;
        break;
      case PatternSeverity.high:
        color = const Color(0xFFEF4444);
        text = l10n.historicalPatternsHigh;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildRecentAnomalies() {
    final l10n = AppLocalizations.of(context)!;
    if (_anomalies.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.historicalPatternsRecentAnomalies,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: widget.isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        ..._anomalies.map((anomaly) => _buildAnomalyItem(anomaly)),
      ],
    );
  }

  Widget _buildAnomalyItem(AnomalyEvent anomaly) {
    final l10n = AppLocalizations.of(context)!;
    String contextText = '';

    final deviation = anomaly.data['deviation'] as double?;
    final change = anomaly.data['change'] as int?;

    if (deviation != null) {
      if (deviation > 0) {
        contextText = l10n.anomalyDeviationHigh(deviation.abs().toInt());
      } else {
        contextText = l10n.anomalyDeviationLow(deviation.abs().toInt());
      }
    } else if (change != null) {
      if (change > 0) {
        contextText = l10n.anomalySpikeIncrease(change.abs());
      } else {
        contextText = l10n.anomalySpikeDecrease(change.abs());
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: _getAnomalyColor(anomaly.severity), width: 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                anomaly.reading,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: widget.isDark ? Colors.white : Colors.black87,
                ),
              ),
              if (anomaly.resolved)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check, size: 12, color: Colors.green),
                      const SizedBox(width: 4),
                      Text(
                        l10n.anomalyResolved,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            contextText,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: widget.isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatDate(anomaly.timestamp),
            style: GoogleFonts.inter(
              fontSize: 12,
              color: widget.isDark ? Colors.white38 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Color _getAnomalyColor(AnomalySeverity severity) {
    switch (severity) {
      case AnomalySeverity.high:
        return const Color(0xFFEF4444);
      case AnomalySeverity.moderate:
        return const Color(0xFFF59E0B);
      case AnomalySeverity.low:
        return const Color(0xFF3B82F6);
    }
  }

  String _formatDate(DateTime date) {
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return l10n.historicalPatternsToday;
    } else if (difference.inDays == 1) {
      return l10n.historicalPatternsYesterday;
    } else if (difference.inDays < 7) {
      return l10n.historicalPatternsDaysAgo(difference.inDays);
    } else {
      return '${date.day}/${date.month}';
    }
  }
}

class HistoricalPattern {
  final HistoricalPatternType type;
  final PatternFrequency frequency;
  final PatternSeverity severity;
  final int occurrences;
  final IconData icon;
  final Color color;
  final Map<String, dynamic> data;

  HistoricalPattern({
    required this.type,
    required this.frequency,
    required this.severity,
    required this.occurrences,
    required this.icon,
    required this.color,
    this.data = const {},
  });
}

enum HistoricalPatternType { morningSpike, weekendRelief, highVariability }

class AnomalyEvent {
  final DateTime timestamp;
  final AnomalyType type;
  final AnomalySeverity severity;
  final String reading;
  final bool resolved;
  final Map<String, dynamic> data;

  AnomalyEvent({
    required this.timestamp,
    required this.type,
    required this.severity,
    required this.reading,
    required this.resolved,
    this.data = const {},
  });
}

enum PatternFrequency { daily, weekly, variable }

enum PatternSeverity { positive, moderate, high }

enum AnomalyType { systolicSpike, diastolicDrop, heartRateVariability }

enum AnomalySeverity { low, moderate, high }
