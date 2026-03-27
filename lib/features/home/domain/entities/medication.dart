import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:arteria/Core/Utils/firebase_helpers.dart';

enum MedicationFrequency {
  onceDaily,
  twiceDaily,
  threeTimesDaily,
  weekly,
  asNeeded;

  String get displayName {
    switch (this) {
      case MedicationFrequency.onceDaily:
        return 'Once daily';
      case MedicationFrequency.twiceDaily:
        return 'Twice daily';
      case MedicationFrequency.threeTimesDaily:
        return 'Three times daily';
      case MedicationFrequency.weekly:
        return 'Weekly';
      case MedicationFrequency.asNeeded:
        return 'As needed';
    }
  }

  List<String> get defaultTimes {
    switch (this) {
      case MedicationFrequency.onceDaily:
        return ['08:00'];
      case MedicationFrequency.twiceDaily:
        return ['08:00', '20:00'];
      case MedicationFrequency.threeTimesDaily:
        return ['08:00', '14:00', '20:00'];
      case MedicationFrequency.weekly:
        return ['08:00'];
      case MedicationFrequency.asNeeded:
        return [];
    }
  }
}

class Medication extends Equatable {
  final String id;
  final String name;
  final String dosage;
  final MedicationFrequency frequency;
  final List<String> times;
  final bool isActive;
  final DateTime? lastTakenAt;
  final bool takenToday;
  final DateTime createdAt;
  final String? instructions;
  final Color? color;

  const Medication({
    required this.id,
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.times,
    this.isActive = true,
    this.lastTakenAt,
    this.takenToday = false,
    required this.createdAt,
    this.instructions,
    this.color,
  });

  factory Medication.fromMap(Map<String, dynamic> map) {
    return Medication(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      dosage: map['dosage'] ?? '',
      frequency: MedicationFrequency.values.firstWhere(
        (e) => e.name == map['frequency'],
        orElse: () => MedicationFrequency.onceDaily,
      ),
      times: List<String>.from(map['times'] ?? []),
      isActive: map['isActive'] ?? true,
      lastTakenAt: FirebaseHelpers.parseDateTime(map['lastTakenAt']),
      takenToday: map['takenToday'] ?? false,
      createdAt: FirebaseHelpers.parseDateTime(map['createdAt']) ?? DateTime.now(),
      instructions: map['instructions'],
      color: map['color'] != null
          ? Color(map['color'])
          : const Color(0xFF6366F1),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'dosage': dosage,
      'frequency': frequency.name,
      'times': times,
      'isActive': isActive,
      'lastTakenAt': lastTakenAt?.toIso8601String(),
      'takenToday': takenToday,
      'createdAt': createdAt.toIso8601String(),
      'instructions': instructions,
      'color': color?.value,
    };
  }

  Medication copyWith({
    String? id,
    String? name,
    String? dosage,
    MedicationFrequency? frequency,
    List<String>? times,
    bool? isActive,
    DateTime? lastTakenAt,
    bool? takenToday,
    DateTime? createdAt,
    String? instructions,
    Color? color,
  }) {
    return Medication(
      id: id ?? this.id,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      frequency: frequency ?? this.frequency,
      times: times ?? this.times,
      isActive: isActive ?? this.isActive,
      lastTakenAt: lastTakenAt ?? this.lastTakenAt,
      takenToday: takenToday ?? this.takenToday,
      createdAt: createdAt ?? this.createdAt,
      instructions: instructions ?? this.instructions,
      color: color ?? this.color,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    dosage,
    frequency,
    times,
    isActive,
    lastTakenAt,
    takenToday,
    createdAt,
    instructions,
    color,
  ];
}

class MedicationLog extends Equatable {
  final String id;
  final String medicationId;
  final DateTime takenAt;
  final bool skipped;
  final String? notes;

  const MedicationLog({
    required this.id,
    required this.medicationId,
    required this.takenAt,
    this.skipped = false,
    this.notes,
  });

  factory MedicationLog.fromMap(Map<String, dynamic> map) {
    return MedicationLog(
      id: map['id'] ?? '',
      medicationId: map['medicationId'] ?? '',
      takenAt: FirebaseHelpers.parseDateTime(map['takenAt']) ?? DateTime.now(),
      skipped: map['skipped'] ?? false,
      notes: map['notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'medicationId': medicationId,
      'takenAt': takenAt.toIso8601String(),
      'skipped': skipped,
      'notes': notes,
    };
  }

  @override
  List<Object?> get props => [id, medicationId, takenAt, skipped, notes];
}
