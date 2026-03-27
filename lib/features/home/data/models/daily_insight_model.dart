import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single health insight stored in Firestore.
///
/// Firestore collection: `users/{uid}/insights`
/// Fields expected according to the schema:
///   title         – String (e.g. "Daily Health Insight")
///   message       – String
///   status        – String? (e.g. "OPTIMAL")
///   icon          – String? (e.g. "heart_rate")
///   type          – String? (e.g. "daily_summary")
///   createdAt     – Timestamp?
///
/// Strict rules:
/// - We absolutely do NOT inject fake medical data.
/// - If a field is missing, we map it as safely as possible.
class InsightModel {
  final String title;
  final String message;
  final String? status;
  final String? icon;
  final String? type;
  final DateTime? createdAt;

  const InsightModel({
    required this.title,
    required this.message,
    this.status,
    this.icon,
    this.type,
    this.createdAt,
  });

  factory InsightModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return InsightModel(
      title: data['title'] as String? ?? 'Insight',
      message: data['message'] as String? ?? 'No insight available yet.',
      status: data['status'] as String?,
      icon: data['icon'] as String?,
      type: data['type'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Minimal neutral fallback when no data exists in Firestore.
  /// No fake data is generated here.
  factory InsightModel.emptyFallback() {
    return const InsightModel(
      title: 'Insight',
      message: 'No insight available yet.',
      status: null,
      icon: null,
      type: null,
      createdAt: null,
    );
  }
}
