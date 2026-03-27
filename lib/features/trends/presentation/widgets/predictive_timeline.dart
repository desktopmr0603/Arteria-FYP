import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;

import '../../../../l10n/app_localizations.dart';
import '../../../home/data/data_sources/health_risk_score_service.dart';

/// Predictive Timeline Widget
class PredictiveTimeline extends StatefulWidget {
  final String userId;
  final HealthRiskScoreService riskScoreService;
  final bool isDark;

  const PredictiveTimeline({
    super.key,
    required this.userId,
    required this.riskScoreService,
    required this.isDark,
  });

  @override
  State<PredictiveTimeline> createState() => _PredictiveTimelineState();
}

class _PredictiveTimelineState extends State<PredictiveTimeline>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  List<PredictionPoint> _predictions = [];
  bool _isLoading = true;

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
      // Fetch real historical risk scores
      final historicalScores = await widget.riskScoreService
          .getHistoricalScores(widget.userId, days: 30);

      if (historicalScores.isNotEmpty) {
        _predictions = _generatePredictionsFromHistory(historicalScores);
      } else {
        // No historical data — show a flat minimal-risk baseline
        _predictions = _generateFallbackPredictions();
      }

      _isLoading = false;
      _animationController.forward();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error loading predictions: $e');
      // On error, show a flat baseline so the UI isn't empty
      _predictions = _generateFallbackPredictions();
      _isLoading = false;
      if (mounted) setState(() {});
    }
  }

  /// Build projections from real historical risk scores.
  /// Uses the recent trend (slope of last scores) to extrapolate forward.
  List<PredictionPoint> _generatePredictionsFromHistory(
    List<HistoricalScore> scores,
  ) {
    final now = DateTime.now();
    final predictions = <PredictionPoint>[];

    // Sort chronologically
    final sorted = [...scores]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Current risk = most recent score
    final currentRisk = sorted.last.score.toDouble().clamp(0.0, 100.0);

    // Calculate daily trend from recent scores
    double dailyTrend = 0.0;
    if (sorted.length >= 2) {
      // Use last few scores to estimate slope
      final recentCount = math.min(5, sorted.length);
      final recentScores = sorted.sublist(sorted.length - recentCount);
      final firstScore = recentScores.first.score.toDouble();
      final lastScore = recentScores.last.score.toDouble();
      final daySpan = recentScores.last.timestamp
              .difference(recentScores.first.timestamp)
              .inDays
              .toDouble();
      if (daySpan > 0) {
        dailyTrend = (lastScore - firstScore) / daySpan;
      }
    }

    // Clamp daily trend to reasonable range (-1.0 to +1.0 per day)
    dailyTrend = dailyTrend.clamp(-1.0, 1.0);

    // Generate projection points for the next 30 days
    for (int i = 0; i <= 30; i += 5) {
      final date = now.add(Duration(days: i));
      final projectedRisk = (currentRisk + dailyTrend * i).clamp(0.0, 100.0);
      // Confidence decreases as we project further into the future
      final confidence = math.max(0.4, 1.0 - (i / 45.0));

      predictions.add(
        PredictionPoint(
          date: date,
          riskScore: projectedRisk,
          confidence: confidence,
          factors: _getRiskFactors(projectedRisk),
        ),
      );
    }

    return predictions;
  }

  /// Fallback when no historical data is available —
  /// shows a flat low-risk baseline so the widget doesn't look broken.
  List<PredictionPoint> _generateFallbackPredictions() {
    final now = DateTime.now();
    final predictions = <PredictionPoint>[];

    for (int i = 0; i <= 30; i += 5) {
      final date = now.add(Duration(days: i));
      // Flat baseline with no trend
      const baseRisk = 10.0;

      predictions.add(
        PredictionPoint(
          date: date,
          riskScore: baseRisk,
          confidence: math.max(0.4, 1.0 - (i / 45.0)),
          factors: _getRiskFactors(baseRisk),
        ),
      );
    }

    return predictions;
  }

  List<String> _getRiskFactors(double risk) {
    final factors = <String>[];
    if (risk > 50) factors.add('BP Trend');
    if (risk > 60) factors.add('Lifestyle');
    if (risk > 70) factors.add('Stress');
    if (risk > 80) factors.add('Medication');
    return factors;
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
            ] else ...[
              _buildPredictionChart(),
              const SizedBox(height: 20),
              _buildKeyInsights(),
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

  Widget _buildPredictionChart() {
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      height: 200,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return LineChart(
            LineChartData(
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
                    interval: 5,
                    getTitlesWidget: (value, meta) {
                      final day = value.toInt();
                      return Text(
                        day % 10 == 0
                            ? '${l10n.predictiveTimelineDay} $day'
                            : '',
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
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: _predictions.asMap().entries.map((entry) {
                    return FlSpot(entry.key.toDouble(), entry.value.riskScore);
                  }).toList(),
                  isCurved: true,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                  ),
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                        radius: 4,
                        color: const Color(0xFF667EEA),
                        strokeWidth: 2,
                        strokeColor: widget.isDark
                            ? Colors.black
                            : Colors.white,
                      );
                    },
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF667EEA).withValues(alpha: 0.3),
                        const Color(0xFF764BA2).withValues(alpha: 0.1),
                      ],
                    ),
                  ),
                ),
              ],
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (group) {
                    return widget.isDark ? Colors.black87 : Colors.white;
                  },
                  tooltipRoundedRadius: 8,
                  getTooltipItems: (spots) {
                    return spots.map((spot) {
                      final index = spot.x.toInt();
                      if (index < _predictions.length) {
                        final prediction = _predictions[index];
                        return LineTooltipItem(
                          '${l10n.predictiveTimelineDay} ${index * 5}\n${l10n.predictiveTimelineRisk}: ${prediction.riskScore.toInt()}%\n${l10n.predictiveTimelineConfidence}: ${(prediction.confidence * 100).toInt()}%',
                          TextStyle(
                            color: widget.isDark
                                ? Colors.white
                                : Colors.black87,
                            fontSize: 12,
                          ),
                        );
                      }
                      return null;
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
    if (_predictions.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final currentRisk = _predictions.first.riskScore;
    final futureRisk = _predictions.last.riskScore;
    final riskChange = futureRisk - currentRisk;

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
            l10n.predictiveTimelineRiskProjection,
            '${riskChange > 0 ? '↑' : '↓'} ${riskChange.abs().toInt()}% ${l10n.predictiveTimelineOver30Days}',
            riskChange > 0 ? Colors.orange : Colors.green,
          ),
          const SizedBox(height: 8),
          _buildInsightItem(
            l10n.predictiveTimelineConfidenceLevel,
            '${((_predictions.last.confidence) * 100).toInt()}%',
            const Color(0xFF667EEA),
          ),
          if (_predictions.last.factors.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildInsightItem(
              l10n.predictiveTimelineKeyFactors,
              _predictions.last.factors
                  .map((f) => _localizeFactor(context, f))
                  .join(', '),
              Colors.purple,
            ),
          ],
        ],
      ),
    );
  }

  String _localizeFactor(BuildContext context, String factor) {
    final l10n = AppLocalizations.of(context)!;
    if (factor == 'BP Trend') return l10n.predictiveTimelineFactorBPTrend;
    if (factor == 'Lifestyle') return l10n.predictiveTimelineFactorLifestyle;
    if (factor == 'Stress') return l10n.predictiveTimelineFactorStress;
    if (factor == 'Medication') return l10n.predictiveTimelineFactorMedication;
    return factor;
  }

  Widget _buildInsightItem(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: widget.isDark ? Colors.white70 : Colors.black54,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
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

class PredictionPoint {
  final DateTime date;
  final double riskScore;
  final double confidence;
  final List<String> factors;

  PredictionPoint({
    required this.date,
    required this.riskScore,
    required this.confidence,
    required this.factors,
  });
}
