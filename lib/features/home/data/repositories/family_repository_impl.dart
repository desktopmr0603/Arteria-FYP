import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:arteria/features/home/domain/entities/family_member.dart';
import 'package:arteria/features/home/domain/repositories/family_repository.dart';

class FamilyRepositoryImpl implements FamilyRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<List<FamilyMember>> getFamilyMembers(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('familyMembers')
          .where('status', isEqualTo: 'accepted')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return FamilyMember(
          id: doc.id,
          userId: data['userId'] ?? '',
          name: data['name'] ?? '',
          profilePicture: data['profilePicture'],
          permission: SharePermission.values.firstWhere(
            (e) => e.name == data['permission'],
            orElse: () => SharePermission.viewOnly,
          ),
          status: FamilyInviteStatus.accepted,
          lastReadingAt: data['lastReadingAt'] != null
              ? DateTime.parse(data['lastReadingAt'])
              : null,
          lastReading: data['lastReading'],
          addedAt: data['addedAt'] != null
              ? DateTime.parse(data['addedAt'])
              : DateTime.now(),
        );
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch family members: $e');
    }
  }

  @override
  Stream<List<FamilyMember>> watchFamilyMembers(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('familyMembers')
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            return FamilyMember(
              id: doc.id,
              userId: data['userId'] ?? '',
              name: data['name'] ?? '',
              profilePicture: data['profilePicture'],
              permission: SharePermission.values.firstWhere(
                (e) => e.name == data['permission'],
                orElse: () => SharePermission.viewOnly,
              ),
              status: FamilyInviteStatus.accepted,
              lastReadingAt: data['lastReadingAt'] != null
                  ? DateTime.parse(data['lastReadingAt'])
                  : null,
              lastReading: data['lastReading'],
              addedAt: data['addedAt'] != null
                  ? DateTime.parse(data['addedAt'])
                  : DateTime.now(),
            );
          }).toList(),
        );
  }

  @override
  Future<FamilyMember?> getFamilyMember(String userId, String memberId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('familyMembers')
          .doc(memberId)
          .get();

      if (!doc.exists) return null;

      final data = doc.data()!;
      return FamilyMember(
        id: doc.id,
        userId: data['userId'] ?? '',
        name: data['name'] ?? '',
        profilePicture: data['profilePicture'],
        permission: SharePermission.values.firstWhere(
          (e) => e.name == data['permission'],
          orElse: () => SharePermission.viewOnly,
        ),
        status: FamilyInviteStatus.values.firstWhere(
          (e) => e.name == data['status'],
          orElse: () => FamilyInviteStatus.pending,
        ),
        lastReadingAt: data['lastReadingAt'] != null
            ? DateTime.parse(data['lastReadingAt'])
            : null,
        lastReading: data['lastReading'],
        addedAt: data['addedAt'] != null
            ? DateTime.parse(data['addedAt'])
            : DateTime.now(),
      );
    } catch (e) {
      throw Exception('Failed to fetch family member: $e');
    }
  }

  @override
  Future<String> sendInvite(
    String userId,
    String inviterName,
    String? email,
    String? phone,
    SharePermission permission,
  ) async {
    try {
      final inviteCode = await generateInviteCode();

      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('outgoingInvites')
          .doc();

      await docRef.set({
        'inviterUserId': userId,
        'inviterName': inviterName,
        'email': email,
        'phone': phone,
        'inviteCode': inviteCode,
        'permission': permission.name,
        'status': 'pending',
        'createdAt': DateTime.now().toIso8601String(),
        'expiresAt': DateTime.now()
            .add(const Duration(days: 7))
            .toIso8601String(),
      });

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to send invite: $e');
    }
  }

  @override
  Future<bool> acceptInvite(String userId, String inviteCode) async {
    try {
      final inviteSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('incomingInvites')
          .where('inviteCode', isEqualTo: inviteCode)
          .limit(1)
          .get();

      if (inviteSnapshot.docs.isEmpty) {
        throw Exception('Invite not found');
      }

      final inviteDoc = inviteSnapshot.docs.first;
      final inviteData = inviteDoc.data();

      if (inviteData['status'] != 'pending') {
        throw Exception('Invite is no longer valid');
      }

      final inviterUserId = inviteData['inviterUserId'];
      final inviterName = inviteData['inviterName'];
      final permission = SharePermission.values.firstWhere(
        (e) => e.name == inviteData['permission'],
        orElse: () => SharePermission.viewOnly,
      );

      await _firestore.runTransaction((transaction) async {
        final inviterDocRef = _firestore
            .collection('users')
            .doc(inviterUserId)
            .collection('familyMembers')
            .doc(userId);

        final inviteDocRef = inviteDoc.reference;
        final incomingInviteRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('incomingInvites')
            .doc(inviteDoc.id);

        transaction.set(inviterDocRef, {
          'userId': userId,
          'name': inviterName,
          'permission': permission.name,
          'status': 'accepted',
          'addedAt': DateTime.now().toIso8601String(),
        });

        transaction.update(inviteDocRef, {'status': 'accepted'});
        transaction.update(incomingInviteRef, {'status': 'accepted'});
      });

      return true;
    } catch (e) {
      throw Exception('Failed to accept invite: $e');
    }
  }

  @override
  Future<bool> declineInvite(String userId, String inviteCode) async {
    try {
      final inviteSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('incomingInvites')
          .where('inviteCode', isEqualTo: inviteCode)
          .limit(1)
          .get();

      if (inviteSnapshot.docs.isEmpty) return false;

      await inviteSnapshot.docs.first.reference.update({'status': 'declined'});
      return true;
    } catch (e) {
      throw Exception('Failed to decline invite: $e');
    }
  }

  @override
  Future<bool> removeFamilyMember(String userId, String memberId) async {
    try {
      final batch = _firestore.batch();

      batch.delete(
        _firestore
            .collection('users')
            .doc(userId)
            .collection('familyMembers')
            .doc(memberId),
      );

      final memberSnapshot = await _firestore
          .collection('users')
          .doc(memberId)
          .collection('familyMembers')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (memberSnapshot.docs.isNotEmpty) {
        batch.delete(memberSnapshot.docs.first.reference);
      }

      await batch.commit();
      return true;
    } catch (e) {
      throw Exception('Failed to remove family member: $e');
    }
  }

  @override
  Future<bool> updateMemberPermission(
    String userId,
    String memberId,
    SharePermission permission,
  ) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('familyMembers')
          .doc(memberId)
          .update({'permission': permission.name});

      return true;
    } catch (e) {
      throw Exception('Failed to update permission: $e');
    }
  }

  @override
  Future<List<FamilyInvite>> getPendingInvites(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('outgoingInvites')
          .where('status', isEqualTo: 'pending')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return FamilyInvite(
          id: doc.id,
          inviterUserId: data['inviterUserId'] ?? '',
          inviterName: data['inviterName'] ?? '',
          email: data['email'],
          phone: data['phone'],
          inviteCode: data['inviteCode'] ?? '',
          permission: SharePermission.values.firstWhere(
            (e) => e.name == data['permission'],
            orElse: () => SharePermission.viewOnly,
          ),
          status: FamilyInviteStatus.pending,
          createdAt: data['createdAt'] != null
              ? DateTime.parse(data['createdAt'])
              : DateTime.now(),
          expiresAt: data['expiresAt'] != null
              ? DateTime.parse(data['expiresAt'])
              : DateTime.now().add(const Duration(days: 7)),
        );
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch pending invites: $e');
    }
  }

  @override
  Future<void> cancelInvite(String userId, String inviteId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('outgoingInvites')
          .doc(inviteId)
          .delete();
    } catch (e) {
      throw Exception('Failed to cancel invite: $e');
    }
  }

  @override
  Future<String> generateInviteCode() async {
    final bytes = utf8.encode('${DateTime.now().millisecondsSinceEpoch}');
    final hash = sha256.convert(bytes).toString().substring(0, 8).toUpperCase();
    return 'ART-$hash';
  }

  @override
  Future<FamilyInvite?> getInviteByCode(String inviteCode) async {
    try {
      final snapshot = await _firestore
          .collectionGroup('incomingInvites')
          .where('inviteCode', isEqualTo: inviteCode)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      final data = snapshot.docs.first.data();
      return FamilyInvite(
        id: snapshot.docs.first.id,
        inviterUserId: data['inviterUserId'] ?? '',
        inviterName: data['inviterName'] ?? '',
        email: data['email'],
        phone: data['phone'],
        inviteCode: inviteCode,
        permission: SharePermission.values.firstWhere(
          (e) => e.name == data['permission'],
          orElse: () => SharePermission.viewOnly,
        ),
        status: FamilyInviteStatus.values.firstWhere(
          (e) => e.name == data['status'],
          orElse: () => FamilyInviteStatus.pending,
        ),
        createdAt: data['createdAt'] != null
            ? DateTime.parse(data['createdAt'])
            : DateTime.now(),
        expiresAt: data['expiresAt'] != null
            ? DateTime.parse(data['expiresAt'])
            : DateTime.now().add(const Duration(days: 7)),
      );
    } catch (e) {
      throw Exception('Failed to get invite: $e');
    }
  }
}
