import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents blood pressure trend data point
class TrendData extends Equatable {
  final DateTime timestamp;
  final int systolic;
  final int diastolic;
  final int? pulse;
  final BPCategory category;
  final String id;

  const TrendData({
    required this.timestamp,
    required this.systolic,
    required this.diastolic,
    this.pulse,
    required this.category,
    required this.id,
  });

  /// Creates TrendData from Firestore data
  factory TrendData.fromFirestore({
    required Map<String, dynamic> data,
    required String id,
  }) {
    final timestamp = data['date'] as Timestamp?;
    final systolic = (data['systolic'] as num?)?.toInt() ?? 0;
    final diastolic = (data['diastolic'] as num?)?.toInt() ?? 0;
    final pulse = data['pulse'] as int?;

    return TrendData(
      id: id,
      timestamp: timestamp?.toDate() ?? DateTime.now(),
      systolic: systolic,
      diastolic: diastolic,
      pulse: pulse,
      category: _classifyBP(systolic, diastolic),
    );
  }

  /// Classifies blood pressure per 2025 AHA/ACC guidelines
  static BPCategory _classifyBP(int systolic, int diastolic) {
    // Hypertensive Crisis: systolic >180 AND/OR diastolic >120
    if (systolic > 180 || diastolic > 120) { return BPCategory.hypertensiveCrisis; }
    // Stage 2 Hypertension: systolic >=140 OR diastolic >=90
    if (systolic >= 140 || diastolic >= 90) { return BPCategory.hypertensionStage2; }
    // Stage 1 Hypertension: systolic >=130 OR diastolic >80
    if (systolic >= 130 || diastolic > 80) { return BPCategory.hypertensionStage1; }
    // Elevated: systolic 121-129 AND diastolic <=80
    if (systolic > 120 && diastolic <= 80) { return BPCategory.elevated; }
    // Hypotension (Low): systolic <90 OR diastolic <60 — checked before Normal
    if (systolic < 90 || diastolic < 60) { return BPCategory.hypotension; }
    // Normal: systolic <120 AND diastolic <80
    return BPCategory.normal;
  }

  /// Converts to Firestore data
  Map<String, dynamic> toFirestore() {
    return {
      'systolic': systolic,
      'diastolic': diastolic,
      'pulse': pulse,
      'date': Timestamp.fromDate(timestamp),
      'category': category.name,
    };
  }

  /// Returns formatted BP reading string
  String get formattedReading => '$systolic/$diastolic mmHg';

  /// Returns formatted timestamp
  String get formattedTimestamp =>
      '${timestamp.day}/${timestamp.month}/${timestamp.year}';

  @override
  List<Object> get props => [
    timestamp,
    systolic,
    diastolic,
    pulse ?? 0,
    category,
    id,
  ];

  @override
  String toString() {
    return 'TrendData(id: $id, timestamp: $timestamp, systolic: $systolic, diastolic: $diastolic, category: $category)';
  }

  /// Create a copy with updated values
  TrendData copyWith({
    DateTime? timestamp,
    int? systolic,
    int? diastolic,
    int? pulse,
    BPCategory? category,
    String? id,
  }) {
    return TrendData(
      timestamp: timestamp ?? this.timestamp,
      systolic: systolic ?? this.systolic,
      diastolic: diastolic ?? this.diastolic,
      pulse: pulse ?? this.pulse,
      category: category ?? this.category,
      id: id ?? this.id,
    );
  }
}

/// Blood Pressure category based on AHA guidelines
enum BPCategory {
  hypotension,
  normal,
  elevated,
  hypertensionStage1,
  hypertensionStage2,
  hypertensiveCrisis;

  String get displayName {
    switch (this) {
      case BPCategory.hypotension:
        return 'Low (Hypotension)';
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

  /// Returns color for the category
  String get colorCode {
    switch (this) {
      case BPCategory.hypotension:
        return '#2196F3'; // Blue
      case BPCategory.normal:
        return '#4CAF50'; // Green
      case BPCategory.elevated:
        return '#FF9800'; // Orange
      case BPCategory.hypertensionStage1:
        return '#FF5722'; // Deep Orange
      case BPCategory.hypertensionStage2:
        return '#F44336'; // Red
      case BPCategory.hypertensiveCrisis:
        return '#D32F2F'; // Dark Red
    }
  }

  /// Returns severity level (0-4)
  int get severity {
    switch (this) {
      case BPCategory.hypotension:
        return 2;
      case BPCategory.normal:
        return 0;
      case BPCategory.elevated:
        return 1;
      case BPCategory.hypertensionStage1:
        return 2;
      case BPCategory.hypertensionStage2:
        return 3;
      case BPCategory.hypertensiveCrisis:
        return 4;
    }
  }

  /// Returns if medical attention is required
  bool get requiresAttention {
    return severity >= 2;
  }
}
