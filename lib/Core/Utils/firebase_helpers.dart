import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseHelpers {
  /// Safely parses a date from Firestore data, which could be a [Timestamp],
  /// a [String] (ISO 8601), or null.
  static DateTime? parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
