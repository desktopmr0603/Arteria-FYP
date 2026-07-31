import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'user_event.dart';
import 'user_state.dart';
import 'package:arteria/features/home/data/data_sources/health_risk_score_service.dart';
import 'package:arteria/features/home/data/data_sources/insight_generator_service.dart';
import 'package:arteria/services/health_notification_service.dart';

class UserBloc extends Bloc<UserEvent, UserState> {
  UserBloc() : super(UserLoading()) {
    on<LoadUserData>(_onLoadUserData);
    on<SaveBPReading>(_onSaveBPReading);
  }

  Future<void> _onLoadUserData(
    LoadUserData event,
    Emitter<UserState> emit,
  ) async {
    emit(UserLoading());

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        emit(UserError('No user logged in'));
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final firstName = userDoc.data()?['firstName'] ?? 'User';

      // Fetch latest BP for the QuickStatsCard
      final latestQuery = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('readings')
          .orderBy('date', descending: true)
          .limit(1)
          .get();

      Map<String, dynamic>? latestReading;
      if (latestQuery.docs.isNotEmpty) {
        final r = latestQuery.docs.first.data();
        final date = r['date'];
        latestReading = {
          'systolic': r['systolic'],
          'diastolic': r['diastolic'],
          'date': date is Timestamp ? date.toDate() : date,
        };
      }

      // Fetch readings from the last 7 days for the WeeklyOverviewCard
      final now = DateTime.now();
      final weekAgo = now.subtract(const Duration(days: 7));
      final weeklyQuery = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('readings')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(weekAgo))
          .orderBy('date', descending: true)
          .get();

      final List<Map<String, dynamic>> weeklyReadings = weeklyQuery.docs.map((
        doc,
      ) {
        final data = doc.data();
        final date = data['date'];
        return {
          'systolic': data['systolic'],
          'diastolic': data['diastolic'],
          'date': date is Timestamp ? date.toDate() : date,
        };
      }).toList();

      final bool isFirstTime = latestReading == null;

      emit(
        UserLoaded(
          firstName: firstName,
          latestReading: latestReading,
          weeklyReadings: weeklyReadings,
          isFirstTimeUser: isFirstTime,
        ),
      );

      // Evaluate push notifications on app open / data refresh (and, since a
      // save triggers LoadUserData, right after a new reading is recorded).
      // Fire-and-forget so it never blocks the UI; it de-duplicates internally.
      HealthNotificationService.runChecksForCurrentUser();
    } catch (e) {
      emit(UserError('Failed to load user data.'));
    }
  }

  Future<void> _onSaveBPReading(
    SaveBPReading event,
    Emitter<UserState> emit,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        emit(UserError('No user logged in'));
        return;
      }

      // Store inside the user's bp readings database — unless the caller has
      // already persisted it (the voice-entry flow writes the raw spoken value
      // itself). Writing again here is what produced duplicate daily readings.
      if (!event.alreadyPersisted) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('readings')
            .add({
              'systolic': event.systolic,
              'diastolic': event.diastolic,
              'date': FieldValue.serverTimestamp(),
            });
      }

      // Auto-compute and store risk score after saving BP reading
      // This populates the risk_scores collection so the Risk Trend chart
      // shows real model-based scores instead of a heuristic fallback.
      _computeAndStoreRiskScore(user.uid, event.systolic, event.diastolic);

      // Reload data after saving
      add(LoadUserData());
    } catch (e) {
      emit(UserError('Failed to save reading: $e'));
    }
  }

  /// Compute risk score in background after a BP reading is recorded.
  /// Uses real user data from Firestore to build the feature vector.
  Future<void> _computeAndStoreRiskScore(
    String uid,
    int newSystolic,
    int newDiastolic,
  ) async {
    try {
      final userFeatures = await _buildUserFeaturesFromFirebase(
        uid,
        newSystolic,
        newDiastolic,
      );

      // Trigger GPT Insight Generation asynchronously without awaiting so it doesn't block RiskService
      InsightGeneratorService.generateAndSaveInsight(
        uid: uid,
        newSystolic: newSystolic.toDouble(),
        newDiastolic: newDiastolic.toDouble(),
        avgSystolic: userFeatures['avg_systolic'] as double? ?? newSystolic.toDouble(),
        avgDiastolic: userFeatures['avg_diastolic'] as double? ?? newDiastolic.toDouble(),
        hasSymptoms: false,
      );

      final riskService = HealthRiskScoreService();
      await riskService.initialize();
      await riskService.calculateRiskScore(
        userId: uid,
        userFeatures: userFeatures,
      );
      riskService.dispose();

      debugPrint('✅ Risk score computed and stored after BP recording');
    } catch (e) {
      // Non-critical — don't block the save flow
      debugPrint('⚠️ Risk score computation failed (non-blocking): $e');
    }
  }

  /// Build a real userFeatures map from Firestore data for the TFLite model.
  Future<Map<String, dynamic>> _buildUserFeaturesFromFirebase(
    String uid,
    int newSystolic,
    int newDiastolic,
  ) async {
    final firestore = FirebaseFirestore.instance;
    final userRef = firestore.collection('users').doc(uid);

    // 1. User profile (age, gender)
    final userDoc = await userRef.get();
    final userData = userDoc.data() ?? {};
    final age = userData['age'] as int? ?? 45;
    final gender = userData['gender'] as String? ?? 'Unknown';

    // 2. Medical profile (smoking, diabetes, activity, weight, height)
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
    double bmi = 25.0; // default
    if (weight != null && height != null && height > 0) {
      final heightM = height / 100.0;
      bmi = weight / (heightM * heightM);
    }

    // Map physical activity level to a score
    final activityStr = (medical['physicalActivity'] as String?) ?? '';
    double activityScore;
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
      default:
        activityScore = 1.0;
    }

    // 3. Recent BP readings to calculate averages
    final now = DateTime.now();
    final monthAgo = now.subtract(const Duration(days: 30));
    final readingsQuery = await userRef
        .collection('readings')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(monthAgo))
        .orderBy('date', descending: true)
        .limit(30)
        .get();

    double avgSystolic = newSystolic.toDouble();
    double avgDiastolic = newDiastolic.toDouble();

    if (readingsQuery.docs.isNotEmpty) {
      final allSys =
          readingsQuery.docs
              .map((d) => (d.data()['systolic'] as num?)?.toDouble())
              .whereType<double>()
              .toList()
            ..add(newSystolic.toDouble());
      final allDia =
          readingsQuery.docs
              .map((d) => (d.data()['diastolic'] as num?)?.toDouble())
              .whereType<double>()
              .toList()
            ..add(newDiastolic.toDouble());

      avgSystolic = allSys.reduce((a, b) => a + b) / allSys.length;
      avgDiastolic = allDia.reduce((a, b) => a + b) / allDia.length;
    }

    // Estimate sedentary minutes from activity level
    double sedentaryMinutes;
    if (activityScore >= 2.0) {
      sedentaryMinutes = 180;
    } else if (activityScore >= 1.0) {
      sedentaryMinutes = 360;
    } else {
      sedentaryMinutes = 540;
    }

    return {
      'age': age,
      'gender': gender,
      'avg_systolic': avgSystolic,
      'avg_diastolic': avgDiastolic,
      'latest_systolic': newSystolic,
      'latest_diastolic': newDiastolic,
      'bmi': bmi,
      'smoker_status': smoker,
      'has_diabetes': hasDiabetes,
      'physical_activity_score': activityScore,
      'sedentary_minutes': sedentaryMinutes,
      'sodium_intake': 2300, // default estimate, refine if user logs diet
      'total_cholesterol': 200, // default estimate
      'fasting_glucose': 100, // default estimate
      'alcohol_use': 0,
      'takes_bp_medication':
          (medical['medications'] as String?)?.isNotEmpty == true ? 1.0 : 0.0,
      'has_heart_condition': 0,
    };
  }
}
