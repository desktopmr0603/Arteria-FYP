import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../features/home/data/data_sources/health_risk_score_service.dart';
import '../features/home/data/data_sources/bp_anomaly_remote_data_source.dart';

/// Health Notification Service
///
/// Monitors health data and sends contextual notifications for important
/// health events, thresholds, and trends.
///
/// Features:
/// - Real-time health event monitoring
/// - Contextual alert generation
/// - Smart notification scheduling
/// - Alert history tracking
class HealthNotificationService {
  final String _userId;
  final HealthRiskScoreService _riskScoreService;
  final BPAnomalyRemoteDataSource _anomalyService;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  Timer? _monitoringTimer;
  Timer? _dailySummaryTimer;

  // Notification thresholds
  static const double _riskChangeThreshold = 0.15; // 15% change
  static const int _monitoringIntervalHours = 6;
  static const int _dailySummaryHour = 20; // 8 PM

  HealthNotificationService({
    required String userId,
    required HealthRiskScoreService riskScoreService,
    required BPAnomalyRemoteDataSource anomalyService,
  }) : _userId = userId,
       _riskScoreService = riskScoreService,
       _anomalyService = anomalyService;

  /// Initialize notification service and start monitoring
  Future<void> initialize() async {
    await _initializeNotifications();
    await _startHealthMonitoring();
    await _scheduleDailySummary();
  }

  /// Initialize local notifications
  Future<void> _initializeNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  /// Start background health monitoring
  Future<void> _startHealthMonitoring() async {
    _monitoringTimer = Timer.periodic(
      Duration(hours: _monitoringIntervalHours),
      (_) => _performHealthCheck(),
    );

    // Perform initial check
    await _performHealthCheck();
  }

  /// Schedule daily health summary
  Future<void> _scheduleDailySummary() async {
    final now = DateTime.now();
    final scheduledTime = DateTime(
      now.year,
      now.month,
      now.day,
      _dailySummaryHour,
      0,
      0,
    );

    final initialDelay = scheduledTime.isAfter(now)
        ? scheduledTime.difference(now)
        : Duration(days: 1) - now.difference(scheduledTime);

    _dailySummaryTimer = Timer(initialDelay, () {
      _sendDailyHealthSummary();
      // Schedule next day
      _scheduleDailySummary();
    });
  }

  /// Perform comprehensive health check
  Future<void> _performHealthCheck() async {
    try {
      debugPrint('🔍 Performing health check for user $_userId');

      // Check risk score changes
      await _checkRiskScoreChanges();

      // Check for new anomalies
      await _checkForAnomalies();

      // Check BP trends
      await _checkBPTrends();

      // Check medication adherence
      await _checkMedicationAdherence();

      debugPrint('✅ Health check completed');
    } catch (e) {
      debugPrint('❌ Error during health check: $e');
    }
  }

  /// Check for significant risk score changes
  Future<void> _checkRiskScoreChanges() async {
    try {
      final userProfile = await _buildUserProfile();
      final currentReport = await _riskScoreService.calculateRiskScore(
        userId: _userId,
        userFeatures: userProfile,
      );

      // Get previous risk score
      final previousScore = await _getPreviousRiskScore();

      if (previousScore != null) {
        final change = (currentReport.overallScore - previousScore.score).abs();
        final percentageChange = change / previousScore.score;

        if (percentageChange >= _riskChangeThreshold) {
          await _sendRiskChangeNotification(
            currentReport,
            previousScore,
            percentageChange,
          );
        }
      }

      // Store current score for future comparison
      await _storeRiskScore(currentReport);
    } catch (e) {
      debugPrint('Error checking risk score changes: $e');
    }
  }

  /// Check for new anomalies
  Future<void> _checkForAnomalies() async {
    try {
      final recentReadings = await _getRecentBPReadings(days: 1);

      for (final reading in recentReadings) {
        final anomaly = _anomalyService.detectAnomaly(
          systolic: reading['systolic'] as int,
          diastolic: reading['diastolic'] as int,
          previousSystolic: reading['previous_systolic'] as int?,
          previousDiastolic: reading['previous_diastolic'] as int?,
        );

        if (anomaly.isAnomaly) {
          final alreadyNotified = await _wasAnomalyNotified(anomaly);
          if (!alreadyNotified) {
            await _sendAnomalyNotification(anomaly, reading);
            await _markAnomalyNotified(anomaly);
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking for anomalies: $e');
    }
  }

  /// Check BP trends
  Future<void> _checkBPTrends() async {
    try {
      final weeklyReadings = await _getRecentBPReadings(days: 7);

      if (weeklyReadings.length < 3) return;

      // Calculate trend
      final avgSystolic =
          weeklyReadings
              .map((r) => r['systolic'] as int)
              .reduce((a, b) => a + b) /
          weeklyReadings.length;

      final previousWeekReadings = await _getPreviousWeekReadings();
      if (previousWeekReadings.isNotEmpty) {
        final prevAvgSystolic =
            previousWeekReadings
                .map((r) => r['systolic'] as int)
                .reduce((a, b) => a + b) /
            previousWeekReadings.length;

        final change = avgSystolic - prevAvgSystolic;

        // Send trend notification if significant change
        if (change > 10) {
          await _sendBPTrendNotification('increasing', change.round());
        } else if (change < -10) {
          await _sendBPTrendNotification('decreasing', change.abs().round());
        }
      }
    } catch (e) {
      debugPrint('Error checking BP trends: $e');
    }
  }

  /// Check medication adherence
  Future<void> _checkMedicationAdherence() async {
    try {
      final medications = await _getActiveMedications();
      final today = DateTime.now();

      for (final medication in medications) {
        if (!medication['taken_today']) {
          final lastTaken = medication['last_taken'] as Timestamp?;
          final daysSinceLastTaken = lastTaken != null
              ? today.difference(lastTaken.toDate()).inDays
              : 999;

          if (daysSinceLastTaken >= 2) {
            await _sendMedicationAdherenceNotification(
              medication['name'] as String,
              daysSinceLastTaken,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking medication adherence: $e');
    }
  }

  /// Send risk score change notification
  Future<void> _sendRiskChangeNotification(
    HealthRiskReport currentReport,
    HistoricalScore previousScore,
    double percentageChange,
  ) async {
    final isIncrease = currentReport.overallScore > previousScore.score;
    final direction = isIncrease ? 'increased' : 'decreased';

    String title;
    String body;

    if (isIncrease) {
      title = '⚠️ Health Risk Increased';
      body =
          'Your risk score has $direction by ${(percentageChange * 100).round()}%. Current score: ${currentReport.overallScore}/100';
    } else {
      title = '🎉 Health Risk Improved';
      body =
          'Great news! Your risk score has $direction by ${(percentageChange * 100).round()}%. Current score: ${currentReport.overallScore}/100';
    }

    await _showNotification(
      title: title,
      body: body,
      payload: 'risk_change',
      data: {
        'previous_score': previousScore.score,
        'current_score': currentReport.overallScore,
        'percentage_change': percentageChange,
      },
    );
  }

  /// Send anomaly notification
  Future<void> _sendAnomalyNotification(
    AnomalyResult anomaly,
    Map<String, dynamic> reading,
  ) async {
    String title;
    String body;

    switch (anomaly.riskLevel) {
      case AnomalyRiskLevel.high:
        title = '🚨 Critical Health Alert';
        body =
            'Unusual BP pattern detected: ${reading['systolic']}/${reading['diastolic']} mmHg. Please check your reading.';
        break;
      case AnomalyRiskLevel.moderate:
        title = '⚠️ Health Alert';
        body =
            'Unusual BP reading: ${reading['systolic']}/${reading['diastolic']} mmHg. Consider taking another reading.';
        break;
      case AnomalyRiskLevel.low:
        title = 'ℹ️ Health Notice';
        body =
            'Slightly unusual BP reading: ${reading['systolic']}/${reading['diastolic']} mmHg.';
        break;
      default:
        return; // Don't send notification for no risk
    }

    await _showNotification(
      title: title,
      body: body,
      payload: 'anomaly',
      data: {
        'systolic': reading['systolic'],
        'diastolic': reading['diastolic'],
        'risk_level': anomaly.riskLevel.name,
        'explanations': anomaly.explanations,
      },
    );
  }

  /// Send BP trend notification
  Future<void> _sendBPTrendNotification(String direction, int change) async {
    final title = direction == 'increasing'
        ? '📈 BP Trend Alert'
        : '📉 BP Trend Update';

    final body = direction == 'increasing'
        ? 'Your blood pressure has been trending upward by $change mmHg this week. Consider reviewing your lifestyle factors.'
        : 'Great progress! Your blood pressure has decreased by $change mmHg this week. Keep up the good work!';

    await _showNotification(
      title: title,
      body: body,
      payload: 'bp_trend',
      data: {'direction': direction, 'change': change},
    );
  }

  /// Send medication adherence notification
  Future<void> _sendMedicationAdherenceNotification(
    String medicationName,
    int daysSinceLastTaken,
  ) async {
    final title = '💊 Medication Reminder';
    final body =
        'You haven\'t taken $medicationName for $daysSinceLastTaken day${daysSinceLastTaken == 1 ? '' : 's'}. Please check your medication schedule.';

    await _showNotification(
      title: title,
      body: body,
      payload: 'medication_adherence',
      data: {
        'medication': medicationName,
        'days_since_last_taken': daysSinceLastTaken,
      },
    );
  }

  /// Send daily health summary
  Future<void> _sendDailyHealthSummary() async {
    try {
      final userProfile = await _buildUserProfile();
      final riskReport = await _riskScoreService.calculateRiskScore(
        userId: _userId,
        userFeatures: userProfile,
      );

      final todayReadings = await _getRecentBPReadings(days: 1);
      final todayAnomalies = await _getTodayAnomalies();

      String summary = 'Daily Health Summary:\n';
      summary +=
          'Risk Score: ${riskReport.overallScore}/100 (${riskReport.category.name})\n';

      if (todayReadings.isNotEmpty) {
        final latest = todayReadings.first;
        summary +=
            'Latest BP: ${latest['systolic']}/${latest['diastolic']} mmHg\n';
      }

      if (todayAnomalies.isNotEmpty) {
        summary += 'Anomalies detected: ${todayAnomalies.length}\n';
      } else {
        summary += 'No anomalies detected today\n';
      }

      await _showNotification(
        title: '📊 Daily Health Summary',
        body: summary,
        payload: 'daily_summary',
        data: {
          'risk_score': riskReport.overallScore,
          'readings_count': todayReadings.length,
          'anomalies_count': todayAnomalies.length,
        },
      );
    } catch (e) {
      debugPrint('Error sending daily summary: $e');
    }
  }

  /// Show notification
  Future<void> _showNotification({
    required String title,
    required String body,
    required String payload,
    Map<String, dynamic>? data,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'health_notifications',
      'Health Notifications',
      channelDescription: 'Important health alerts and updates',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    // Handle navigation based on payload
    switch (response.payload) {
      case 'risk_change':
        // Navigate to insights/risk details
        break;
      case 'anomaly':
        // Navigate to BP readings with anomaly highlighted
        break;
      case 'bp_trend':
        // Navigate to trends screen
        break;
      case 'medication_adherence':
        // Navigate to medications screen
        break;
      case 'daily_summary':
        // Navigate to insights screen
        break;
    }
  }

  // Helper methods
  Future<Map<String, dynamic>> _buildUserProfile() async {
    try {
      final userRef = _firestore.collection('users').doc(_userId);

      // Fetch user profile
      final userDoc = await userRef.get();
      final userData = userDoc.data() ?? {};
      final age = userData['age'] as int? ?? 40;
      final gender = userData['gender'] as String? ?? 'unknown';

      // Fetch medical profile
      final medicalDoc = await userRef
          .collection('medicalProfile')
          .doc('current')
          .get();
      final medical = medicalDoc.exists
          ? medicalDoc.data() ?? {}
          : <String, dynamic>{};

      final smoker = (medical['smoker'] as bool?) == true ? 1.0 : 0.0;
      final hasDiabetes = (medical['hasDiabetes'] as bool?) == true ? 1.0 : 0.0;
      final weight = (medical['weight'] as num?)?.toDouble();
      final height = (medical['height'] as num?)?.toDouble();
      double bmi = 25.0;
      if (weight != null && height != null && height > 0) {
        final heightM = height / 100.0;
        bmi = weight / (heightM * heightM);
      }

      // Map physical activity to a score
      final activityStr = (medical['physicalActivity'] as String?) ?? '';
      double activityScore = 1.0;
      switch (activityStr.toLowerCase()) {
        case 'very active':
        case 'high':
          activityScore = 2.5;
          break;
        case 'active':
        case 'moderate':
          activityScore = 1.5;
          break;
        case 'light':
        case 'low':
          activityScore = 0.8;
          break;
        case 'sedentary':
        case 'none':
          activityScore = 0.3;
          break;
      }

      // Fetch recent BP readings for averages
      final monthAgo = DateTime.now().subtract(const Duration(days: 30));
      final readingsQuery = await userRef
          .collection('readings')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(monthAgo))
          .orderBy('date', descending: true)
          .limit(30)
          .get();

      double avgSystolic = 120;
      double avgDiastolic = 80;
      if (readingsQuery.docs.isNotEmpty) {
        final sysList = readingsQuery.docs
            .map((d) => (d.data()['systolic'] as num?)?.toDouble())
            .whereType<double>()
            .toList();
        final diaList = readingsQuery.docs
            .map((d) => (d.data()['diastolic'] as num?)?.toDouble())
            .whereType<double>()
            .toList();
        if (sysList.isNotEmpty) {
          avgSystolic = sysList.reduce((a, b) => a + b) / sysList.length;
        }
        if (diaList.isNotEmpty) {
          avgDiastolic = diaList.reduce((a, b) => a + b) / diaList.length;
        }
      }

      // Estimate sedentary minutes from activity level
      double sedentaryMinutes = 360;
      if (activityScore >= 2.0) {
        sedentaryMinutes = 180;
      } else if (activityScore < 1.0) {
        sedentaryMinutes = 540;
      }

      return {
        'age': age,
        'gender': gender,
        'avg_systolic': avgSystolic,
        'avg_diastolic': avgDiastolic,
        'sodium_intake': 2300,
        'sedentary_minutes': sedentaryMinutes,
        'smoker_status': smoker,
        'alcohol_use': 0,
        'has_diabetes': hasDiabetes,
        'takes_bp_medication':
            (medical['medications'] as String?)?.isNotEmpty == true ? 1.0 : 0.0,
        'has_heart_condition': 0,
        'physical_activity_score': activityScore,
        'bmi': bmi,
      };
    } catch (e) {
      debugPrint('⚠️ Error building user profile, using defaults: $e');
      // Fallback to safe defaults
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
  }

  Future<HistoricalScore?> _getPreviousRiskScore() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('risk_scores')
          .orderBy('timestamp', descending: true)
          .limit(2)
          .get();

      if (snapshot.docs.length >= 2) {
        final data = snapshot.docs.last.data();
        final timestamp =
            (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
        return HistoricalScore(
          score: data['score'] as int,
          timestamp: timestamp,
        );
      }
    } catch (e) {
      debugPrint('Error getting previous risk score: $e');
    }
    return null;
  }

  Future<void> _storeRiskScore(HealthRiskReport report) async {
    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('risk_scores')
          .add({
            'score': report.overallScore,
            'category': report.category.name,
            'timestamp': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      debugPrint('Error storing risk score: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _getRecentBPReadings({
    required int days,
  }) async {
    // Integration with existing BP data service
    return [];
  }

  Future<List<Map<String, dynamic>>> _getPreviousWeekReadings() async {
    // Integration with existing BP data service
    return [];
  }

  Future<List<Map<String, dynamic>>> _getActiveMedications() async {
    // Integration with existing medication service
    return [];
  }

  Future<bool> _wasAnomalyNotified(AnomalyResult anomaly) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('notification_history')
          .where('type', isEqualTo: 'anomaly')
          .where(
            'created_at',
            isGreaterThan: Timestamp.fromDate(
              DateTime.now().subtract(const Duration(hours: 24)),
            ),
          )
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking anomaly notification history: $e');
      return false;
    }
  }

  Future<void> _markAnomalyNotified(AnomalyResult anomaly) async {
    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('notification_history')
          .add({
            'type': 'anomaly',
            'risk_level': anomaly.riskLevel.name,
            'explanations': anomaly.explanations,
            'created_at': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      debugPrint('Error marking anomaly notified: $e');
    }
  }

  Future<List<AnomalyResult>> _getTodayAnomalies() async {
    // Integration with existing anomaly service
    return [];
  }

  /// Dispose resources
  void dispose() {
    _monitoringTimer?.cancel();
    _dailySummaryTimer?.cancel();
  }
}

// Data class for historical scores
class HistoricalScore {
  final int score;
  final DateTime timestamp;

  HistoricalScore({required this.score, required this.timestamp});
}
