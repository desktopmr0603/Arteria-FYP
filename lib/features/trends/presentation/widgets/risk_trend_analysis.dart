import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;

import '../../../../l10n/app_localizations.dart';
import '../../../home/data/data_sources/health_risk_score_service.dart';
import '../../domain/entities/trend_data.dart';

/// Risk Trend Analysis Widget
///
/// Displays comprehensive risk score analysis with historical trends,
/// feature importance, and intervention impact visualization.
class RiskTrendAnalysis extends StatefulWidget {
  final String userId;
  final HealthRiskScoreService riskScoreService;
  final bool isDark;
  final List<TrendData> trendData;

  const RiskTrendAnalysis({
    super.key,
    required this.userId,
    required this.riskScoreService,
    required this.isDark,
    required this.trendData,
  });

  @override
  State<RiskTrendAnalysis> createState() => _RiskTrendAnalysisState();
}

class _RiskTrendAnalysisState extends State<RiskTrendAnalysis>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _featureAnimationController;
  List<RiskDataPoint> _riskHistory = [];
  List<FeatureImpact> _featureImpacts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _featureAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _loadRiskData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _featureAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadRiskData() async {
    try {
      final historicalScores = await widget.riskScoreService
          .getHistoricalScores(widget.userId, days: 90);

      if (historicalScores.isNotEmpty) {
        _riskHistory = _riskHistoryFromScores(historicalScores);
      } else {
        _riskHistory = _riskHistoryFromReadings(widget.trendData);
      }

      // Fetch real medical profile to enrich feature impacts
      Map<String, dynamic> medicalProfile = {};
      try {
        final medicalDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .collection('medicalProfile')
            .doc('current')
            .get();
        if (medicalDoc.exists) {
          medicalProfile = medicalDoc.data() ?? {};
        }
      } catch (e) {
        debugPrint('Could not fetch medical profile for impacts: $e');
      }

      _featureImpacts = _computeFeatureImpacts(
        widget.trendData,
        medicalProfile,
      );
      _isLoading = false;
      _animationController.forward();

      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _featureAnimationController.forward();
        }
      });

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error loading risk data: $e');
      _isLoading = false;
      if (mounted) setState(() {});
    }
  }

  List<RiskDataPoint> _riskHistoryFromScores(List<HistoricalScore> scores) {
    final sorted = [...scores]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return sorted.map((s) {
      final risk = s.score.toDouble().clamp(0.0, 100.0);
      return RiskDataPoint(
        date: s.timestamp,
        riskScore: risk,
        category: _getRiskCategory(risk),
      );
    }).toList();
  }

  List<RiskDataPoint> _riskHistoryFromReadings(List<TrendData> readings) {
    if (readings.isEmpty) return [];

    final sorted = [...readings]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final byDay = <DateTime, List<TrendData>>{};

    for (final r in sorted) {
      final day = DateTime(
        r.timestamp.year,
        r.timestamp.month,
        r.timestamp.day,
      );
      byDay[day] = (byDay[day] ?? [])..add(r);
    }

    final points = byDay.entries.map((e) {
      final dayReadings = e.value;
      final avgSys =
          dayReadings.map((d) => d.systolic).reduce((a, b) => a + b) /
          dayReadings.length;
      final avgDia =
          dayReadings.map((d) => d.diastolic).reduce((a, b) => a + b) /
          dayReadings.length;

      // Heuristic risk score derived from BP category severity + distance from 120/80.
      final severityRisk = _bpSeverity(avgSys.round(), avgDia.round()) * 20.0;
      final sysDelta = math.max(0.0, avgSys - 120.0) * 0.4;
      final diaDelta = math.max(0.0, avgDia - 80.0) * 0.7;
      final risk = (severityRisk + sysDelta + diaDelta).clamp(0.0, 100.0);

      return RiskDataPoint(
        date: e.key,
        riskScore: risk,
        category: _getRiskCategory(risk),
      );
    }).toList();

    points.sort((a, b) => a.date.compareTo(b.date));
    return points;
  }

  int _bpSeverity(int systolic, int diastolic) {
    if (systolic >= 180 || diastolic >= 120) return 4;
    if (systolic >= 140 || diastolic >= 90) return 3;
    if (systolic >= 130 || diastolic > 80) return 2;
    if (systolic > 120 && diastolic <= 80) return 1;
    return 0;
  }

  List<FeatureImpact> _computeFeatureImpacts(
    List<TrendData> readings,
    Map<String, dynamic> medicalProfile,
  ) {
    final impacts = <FeatureImpact>[];

    if (readings.length < 3) {
      return [
        FeatureImpact(
          name: 'Blood Pressure',
          impact: 100.0,
          trend: 0.0,
          color: const Color(0xFFEF4444),
          icon: Icons.favorite,
        ),
      ];
    }

    final sorted = [...readings]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final takeN = math.min(7, sorted.length);
    final recent = sorted.sublist(sorted.length - takeN);

    double mean(List<int> xs) => xs.reduce((a, b) => a + b) / xs.length;
    double std(List<int> xs) {
      final m = mean(xs);
      final v =
          xs.map((x) => (x - m) * (x - m)).reduce((a, b) => a + b) / xs.length;
      return math.sqrt(v);
    }

    final sysAll = sorted.map((e) => e.systolic).toList();
    final diaAll = sorted.map((e) => e.diastolic).toList();
    final sysRecent = recent.map((e) => e.systolic).toList();
    final diaRecent = recent.map((e) => e.diastolic).toList();

    final sysTrend = mean(sysAll) - mean(sysRecent);
    final diaTrend = mean(diaAll) - mean(diaRecent);

    final sysStd = std(sysAll);
    final diaStd = std(diaAll);
    final variability = ((sysStd + diaStd) / 2).clamp(0.0, 30.0);

    // === BP-based impacts ===
    final sysImpactRaw = (mean(sysAll) - 110.0).abs();
    final diaImpactRaw = (mean(diaAll) - 70.0).abs();
    final varImpactRaw = variability;

    // === Lifestyle-based impacts from medical profile ===
    double smokingImpact = 0;
    double bmiImpact = 0;
    double activityImpact = 0;
    double medicationImpact = 0;

    // Smoking status
    final isSmoker = (medicalProfile['smoker'] as bool?) == true;
    if (isSmoker) smokingImpact = 15.0;

    // BMI
    final weight = (medicalProfile['weight'] as num?)?.toDouble();
    final height = (medicalProfile['height'] as num?)?.toDouble();
    if (weight != null && height != null && height > 0) {
      final heightM = height / 100.0;
      final bmi = weight / (heightM * heightM);
      if (bmi > 30) {
        bmiImpact = 12.0;
      } else if (bmi > 25) {
        bmiImpact = 6.0;
      }
    }

    // Physical activity level
    final activityStr = (medicalProfile['physicalActivity'] as String?) ?? '';
    switch (activityStr.toLowerCase()) {
      case 'sedentary':
      case 'none':
        activityImpact = 10.0;
        break;
      case 'light':
      case 'low':
        activityImpact = 5.0;
        break;
      default:
        activityImpact = 0.0;
    }

    // Medication status
    final medications = medicalProfile['medications'] as String?;
    if (medications != null && medications.isNotEmpty) {
      medicationImpact = 5.0; // tracked as protective factor
    }

    // Normalize all impacts to sum to 100
    final totalRaw =
        sysImpactRaw +
        diaImpactRaw +
        varImpactRaw +
        smokingImpact +
        bmiImpact +
        activityImpact +
        medicationImpact;
    final denom = math.max(1.0, totalRaw);

    // Always include BP impacts
    impacts.addAll([
      FeatureImpact(
        name: 'Systolic BP',
        impact: (sysImpactRaw / denom) * 100,
        trend: sysTrend,
        color: const Color(0xFFEF4444),
        icon: Icons.arrow_upward,
      ),
      FeatureImpact(
        name: 'Diastolic BP',
        impact: (diaImpactRaw / denom) * 100,
        trend: diaTrend,
        color: const Color(0xFFF59E0B),
        icon: Icons.arrow_downward,
      ),
      FeatureImpact(
        name: 'BP Variability',
        impact: (varImpactRaw / denom) * 100,
        trend: 0.0,
        color: const Color(0xFF8B5CF6),
        icon: Icons.show_chart,
      ),
    ]);

    // Add lifestyle impacts only when they are meaningful
    if (smokingImpact > 0) {
      impacts.add(
        FeatureImpact(
          name: 'Smoking',
          impact: (smokingImpact / denom) * 100,
          trend: 0.0,
          color: const Color(0xFFDC2626),
          icon: Icons.smoke_free,
        ),
      );
    }

    if (bmiImpact > 0) {
      impacts.add(
        FeatureImpact(
          name: 'BMI',
          impact: (bmiImpact / denom) * 100,
          trend: 0.0,
          color: const Color(0xFFE67E22),
          icon: Icons.monitor_weight,
        ),
      );
    }

    if (activityImpact > 0) {
      impacts.add(
        FeatureImpact(
          name: 'Low Activity',
          impact: (activityImpact / denom) * 100,
          trend: 0.0,
          color: const Color(0xFF3B82F6),
          icon: Icons.directions_run,
        ),
      );
    }

    if (medicationImpact > 0) {
      impacts.add(
        FeatureImpact(
          name: 'On Medication',
          impact: (medicationImpact / denom) * 100,
          trend: 0.0,
          color: const Color(0xFF10B981),
          icon: Icons.medication,
        ),
      );
    }

    // Sort by impact descending
    impacts.sort((a, b) => b.impact.compareTo(a.impact));
    return impacts;
  }

  RiskCategory _getRiskCategory(double risk) {
    if (risk < 30) return RiskCategory.low;
    if (risk < 50) return RiskCategory.moderate;
    if (risk < 70) return RiskCategory.elevated;
    if (risk < 85) return RiskCategory.high;
    return RiskCategory.veryHigh;
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
                  const Color(0xFF1A1F36).withOpacity(0.8),
                  const Color(0xFF0E1225).withOpacity(0.8),
                ]
              : [
                  Colors.white.withOpacity(0.9),
                  const Color(0xFFF8FAFF).withOpacity(0.9),
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
              _buildRiskTrendChart(),
              const SizedBox(height: 24),
              _buildFeatureImpactAnalysis(),
              const SizedBox(height: 24),
              _buildRiskSummary(),
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
              colors: [Color(0xFF10B981), Color(0xFF059669)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.analytics, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.riskTrendAnalysisTitle,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: widget.isDark ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                l10n.riskTrendAnalysisSubtitle,
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
      height: 300,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(
                const Color(0xFF10B981),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.riskTrendAnalysisAnalyzing,
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
  // ...

  Widget _buildRiskTrendChart() {
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
                    interval: 15,
                    getTitlesWidget: (value, meta) {
                      final day = value.toInt();
                      return Text(
                        day % 15 == 0 ? '-${day}d' : '',
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
                  spots: _riskHistory.asMap().entries.map((entry) {
                    return FlSpot(entry.key.toDouble(), entry.value.riskScore);
                  }).toList(),
                  isCurved: true,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                  ),
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF10B981).withValues(alpha: 0.3),
                        const Color(0xFF059669).withValues(alpha: 0.1),
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
                      if (index < _riskHistory.length) {
                        final dataPoint = _riskHistory[index];
                        return LineTooltipItem(
                          '${dataPoint.date.day}/${dataPoint.date.month}\nRisk: ${dataPoint.riskScore.toInt()}%\n${dataPoint.category.displayName}',
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

  Widget _buildFeatureImpactAnalysis() {
    final l10n = AppLocalizations.of(context)!;
    return AnimatedBuilder(
      animation: _featureAnimationController,
      builder: (context, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.riskTrendAnalysisFeatureImpact,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: widget.isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            ..._featureImpacts.asMap().entries.map((entry) {
              final index = entry.key;
              final feature = entry.value;
              final delay = index * 0.1;
              final animationValue = (_featureAnimationController.value - delay)
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
                  child: _buildFeatureItem(feature),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildFeatureItem(FeatureImpact feature) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: feature.color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: feature.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(feature.icon, color: feature.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature.name,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: widget.isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  '${feature.impact.toInt()}% impact',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: widget.isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: feature.trend > 0
                  ? Colors.green.withValues(alpha: 0.1)
                  : Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  feature.trend > 0 ? Icons.trending_up : Icons.trending_down,
                  size: 14,
                  color: feature.trend > 0 ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 4),
                Text(
                  '${feature.trend.abs().toStringAsFixed(1)}%',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: feature.trend > 0 ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskSummary() {
    if (_riskHistory.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final currentRisk = _riskHistory.last.riskScore;
    final weeklyChange = _riskHistory.length >= 8
        ? (currentRisk - _riskHistory[_riskHistory.length - 8].riskScore)
        : 0.0;
    final monthlyChange = _riskHistory.length >= 30
        ? (currentRisk - _riskHistory[_riskHistory.length - 30].riskScore)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF10B981).withOpacity(0.1),
            const Color(0xFF059669).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.riskTrendAnalysisSummary,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: widget.isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  l10n.riskTrendAnalysisCurrentRisk,
                  '${currentRisk.toInt()}%',
                  _getRiskCategory(currentRisk).color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  l10n.riskTrendAnalysisWeeklyChange,
                  '${weeklyChange > 0 ? '+' : ''}${weeklyChange.toStringAsFixed(1)}%',
                  weeklyChange > 0 ? Colors.orange : Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  l10n.riskTrendAnalysisMonthlyChange,
                  '${monthlyChange > 0 ? '+' : ''}${monthlyChange.toStringAsFixed(1)}%',
                  monthlyChange > 0 ? Colors.orange : Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: widget.isDark ? Colors.white60 : Colors.black54,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class RiskDataPoint {
  final DateTime date;
  final double riskScore;
  final RiskCategory category;

  RiskDataPoint({
    required this.date,
    required this.riskScore,
    required this.category,
  });
}

class FeatureImpact {
  final String name;
  final double impact;
  final double trend;
  final Color color;
  final IconData icon;

  FeatureImpact({
    required this.name,
    required this.impact,
    required this.trend,
    required this.color,
    required this.icon,
  });
}

enum RiskCategory {
  low('Low Risk', Colors.green),
  moderate('Moderate Risk', Colors.yellow),
  elevated('Elevated Risk', Colors.orange),
  high('High Risk', Colors.red),
  veryHigh('Very High Risk', Colors.purple);

  const RiskCategory(this.displayName, this.color);
  final String displayName;
  final Color color;
}
