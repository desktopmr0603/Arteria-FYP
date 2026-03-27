import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

import '../features/home/data/data_sources/health_risk_score_service.dart';
import '../features/home/data/data_sources/bp_anomaly_remote_data_source.dart';
import '../features/home/data/repositories/medication_repository_impl.dart';

/// Natural Language Health Service
///
/// Processes conversational health queries using LLM to understand
/// natural language and provide contextual health information responses.
///
/// Supports conversational queries like:
/// - "How's my health doing?"
/// - "What are my stats?"
/// - "Tell me about my blood pressure"
/// - "Am I getting better?"
/// - "What's my risk score?"
/// - "Any concerns with my recent readings?"
class NaturalLanguageHealthService {
  final String _serverUrl;
  final String _userId;

  // Services for data retrieval
  final HealthRiskScoreService _riskScoreService = HealthRiskScoreService();
  final MedicationRepositoryImpl _medicationRepository =
      MedicationRepositoryImpl();

  NaturalLanguageHealthService({
    required String serverUrl,
    required String userId,
  }) : _serverUrl = serverUrl,
       _userId = userId;

  /// Analyze natural language health query and determine intent
  Future<HealthIntent> analyzeHealthQuery(
    String query, {
    String language = 'en',
  }) async {
    try {
      // Use LLM to understand the query intent
      final response = await http.post(
        Uri.parse('$_serverUrl/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'message':
              '''
Analyze this health query and determine the user's intent. Respond with JSON:

Query: "$query"

Possible intents:
- HEALTH_STATUS: General health overview request
- RISK_SCORE: Specific risk score inquiry
- BP_READINGS: Blood pressure data request
- ANOMALIES: Anomaly detection inquiry
- TRENDS: Health trend analysis request
- MEDICATION: Medication-related inquiry
- RECOMMENDATIONS: Health advice request
- COMPARISON: Health comparison over time

Respond with:
{
  "intent": "INTENT_NAME",
  "confidence": 0.95,
  "entities": {
    "timeframe": "recent/week/month/all",
    "metrics": ["bp", "risk", "medications"],
    "comparison": "current_vs_previous"
  },
  "response_type": "summary/detailed/analysis"
}
''',
          'user_id': _userId,
          'language': language, // Add language parameter
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return HealthIntent.fromJson(data['response'] ?? data);
      }
    } catch (e) {
      debugPrint('Error analyzing health query: $e');
    }

    // Fallback to basic keyword analysis
    return _fallbackIntentAnalysis(query);
  }

  /// Generate contextual health response based on intent
  Future<String> generateHealthResponse(
    HealthIntent intent, {
    String language = 'en',
  }) async {
    try {
      switch (intent.intent) {
        case HealthIntentType.healthStatus:
        case HealthIntentType.recommendations:
          return await _generateHealthStatusResponse(intent, language);
        case HealthIntentType.riskScore:
          return await _generateRiskScoreResponse(intent, language);
        case HealthIntentType.bpReadings:
          return await _generateBPReadingsResponse(intent, language);
        case HealthIntentType.anomalies:
          return await _generateAnomaliesResponse(intent, language);
        case HealthIntentType.trends:
          return await _generateTrendsResponse(intent, language);
        case HealthIntentType.medication:
          return await _generateMedicationResponse(intent, language);
        case HealthIntentType.comparison:
          return await _generateComparisonResponse(intent, language);
        default:
          return language == 'fr'
              ? "Je ne sais pas comment vous aider avec cela. Vous pouvez demander sur votre état de santé, score de risque, lectures de tension artérielle, ou tendances de santé."
              : "I'm not sure how to help with that. You can ask about your health status, risk score, blood pressure readings, or health trends.";
      }
    } catch (e) {
      debugPrint('Error generating health response: $e');
      return language == 'fr'
          ? "J'ai du mal à accéder à vos données de santé en ce moment. Veuillez réessayer dans un instant."
          : "I'm having trouble accessing your health data right now. Please try again in a moment.";
    }
  }

  Future<String> _generateHealthStatusResponse(
    HealthIntent intent,
    String language,
  ) async {
    // Get comprehensive health overview
    final userProfile = await _buildUserProfile();
    final riskReport = await _riskScoreService.calculateRiskScore(
      userId: _userId,
      userFeatures: userProfile,
    );

    final latestReading = await _getLatestBPReading();
    final recentAnomalies = await _getRecentAnomalies();

    final response = StringBuffer();
    final isFrench = language == 'fr';

    response.write(
      isFrench
          ? 'Basé sur vos données de santé récentes, '
          : 'Based on your recent health data, ',
    );

    // Overall status
    if (riskReport.overallScore < 40) {
      response.write(
        isFrench
            ? 'votre état de santé général semble bon. '
            : 'your overall health status is looking good. ',
      );
    } else if (riskReport.overallScore < 70) {
      response.write(
        isFrench
            ? 'votre état de santé montre quelques domaines à améliorer. '
            : 'your health status shows some areas for improvement. ',
      );
    } else {
      response.write(
        isFrench
            ? 'votre état de santé nécessite une attention. '
            : 'your health status requires attention. ',
      );
    }

    // Latest reading
    if (latestReading != null) {
      response.write(
        isFrench
            ? 'Votre dernière lecture était de ${latestReading['systolic']}/${latestReading['diastolic']} mmHg. '
            : 'Your most recent blood pressure was ${latestReading['systolic']}/${latestReading['diastolic']} mmHg. ',
      );
    }

    // Risk score
    response.write(
      isFrench
          ? 'Votre score de risque actuel est ${riskReport.overallScore} sur 100. '
          : 'Your current health risk score is ${riskReport.overallScore} out of 100. ',
    );

    // Top concern
    if (riskReport.topFactors.isNotEmpty) {
      final topFactor = riskReport.topFactors.first;
      response.write(
        isFrench
            ? 'Le principal facteur est ${topFactor.name.toLowerCase()}, contribuant à ${topFactor.contributionPercent} pour cent. '
            : 'The main factor affecting your score is ${topFactor.name.toLowerCase()}, contributing ${topFactor.contributionPercent} percent. ',
      );
    }

    // Anomalies
    if (recentAnomalies.isNotEmpty) {
      response.write(
        isFrench
            ? 'J\'ai détecté ${recentAnomalies.length} anomalie${recentAnomalies.length == 1 ? '' : 's'} récente${recentAnomalies.length == 1 ? '' : 's'}. '
            : 'I\'ve detected ${recentAnomalies.length} unusual pattern${recentAnomalies.length == 1 ? '' : 's'} in your recent readings. ',
      );
    }

    response.write(
      isFrench
          ? 'Comment vous sentez-vous globalement ces derniers jours? Avez-vous des symptômes ou des effets secondaires des médicaments?'
          : 'How have you been feeling overall? Are you experiencing any symptoms or side effects from your medications?',
    );

    return response.toString();
  }

  Future<String> _generateRiskScoreResponse(
    HealthIntent intent,
    String language,
  ) async {
    final userProfile = await _buildUserProfile();
    final riskReport = await _riskScoreService.calculateRiskScore(
      userId: _userId,
      userFeatures: userProfile,
    );

    final response = StringBuffer();
    final isFrench = language == 'fr';
    response.write(
      isFrench
          ? 'Votre score de risque actuel est ${riskReport.overallScore} sur 100, '
          : 'Your current health risk score is ${riskReport.overallScore} out of 100, ',
    );

    switch (riskReport.category) {
      case RiskCategory.low:
        response.write(
          isFrench
              ? 'ce qui est considéré comme un risque faible. '
              : 'which is considered low risk. ',
        );
        break;
      case RiskCategory.moderate:
        response.write(
          isFrench
              ? 'ce qui est dans la zone modérée. '
              : 'which is in the moderate range. ',
        );
        break;
      case RiskCategory.elevated:
        response.write(
          isFrench
              ? 'ce qui est élevé et mérite d\'être surveillé. '
              : 'which is elevated and worth monitoring. ',
        );
        break;
      case RiskCategory.high:
        response.write(
          isFrench
              ? 'ce qui est élevé et nécessite de l\'attention. '
              : 'which is high and requires attention. ',
        );
        break;
      case RiskCategory.veryHigh:
        response.write(
          isFrench
              ? 'ce qui est très élevé et doit être traité rapidement. '
              : 'which is very high and should be addressed promptly. ',
        );
        break;
    }

    if (riskReport.topFactors.isNotEmpty) {
      response.write(
        isFrench
            ? 'Les principaux facteurs sont : '
            : 'The main contributors to your score are: ',
      );
      for (int i = 0; i < riskReport.topFactors.length && i < 3; i++) {
        final factor = riskReport.topFactors[i];
        if (i > 0) response.write(', ');
        response.write('${factor.name} (${factor.contributionPercent}%)');
      }
      response.write('. ');
    }

    if (riskReport.historicalScores.isNotEmpty) {
      final recentScores = riskReport.historicalScores.length > 5
          ? riskReport.historicalScores.sublist(
              riskReport.historicalScores.length - 5,
            )
          : riskReport.historicalScores;
      final latest = recentScores.last;
      final previous = recentScores.length > 1
          ? recentScores[recentScores.length - 2]
          : null;

      if (previous != null) {
        final change = latest.score - previous.score;
        if (change.abs() > 5) {
          response.write(
            isFrench
                ? 'C\'est ${change > 0 ? 'plus élevé' : 'plus bas'} que votre score précédent de ${previous.score}. '
                : 'This is ${change > 0 ? 'higher' : 'lower'} than your previous score of ${previous.score}. ',
          );
        }
      }
    }

    response.write(
      isFrench
          ? 'Souhaitez-vous des conseils personnalisés pour améliorer ce score?'
          : 'Would you like personalized tips to improve this score?',
    );

    return response.toString();
  }

  Future<String> _generateBPReadingsResponse(
    HealthIntent intent,
    String language,
  ) async {
    final readings = await _getRecentReadings(
      intent.entities['timeframe'] ?? 'recent',
    );
    final isFrench = language == 'fr';

    if (readings.isEmpty) {
      return isFrench
          ? 'Je n\'ai pas de lectures de tension à partager. Essayez d\'enregistrer quelques mesures d\'abord.'
          : 'I don\'t have any blood pressure readings to share with you. Try recording some measurements first.';
    }

    final response = StringBuffer();
    response.write(
      isFrench
          ? 'Voici vos données de tension artérielle : '
          : 'Here\'s your blood pressure data: ',
    );

    final latest = readings.first;
    response.write(
      isFrench
          ? 'Votre dernière lecture était de ${latest['systolic']}/${latest['diastolic']} mmHg'
          : 'Your latest reading was ${latest['systolic']}/${latest['diastolic']} mmHg',
    );
    if (latest['pulse'] != null) {
      response.write(
        isFrench
            ? ' avec un pouls de ${latest['pulse']} bpm'
            : ' with a pulse of ${latest['pulse']} bpm',
      );
    }
    response.write(
      isFrench
          ? ' enregistrée ${_formatDate(latest['timestamp'])}. '
          : ' recorded ${_formatDate(latest['timestamp'])}. ',
    );

    if (readings.length > 1) {
      final avgSystolic =
          readings.map((r) => r['systolic'] as int).reduce((a, b) => a + b) /
          readings.length;
      final avgDiastolic =
          readings.map((r) => r['diastolic'] as int).reduce((a, b) => a + b) /
          readings.length;

      response.write(
        isFrench
            ? 'Sur les ${readings.length} dernière${readings.length == 1 ? '' : 's'} mesure${readings.length == 1 ? '' : 's'}, votre moyenne est ${avgSystolic.round()}/${avgDiastolic.round()} mmHg. '
            : 'Over the past ${readings.length} reading${readings.length == 1 ? '' : 's'}, your average is ${avgSystolic.round()}/${avgDiastolic.round()} mmHg. ',
      );

      if (avgSystolic < 120 && avgDiastolic < 80) {
        response.write(
          isFrench
              ? 'C\'est dans la plage normale. '
              : 'This is in the normal range. ',
        );
      } else if (avgSystolic < 130 && avgDiastolic < 80) {
        response.write(
          isFrench
              ? 'C\'est considéré comme élevé. '
              : 'This is considered elevated. ',
        );
      } else {
        response.write(
          isFrench
              ? 'C\'est dans la plage d\'hypertension. '
              : 'This is in the high blood pressure range. ',
        );
      }
    }

    response.write(
      isFrench
          ? 'Avez-vous remarqué des symptômes récemment, comme des maux de tête ou des étourdissements?'
          : 'Have you noticed any symptoms recently, like headaches or dizziness?',
    );

    return response.toString();
  }

  Future<String> _generateAnomaliesResponse(
    HealthIntent intent,
    String language,
  ) async {
    final anomalies = await _getRecentAnomalies();
    final isFrench = language == 'fr';

    if (anomalies.isEmpty) {
      return isFrench
          ? 'Je n\'ai détecté aucune anomalie dans vos lectures récentes. Tout semble normal.'
          : 'I haven\'t detected any unusual patterns in your recent blood pressure readings. Everything looks normal.';
    }

    final response = StringBuffer();
    response.write(
      isFrench
          ? 'J\'ai détecté ${anomalies.length} anomalie${anomalies.length == 1 ? '' : 's'} : '
          : 'I\'ve detected ${anomalies.length} unusual pattern${anomalies.length == 1 ? '' : 's'}: ',
    );

    for (int i = 0; i < anomalies.length && i < 3; i++) {
      final anomaly = anomalies[i];
      if (i > 0) response.write(' ');
      response.write('${anomaly.explanations.first}');
    }

    final highRiskAnomalies = anomalies
        .where((a) => a.riskLevel == AnomalyRiskLevel.high)
        .length;
    if (highRiskAnomalies > 0) {
      response.write(
        isFrench
            ? ' ${highRiskAnomalies} nécessitent une attention immédiate. '
            : ' ${highRiskAnomalies} of these require immediate attention. ',
      );
    }

    response.write(
      isFrench
          ? 'Ma recommandation : ${anomalies.first.recommendation}'
          : 'My recommendation: ${anomalies.first.recommendation}',
    );
    response.write(
      isFrench
          ? ' Avez-vous ressenti quelque chose d\'inhabituel quand ces variations se sont produites?'
          : ' Did you feel anything unusual when these changes happened?',
    );

    return response.toString();
  }

  Future<String> _generateTrendsResponse(
    HealthIntent intent,
    String language,
  ) async {
    final userProfile = await _buildUserProfile();
    final riskReport = await _riskScoreService.calculateRiskScore(
      userId: _userId,
      userFeatures: userProfile,
    );

    final response = StringBuffer();
    final isFrench = language == 'fr';

    if (riskReport.historicalScores.length >= 2) {
      final recent = riskReport.historicalScores.length > 5
          ? riskReport.historicalScores.sublist(
              riskReport.historicalScores.length - 5,
            )
          : riskReport.historicalScores;
      if (recent.length >= 2) {
        final first = recent.first;
        final last = recent.last;
        final change = last.score - first.score;

        if (change > 10) {
          response.write(
            isFrench
                ? 'Votre risque de santé augmente récemment. '
                : 'Your health risk has been increasing recently. ',
          );
        } else if (change < -10) {
          response.write(
            isFrench
                ? 'Bonne nouvelle! Votre risque s\'améliore. '
                : 'Great news! Your health risk has been improving. ',
          );
        } else {
          response.write(
            isFrench
                ? 'Votre risque est resté relativement stable. '
                : 'Your health risk has been relatively stable. ',
          );
        }
      }
    }

    final readings = await _getRecentReadings('week');
    if (readings.length >= 3) {
      final avgSystolic =
          readings.map((r) => r['systolic'] as int).reduce((a, b) => a + b) /
          readings.length;
      final avgDiastolic =
          readings.map((r) => r['diastolic'] as int).reduce((a, b) => a + b) /
          readings.length;

      response.write(
        isFrench
            ? 'Votre moyenne cette semaine est ${avgSystolic.round()}/${avgDiastolic.round()} mmHg. '
            : 'Your average blood pressure this week is ${avgSystolic.round()}/${avgDiastolic.round()} mmHg. ',
      );

      final previousReadings = await _getPreviousWeekReadings();
      if (previousReadings.isNotEmpty) {
        final prevAvgSys =
            previousReadings
                .map((r) => r['systolic'] as int)
                .reduce((a, b) => a + b) /
            previousReadings.length;
        final change = avgSystolic - prevAvgSys;

        if (change > 5) {
          response.write(
            isFrench
                ? 'C\'est plus élevé que la semaine dernière. '
                : 'This is higher than last week. ',
          );
        } else if (change < -5) {
          response.write(
            isFrench
                ? 'C\'est plus bas que la semaine dernière, ce qui est bien. '
                : 'This is lower than last week, which is good. ',
          );
        } else {
          response.write(
            isFrench
                ? 'C\'est similaire à la semaine dernière. '
                : 'This is similar to last week. ',
          );
        }
      }
    }

    response.write(
      isFrench
          ? 'Voulez-vous que je surveille cela de plus près cette semaine?'
          : 'Would you like me to keep a closer eye on this trend this week?',
    );

    return response.toString();
  }

  Future<String> _generateMedicationResponse(
    HealthIntent intent,
    String language,
  ) async {
    final medications = await _medicationRepository.getMedications(_userId);
    final isFrench = language == 'fr';

    if (medications.isEmpty) {
      return isFrench
          ? 'Vous n\'avez aucun médicament enregistré. Voulez-vous en ajouter?'
          : 'You don\'t have any medications recorded in the app. Would you like to add some?';
    }

    final response = StringBuffer();
    response.write(
      isFrench
          ? 'Vous avez ${medications.length} médicament${medications.length == 1 ? '' : 's'} enregistré${medications.length == 1 ? '' : 's'} : '
          : 'You have ${medications.length} medication${medications.length == 1 ? '' : 's'} on record: ',
    );

    final activeMeds = medications.where((m) => m.isActive).toList();
    for (int i = 0; i < activeMeds.length && i < 3; i++) {
      final med = activeMeds[i];
      if (i > 0) response.write(', ');
      response.write('${med.name} (${med.dosage})');
    }

    if (activeMeds.length > 3) {
      response.write(
        isFrench
            ? ' et ${activeMeds.length - 3} autres'
            : ' and ${activeMeds.length - 3} more',
      );
    }

    final takenToday = activeMeds.where((m) => m.takenToday).length;
    if (takenToday < activeMeds.length) {
      response.write(
        isFrench
            ? '. Il vous reste ${activeMeds.length - takenToday} médicament${activeMeds.length - takenToday == 1 ? '' : 's'} à prendre aujourd\'hui.'
            : '. You have ${activeMeds.length - takenToday} medication${activeMeds.length - takenToday == 1 ? '' : 's'} to take today.',
      );
    } else {
      response.write(
        isFrench
            ? '. Vous avez pris tous vos médicaments aujourd\'hui - bravo!'
            : '. You\'ve taken all your medications today - great job!',
      );
    }

    response.write(
      isFrench
          ? ' Ressentez-vous des effets secondaires ou des symptômes liés à vos médicaments?'
          : ' Are you experiencing any side effects or symptoms from your medications?',
    );

    return response.toString();
  }

  Future<String> _generateComparisonResponse(
    HealthIntent intent,
    String language,
  ) async {
    final userProfile = await _buildUserProfile();
    final riskReport = await _riskScoreService.calculateRiskScore(
      userId: _userId,
      userFeatures: userProfile,
    );

    final response = StringBuffer();
    final isFrench = language == 'fr';

    if (riskReport.historicalScores.length < 2) {
      response.write(
        isFrench
            ? 'J\'ai besoin de plus de données pour comparer. Continuez à enregistrer vos mesures régulièrement. '
            : 'I need more historical data to make comparisons. Keep recording your health data regularly. ',
      );
      response.write(
        isFrench
            ? 'Souhaitez-vous que je vous rappelle de prendre vos mesures?'
            : 'Would you like reminders to keep tracking your readings?',
      );
      return response.toString();
    }

    final latest = riskReport.historicalScores.last;
    final previous =
        riskReport.historicalScores[riskReport.historicalScores.length - 2];
    final change = latest.score - previous.score;

    response.write(
      isFrench
          ? 'Comparaison de votre état actuel avec les périodes précédentes : '
          : 'Comparing your current health status to previous periods: ',
    );
    response.write(
      isFrench
          ? 'Votre score de risque a ${change > 0 ? 'augmenté' : 'diminué'} de ${change.abs().toStringAsFixed(1)} points. '
          : 'Your risk score has ${change > 0 ? 'increased' : 'decreased'} by ${change.abs().toStringAsFixed(1)} points. ',
    );

    if (change.abs() > 10) {
      response.write(
        isFrench
            ? 'C\'est un changement important à noter. '
            : 'That is a significant change worth noting. ',
      );
    } else {
      response.write(
        isFrench ? 'C\'est un changement léger. ' : 'This is a mild change. ',
      );
    }

    final readings = await _getRecentReadings('week');
    if (readings.isNotEmpty) {
      final avgSystolic =
          readings.map((r) => r['systolic'] as int).reduce((a, b) => a + b) /
          readings.length;
      final avgDiastolic =
          readings.map((r) => r['diastolic'] as int).reduce((a, b) => a + b) /
          readings.length;
      response.write(
        isFrench
            ? 'Votre moyenne récente est ${avgSystolic.round()}/${avgDiastolic.round()} mmHg. '
            : 'Your average blood pressure for the recent period is ${avgSystolic.round()}/${avgDiastolic.round()} mmHg. ',
      );
    }

    response.write(
      isFrench
          ? 'Souhaitez-vous que je suggère des actions pour améliorer cette tendance?'
          : 'Would you like suggested actions to improve this trend?',
    );

    return response.toString();
  }

  // Helper methods
  HealthIntent _fallbackIntentAnalysis(String query) {
    final lowerQuery = query.toLowerCase();

    if (lowerQuery.contains('risk') || lowerQuery.contains('score')) {
      return HealthIntent(
        intent: HealthIntentType.riskScore,
        confidence: 0.8,
        entities: {},
        responseType: 'summary',
      );
    } else if (lowerQuery.contains('blood pressure') ||
        lowerQuery.contains('bp')) {
      return HealthIntent(
        intent: HealthIntentType.bpReadings,
        confidence: 0.8,
        entities: {},
        responseType: 'summary',
      );
    } else if (lowerQuery.contains('anomal') ||
        lowerQuery.contains('unusual') ||
        lowerQuery.contains('concern')) {
      return HealthIntent(
        intent: HealthIntentType.anomalies,
        confidence: 0.8,
        entities: {},
        responseType: 'summary',
      );
    } else if (lowerQuery.contains('trend') ||
        lowerQuery.contains('changing') ||
        lowerQuery.contains('getting')) {
      return HealthIntent(
        intent: HealthIntentType.trends,
        confidence: 0.8,
        entities: {},
        responseType: 'analysis',
      );
    } else if (lowerQuery.contains('medication') ||
        lowerQuery.contains('medicine')) {
      return HealthIntent(
        intent: HealthIntentType.medication,
        confidence: 0.8,
        entities: {},
        responseType: 'summary',
      );
    } else {
      return HealthIntent(
        intent: HealthIntentType.healthStatus,
        confidence: 0.7,
        entities: {},
        responseType: 'summary',
      );
    }
  }

  Future<Map<String, dynamic>> _buildUserProfile() async {
    // This would integrate with existing user data
    return {
      'age': 40,
      'gender': 'unknown',
      'avg_systolic': 120,
      'avg_diastolic': 80,
      'sodium_intake': 2300,
      'sedentary_minutes': 360,
      'smoker_status': 0,
      'alcohol_use': 0,
      'has_diabetes': 0,
      'takes_bp_medication': 0,
      'has_heart_condition': 0,
      'physical_activity_score': 1.5,
    };
  }

  Future<Map<String, dynamic>?> _getLatestBPReading() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .collection('bp_readings')
          .orderBy('date', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        return {
          'systolic': data['systolic'],
          'diastolic': data['diastolic'],
          'pulse': data['pulse'],
          'timestamp': data['date'],
        };
      }
    } catch (e) {
      debugPrint('Error fetching latest BP reading: $e');
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> _getRecentReadings(
    String timeframe,
  ) async {
    try {
      int days = 7; // default to week
      if (timeframe == 'recent') days = 7;
      if (timeframe == 'week') days = 7;
      if (timeframe == 'month') days = 30;
      if (timeframe == 'all') days = 365;

      final cutoff = DateTime.now().subtract(Duration(days: days));
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .collection('bp_readings')
          .where('date', isGreaterThanOrEqualTo: cutoff)
          .orderBy('date', descending: true)
          .limit(50)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'systolic': data['systolic'],
          'diastolic': data['diastolic'],
          'pulse': data['pulse'],
          'timestamp': data['date'],
        };
      }).toList();
    } catch (e) {
      debugPrint('Error fetching recent readings: $e');
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> _getPreviousWeekReadings() async {
    try {
      final now = DateTime.now();
      final weekAgo = now.subtract(const Duration(days: 7));
      final twoWeeksAgo = now.subtract(const Duration(days: 14));

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .collection('bp_readings')
          .where('date', isGreaterThanOrEqualTo: twoWeeksAgo)
          .where('date', isLessThanOrEqualTo: weekAgo)
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'systolic': data['systolic'],
          'diastolic': data['diastolic'],
          'pulse': data['pulse'],
          'timestamp': data['date'],
        };
      }).toList();
    } catch (e) {
      debugPrint('Error fetching previous week readings: $e');
    }
    return [];
  }

  Future<List<AnomalyResult>> _getRecentAnomalies() async {
    try {
      // Get recent readings to check for anomalies
      final readings = await _getRecentReadings('week');
      final anomalies = <AnomalyResult>[];

      for (int i = 1; i < readings.length; i++) {
        final current = readings[i];
        final previous = readings[i - 1];

        final sysChange =
            (current['systolic'] as int) - (previous['systolic'] as int);
        final diaChange =
            (current['diastolic'] as int) - (previous['diastolic'] as int);

        // Detect significant changes
        if (sysChange.abs() > 20 || diaChange.abs() > 15) {
          final riskLevel = sysChange.abs() > 30
              ? AnomalyRiskLevel.high
              : AnomalyRiskLevel.moderate;
          final anomalyType = sysChange > 0
              ? AnomalyType.suddenSpike
              : AnomalyType.suddenDrop;

          anomalies.add(
            AnomalyResult(
              isAnomaly: true,
              anomalyTypes: [anomalyType],
              explanations: [
                'Significant BP change detected: ${sysChange > 0 ? '+' : ''}$sysChange/${diaChange > 0 ? '+' : ''}$diaChange mmHg',
              ],
              severity: sysChange.abs().toDouble(),
              riskLevel: riskLevel,
              recommendation:
                  'Monitor closely and consult healthcare provider if trend continues',
            ),
          );
        }
      }

      return anomalies;
    } catch (e) {
      debugPrint('Error detecting anomalies: $e');
    }
    return [];
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp is DateTime) {
      final now = DateTime.now();
      final difference = now.difference(timestamp);

      if (difference.inDays == 0) {
        return 'today';
      } else if (difference.inDays == 1) {
        return 'yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else {
        return '${timestamp.day}/${timestamp.month}';
      }
    }
    return 'recently';
  }
}

// Data classes
class HealthIntent {
  final HealthIntentType intent;
  final double confidence;
  final Map<String, dynamic> entities;
  final String responseType;

  HealthIntent({
    required this.intent,
    required this.confidence,
    required this.entities,
    required this.responseType,
  });

  factory HealthIntent.fromJson(Map<String, dynamic> json) {
    return HealthIntent(
      intent: _parseIntentType(json['intent'] ?? 'HEALTH_STATUS'),
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      entities: json['entities'] ?? {},
      responseType: json['response_type'] ?? 'summary',
    );
  }

  static HealthIntentType _parseIntentType(String intent) {
    switch (intent.toUpperCase()) {
      case 'HEALTH_STATUS':
        return HealthIntentType.healthStatus;
      case 'RISK_SCORE':
        return HealthIntentType.riskScore;
      case 'BP_READINGS':
        return HealthIntentType.bpReadings;
      case 'ANOMALIES':
        return HealthIntentType.anomalies;
      case 'TRENDS':
        return HealthIntentType.trends;
      case 'MEDICATION':
        return HealthIntentType.medication;
      case 'RECOMMENDATIONS':
        return HealthIntentType.recommendations;
      case 'COMPARISON':
        return HealthIntentType.comparison;
      default:
        return HealthIntentType.healthStatus;
    }
  }
}

enum HealthIntentType {
  healthStatus,
  riskScore,
  bpReadings,
  anomalies,
  trends,
  medication,
  recommendations,
  comparison,
}
