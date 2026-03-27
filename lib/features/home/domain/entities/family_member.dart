import 'package:equatable/equatable.dart';
import 'package:arteria/Core/Utils/firebase_helpers.dart';

enum FamilyInviteStatus {
  pending,
  accepted,
  declined,
  expired;

  String get displayName {
    switch (this) {
      case FamilyInviteStatus.pending:
        return 'Pending';
      case FamilyInviteStatus.accepted:
        return 'Connected';
      case FamilyInviteStatus.declined:
        return 'Declined';
      case FamilyInviteStatus.expired:
        return 'Expired';
    }
  }
}

enum SharePermission {
  viewOnly,
  viewAndExport,
  fullAccess;

  String get displayName {
    switch (this) {
      case SharePermission.viewOnly:
        return 'View Only';
      case SharePermission.viewAndExport:
        return 'View & Export';
      case SharePermission.fullAccess:
        return 'Full Access';
    }
  }

  String get description {
    switch (this) {
      case SharePermission.viewOnly:
        return 'Can view your readings and trends';
      case SharePermission.viewAndExport:
        return 'Can view and share your reports';
      case SharePermission.fullAccess:
        return 'Full access to your health data';
    }
  }
}

class FamilyMember extends Equatable {
  final String id;
  final String userId;
  final String name;
  final String? profilePicture;
  final SharePermission permission;
  final FamilyInviteStatus status;
  final DateTime? lastReadingAt;
  final Map<String, dynamic>? lastReading;
  final DateTime addedAt;

  const FamilyMember({
    required this.id,
    required this.userId,
    required this.name,
    this.profilePicture,
    required this.permission,
    required this.status,
    this.lastReadingAt,
    this.lastReading,
    required this.addedAt,
  });

  factory FamilyMember.fromMap(Map<String, dynamic> map) {
    return FamilyMember(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      profilePicture: map['profilePicture'],
      permission: SharePermission.values.firstWhere(
        (e) => e.name == map['permission'],
        orElse: () => SharePermission.viewOnly,
      ),
      status: FamilyInviteStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => FamilyInviteStatus.pending,
      ),
      lastReadingAt: FirebaseHelpers.parseDateTime(map['lastReadingAt']),
      lastReading: map['lastReading'],
      addedAt: FirebaseHelpers.parseDateTime(map['addedAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'profilePicture': profilePicture,
      'permission': permission.name,
      'status': status.name,
      'lastReadingAt': lastReadingAt?.toIso8601String(),
      'lastReading': lastReading,
      'addedAt': addedAt.toIso8601String(),
    };
  }

  FamilyMember copyWith({
    String? id,
    String? userId,
    String? name,
    String? profilePicture,
    SharePermission? permission,
    FamilyInviteStatus? status,
    DateTime? lastReadingAt,
    Map<String, dynamic>? lastReading,
    DateTime? addedAt,
  }) {
    return FamilyMember(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      profilePicture: profilePicture ?? this.profilePicture,
      permission: permission ?? this.permission,
      status: status ?? this.status,
      lastReadingAt: lastReadingAt ?? this.lastReadingAt,
      lastReading: lastReading ?? this.lastReading,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  bool get isConnected => status == FamilyInviteStatus.accepted;

  bool get hasRecentReading {
    if (lastReadingAt == null) return false;
    final now = DateTime.now();
    return now.difference(lastReadingAt!).inHours < 48;
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    name,
    profilePicture,
    permission,
    status,
    lastReadingAt,
    lastReading,
    addedAt,
  ];
}

class FamilyInvite extends Equatable {
  final String id;
  final String inviterUserId;
  final String inviterName;
  final String? email;
  final String? phone;
  final String inviteCode;
  final SharePermission permission;
  final FamilyInviteStatus status;
  final DateTime createdAt;
  final DateTime expiresAt;

  const FamilyInvite({
    required this.id,
    required this.inviterUserId,
    required this.inviterName,
    this.email,
    this.phone,
    required this.inviteCode,
    required this.permission,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
  });

  factory FamilyInvite.fromMap(Map<String, dynamic> map) {
    return FamilyInvite(
      id: map['id'] ?? '',
      inviterUserId: map['inviterUserId'] ?? '',
      inviterName: map['inviterName'] ?? '',
      email: map['email'],
      phone: map['phone'],
      inviteCode: map['inviteCode'] ?? '',
      permission: SharePermission.values.firstWhere(
        (e) => e.name == map['permission'],
        orElse: () => SharePermission.viewOnly,
      ),
      status: FamilyInviteStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => FamilyInviteStatus.pending,
      ),
      createdAt: FirebaseHelpers.parseDateTime(map['createdAt']) ?? DateTime.now(),
      expiresAt: FirebaseHelpers.parseDateTime(map['expiresAt']) ?? DateTime.now().add(const Duration(days: 7)),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'inviterUserId': inviterUserId,
      'inviterName': inviterName,
      'email': email,
      'phone': phone,
      'inviteCode': inviteCode,
      'permission': permission.name,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
    };
  }

  FamilyInvite copyWith({
    String? id,
    String? inviterUserId,
    String? inviterName,
    String? email,
    String? phone,
    String? inviteCode,
    SharePermission? permission,
    FamilyInviteStatus? status,
    DateTime? createdAt,
    DateTime? expiresAt,
  }) {
    return FamilyInvite(
      id: id ?? this.id,
      inviterUserId: inviterUserId ?? this.inviterUserId,
      inviterName: inviterName ?? this.inviterName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      inviteCode: inviteCode ?? this.inviteCode,
      permission: permission ?? this.permission,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  @override
  List<Object?> get props => [
    id,
    inviterUserId,
    inviterName,
    email,
    phone,
    inviteCode,
    permission,
    status,
    createdAt,
    expiresAt,
  ];
}
