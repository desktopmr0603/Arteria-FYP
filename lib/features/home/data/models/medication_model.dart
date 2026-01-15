import 'package:arteria/features/home/domain/entities/medication.dart';
import 'package:flutter/material.dart';

class MedicationModel {
  final String id;
  final String userId;
  final String name;
  final String dosage;
  final String frequency;
  final List<String> times;
  final bool isActive;
  final String? lastTakenAt;
  final bool takenToday;
  final String createdAt;
  final String? instructions;
  final int color;

  MedicationModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.times,
    required this.isActive,
    this.lastTakenAt,
    required this.takenToday,
    required this.createdAt,
    this.instructions,
    required this.color,
  });

  factory MedicationModel.fromDocument(Map<String, dynamic> doc) {
    return MedicationModel(
      id: doc['id'] ?? '',
      userId: doc['userId'] ?? '',
      name: doc['name'] ?? '',
      dosage: doc['dosage'] ?? '',
      frequency: doc['frequency'] ?? 'onceDaily',
      times: List<String>.from(doc['times'] ?? []),
      isActive: doc['isActive'] ?? true,
      lastTakenAt: doc['lastTakenAt'],
      takenToday: doc['takenToday'] ?? false,
      createdAt: doc['createdAt'] ?? DateTime.now().toIso8601String(),
      instructions: doc['instructions'],
      color: doc['color'] ?? 0xFF6366F1,
    );
  }

  Medication toEntity() {
    return Medication(
      id: id,
      name: name,
      dosage: dosage,
      frequency: MedicationFrequency.values.firstWhere(
        (e) => e.name == frequency,
        orElse: () => MedicationFrequency.onceDaily,
      ),
      times: times,
      isActive: isActive,
      lastTakenAt: lastTakenAt != null ? DateTime.parse(lastTakenAt!) : null,
      takenToday: takenToday,
      createdAt: DateTime.parse(createdAt),
      instructions: instructions,
      color: Color(color),
    );
  }

  Map<String, dynamic> toDocument() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'dosage': dosage,
      'frequency': frequency,
      'times': times,
      'isActive': isActive,
      'lastTakenAt': lastTakenAt,
      'takenToday': takenToday,
      'createdAt': createdAt,
      'instructions': instructions,
      'color': color,
    };
  }
}
