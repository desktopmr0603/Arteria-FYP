import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;

import '../../../../l10n/app_localizations.dart';
import '../../../home/data/data_sources/daily_risk_score_service.dart';

/// Predictive Timeline Widget
class PredictiveTimeline extends StatefulWidget {
  final String userId;
  final DailyRiskScoreService dailyRiskScoreService;
  final bool isDark;

  const PredictiveTimeline({
    super.key,
    required this.userId,
    required this.dailyRiskScoreService,
    required this.isDark,
  });

  @override
  State<PredictiveTimeline> createState() => _PredictiveTimelineState();
}

/// Minimum historical observations required for a defensible linear
/// regression projection.
const int _minHistoryForProjection = 7;

/// Forecast horizon (days forward from "now").
const int _forecastDays = 7;

/// Past window (days back from "now") shown on the chart for context.
const int _historyWindowDays = 14;

/// Risk band color palette — keep in sync with [DailyRiskScoreService]'s
/// band thresholds. Drives the EWMA line, key-insight chip colors, and
/// the projected-endpoint chip so the user can read state at a glance.
const Map<RiskBand, Color> _bandColors = {
  RiskBand.green: Color(0xFF10B981),
  RiskBand.amber: Color(0xFFF59E0B),
  RiskBand.orange: Color(0xFFFB923C),
  RiskBand.red: Color(0xFFEF4444),
};

RiskBand _bandFor(double score) {
  if (score < 30) return RiskBand.green;
  if (score < 60) return RiskBand.amber;
  if (score < 80) return RiskBand.orange;
  return RiskBand.red;
}

/// Two-sided 95% Student-t critical values, keyed by degrees of freedom.
/// The forecast runs on small samples (n can be as low as
/// [_minHistoryForProjection] ⇒ df as low as 5), where a flat Normal z≈1.96
/// understates the prediction interval. Beyond df=30 the t value is within
/// ~1% of 1.96, so we fall back to the Normal approximation there.
const Map<int, double> _tCritical95Table = {
  1: 12.706, 2: 4.303, 3: 3.182, 4: 2.776, 5: 2.571,
  6: 2.447, 7: 2.365, 8: 2.306, 9: 2.262, 10: 2.228,
  11: 2.201, 12: 2.179, 13: 2.160, 14: 2.145, 15: 2.131,
  16: 2.120, 17: 2.110, 18: 2.101, 19: 2.093, 20: 2.086,
  21: 2.080, 22: 2.074, 23: 2.069, 24: 2.064, 25: 2.060,
  26: 2.056, 27: 2.052, 28: 2.048, 29: 2.045, 30: 2.042,
};

/// Two-sided 95% Student-t critical value for [df] degrees of freedom,
/// falling back to the Normal approximation (1.96) for df<1 or df>30.
double _tCritical95(int df) {
  if (df < 1) return 1.96;
  return _tCritical95Table[df] ?? 1.96;
}

class _PredictiveTimelineState extends State<PredictiveTimeline>
    with TickerProviderStateMixin {
  late AnimationController _animationController;

  /// EWMA-smoothed historical line — drives both the visible curve and
  /// the OLS regression so the projection is robust to single-day spikes.
  List<_TimelinePoint> _historical = [];

  /// Raw daily DRS values overlaid as faint dots, so the user can see the
  /// underlying day-to-day variation behind the smoothed line.
  List<_TimelinePoint> _rawDaily = [];

  /// Forecasted scores with 95% prediction-interval bounds.
  List<_TimelinePoint> _projected = [];

  /// Regression slope in risk-score points per day (null if not fitted).
  double? _dailySlope;

  /// Risk band of the most recent EWMA value — drives line + chip colors.
  RiskBand _currentBand = RiskBand.green;

  /// Risk band of the projected endpoint — drives the "where you're heading"
  /// chip color so a green→red trajectory reads as a warning even mid-flight.
  RiskBand _projectedBand = RiskBand.green;

  bool _isLoading = true;
  bool _locked = false;
  int _availableObservations = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _loadPredictions();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadPredictions() async {
    try {
      final series = await widget.dailyRiskScoreService.getDailySeries(
        userId: widget.userId,
        days: _historyWindowDays,
      );
      _availableObservations = series.length;

      _rawDaily = series
          .map(
            (s) =>
                _TimelinePoint(date: s.date, value: s.drs, isProjection: false),
          )
          .toList();

      _historical = series
          .map(
            (s) => _TimelinePoint(
              date: s.date,
              value: s.ewma,
              isProjection: false,
            ),
          )
          .toList();

      if (series.length < _minHistoryForProjection) {
        _locked = true;
        _projected = const [];
      } else {
        _locked = false;
        _projected = _forecast(_historical, _rawDaily);
      }

      if (series.isNotEmpty) {
        _currentBand = series.last.band;
      }
      _projectedBand = _projected.isEmpty
          ? _currentBand
          : _bandFor(_projected.last.value);
    } catch (e) {
      debugPrint('Error loading predictions: $e');
      _locked = true;
      _historical = const [];
      _rawDaily = const [];
      _projected = const [];
    } finally {
      _isLoading = false;
      if (mounted) {
        _animationController.forward();
        setState(() {});
      }
    }
  }

  /// Ordinary-least-squares linear regression for the projected trend, then
  /// forecast `_forecastDays` days forward with a 95% prediction interval.
  ///
  /// The slope/intercept are fit on the EWMA-smoothed [history] (stable trend,
  /// robust to single-day spikes), but the interval's residual standard error
  /// is computed from the RAW daily values ([rawDaily]) around that same line.
  /// EWMA residuals are autocorrelated and artificially small, which made the
  /// band over-confident; raw residuals reflect the genuine day-to-day spread a
  /// future observation could land in, so the interval is honestly calibrated.
  List<_TimelinePoint> _forecast(
    List<_TimelinePoint> history,
    List<_TimelinePoint> rawDaily,
  ) {
    if (history.length < _minHistoryForProjection) return const [];

    // Encode each day as an integer offset from the first observation so the
    // regression is numerically stable regardless of absolute dates.
    final day0 = history.first.date;
    final xs = history
        .map((p) => p.date.difference(day0).inDays.toDouble())
        .toList();
    final ys = history.map((p) => p.value).toList();
    final n = xs.length;

    // Raw daily value aligned to each history point by date, falling back to
    // the smoothed value if a raw point is missing for that day.
    final rawByDate = <DateTime, double>{
      for (final p in rawDaily) p.date: p.value,
    };
    final rawY = [
      for (final p in history) rawByDate[p.date] ?? p.value,
    ];

    final xMean = xs.reduce((a, b) => a + b) / n;
    final yMean = ys.reduce((a, b) => a + b) / n;

    double sxy = 0;
    double sxx = 0;
    for (int i = 0; i < n; i++) {
      sxy += (xs[i] - xMean) * (ys[i] - yMean);
      sxx += (xs[i] - xMean) * (xs[i] - xMean);
    }

    // Degenerate case: all readings on the same day -> no slope, no CI.
    if (sxx == 0) {
      _dailySlope = 0;
      return List.generate(_forecastDays, (i) {
        final date = history.last.date.add(Duration(days: i + 1));
        return _TimelinePoint(
          date: date,
          value: yMean.clamp(0.0, 100.0),
          lower: yMean.clamp(0.0, 100.0),
          upper: yMean.clamp(0.0, 100.0),
          isProjection: true,
        );
      });
    }

    final slope = sxy / sxx;
    final intercept = yMean - slope * xMean;

    // Residual standard error from the RAW daily values around the fitted
    // trend line — our uncertainty per-point. Using raw (not EWMA) residuals
    // keeps the band from being artificially narrow.
    double ssRes = 0;
    for (int i = 0; i < n; i++) {
      final yHat = intercept + slope * xs[i];
      ssRes += (rawY[i] - yHat) * (rawY[i] - yHat);
    }
    final rse = math.sqrt(ssRes / math.max(1, n - 2));

    _dailySlope = slope;

    // 95% interval using the Student-t critical value for df = n-2. The
    // t-distribution (vs a flat Normal z≈1.96) properly widens the band for
    // the small samples this projection runs on (n can be as low as 7, giving
    // df=5 and t≈2.57 instead of 1.96 — a ~31% wider, more honest interval).
    final z = _tCritical95(n - 2);
    final sMeanX = xs.map((x) => (x - xMean) * (x - xMean)).reduce(
      (a, b) => a + b,
    );

    final forecasts = <_TimelinePoint>[];
    for (int i = 1; i <= _forecastDays; i++) {
      final xForecast = xs.last + i;
      final yHat = intercept + slope * xForecast;

      // Prediction-interval half-width widens with horizon and distance from
      // the mean of x (standard OLS formula).
      final se = rse *
          math.sqrt(
            1 +
                1 / n +
                ((xForecast - xMean) * (xForecast - xMean)) /
                    math.max(1e-9, sMeanX),
          );
      final halfWidth = z * se;

      forecasts.add(
        _TimelinePoint(
          date: history.last.date.add(Duration(days: i)),
          value: yHat.clamp(0.0, 100.0),
          lower: (yHat - halfWidth).clamp(0.0, 100.0),
          upper: (yHat + halfWidth).clamp(0.0, 100.0),
          isProjection: true,
        ),
      );
    }
    return forecasts;
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
            ] else if (_locked) ...[
              _buildLockedState(),
            ] else ...[
              _buildPlainSummary(),
              const SizedBox(height: 18),
              _buildChartLegend(),
              const SizedBox(height: 10),
              _buildPredictionChart(),
              const SizedBox(height: 20),
              _buildKeyInsights(),
              const SizedBox(height: 14),
              _buildMethodBadge(),
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
              colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.timeline, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.predictiveTimelineTitle,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: widget.isDark ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                l10n.predictiveTimelineSubtitle,
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

  Widget _buildLoadingState() {
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(
                const Color(0xFF667EEA),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.predictiveTimelineAnalyzing,
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

  /// Plain-language name for a risk band, so the takeaway reads as words
  /// ("Low", "High") rather than a number an unfamiliar user can't anchor.
  String _levelLabel(AppLocalizations l10n, RiskBand band) {
    switch (band) {
      case RiskBand.green:
        return l10n.predictiveTimelineLevelLow;
      case RiskBand.amber:
        return l10n.predictiveTimelineLevelModerate;
      case RiskBand.orange:
        return l10n.predictiveTimelineLevelElevated;
      case RiskBand.red:
        return l10n.predictiveTimelineLevelHigh;
    }
  }

  /// Hero takeaway: states the current risk level in plain words and where
  /// it's heading, in one sentence, colored and iconned so it's legible at a
  /// glance regardless of the reader's health literacy. Everything below is
  /// supporting detail for those who want it.
  Widget _buildPlainSummary() {
    if (_historical.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;

    final currentRisk = _historical.last.value;
    final futureRisk =
        _projected.isNotEmpty ? _projected.last.value : currentRisk;
    final change = futureRisk - currentRisk;
    final color = _bandColors[_currentBand]!;
    final level = _levelLabel(l10n, _currentBand);

    // A ±2-point move over the 7-day horizon is below the noise floor we'd
    // describe as a real direction, so treat it as "steady".
    final IconData trendIcon;
    final String outlook;
    if (change > 2) {
      trendIcon = Icons.trending_up_rounded;
      outlook = l10n.predictiveTimelineSummaryRising;
    } else if (change < -2) {
      trendIcon = Icons.trending_down_rounded;
      outlook = l10n.predictiveTimelineSummaryFalling;
    } else {
      trendIcon = Icons.trending_flat_rounded;
      outlook = l10n.predictiveTimelineSummarySteady;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: widget.isDark ? 0.16 : 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(trendIcon, size: 26, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.predictiveTimelineSummaryHeadline(level),
                  style: GoogleFonts.inter(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  outlook,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    height: 1.4,
                    color: widget.isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Plain-words key for the chart: maps each visual style to what it means,
  /// so the line/dashes/shaded band aren't left for the reader to decode.
  Widget _buildChartLegend() {
    final l10n = AppLocalizations.of(context)!;
    final textStyle = GoogleFonts.inter(
      fontSize: 12,
      color: widget.isDark ? Colors.white70 : Colors.black54,
    );
    Widget item(Widget swatch, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            swatch,
            const SizedBox(width: 6),
            Text(label, style: textStyle),
          ],
        );

    return Wrap(
      spacing: 18,
      runSpacing: 8,
      children: [
        item(
          Container(
            width: 18,
            height: 3,
            decoration: BoxDecoration(
              color: _bandColors[_currentBand]!,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          l10n.predictiveTimelineLegendRecorded,
        ),
        item(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              3,
              (_) => Container(
                width: 4,
                height: 3,
                margin: const EdgeInsets.only(right: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF764BA2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          l10n.predictiveTimelineLegendPredicted,
        ),
        item(
          Container(
            width: 18,
            height: 12,
            decoration: BoxDecoration(
              color: const Color(0xFF764BA2).withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(
                color: const Color(0xFF764BA2).withValues(alpha: 0.4),
              ),
            ),
          ),
          l10n.predictiveTimelineLegendRange,
        ),
      ],
    );
  }

  Widget _buildMethodBadge() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF667EEA).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.functions_rounded,
            size: 14,
            color: Color(0xFF667EEA),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              l10n.predictiveTimelineMethodBadge,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF667EEA),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockedState() {
    final l10n = AppLocalizations.of(context)!;
    final needed = _minHistoryForProjection - _availableObservations;
    return Container(
      padding: const EdgeInsets.all(18),
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
                  color: const Color(0xFF667EEA).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.timeline_rounded,
                  size: 20,
                  color: Color(0xFF667EEA),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.predictiveTimelineProjectionUnlocksSoon,
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
            needed > 0
                ? l10n.predictiveTimelineNeedMoreDays(
                    needed,
                    _availableObservations,
                    _minHistoryForProjection,
                  )
                : l10n.predictiveTimelineProcessingHistory,
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

  Widget _buildPredictionChart() {
    final l10n = AppLocalizations.of(context)!;
    final allPoints = [..._historical, ..._projected];
    if (allPoints.isEmpty) return const SizedBox.shrink();

    // X axis: days offset from earliest historical observation.
    final day0 = allPoints.first.date;
    double xOf(_TimelinePoint p) =>
        p.date.difference(day0).inDays.toDouble();

    final histSpots = _historical
        .map((p) => FlSpot(xOf(p), p.value))
        .toList();
    final rawSpots = _rawDaily
        .map((p) => FlSpot(xOf(p), p.value))
        .toList();
    final projSpots = _projected
        .map((p) => FlSpot(xOf(p), p.value))
        .toList();
    // Stitch the connecting point so the projected line starts visually from
    // the last historical value.
    if (histSpots.isNotEmpty && projSpots.isNotEmpty) {
      projSpots.insert(0, histSpots.last);
    }
    final upperSpots = _projected
        .map((p) => FlSpot(xOf(p), p.upper ?? p.value))
        .toList();
    final lowerSpots = _projected
        .map((p) => FlSpot(xOf(p), p.lower ?? p.value))
        .toList();
    if (histSpots.isNotEmpty && upperSpots.isNotEmpty) {
      upperSpots.insert(0, histSpots.last);
      lowerSpots.insert(0, histSpots.last);
    }

    // Anchor the x-axis to human reference points rather than raw day
    // offsets: where the oldest data sits, where "today" is (the past/future
    // boundary), and where the forecast ends.
    final double todayX =
        _historical.isNotEmpty ? xOf(_historical.last) : 0;
    final double maxX = xOf(allPoints.last);
    final int weeksAgo = math.max(1, (todayX / 7).round());

    return SizedBox(
      height: 240,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return LineChart(
            LineChartData(
              minY: 0,
              maxY: 100,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 20,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: widget.isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.grey.withValues(alpha: 0.2),
                    strokeWidth: 1,
                  );
                },
              ),
              titlesData: FlTitlesData(
                show: true,
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 20,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        '${value.toInt()}%',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: widget.isDark
                              ? Colors.white60
                              : Colors.black54,
                        ),
                      );
                    },
                  ),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1,
                    reservedSize: 28,
                    getTitlesWidget: (value, meta) {
                      // Only the two far-apart endpoints sit on the axis;
                      // "Today" lives on the divider line so the labels can't
                      // collide (they're just 7 days apart, and translations
                      // like French "Aujourd'hui"/"Dans 7 jours" are wide).
                      final day = value.round();
                      String? label;
                      if (day == 0) {
                        label =
                            l10n.predictiveTimelineAxisWeeksAgo(weeksAgo);
                      } else if (day == maxX.round()) {
                        label = l10n.predictiveTimelineAxisInDays(
                          _forecastDays,
                        );
                      } else {
                        return const SizedBox.shrink();
                      }
                      return SideTitleWidget(
                        axisSide: meta.axisSide,
                        space: 8,
                        fitInside:
                            SideTitleFitInsideData.fromTitleMeta(meta),
                        child: Text(
                          label,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: widget.isDark
                                ? Colors.white60
                                : Colors.black54,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                // 0 — EWMA-smoothed historical line (trend the user reads).
                // Colored by the *current* band, so a glance at the line
                // tells the user which clinical zone they're sitting in.
                LineChartBarData(
                  spots: histSpots,
                  isCurved: false,
                  color: _bandColors[_currentBand]!,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                ),
                // 1 — projected dashed line
                LineChartBarData(
                  spots: projSpots,
                  isCurved: false,
                  color: const Color(0xFF764BA2),
                  barWidth: 3,
                  dashArray: const [6, 4],
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) =>
                        FlDotCirclePainter(
                      radius: 3,
                      color: const Color(0xFF764BA2),
                      strokeWidth: 2,
                      strokeColor:
                          widget.isDark ? Colors.black : Colors.white,
                    ),
                  ),
                ),
                // 2 — upper CI
                LineChartBarData(
                  spots: upperSpots,
                  isCurved: false,
                  color: const Color(0xFF764BA2).withValues(alpha: 0.0),
                  barWidth: 0,
                  dotData: const FlDotData(show: false),
                ),
                // 3 — lower CI (fills between 2 and 3)
                LineChartBarData(
                  spots: lowerSpots,
                  isCurved: false,
                  color: const Color(0xFF764BA2).withValues(alpha: 0.0),
                  barWidth: 0,
                  dotData: const FlDotData(show: false),
                ),
                // 4 — raw daily DRS as faint dots (the actual observations
                // behind the smoothed trend). No line, dots only.
                LineChartBarData(
                  spots: rawSpots,
                  color: Colors.transparent,
                  barWidth: 0,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) =>
                        FlDotCirclePainter(
                      radius: 2.5,
                      color: _bandColors[_currentBand]!
                          .withValues(alpha: 0.45),
                      strokeWidth: 0,
                      strokeColor: Colors.transparent,
                    ),
                  ),
                ),
              ],
              betweenBarsData: [
                BetweenBarsData(
                  fromIndex: 2,
                  toIndex: 3,
                  color: const Color(0xFF764BA2).withValues(alpha: 0.18),
                ),
              ],
              // Vertical marker at "today" so the boundary between recorded
              // history (left) and prediction (right) is unmistakable.
              extraLinesData: ExtraLinesData(
                verticalLines: [
                  VerticalLine(
                    x: todayX,
                    color: widget.isDark
                        ? Colors.white.withValues(alpha: 0.25)
                        : Colors.black.withValues(alpha: 0.18),
                    strokeWidth: 1.5,
                    dashArray: const [4, 4],
                    label: VerticalLineLabel(
                      show: true,
                      alignment: Alignment.topRight,
                      padding: const EdgeInsets.only(left: 6, bottom: 4),
                      labelResolver: (_) =>
                          l10n.predictiveTimelineAxisToday,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: widget.isDark
                            ? Colors.white
                            : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (group) =>
                      widget.isDark ? Colors.black87 : Colors.white,
                  tooltipRoundedRadius: 8,
                  getTooltipItems: (spots) {
                    return spots.map((spot) {
                      // Bar 4 is the raw-dot overlay — its value is already
                      // represented by the EWMA tooltip at the same day, so
                      // skip it to avoid two tooltips per touch.
                      if (spot.barIndex == 4) return null;
                      final int dayOffset = spot.x.toInt();
                      _TimelinePoint? match;
                      for (final p in allPoints) {
                        if (p.date.difference(day0).inDays == dayOffset) {
                          match = p;
                          break;
                        }
                      }
                      if (match == null) return null;
                      final label = match.isProjection
                          ? l10n.predictiveTimelineTooltipProjected
                          : l10n.predictiveTimelineTooltipObserved;
                      final ciText = match.isProjection
                          ? '\n${l10n.predictiveTimelineTooltipCI(match.lower!.toInt(), match.upper!.toInt())}'
                          : '';
                      final riskText = l10n.predictiveTimelineTooltipRiskValue(
                        match.value.toInt(),
                      );
                      return LineTooltipItem(
                        '$label\n$riskText$ciText',
                        TextStyle(
                          color: widget.isDark
                              ? Colors.white
                              : Colors.black87,
                          fontSize: 12,
                        ),
                      );
                    }).toList();
                  },
                ),
                handleBuiltInTouches: true,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildKeyInsights() {
    if (_historical.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;

    final currentRisk = _historical.last.value;
    final futureRisk =
        _projected.isNotEmpty ? _projected.last.value : currentRisk;
    final riskChange = futureRisk - currentRisk;
    final slopePerWeek = (_dailySlope ?? 0) * 7;
    final ciHalfWidth = _projected.isNotEmpty
        ? (_projected.last.upper! - _projected.last.lower!) / 2
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF667EEA).withValues(alpha: 0.1),
            const Color(0xFF764BA2).withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF667EEA).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.predictiveTimelineKeyInsights,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: widget.isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          _buildInsightItem(
            l10n.predictiveTimelineInsightCurrentRisk,
            '${currentRisk.toInt()}%',
            _bandColors[_currentBand]!,
          ),
          const SizedBox(height: 8),
          _buildInsightItem(
            l10n.predictiveTimelineInsight7DayProjection,
            '${futureRisk.toInt()}%  '
                '(${riskChange >= 0 ? '+' : ''}${riskChange.toStringAsFixed(1)})',
            _bandColors[_projectedBand]!,
          ),
          const SizedBox(height: 8),
          _buildInsightItem(
            l10n.predictiveTimelineInsightWeeklyTrend,
            l10n.predictiveTimelineInsightPerWeek(
              '${slopePerWeek >= 0 ? '+' : ''}${slopePerWeek.toStringAsFixed(1)}',
            ),
            // Trend direction is the one place where direction-as-color
            // *is* meaningful: green = improving, amber = worsening.
            slopePerWeek > 0
                ? _bandColors[RiskBand.amber]!
                : _bandColors[RiskBand.green]!,
          ),
          const SizedBox(height: 8),
          _buildInsightItem(
            l10n.predictiveTimelineInsightProjectionUncertainty,
            '± ${ciHalfWidth.toStringAsFixed(1)}%',
            const Color(0xFF94A3B8),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightItem(String label, String value, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Wrap rather than ellipsize: longer translations (e.g. French)
        // stay fully readable across two lines instead of being truncated.
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.3,
              color: widget.isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          textAlign: TextAlign.right,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// A point on the predictive timeline. Historical points have only [value];
/// projected points additionally carry a 95% prediction-interval band via
/// [lower]/[upper].
class _TimelinePoint {
  final DateTime date;
  final double value;
  final double? lower;
  final double? upper;
  final bool isProjection;

  const _TimelinePoint({
    required this.date,
    required this.value,
    this.lower,
    this.upper,
    required this.isProjection,
  });
}
