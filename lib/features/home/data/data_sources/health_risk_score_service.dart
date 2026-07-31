import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'bp_predictor_remote_data_source.dart';

/// Personalized Health Risk Score with Explainable AI
///
/// Extends the existing TFLite predictor with feature importance analysis
/// to provide users with actionable insights about their risk factors.
///
/// Features:
/// - Calculates comprehensive health risk score (0-100)
/// - Identifies top contributing risk factors
/// - Tracks risk score over time
/// - Generates personalized improvement recommendations
class HealthRiskScoreService {
  final BPPredictorRemoteDataSource _predictor = BPPredictorRemoteDataSource();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isInitialized = false;

  /// Initialize the service
  Future<void> initialize() async {
    if (!_isInitialized) {
      try {
        await _predictor.loadModel();
        _isInitialized = true;
        debugPrint('✅ Health Risk Score Service initialized successfully');
      } catch (e) {
        debugPrint('⚠️ Model loading failed, service will use fallback predictions: $e');
        _isInitialized = true; // Still mark as initialized to use fallbacks
      }
    }
  }

  Future<List<HistoricalScore>> getHistoricalScores(
    String userId, {
    int days = 30,
  }) {
    return _getHistoricalScores(userId, days: days);
  }

  /// Calculate comprehensive health risk score with feature importance
  Future<HealthRiskReport> calculateRiskScore({
    required String userId,
    required Map<String, dynamic> userFeatures,
  }) async {
    if (!_isInitialized || !_predictor.isLoaded) {
      await initialize();
    }

    try {
      // Get base risk prediction from TFLite model or fallback
      final baseRiskProbability = _predictor.predictRisk(userFeatures);
      final usedFallback = !_predictor.isModelAvailable;
      
      if (usedFallback) {
        debugPrint('⚠️ Using rule-based fallback prediction (ML model unavailable)');
      }

      // Calculate feature importance using perturbation analysis
      final featureImportance = await _calculateFeatureImportance(userFeatures);

      // Convert probability to 0-100 score
      final riskScore = (baseRiskProbability * 100).round();

      // Identify top risk factors
      final topFactors = _identifyTopFactors(featureImportance, userFeatures);

      // Generate personalized recommendations
      final recommendations = _generateRecommendations(
        topFactors,
        userFeatures,
      );

      // Determine risk category
      final category = _categorizeRisk(riskScore);

      // Save score to Firebase for longitudinal tracking
      await _saveRiskScore(userId, riskScore, category);

      // Get historical scores for trend
      final historicalScores = await _getHistoricalScores(userId);

      return HealthRiskReport(
        overallScore: riskScore,
        category: category,
        probability: baseRiskProbability,
        topFactors: topFactors,
        recommendations: recommendations,
        historicalScores: historicalScores,
        generatedAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('❌ Error calculating risk score: $e');
      rethrow;
    }
  }

  /// Calculate feature importance using perturbation-based analysis
  /// This approximates SHAP values for explainability
  Future<Map<String, double>> _calculateFeatureImportance(
    Map<String, dynamic> baseFeatures,
  ) async {
    final importance = <String, double>{};

    // Key modifiable factors to analyze
    final modifiableFactors = {
      'avg_systolic': {'low': 110.0, 'high': 140.0},
      'avg_diastolic': {'low': 70.0, 'high': 90.0},
      'sodium_intake': {'low': 1500.0, 'high': 4000.0},
      'sedentary_minutes': {'low': 180.0, 'high': 600.0},
      'total_cholesterol': {'low': 150.0, 'high': 240.0},
      'fasting_glucose': {'low': 80.0, 'high': 140.0},
      'smoker_status': {'low': 0.0, 'high': 1.0},
      'alcohol_use': {'low': 0.0, 'high': 1.0},
    };

    for (final entry in modifiableFactors.entries) {
      final featureName = entry.key;
      final range = entry.value;

      // Create perturbed features with low value
      final lowFeatures = Map<String, dynamic>.from(baseFeatures);
      lowFeatures[featureName] = range['low'];
      final lowScore = _predictor.predictRisk(lowFeatures);

      // Create perturbed features with high value
      final highFeatures = Map<String, dynamic>.from(baseFeatures);
      highFeatures[featureName] = range['high'];
      final highScore = _predictor.predictRisk(highFeatures);

      // Importance = how much the score changes when this feature varies
      final impactRange = (highScore - lowScore).abs();

      // Normalize by baseline sensitivity
      importance[featureName] = impactRange;
    }

    // Normalize importance to percentages
    final totalImportance = importance.values.reduce((a, b) => a + b);
    if (totalImportance > 0) {
      for (final key in importance.keys) {
        importance[key] = (importance[key]! / totalImportance) * 100;
      }
    }

    return importance;
  }

  /// Identify the top contributing risk factors
  List<RiskFactor> _identifyTopFactors(
    Map<String, double> importance,
    Map<String, dynamic> userFeatures,
  ) {
    final factors = <RiskFactor>[];

    // Sort by importance
    final sortedEntries = importance.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Take top 5 factors
    for (final entry in sortedEntries.take(5)) {
      final featureName = entry.key;
      final contributionPercent = entry.value;

      final currentValue = userFeatures[featureName];
      final status = _evaluateFactorStatus(featureName, currentValue);

      factors.add(
        RiskFactor(
          name: _getReadableName(featureName),
          technicalName: featureName,
          contributionPercent: contributionPercent.round(),
          currentValue: currentValue?.toString() ?? 'Unknown',
          status: status,
          explanation: _getFactorExplanation(featureName, currentValue, status),
        ),
      );
    }

    return factors;
  }

  /// Evaluate if a factor is in a good, moderate, or concerning range
  FactorStatus _evaluateFactorStatus(String featureName, dynamic value) {
    if (value == null) return FactorStatus.unknown;

    final numValue = (value is num)
        ? value.toDouble()
        : double.tryParse(value.toString()) ?? 0;

    switch (featureName) {
      case 'avg_systolic':
        if (numValue <= 120) return FactorStatus.good;
        if (numValue <= 130) return FactorStatus.moderate;
        return FactorStatus.concerning;
      case 'avg_diastolic':
        if (numValue <= 80) return FactorStatus.good;
        if (numValue <= 85) return FactorStatus.moderate;
        return FactorStatus.concerning;
      case 'sodium_intake':
        if (numValue <= 2000) return FactorStatus.good;
        if (numValue <= 2300) return FactorStatus.moderate;
        return FactorStatus.concerning;
      case 'sedentary_minutes':
        if (numValue <= 300) return FactorStatus.good;
        if (numValue <= 480) return FactorStatus.moderate;
        return FactorStatus.concerning;
      case 'smoker_status':
        return numValue == 0 ? FactorStatus.good : FactorStatus.concerning;
      case 'alcohol_use':
        return numValue == 0 ? FactorStatus.good : FactorStatus.moderate;
      default:
        return FactorStatus.unknown;
    }
  }

  /// Generate personalized recommendations based on risk factors
  List<HealthRecommendation> _generateRecommendations(
    List<RiskFactor> topFactors,
    Map<String, dynamic> userFeatures,
  ) {
    final recommendations = <HealthRecommendation>[];

    for (final factor in topFactors.where(
      (f) => f.status != FactorStatus.good,
    )) {
      switch (factor.technicalName) {
        case 'avg_systolic':
        case 'avg_diastolic':
          recommendations.add(
            HealthRecommendation(
              category: 'Blood Pressure',
              title: 'Monitor BP More Frequently',
              description:
                  'Your blood pressure readings are a key factor. '
                  'Consider daily monitoring and noting patterns related to meals, stress, and sleep.',
              impact:
                  'Could reduce risk by up to ${(factor.contributionPercent * 0.5).round()}%',
              priority: RecommendationPriority.high,
            ),
          );
          break;
        case 'sodium_intake':
          recommendations.add(
            HealthRecommendation(
              category: 'Diet',
              title: 'Reduce Sodium Intake',
              description:
                  'Aim for less than 2,300mg of sodium per day. '
                  'Focus on fresh foods and check labels for hidden sodium.',
              impact:
                  'Could reduce risk by up to ${(factor.contributionPercent * 0.4).round()}%',
              priority: RecommendationPriority.high,
            ),
          );
          break;
        case 'sedentary_minutes':
          recommendations.add(
            HealthRecommendation(
              category: 'Activity',
              title: 'Increase Daily Movement',
              description:
                  'Try to reduce sitting time by taking short walks. '
                  'Even 5-minute breaks every hour can make a difference.',
              impact:
                  'Could reduce risk by up to ${(factor.contributionPercent * 0.3).round()}%',
              priority: RecommendationPriority.medium,
            ),
          );
          break;
        case 'smoker_status':
          recommendations.add(
            HealthRecommendation(
              category: 'Lifestyle',
              title: 'Smoking Cessation',
              description:
                  'Quitting smoking is one of the most impactful changes for heart health. '
                  'Consider speaking with your doctor about cessation programs.',
              impact:
                  'Could reduce risk by up to ${(factor.contributionPercent * 0.8).round()}%',
              priority: RecommendationPriority.high,
            ),
          );
          break;
      }
    }

    // Limit to top 3 recommendations
    recommendations.sort(
      (a, b) => b.priority.index.compareTo(a.priority.index),
    );
    return recommendations.take(3).toList();
  }

  /// Categorize overall risk level
  RiskCategory _categorizeRisk(int score) {
    if (score < 20) return RiskCategory.low;
    if (score < 40) return RiskCategory.moderate;
    if (score < 60) return RiskCategory.elevated;
    if (score < 80) return RiskCategory.high;
    return RiskCategory.veryHigh;
  }

  /// Save risk score to Firebase for longitudinal tracking
  Future<void> _saveRiskScore(
    String userId,
    int score,
    RiskCategory category,
  ) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('risk_scores')
          .add({
            'score': score,
            'category': category.name,
            'timestamp': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      debugPrint('⚠️ Could not save risk score: $e');
    }
  }

  /// Get historical risk scores for trend visualization
  Future<List<HistoricalScore>> _getHistoricalScores(
    String userId, {
    int days = 30,
  }) async {
    try {
      final cutoff = DateTime.now().subtract(Duration(days: days));

      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('risk_scores')
          .where(
            'timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(cutoff),
          )
          .orderBy('timestamp', descending: false)
          .limit(30)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        final timestamp =
            (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
        return HistoricalScore(
          score: data['score'] as int,
          timestamp: timestamp,
        );
      }).toList();
    } catch (e) {
      debugPrint('⚠️ Could not fetch historical scores: $e');
      return [];
    }
  }

  /// Get human-readable name for a feature
  String _getReadableName(String technicalName) {
    const nameMap = {
      'avg_systolic': 'Average Systolic BP',
      'avg_diastolic': 'Average Diastolic BP',
      'sodium_intake': 'Sodium Intake',
      'sedentary_minutes': 'Sedentary Time',
      'total_cholesterol': 'Total Cholesterol',
      'fasting_glucose': 'Fasting Glucose',
      'smoker_status': 'Smoking Status',
      'alcohol_use': 'Alcohol Consumption',
    };
    return nameMap[technicalName] ?? technicalName;
  }

  /// Get explanation for a risk factor
  String _getFactorExplanation(
    String featureName,
    dynamic value,
    FactorStatus status,
  ) {
    final statusDesc = status == FactorStatus.good
        ? 'within healthy range'
        : status == FactorStatus.moderate
        ? 'slightly elevated'
        : 'above recommended levels';

    switch (featureName) {
      case 'avg_systolic':
        return 'Your average systolic blood pressure is $statusDesc, '
            'which accounts for a portion of your overall cardiovascular risk.';
      case 'sodium_intake':
        return 'Your estimated sodium intake is $statusDesc. '
            'High sodium can increase blood pressure in sensitive individuals.';
      case 'sedentary_minutes':
        return 'Your daily sedentary time is $statusDesc. '
            'Extended sitting is linked to higher cardiovascular risk.';
      default:
        return 'This factor is $statusDesc.';
    }
  }

  void dispose() {
    _predictor.dispose();
  }
}

// Enums and data classes
enum RiskCategory { low, moderate, elevated, high, veryHigh }

enum FactorStatus { good, moderate, concerning, unknown }

enum RecommendationPriority { low, medium, high }

class RiskFactor {
  final String name;
  final String technicalName;
  final int contributionPercent;
  final String currentValue;
  final FactorStatus status;
  final String explanation;

  RiskFactor({
    required this.name,
    required this.technicalName,
    required this.contributionPercent,
    required this.currentValue,
    required this.status,
    required this.explanation,
  });
}

class HealthRecommendation {
  final String category;
  final String title;
  final String description;
  final String impact;
  final RecommendationPriority priority;

  HealthRecommendation({
    required this.category,
    required this.title,
    required this.description,
    required this.impact,
    required this.priority,
  });
}

class HistoricalScore {
  final int score;
  final DateTime timestamp;

  HistoricalScore({required this.score, required this.timestamp});
}

class HealthRiskReport {
  final int overallScore;
  final RiskCategory category;
  final double probability;
  final List<RiskFactor> topFactors;
  final List<HealthRecommendation> recommendations;
  final List<HistoricalScore> historicalScores;
  final DateTime generatedAt;

  HealthRiskReport({
    required this.overallScore,
    required this.category,
    required this.probability,
    required this.topFactors,
    required this.recommendations,
    required this.historicalScores,
    required this.generatedAt,
  });

  /// Generate a natural language summary for TTS
  String toSpokenSummary() {
    final categoryDesc = {
      RiskCategory.low: 'low',
      RiskCategory.moderate: 'moderate',
      RiskCategory.elevated: 'elevated',
      RiskCategory.high: 'high',
      RiskCategory.veryHigh: 'very high',
    };

    final buffer = StringBuffer();
    buffer.write(
      'Your current health risk score is $overallScore out of 100, ',
    );
    buffer.write('which is considered ${categoryDesc[category]}. ');

    if (topFactors.isNotEmpty) {
      final topFactor = topFactors.first;
      buffer.write(
        'The biggest contributor to your score is ${topFactor.name}, ',
      );
      buffer.write(
        'accounting for about ${topFactor.contributionPercent} percent of your risk. ',
      );
    }

    if (recommendations.isNotEmpty) {
      buffer.write(
        'My top recommendation is: ${recommendations.first.title}. ',
      );
    }

    return buffer.toString();
  }
}
