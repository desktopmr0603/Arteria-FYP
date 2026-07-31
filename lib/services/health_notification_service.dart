import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../features/home/data/data_sources/health_risk_score_service.dart';

/// Pushes real phone notifications for clinically meaningful events derived
/// from the user's own data:
///   • a dangerous latest reading (Stage 2 hypertension or crisis)
///   • a sudden jump from the previous reading
///   • blood pressure trending up week-over-week
///   • a notable increase in the health risk score
///   • missed medication doses for the day
///
/// Every notification is de-duplicated through `users/{uid}/notification_history`
/// so a given event is never pushed twice. Local notifications fire while the
/// app is running; the checks are run with the real signed-in user on app open
/// and right after a reading is saved (see [runChecksForCurrentUser]).
class HealthNotificationService {
  final String _userId;
  final HealthRiskScoreService _riskScoreService;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  Timer? _monitoringTimer;

  // Thresholds.
  static const int _minRiskPointChange = 8; // points out of 100
  static const int _minHoursBetweenScores = 6;
  static const int _trendMmHgThreshold = 8; // week-over-week systolic rise
  static const int _spikeSysThreshold = 20; // jump vs previous reading
  static const int _spikeDiaThreshold = 15;
  static const int _monitoringIntervalHours = 6;

  HealthNotificationService({
    required String userId,
    required HealthRiskScoreService riskScoreService,
  })  : _userId = userId,
        _riskScoreService = riskScoreService;

  // ── Public entry points ────────────────────────────────────────────

  /// One-shot check for the currently-authenticated user. Builds its own
  /// dependencies, runs the checks once (no background timer), then tears them
  /// down. Safe to call after a reading is saved or on app open — the
  /// de-duplication store keeps it from pushing the same event twice.
  static Future<void> runChecksForCurrentUser() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final risk = HealthRiskScoreService();
      await risk.initialize();
      final service =
          HealthNotificationService(userId: uid, riskScoreService: risk);
      await service.runOnce();
      risk.dispose();
    } catch (e) {
      debugPrint('⚠️ Push notification check failed: $e');
    }
  }

  /// Initialize the notification plugin and start periodic monitoring while the
  /// app is alive (used by long-lived screens such as Insights).
  Future<void> initialize() async {
    await _initializeNotifications();
    _monitoringTimer = Timer.periodic(
      const Duration(hours: _monitoringIntervalHours),
      (_) => _performHealthCheck(),
    );
    await _performHealthCheck();
  }

  /// Initialize the plugin and run every check exactly once (no timers).
  Future<void> runOnce() async {
    await _initializeNotifications();
    await _performHealthCheck();
  }

  void dispose() {
    _monitoringTimer?.cancel();
  }

  // ── Init ────────────────────────────────────────────────────────────

  Future<void> _initializeNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _notifications.initialize(settings);

    // Android 13+ requires asking for POST_NOTIFICATIONS at runtime (iOS is
    // covered by the Darwin settings above).
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  // ── Orchestration ───────────────────────────────────────────────────

  Future<void> _performHealthCheck() async {
    try {
      await _checkAbnormalReading();
      await _checkBPTrend();
      await _checkRiskScoreChanges();
      await _checkMedicationAdherence();
    } catch (e) {
      debugPrint('❌ Error during health check: $e');
    }
  }

  // ── 1. Dangerous / spiking latest reading ───────────────────────────

  Future<void> _checkAbnormalReading() async {
    final readings = await _getRecentBPReadings(days: 3);
    if (readings.isEmpty) return;

    final latest = readings.first;
    final sys = latest['systolic'] as int;
    final dia = latest['diastolic'] as int;
    final id = latest['id'] as String;

    String? title;
    String? body;
    String? key;

    if (sys > 180 || dia > 120) {
      title = '🚨 Very High Blood Pressure';
      body =
          'Your latest reading was $sys/$dia mmHg — in the hypertensive crisis range. If you have chest pain, shortness of breath, or vision changes, seek emergency care now.';
      key = 'reading_$id';
    } else if (sys >= 140 || dia >= 90) {
      title = '⚠️ High Blood Pressure';
      body =
          'Your latest reading was $sys/$dia mmHg — in the Stage 2 hypertension range. Consider following up with your healthcare provider.';
      key = 'reading_$id';
    } else {
      // Not absolutely high, but flag a sudden jump from the previous reading.
      final pSys = latest['previous_systolic'] as int?;
      final pDia = latest['previous_diastolic'] as int?;
      if (pSys != null &&
          pDia != null &&
          ((sys - pSys) >= _spikeSysThreshold ||
              (dia - pDia) >= _spikeDiaThreshold)) {
        title = '⚠️ Sudden BP Increase';
        body =
            'Your blood pressure jumped to $sys/$dia mmHg (up +${sys - pSys}/+${dia - pDia} from your previous reading). Rest a few minutes and measure again.';
        key = 'spike_$id';
      } else {
        return;
      }
    }

    if (await _alreadyNotified(key)) return;
    await _showNotification(title: title, body: body, payload: 'reading');
    await _markNotified(key, 'reading');
  }

  // ── 2. Week-over-week BP trend ──────────────────────────────────────

  Future<void> _checkBPTrend() async {
    final thisWeek = await _getRecentBPReadings(days: 7);
    final lastWeek = await _getPreviousWeekReadings();
    if (thisWeek.length < 2 || lastWeek.isEmpty) return;

    double avg(List<Map<String, dynamic>> r) =>
        r.map((e) => e['systolic'] as int).reduce((a, b) => a + b) / r.length;

    final change = (avg(thisWeek) - avg(lastWeek)).round();
    if (change < _trendMmHgThreshold) return;

    final key = 'trend_${_weekKey(DateTime.now())}';
    if (await _alreadyNotified(key)) return;
    await _showNotification(
      title: '📈 Blood Pressure Trending Up',
      body:
          'Your average systolic is up $change mmHg compared with last week. Review your salt, sleep, and stress, and keep monitoring.',
      payload: 'trend',
    );
    await _markNotified(key, 'trend');
  }

  // ── 3. Notable risk-score increase ──────────────────────────────────

  Future<void> _checkRiskScoreChanges() async {
    try {
      final userProfile = await _buildUserProfile();
      final current = await _riskScoreService.calculateRiskScore(
        userId: _userId,
        userFeatures: userProfile,
      );

      final previous = await _getPreviousRiskScore();
      if (previous == null) return;

      final pointChange = current.overallScore - previous.score;
      final hoursApart =
          DateTime.now().difference(previous.timestamp).inHours;

      // Only push a meaningful *increase* measured over a real time gap, so we
      // don't fire on the noise between two back-to-back recalculations.
      if (pointChange >= _minRiskPointChange &&
          hoursApart >= _minHoursBetweenScores) {
        final key = 'risk_${previous.timestamp.millisecondsSinceEpoch}';
        if (await _alreadyNotified(key)) return;
        await _showNotification(
          title: '⚠️ Health Risk Increased',
          body:
              'Your risk score rose by $pointChange points to ${current.overallScore}/100 (was ${previous.score}). Consider reviewing your recent readings and habits.',
          payload: 'risk',
        );
        await _markNotified(key, 'risk');
      }
    } catch (e) {
      debugPrint('Error checking risk score changes: $e');
    }
  }

  // ── 4. Missed medication ────────────────────────────────────────────

  Future<void> _checkMedicationAdherence() async {
    final meds = await _getActiveMedications();
    if (meds.isEmpty) return;

    final now = DateTime.now();
    final startToday = DateTime(now.year, now.month, now.day);

    // Doses that should have been taken by now, spread evenly across the day.
    var dueSoFar = 0;
    for (final m in meds) {
      final perDay = m['doses_per_day'] as int;
      dueSoFar += (perDay * (now.hour / 24)).round();
    }
    if (dueSoFar == 0) return;

    final taken = await _countDosesTakenSince(startToday);
    final missed = dueSoFar - taken;
    if (missed <= 0) return;

    // Once per calendar day.
    final key = 'med_${startToday.toIso8601String().substring(0, 10)}';
    if (await _alreadyNotified(key)) return;
    await _showNotification(
      title: '💊 Medication Reminder',
      body:
          'You have $missed dose${missed == 1 ? '' : 's'} due but not yet logged today. Consistent timing helps keep your blood pressure controlled.',
      payload: 'medication',
    );
    await _markNotified(key, 'medication');
  }

  // ── Data fetches ────────────────────────────────────────────────────

  /// Recent readings, newest first, each annotated with the chronologically
  /// previous reading's values (for spike detection).
  Future<List<Map<String, dynamic>>> _getRecentBPReadings({
    required int days,
  }) async {
    try {
      final since = DateTime.now().subtract(Duration(days: days));
      final snap = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('readings')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
          .orderBy('date', descending: true)
          .get();

      final docs = snap.docs;
      final out = <Map<String, dynamic>>[];
      for (var i = 0; i < docs.length; i++) {
        final data = docs[i].data();
        final sys = (data['systolic'] as num?)?.toInt();
        final dia = (data['diastolic'] as num?)?.toInt();
        if (sys == null || dia == null) continue;
        final prev = i + 1 < docs.length ? docs[i + 1].data() : null;
        out.add({
          'id': docs[i].id,
          'systolic': sys,
          'diastolic': dia,
          'previous_systolic': (prev?['systolic'] as num?)?.toInt(),
          'previous_diastolic': (prev?['diastolic'] as num?)?.toInt(),
        });
      }
      return out;
    } catch (e) {
      debugPrint('Error fetching recent readings: $e');
      return [];
    }
  }

  /// Readings from the 7–14 day window (the week before this one).
  Future<List<Map<String, dynamic>>> _getPreviousWeekReadings() async {
    try {
      final now = DateTime.now();
      final weekAgo = now.subtract(const Duration(days: 7));
      final twoWeeksAgo = now.subtract(const Duration(days: 14));

      final snap = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('readings')
          .where('date',
              isGreaterThanOrEqualTo: Timestamp.fromDate(twoWeeksAgo))
          .where('date', isLessThan: Timestamp.fromDate(weekAgo))
          .orderBy('date', descending: true)
          .get();

      return snap.docs
          .map((d) {
            final data = d.data();
            return {
              'systolic': (data['systolic'] as num?)?.toInt() ?? 0,
              'diastolic': (data['diastolic'] as num?)?.toInt() ?? 0,
            };
          })
          .where((m) => (m['systolic'] as int) > 0)
          .toList();
    } catch (e) {
      debugPrint('Error fetching previous week readings: $e');
      return [];
    }
  }

  /// Active medications reduced to their per-day dose count.
  Future<List<Map<String, dynamic>>> _getActiveMedications() async {
    try {
      final snap = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('medications')
          .where('isActive', isEqualTo: true)
          .get();

      return snap.docs.map((d) {
        final freq = (d.data()['frequency'] as String?) ?? 'onceDaily';
        return {'doses_per_day': _dosesPerDay(freq)};
      }).toList();
    } catch (e) {
      debugPrint('Error fetching active medications: $e');
      return [];
    }
  }

  Future<int> _countDosesTakenSince(DateTime start) async {
    try {
      final snap = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('medicationLogs')
          .get();

      var count = 0;
      for (final d in snap.docs) {
        final data = d.data();
        final raw = data['takenAt'];
        DateTime? ts;
        if (raw is Timestamp) {
          ts = raw.toDate();
        } else if (raw is String) {
          ts = DateTime.tryParse(raw);
        }
        if (ts != null && !ts.isBefore(start) && data['skipped'] != true) {
          count++;
        }
      }
      return count;
    } catch (e) {
      debugPrint('Error counting medication logs: $e');
      return 0;
    }
  }

  int _dosesPerDay(String frequency) {
    switch (frequency) {
      case 'twiceDaily':
        return 2;
      case 'threeTimesDaily':
        return 3;
      case 'weekly':
      case 'asNeeded':
        return 0;
      case 'onceDaily':
      default:
        return 1;
    }
  }

  // ── Risk-score helpers ──────────────────────────────────────────────

  Future<Map<String, dynamic>> _buildUserProfile() async {
    try {
      final userRef = _firestore.collection('users').doc(_userId);

      final userDoc = await userRef.get();
      final userData = userDoc.data() ?? {};
      final age = userData['age'] as int? ?? 40;
      final gender = userData['gender'] as String? ?? 'unknown';

      final medicalDoc =
          await userRef.collection('medicalProfile').doc('current').get();
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

  Future<_PreviousScore?> _getPreviousRiskScore() async {
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
        return _PreviousScore(
          score: (data['score'] as num?)?.toInt() ?? 0,
          timestamp: timestamp,
        );
      }
    } catch (e) {
      debugPrint('Error getting previous risk score: $e');
    }
    return null;
  }

  // ── De-duplication ──────────────────────────────────────────────────

  Future<bool> _alreadyNotified(String key) async {
    try {
      final snap = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('notification_history')
          .where('key', isEqualTo: key)
          .limit(1)
          .get();
      return snap.docs.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _markNotified(String key, String type) async {
    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('notification_history')
          .add({
        'key': key,
        'type': type,
        'created_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error marking notification: $e');
    }
  }

  // ── Show ────────────────────────────────────────────────────────────

  Future<void> _showNotification({
    required String title,
    required String body,
    required String payload,
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
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Year + week-of-year, enough to de-duplicate once per calendar week.
  String _weekKey(DateTime d) {
    final firstDay = DateTime(d.year, 1, 1);
    final week = (d.difference(firstDay).inDays / 7).floor();
    return '${d.year}-w$week';
  }
}

/// A previously-recorded risk score used for change detection.
class _PreviousScore {
  const _PreviousScore({required this.score, required this.timestamp});
  final int score;
  final DateTime timestamp;
}
