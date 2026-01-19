import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Types of reminder repeat patterns
enum RepeatType { daily, weekdays, weekends, custom }

/// Model representing a BP measurement reminder
class Reminder {
  final String id;
  final TimeOfDay time;
  final RepeatType repeatType;
  final List<int> customDays; // 1-7 for Monday-Sunday
  final bool isEnabled;
  final String? label;
  final DateTime createdAt;

  const Reminder({
    required this.id,
    required this.time,
    this.repeatType = RepeatType.daily,
    this.customDays = const [],
    this.isEnabled = true,
    this.label,
    required this.createdAt,
  });

  /// Create a Reminder from Firestore document
  factory Reminder.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Reminder(
      id: doc.id,
      time: TimeOfDay(
        hour: (data['hour'] as num?)?.toInt() ?? 8,
        minute: (data['minute'] as num?)?.toInt() ?? 0,
      ),
      repeatType: RepeatType.values.firstWhere(
        (e) => e.name == data['repeatType'],
        orElse: () => RepeatType.daily,
      ),
      customDays: List<int>.from(data['customDays'] ?? []),
      isEnabled: data['isEnabled'] as bool? ?? true,
      label: data['label'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Convert Reminder to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'hour': time.hour,
      'minute': time.minute,
      'repeatType': repeatType.name,
      'customDays': customDays,
      'isEnabled': isEnabled,
      'label': label,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  /// Create a copy with modified fields
  Reminder copyWith({
    String? id,
    TimeOfDay? time,
    RepeatType? repeatType,
    List<int>? customDays,
    bool? isEnabled,
    String? label,
    DateTime? createdAt,
  }) {
    return Reminder(
      id: id ?? this.id,
      time: time ?? this.time,
      repeatType: repeatType ?? this.repeatType,
      customDays: customDays ?? this.customDays,
      isEnabled: isEnabled ?? this.isEnabled,
      label: label ?? this.label,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Get a formatted time string (e.g., "8:00 AM")
  String get formattedTime {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  /// Get a formatted repeat string
  String get formattedRepeat {
    switch (repeatType) {
      case RepeatType.daily:
        return 'Daily';
      case RepeatType.weekdays:
        return 'Weekdays';
      case RepeatType.weekends:
        return 'Weekends';
      case RepeatType.custom:
        if (customDays.isEmpty) return 'Custom';
        final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        return customDays.map((d) => days[d - 1]).join(', ');
    }
  }

  /// Check if reminder should trigger on a given weekday (1-7, Monday-Sunday)
  bool shouldTriggerOnDay(int weekday) {
    switch (repeatType) {
      case RepeatType.daily:
        return true;
      case RepeatType.weekdays:
        return weekday >= 1 && weekday <= 5;
      case RepeatType.weekends:
        return weekday == 6 || weekday == 7;
      case RepeatType.custom:
        return customDays.contains(weekday);
    }
  }

  /// Calculate the next trigger DateTime from now
  DateTime? getNextTriggerTime() {
    final now = DateTime.now();
    var candidate = DateTime(
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    // If today's time has passed, start from tomorrow
    if (candidate.isBefore(now)) {
      candidate = candidate.add(const Duration(days: 1));
    }

    // Find next valid day (up to 7 days ahead)
    for (int i = 0; i < 7; i++) {
      final checkDate = candidate.add(Duration(days: i));
      if (shouldTriggerOnDay(checkDate.weekday)) {
        return checkDate;
      }
    }

    return null; // No valid day found
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Reminder && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
