import 'package:cloud_firestore/cloud_firestore.dart';

/// Blood Pressure category based on AHA guidelines
enum BPCategory {
  normal,
  elevated,
  hypertensionStage1,
  hypertensionStage2,
  hypertensiveCrisis,
}

/// Blood Pressure classification result
class BPClassification {
  final BPCategory category;
  final int severity;
  final String description;
  final int systolic;
  final int diastolic;
  final bool isNormal;
  final bool requiresAttention;

  BPClassification({
    required this.category,
    required this.severity,
    required this.description,
    required this.systolic,
    required this.diastolic,
    required this.isNormal,
    required this.requiresAttention,
  });

  String get categoryName {
    switch (category) {
      case BPCategory.normal:
        return 'Normal';
      case BPCategory.elevated:
        return 'Elevated';
      case BPCategory.hypertensionStage1:
        return 'Hypertension Stage 1';
      case BPCategory.hypertensionStage2:
        return 'Hypertension Stage 2';
      case BPCategory.hypertensiveCrisis:
        return 'Hypertensive Crisis';
    }
  }
}

/// Service for fetching and analyzing BP data from Firestore
class BPDataService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get latest BP reading for a user
  Future<Map<String, dynamic>?> getLatestReading(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('readings')
          .orderBy('date', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      final doc = snapshot.docs.first;
      final data = doc.data();
      return {
        'id': doc.id,
        'systolic': data['systolic'],
        'diastolic': data['diastolic'],
        'pulse': data['pulse'],
        'timestamp': data['date'],
      };
    } catch (e) {
      print('Error fetching latest BP reading: $e');
      return null;
    }
  }

  /// Get today's BP readings
  Future<List<Map<String, dynamic>>> getTodayReadings(String userId) async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);

      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('readings')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'systolic': data['systolic'],
          'diastolic': data['diastolic'],
          'pulse': data['pulse'],
          'timestamp': data['date'],
        };
      }).toList();
    } catch (e) {
      print('Error fetching today\'s BP readings: $e');
      return [];
    }
  }

  /// Get BP history for specified number of days
  Future<List<Map<String, dynamic>>> getHistory(String userId, {int days = 7}) async {
    try {
      final startDate = DateTime.now().subtract(Duration(days: days));

      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('readings')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'systolic': data['systolic'],
          'diastolic': data['diastolic'],
          'pulse': data['pulse'],
          'timestamp': data['date'],
        };
      }).toList();
    } catch (e) {
      print('Error fetching BP history: $e');
      return [];
    }
  }

  /// Get user profile (including age)
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return doc.exists ? doc.data() : null;
    } catch (e) {
      print('Error fetching user profile: $e');
      return null;
    }
  }

  /// Classify BP reading based on AHA guidelines
  BPClassification classifyBP(int systolic, int diastolic, {int? age}) {
    BPCategory category;
    int severity;
    String description;

    if (systolic < 120 && diastolic < 80) {
      category = BPCategory.normal;
      severity = 0;
      description = 'Your blood pressure is in the normal range.';
    } else if (systolic < 130 && diastolic < 80) {
      category = BPCategory.elevated;
      severity = 1;
      description = 'Your blood pressure is elevated. Lifestyle changes are recommended.';
    } else if ((systolic >= 120 && systolic <= 129) && diastolic < 80) {
      category = BPCategory.elevated;
      severity = 1;
      description = 'Your blood pressure is elevated. Lifestyle changes are recommended.';
    } else if ((systolic >= 130 && systolic <= 139) || (diastolic >= 80 && diastolic <= 89)) {
      category = BPCategory.hypertensionStage1;
      severity = 2;
      description = 'You have Stage 1 Hypertension. Consult your doctor about treatment options.';
    } else if (systolic >= 140 || diastolic >= 90) {
      if (systolic >= 180 || diastolic >= 120) {
        category = BPCategory.hypertensiveCrisis;
        severity = 4;
        description = 'URGENT: You may be experiencing a hypertensive crisis. Seek immediate medical attention!';
      } else {
        category = BPCategory.hypertensionStage2;
        severity = 3;
        description = 'You have Stage 2 Hypertension. Medical treatment is typically required.';
      }
    } else {
      category = BPCategory.normal;
      severity = 0;
      description = 'Your blood pressure is in the normal range.';
    }

    // Age-specific considerations
    if (age != null) {
      if (age >= 65) {
        description += ' Note: Blood pressure targets may differ for older adults. Consult your doctor.';
      } else if (age < 18) {
        description += ' Note: Pediatric BP ranges differ from adults. Please consult a pediatrician.';
      }
    }

    return BPClassification(
      category: category,
      severity: severity,
      description: description,
      systolic: systolic,
      diastolic: diastolic,
      isNormal: category == BPCategory.normal,
      requiresAttention: severity >= 2,
    );
  }

  /// Calculate statistics from multiple readings
  Map<String, dynamic> calculateStats(List<Map<String, dynamic>> readings) {
    if (readings.isEmpty) {
      return {
        'count': 0,
        'average': null,
        'min': null,
        'max': null,
        'latest': null,
      };
    }

    final systolicValues = readings.map((r) => r['systolic'] as int).toList();
    final diastolicValues = readings.map((r) => r['diastolic'] as int).toList();

    final avgSystolic = systolicValues.reduce((a, b) => a + b) / systolicValues.length;
    final avgDiastolic = diastolicValues.reduce((a, b) => a + b) / diastolicValues.length;

    return {
      'count': readings.length,
      'average': {
        'systolic': avgSystolic.round(),
        'diastolic': avgDiastolic.round(),
        'formatted': '${avgSystolic.round()}/${avgDiastolic.round()} mmHg',
      },
      'min': {
        'systolic': systolicValues.reduce((a, b) => a < b ? a : b),
        'diastolic': diastolicValues.reduce((a, b) => a < b ? a : b),
      },
      'max': {
        'systolic': systolicValues.reduce((a, b) => a > b ? a : b),
        'diastolic': diastolicValues.reduce((a, b) => a > b ? a : b),
      },
      'latest': readings.first,
    };
  }

  /// Analyze trend in BP readings
  Map<String, dynamic> analyzeTrend(List<Map<String, dynamic>> readings) {
    if (readings.length < 2) {
      return {
        'trend': 'insufficient_data',
        'description': 'Not enough data to determine a trend.',
      };
    }

    // Calculate averages
    final systolicValues = readings.map((r) => r['systolic'] as int).toList();
    final diastolicValues = readings.map((r) => r['diastolic'] as int).toList();

    final avgSystolic = systolicValues.reduce((a, b) => a + b) / systolicValues.length;
    final avgDiastolic = diastolicValues.reduce((a, b) => a + b) / diastolicValues.length;

    // Compare recent vs older readings
    final recentCount = (readings.length / 2).ceil();
    final recentSystolic = systolicValues.take(recentCount).reduce((a, b) => a + b) / recentCount;
    final recentDiastolic = diastolicValues.take(recentCount).reduce((a, b) => a + b) / recentCount;

    final olderSystolic = systolicValues.skip(recentCount).reduce((a, b) => a + b) / (readings.length - recentCount);
    final olderDiastolic = diastolicValues.skip(recentCount).reduce((a, b) => a + b) / (readings.length - recentCount);

    final sysChange = recentSystolic - olderSystolic;
    final diaChange = recentDiastolic - olderDiastolic;

    // Threshold for significant change (5 mmHg)
    const threshold = 5.0;

    String trend;
    String description;

    if (sysChange > threshold || diaChange > threshold) {
      trend = 'increasing';
      description = 'Your blood pressure has been trending upward recently.';
    } else if (sysChange < -threshold || diaChange < -threshold) {
      trend = 'decreasing';
      description = 'Your blood pressure has been trending downward recently.';
    } else {
      trend = 'stable';
      description = 'Your blood pressure has been relatively stable.';
    }

    return {
      'trend': trend,
      'description': description,
      'average_systolic': avgSystolic.round(),
      'average_diastolic': avgDiastolic.round(),
      'change_systolic': sysChange.round(),
      'change_diastolic': diaChange.round(),
      'reading_count': readings.length,
    };
  }

  /// Format BP data as context for AI
  /// 
  /// Set [mlRiskProbability] and [mlRiskLevel] when ML model predictions are available.
  String formatBPContext({
    required String userId,
    required Map<String, dynamic>? latestReading,
    List<Map<String, dynamic>>? weeklyReadings,
    int? userAge,
    String? gender,
    Map<String, dynamic>? medicalProfile,
    double? mlRiskProbability,
    String? mlRiskLevel,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('User Context:');
    buffer.writeln('- User ID: $userId');
    if (userAge != null) {
      buffer.writeln('- Age: $userAge years');
    }
    if (gender != null) {
      buffer.writeln('- Gender: $gender');
    }
    buffer.writeln();

    if (latestReading != null) {
      final systolic = latestReading['systolic'] as int;
      final diastolic = latestReading['diastolic'] as int;
      final pulse = latestReading['pulse'] as int?;
      final timestamp = (latestReading['timestamp'] as Timestamp?)?.toDate();

      final classification = classifyBP(systolic, diastolic, age: userAge);

      buffer.writeln('Latest Blood Pressure Reading:');
      buffer.writeln('- Reading: $systolic/$diastolic mmHg');
      if (pulse != null) {
        buffer.writeln('- Pulse: $pulse bpm');
      }
      if (timestamp != null) {
        buffer.writeln('- Recorded: ${timestamp.toString()}');
      }
      buffer.writeln('- Classification: ${classification.categoryName}');
      buffer.writeln('- Status: ${classification.description}');
      buffer.writeln();
    }

    // ML Model Prediction Section
    if (mlRiskProbability != null) {
      buffer.writeln('AI Risk Assessment (Machine Learning Model):');
      buffer.writeln('- Hypertension Risk Probability: ${(mlRiskProbability * 100).toStringAsFixed(1)}%');
      buffer.writeln('- Risk Level: ${mlRiskLevel ?? _classifyMLRisk(mlRiskProbability)}');
      buffer.writeln('- Note: This prediction uses NHANES 2021-2023 trained model');
      buffer.writeln();
    }

    if (weeklyReadings != null && weeklyReadings.isNotEmpty) {
      final stats = calculateStats(weeklyReadings);
      final trend = analyzeTrend(weeklyReadings);

      buffer.writeln('Weekly Summary (${stats['count']} readings):');
      buffer.writeln('- Average: ${stats['average']['formatted']}');
      buffer.writeln('- Trend: ${trend['description']}');
      buffer.writeln();
    }

    // Medical History Information
    final availableMedicalInfo = <String>[];
    final missingMedicalInfo = <String>[];

    if (medicalProfile != null) {
      // Check medications
      final medications = medicalProfile['medications'] as String?;
      if (medications != null && medications.trim().isNotEmpty) {
        availableMedicalInfo.add('Medications: $medications');
      } else {
        missingMedicalInfo.add('Current medications (especially BP medications)');
      }

      // Check smoking status
      final smoker = medicalProfile['smoker'] as bool?;
      if (smoker != null) {
        availableMedicalInfo.add('Smoking status: ${smoker ? "Smoker" : "Non-smoker"}');
      } else {
        missingMedicalInfo.add('Smoking or tobacco use status');
      }

      // Check pregnancy (only relevant for females)
      if (gender?.toLowerCase() == 'female') {
        final isPregnant = medicalProfile['isPregnant'] as bool?;
        if (isPregnant != null) {
          availableMedicalInfo.add('Pregnancy status: ${isPregnant ? "Currently pregnant" : "Not pregnant"}');
        } else {
          missingMedicalInfo.add('Pregnancy status');
        }
      }

      // Check diabetes
      final hasDiabetes = medicalProfile['hasDiabetes'] as bool?;
      if (hasDiabetes != null) {
        availableMedicalInfo.add('Diabetes: ${hasDiabetes ? "Yes" : "No"}');
      } else {
        missingMedicalInfo.add('Diabetes or other chronic conditions');
      }

      // Check physical activity
      final physicalActivity = medicalProfile['physicalActivity'] as String?;
      if (physicalActivity != null && physicalActivity.trim().isNotEmpty) {
        availableMedicalInfo.add('Physical Activity: $physicalActivity');
      } else {
        missingMedicalInfo.add('Typical diet and exercise routine');
      }

      // Check weight and height for BMI context
      final weight = medicalProfile['weight'] as num?;
      final height = medicalProfile['height'] as num?;
      if (weight != null && height != null) {
        final heightM = height / 100;
        final bmi = weight / (heightM * heightM);
        availableMedicalInfo.add('BMI: ${bmi.toStringAsFixed(1)} (Weight: ${weight}kg, Height: ${height}cm)');
      }
    }

    // Output available medical information
    if (availableMedicalInfo.isNotEmpty) {
      buffer.writeln('Available Medical Information:');
      for (final info in availableMedicalInfo) {
        buffer.writeln('- $info');
      }
      buffer.writeln();
    }

    // Output missing medical information
    if (missingMedicalInfo.isNotEmpty) {
      buffer.writeln('Missing Medical Information (ask if user inquires about BP normality):');
      for (final info in missingMedicalInfo) {
        buffer.writeln('- $info');
      }
      buffer.writeln();
    }

    buffer.writeln('Important: Always remind the user that this is informational only and not a substitute for professional medical advice.');

    return buffer.toString();
  }

  /// Classify ML risk probability
  String _classifyMLRisk(double probability) {
    if (probability < 0.3) return 'Low';
    if (probability < 0.6) return 'Moderate';
    return 'High';
  }

  /// Get recommendations based on classification
  List<String> getRecommendations(BPClassification classification) {
    switch (classification.category) {
      case BPCategory.normal:
        return [
          'Maintain a healthy lifestyle with regular exercise',
          'Continue eating a balanced diet low in sodium',
          'Monitor your blood pressure regularly',
          'Maintain a healthy weight',
        ];

      case BPCategory.elevated:
        return [
          'Adopt heart-healthy lifestyle changes',
          'Reduce sodium intake to less than 2,300mg per day',
          'Exercise at least 150 minutes per week',
          'Limit alcohol consumption',
          'Manage stress through relaxation techniques',
          'Monitor your BP more frequently',
        ];

      case BPCategory.hypertensionStage1:
        return [
          'Consult your doctor about treatment options',
          'Make lifestyle changes: diet, exercise, stress management',
          'Reduce sodium intake significantly',
          'Consider the DASH diet',
          'Monitor your BP regularly at home',
          'Medication may be recommended by your doctor',
        ];

      case BPCategory.hypertensionStage2:
        return [
          'Schedule an appointment with your doctor soon',
          'Medication is typically required at this stage',
          'Follow prescribed treatment plan carefully',
          'Make comprehensive lifestyle changes',
          'Monitor BP daily and keep a log',
          'Reduce sodium to less than 1,500mg per day',
        ];

      case BPCategory.hypertensiveCrisis:
        return [
          'SEEK IMMEDIATE MEDICAL ATTENTION',
          'Call emergency services or go to ER',
          'Do not wait - this is a medical emergency',
          'Rest and try to remain calm while getting help',
        ];
    }
  }
}
