import 'package:equatable/equatable.dart';

/// Time range for filtering trend data
class TimeRange extends Equatable {
  final DateTime start;
  final DateTime end;
  final TimeRangeType type;
  final String? displayName;

  const TimeRange({
    required this.start,
    required this.end,
    required this.type,
    this.displayName,
  });

  /// Factory for predefined time ranges
  factory TimeRange.last7Days() {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 7));
    return TimeRange(
      start: start,
      end: now,
      type: TimeRangeType.last7Days,
      displayName: 'Last 7 Days',
    );
  }

  factory TimeRange.last30Days() {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 30));
    return TimeRange(
      start: start,
      end: now,
      type: TimeRangeType.last30Days,
      displayName: 'Last 30 Days',
    );
  }

  factory TimeRange.last90Days() {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 90));
    return TimeRange(
      start: start,
      end: now,
      type: TimeRangeType.last90Days,
      displayName: 'Last 90 Days',
    );
  }

  factory TimeRange.thisYear() {
    final now = DateTime.now();
    final start = DateTime(now.year, 1, 1);
    return TimeRange(
      start: start,
      end: now,
      type: TimeRangeType.thisYear,
      displayName: 'This Year',
    );
  }

  factory TimeRange.custom({required DateTime start, required DateTime end}) {
    return TimeRange(
      start: start,
      end: end,
      type: TimeRangeType.custom,
      displayName: '${_formatDate(start)} - ${_formatDate(end)}',
    );
  }

  /// Format date for display
  static String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  /// Get formatted display name
  String get formattedName {
    return displayName ?? _formatDate(start) + ' - ' + _formatDate(end);
  }

  /// Get duration of time range
  Duration get duration {
    return end.difference(start);
  }

  /// Get number of days in range
  int get days {
    return duration.inDays;
  }

  /// Check if range is valid (start before end)
  bool get isValid {
    return start.isBefore(end) || start.isAtSameMomentAs(end);
  }

  /// Check if range is recent (within last 30 days)
  bool get isRecent {
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    return start.isAfter(thirtyDaysAgo);
  }

  /// Check if range is long term (more than 90 days)
  bool get isLongTerm {
    return days > 90;
  }

  /// Check if range contains specific date
  bool contains(DateTime date) {
    return (date.isAfter(start) || date.isAtSameMomentAs(start)) &&
        (date.isBefore(end) || date.isAtSameMomentAs(end));
  }

  /// Check if range overlaps with another range
  bool overlaps(TimeRange other) {
    return start.isBefore(other.end) && end.isAfter(other.start);
  }

  /// Create a copy with updated values
  TimeRange copyWith({
    DateTime? start,
    DateTime? end,
    TimeRangeType? type,
    String? displayName,
  }) {
    return TimeRange(
      start: start ?? this.start,
      end: end ?? this.end,
      type: type ?? this.type,
      displayName: displayName ?? this.displayName,
    );
  }

  /// Convert to Map for serialization
  Map<String, dynamic> toMap() {
    return {
      'start': start.toIso8601String(),
      'end': end.toIso8601String(),
      'type': type.name,
      'displayName': displayName,
    };
  }

  /// Create from Map
  factory TimeRange.fromMap(Map<String, dynamic> map) {
    return TimeRange(
      start: DateTime.parse(map['start']),
      end: DateTime.parse(map['end']),
      type: TimeRangeType.values.firstWhere((e) => e.name == map['type']),
      displayName: map['displayName'],
    );
  }

  @override
  List<Object> get props => [start, end, type, displayName ?? ''];

  @override
  String toString() {
    return 'TimeRange(type: $type, start: $start, end: $end)';
  }
}

/// Predefined time range types
enum TimeRangeType {
  last7Days,
  last30Days,
  last90Days,
  thisYear,
  custom;

  String get displayName {
    switch (this) {
      case TimeRangeType.last7Days:
        return 'Last 7 Days';
      case TimeRangeType.last30Days:
        return 'Last 30 Days';
      case TimeRangeType.last90Days:
        return 'Last 90 Days';
      case TimeRangeType.thisYear:
        return 'This Year';
      case TimeRangeType.custom:
        return 'Custom Range';
    }
  }

  /// Get default days for this type
  int get defaultDays {
    switch (this) {
      case TimeRangeType.last7Days:
        return 7;
      case TimeRangeType.last30Days:
        return 30;
      case TimeRangeType.last90Days:
        return 90;
      case TimeRangeType.thisYear:
        return DateTime.now()
            .difference(DateTime(DateTime.now().year, 1, 1))
            .inDays;
      case TimeRangeType.custom:
        return 30; // Default fallback
    }
  }

  /// Check if type is predefined
  bool get isPredefined {
    return this != TimeRangeType.custom;
  }

  /// Check if type is suitable for detailed analysis
  bool get isDetailedAnalysis {
    return this == TimeRangeType.last30Days || this == TimeRangeType.last90Days;
  }

  /// Check if type is suitable for quick overview
  bool get isQuickOverview {
    return this == TimeRangeType.last7Days;
  }
}
