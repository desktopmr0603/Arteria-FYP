import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// BP Anomaly Detection and Trend Forecasting Service
/// Provides intelligent anomaly detection and 7-day trend predictions
/// using statistical methods (when LSTM model is not loaded) or ML model.
/// Features:
/// - Detects unusual BP readings based on personal baseline
/// - Identifies sudden spikes or drops
/// - Forecasts 7-day trend direction
/// - Provides explainable alerts
class BPAnomalyRemoteDataSource {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // User's personal baseline statistics
  double? _baselineSystolicMean;
  double? _baselineSystolicStd;
  double? _baselineDiastolicMean;
  double? _baselineDiastolicStd;

  // Anomaly detection thresholds
  static const double _zScoreThreshold = 2.0; // 2 standard deviations
  static const double _spikeThreshold = 25.0; // mmHg sudden change
  static const int _minimumReadingsForBaseline = 5;

  /// Check if user has enough data for baseline calculation
  bool get hasBaseline => _baselineSystolicMean != null && _baselineDiastolicMean != null;
  
  /// Get baseline status message for user feedback
  String get baselineStatus {
    if (hasBaseline) {
      return 'Personal baseline established from your readings';
    }
    return 'Need ${_minimumReadingsForBaseline - (_baselineSystolicMean == null ? 0 : 1)} more readings to establish your baseline';
  }

  /// Initialize the service and calculate user baseline
  Future<void> initialize(String userId) async {
    await _calculateUserBaseline(userId);
  }

  /// Calculate user's personal BP baseline from historical data
  Future<void> _calculateUserBaseline(String userId) async {
    try {
      final cutoffDate = DateTime.now().subtract(const Duration(days: 30));

      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('readings')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(cutoffDate))
          .orderBy('date', descending: true)
          .limit(100)
          .get();

      if (snapshot.docs.length < _minimumReadingsForBaseline) {
        debugPrint('⚠️ Not enough readings for baseline calculation');
        return;
      }

      final systolicValues = <double>[];
      final diastolicValues = <double>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data['systolic'] != null) {
          systolicValues.add((data['systolic'] as num).toDouble());
        }
        if (data['diastolic'] != null) {
          diastolicValues.add((data['diastolic'] as num).toDouble());
        }
      }

      if (systolicValues.isNotEmpty) {
        _baselineSystolicMean = _mean(systolicValues);
        _baselineSystolicStd = _standardDeviation(systolicValues);
      }

      if (diastolicValues.isNotEmpty) {
        _baselineDiastolicMean = _mean(diastolicValues);
        _baselineDiastolicStd = _standardDeviation(diastolicValues);
      }

      debugPrint(
        '✅ Baseline calculated: Sys ${_baselineSystolicMean?.toStringAsFixed(1)} ± ${_baselineSystolicStd?.toStringAsFixed(1)}, '
        'Dia ${_baselineDiastolicMean?.toStringAsFixed(1)} ± ${_baselineDiastolicStd?.toStringAsFixed(1)}',
      );
    } catch (e) {
      debugPrint('❌ Error calculating baseline: $e');
    }
  }

  /// Detect if a BP reading is anomalous based on user's baseline
  AnomalyResult detectAnomaly({
    required int systolic,
    required int diastolic,
    int? previousSystolic,
    int? previousDiastolic,
  }) {
    final anomalies = <AnomalyType>[];
    final explanations = <String>[];
    double? deviationValue;
    int? changeValue;
    double severity = 0.0;

    // Essentially, this is Check #1: Comparing the new reading to YOUR Normal
    // Z-score based anomaly detection (deviation from personal baseline)
    if (_baselineSystolicMean != null &&
        _baselineSystolicStd != null &&
        _baselineSystolicStd! > 0) {
      final systolicZScore =
          (systolic - _baselineSystolicMean!) / _baselineSystolicStd!;

      if (systolicZScore.abs() > _zScoreThreshold) {
        anomalies.add(AnomalyType.deviationFromBaseline);
        final deviation = (systolic - _baselineSystolicMean!).round();
        deviationValue = deviation.toDouble();
        if (systolicZScore > 0) {
          explanations.add(
            'Your systolic reading is ${deviation.abs()} millimeters of mercury higher than your usual average.',
          );
        } else {
          explanations.add(
            'Your systolic reading is ${deviation.abs()} millimeters of mercury lower than your usual average.',
          );
        }
        severity = max(
          severity,
          systolicZScore.abs() / 3.0,
        ); // Normalize to 0-1
      }
    }

    if (_baselineDiastolicMean != null &&
        _baselineDiastolicStd != null &&
        _baselineDiastolicStd! > 0) {
      final diastolicZScore =
          (diastolic - _baselineDiastolicMean!) / _baselineDiastolicStd!;

      if (diastolicZScore.abs() > _zScoreThreshold) {
        if (!anomalies.contains(AnomalyType.deviationFromBaseline)) {
          anomalies.add(AnomalyType.deviationFromBaseline);
        }
        final deviation = (diastolic - _baselineDiastolicMean!).round();
        if (deviationValue == null || deviationValue.abs() < deviation.abs()) {
          deviationValue = deviation
              .toDouble(); // Prioritize larger deviation or just store one
        }

        if (diastolicZScore > 0) {
          explanations.add(
            'Your diastolic reading is ${deviation.abs()} millimeters of mercury higher than usual.',
          );
        } else {
          explanations.add(
            'Your diastolic reading is ${deviation.abs()} millimeters of mercury lower than usual.',
          );
        }
        severity = max(severity, diastolicZScore.abs() / 3.0);
      }
    }

    // This checks whether there was a sudden spike or drop from previous reading (could be yesterday)
    if (previousSystolic != null) {
      final systolicChange = systolic - previousSystolic;
      if (systolicChange.abs() > _spikeThreshold) {
        anomalies.add(
          systolicChange > 0 ? AnomalyType.suddenSpike : AnomalyType.suddenDrop,
        );
        changeValue = systolicChange;
        if (systolicChange > 0) {
          explanations.add(
            'This is a sudden increase of $systolicChange millimeters of mercury from your previous reading.',
          );
        } else {
          explanations.add(
            'This is a sudden decrease of ${systolicChange.abs()} millimeters of mercury from your previous reading.',
          );
        }
        severity = max(severity, systolicChange.abs() / 50.0);
      }
    }

    // Time-of-day pattern detection would go here with LSTM model

    // Determine overall risk level
    AnomalyRiskLevel riskLevel;
    if (severity > 0.8 || anomalies.contains(AnomalyType.suddenSpike)) {
      riskLevel = AnomalyRiskLevel.high;
    } else if (severity > 0.4) {
      riskLevel = AnomalyRiskLevel.moderate;
    } else if (anomalies.isNotEmpty) {
      riskLevel = AnomalyRiskLevel.low;
    } else {
      riskLevel = AnomalyRiskLevel.none;
    }

    return AnomalyResult(
      isAnomaly: anomalies.isNotEmpty,
      anomalyTypes: anomalies,
      explanations: explanations,
      severity: severity.clamp(0.0, 1.0),
      riskLevel: riskLevel,
      recommendation: _generateRecommendation(riskLevel, anomalies),
      deviationValue: deviationValue,
      changeValue: changeValue,
    );
  }

  /// Forecast 7-day BP trend using exponential moving average
  /// Returns predicted direction and confidence
  Future<TrendForecast> forecastTrend(String userId) async {
    try {
      final cutoffDate = DateTime.now().subtract(const Duration(days: 14));

      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('readings')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(cutoffDate))
          .orderBy(
            'date',
            descending: false,
          ) // Oldest first for trend calculation
          .get();

      if (snapshot.docs.length < 3) {
        return TrendForecast(
          direction: TrendDirection.stable,
          confidence: 0.0,
          predictedChange: 0,
          explanation:
              'Not enough data to forecast trends. Keep recording daily readings!',
        );
      }

      final systolicValues = <double>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data['systolic'] != null) {
          systolicValues.add((data['systolic'] as num).toDouble());
        }
      }

      // Calculate trend using linear regression
      final slope = _calculateLinearSlope(systolicValues);
      final predictedWeeklyChange = slope * 7; // Extrapolate to 7 days

      // Calculate confidence based on R² value
      final rSquared = _calculateRSquared(systolicValues);

      TrendDirection direction;
      if (predictedWeeklyChange > 5) {
        direction = TrendDirection.increasing;
      } else if (predictedWeeklyChange < -5) {
        direction = TrendDirection.decreasing;
      } else {
        direction = TrendDirection.stable;
      }

      String explanation;
      if (direction == TrendDirection.increasing) {
        explanation =
            'Your blood pressure appears to be trending upward. '
            'Consider reviewing your sodium intake and stress levels.';
      } else if (direction == TrendDirection.decreasing) {
        explanation =
            'Great news! Your blood pressure is showing a downward trend. '
            'Keep up your current healthy habits.';
      } else {
        explanation =
            'Your blood pressure is stable. '
            'Continue monitoring and maintaining your current routine.';
      }

      return TrendForecast(
        direction: direction,
        confidence: rSquared.clamp(0.0, 1.0),
        predictedChange: predictedWeeklyChange.round(),
        explanation: explanation,
      );
    } catch (e) {
      debugPrint('❌ Error forecasting trend: $e');
      return TrendForecast(
        direction: TrendDirection.stable,
        confidence: 0.0,
        predictedChange: 0,
        explanation: 'Unable to calculate trend at this time.',
      );
    }
  }

  // Statistical helper methods
  double _mean(List<double> values) {
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  double _standardDeviation(List<double> values) {
    if (values.length < 2) return 0;
    final avg = _mean(values);
    final variance =
        values.map((v) => pow(v - avg, 2)).reduce((a, b) => a + b) /
        (values.length - 1);
    return sqrt(variance);
  }

  double _calculateLinearSlope(List<double> values) {
    if (values.length < 2) return 0;

    final n = values.length;
    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;

    for (int i = 0; i < n; i++) {
      sumX += i;
      sumY += values[i];
      sumXY += i * values[i];
      sumX2 += i * i;
    }

    final denominator = (n * sumX2 - sumX * sumX);
    if (denominator == 0) return 0;

    return (n * sumXY - sumX * sumY) / denominator;
  }

  double _calculateRSquared(List<double> values) {
    if (values.length < 3) return 0;

    final slope = _calculateLinearSlope(values);
    final intercept = _mean(values) - slope * (values.length - 1) / 2;

    double ssTot = 0, ssRes = 0;
    final avg = _mean(values);

    for (int i = 0; i < values.length; i++) {
      final predicted = intercept + slope * i;
      ssTot += pow(values[i] - avg, 2);
      ssRes += pow(values[i] - predicted, 2);
    }

    if (ssTot == 0) return 0;
    return 1 - (ssRes / ssTot);
  }

  String _generateRecommendation(
    AnomalyRiskLevel riskLevel,
    List<AnomalyType> anomalies,
  ) {
    switch (riskLevel) {
      case AnomalyRiskLevel.high:
        return 'I recommend taking another reading in 15 minutes while seated quietly. '
            'If readings remain elevated, please contact your healthcare provider.';
      case AnomalyRiskLevel.moderate:
        return 'Consider taking another reading later today to confirm this pattern. '
            'Note any factors like stress, caffeine, or missed medication.';
      case AnomalyRiskLevel.low:
        return 'This reading is slightly unusual for you. '
            'Continue monitoring as normal and look for any patterns.';
      case AnomalyRiskLevel.none:
        return 'This reading is consistent with your typical pattern.';
    }
  }
}

// Result classes
enum AnomalyType {
  deviationFromBaseline,
  suddenSpike,
  suddenDrop,
  timeOfDayAnomaly,
  highVariability,
}

enum AnomalyRiskLevel { none, low, moderate, high }

enum TrendDirection { increasing, stable, decreasing }

class AnomalyResult {
  final bool isAnomaly;
  final List<AnomalyType> anomalyTypes;
  final List<String> explanations;
  final double severity;
  final AnomalyRiskLevel riskLevel;
  final String recommendation;
  final double? deviationValue;
  final int? changeValue;

  AnomalyResult({
    required this.isAnomaly,
    required this.anomalyTypes,
    required this.explanations,
    required this.severity,
    required this.riskLevel,
    required this.recommendation,
    this.deviationValue,
    this.changeValue,
  });
}

class TrendForecast {
  final TrendDirection direction;
  final double confidence;
  final int predictedChange;
  final String explanation;

  TrendForecast({
    required this.direction,
    required this.confidence,
    required this.predictedChange,
    required this.explanation,
  });
}
