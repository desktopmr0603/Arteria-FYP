import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:arteria/features/home/domain/entities/family_member.dart';
import 'package:arteria/features/home/domain/repositories/family_member_repository.dart';
import 'package:arteria/Core/Utils/firebase_helpers.dart';

/// Production family-sharing repository.
///
/// Invite codes live in a single top-level `familyInvites` collection keyed
/// by the code itself, so any signed-in user can redeem a code with an O(1)
/// document lookup — no composite index and no collection-group query. When
/// an invite is accepted, a `familyMembers` document is written under BOTH
/// users (doc id = the other user's uid) so the connection is visible to
/// each side and can be cleanly removed later.
///
/// The previous design wrote invites to the inviter's `outgoingInvites` but
/// read them from the invitee's `incomingInvites` — a collection nothing
/// ever populated — so a generated code could never be redeemed.
class FamilyMemberRepositoryImpl implements FamilyRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const Duration _inviteValidity = Duration(days: 7);

  CollectionReference<Map<String, dynamic>> get _invites =>
      _firestore.collection('familyInvites');

  CollectionReference<Map<String, dynamic>> _familyMembersOf(String uid) =>
      _firestore.collection('users').doc(uid).collection('familyMembers');

  FamilyMember _memberFromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
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
      status: FamilyInviteStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => FamilyInviteStatus.accepted,
      ),
      lastReadingAt: FirebaseHelpers.parseDateTime(data['lastReadingAt']),
      lastReading: data['lastReading'],
      addedAt: FirebaseHelpers.parseDateTime(data['addedAt']) ?? DateTime.now(),
    );
  }

  @override
  Future<List<FamilyMember>> getFamilyMembers(String userId) async {
    try {
      final snapshot = await _familyMembersOf(userId)
          .where('status', isEqualTo: 'accepted')
          .get();
      return snapshot.docs.map(_memberFromDoc).toList();
    } catch (e) {
      throw Exception('Failed to fetch family members: $e');
    }
  }

  @override
  Stream<List<FamilyMember>> watchFamilyMembers(String userId) {
    return _familyMembersOf(userId)
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(_memberFromDoc).toList());
  }

  @override
  Future<FamilyMember?> getFamilyMember(String userId, String memberId) async {
    try {
      final doc = await _familyMembersOf(userId).doc(memberId).get();
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
        lastReadingAt: FirebaseHelpers.parseDateTime(data['lastReadingAt']),
        lastReading: data['lastReading'],
        addedAt:
            FirebaseHelpers.parseDateTime(data['addedAt']) ?? DateTime.now(),
      );
    } catch (e) {
      throw Exception('Failed to fetch family member: $e');
    }
  }

  @override
  Future<String> generateInviteCode() async {
    // Unambiguous alphabet — no 0/O/1/I/L — so a spoken or typed code is
    // hard to get wrong. Doc id = code, so retry on the (vanishingly rare)
    // collision rather than risk overwriting a live invite.
    const alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    for (var attempt = 0; attempt < 5; attempt++) {
      final body =
          List.generate(8, (_) => alphabet[rng.nextInt(alphabet.length)])
              .join();
      final code = 'ART-$body';
      final existing = await _invites.doc(code).get();
      if (!existing.exists) return code;
    }
    // Fallback — astronomically unlikely to be reached.
    return 'ART-${DateTime.now().microsecondsSinceEpoch.toRadixString(36).toUpperCase()}';
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
      final code = await generateInviteCode();
      final now = DateTime.now();

      await _invites.doc(code).set({
        'inviteCode': code,
        'inviterUserId': userId,
        'inviterName': inviterName,
        'email': (email != null && email.isNotEmpty) ? email : null,
        'phone': (phone != null && phone.isNotEmpty) ? phone : null,
        'permission': permission.name,
        'status': 'pending',
        'createdAt': now.toIso8601String(),
        'expiresAt': now.add(_inviteValidity).toIso8601String(),
      });

      // The repository contract returns the redeemable code.
      return code;
    } catch (e) {
      throw Exception('Failed to create invite: $e');
    }
  }

  @override
  Future<FamilyInvite?> getInviteByCode(String inviteCode) async {
    try {
      final code = inviteCode.trim().toUpperCase();
      if (code.isEmpty) return null;
      final doc = await _invites.doc(code).get();
      if (!doc.exists) return null;
      return FamilyInvite.fromMap({
        ...doc.data()!,
        'id': doc.id,
        'inviteCode': code,
      });
    } catch (e) {
      throw Exception('Failed to look up invite: $e');
    }
  }

  @override
  Future<bool> acceptInvite(String userId, String inviteCode) async {
    final code = inviteCode.trim().toUpperCase();
    final inviteRef = _invites.doc(code);

    try {
      await _firestore.runTransaction((tx) async {
        // ---- all reads first (Firestore transaction requirement) ----
        final inviteSnap = await tx.get(inviteRef);
        if (!inviteSnap.exists) {
          throw Exception('Invite code not found.');
        }
        final data = inviteSnap.data()!;

        final status = data['status'];
        if (status == 'accepted') {
          throw Exception('This invite has already been used.');
        }
        if (status != 'pending') {
          throw Exception('This invite is no longer available.');
        }

        final expiresAt = FirebaseHelpers.parseDateTime(data['expiresAt']);
        if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
          throw Exception('This invite has expired.');
        }

        final inviterUserId = (data['inviterUserId'] as String?) ?? '';
        if (inviterUserId.isEmpty) {
          throw Exception('This invite is invalid.');
        }
        if (inviterUserId == userId) {
          throw Exception("You can't accept your own invite.");
        }

        final inviterMemberRef = _familyMembersOf(inviterUserId).doc(userId);
        final myMemberRef = _familyMembersOf(userId).doc(inviterUserId);
        final meRef = _firestore.collection('users').doc(userId);

        final existing = await tx.get(inviterMemberRef);
        final meSnap = await tx.get(meRef);

        if (existing.exists) {
          throw Exception("You're already connected with this family.");
        }

        // ---- writes ----
        final inviterName =
            (data['inviterName'] as String?) ?? 'Family member';
        final permission = (data['permission'] as String?) ?? 'viewOnly';
        final myName =
            ((meSnap.data()?['firstName'] as String?) ?? '').trim();
        final accepterName = myName.isEmpty ? 'Family member' : myName;
        final nowIso = DateTime.now().toIso8601String();

        // Inviter sees the new member.
        tx.set(inviterMemberRef, {
          'userId': userId,
          'name': accepterName,
          'permission': permission,
          'status': 'accepted',
          'addedAt': nowIso,
        });
        // Member sees the inviter — the connection is bidirectional.
        tx.set(myMemberRef, {
          'userId': inviterUserId,
          'name': inviterName,
          'permission': permission,
          'status': 'accepted',
          'addedAt': nowIso,
        });
        // Retire the invite so the code cannot be reused.
        tx.update(inviteRef, {
          'status': 'accepted',
          'accepterUserId': userId,
          'accepterName': accepterName,
          'acceptedAt': nowIso,
        });
      });

      return true;
    } catch (e) {
      // Surface the human-readable validation message unchanged.
      final msg = e.toString();
      throw Exception(
        msg.startsWith('Exception: ') ? msg.substring(11) : msg,
      );
    }
  }

  @override
  Future<bool> declineInvite(String userId, String inviteCode) async {
    try {
      final code = inviteCode.trim().toUpperCase();
      final ref = _invites.doc(code);
      final snap = await ref.get();
      if (!snap.exists) return false;
      await ref.update({'status': 'declined'});
      return true;
    } catch (e) {
      throw Exception('Failed to decline invite: $e');
    }
  }

  @override
  Future<bool> removeFamilyMember(String userId, String memberId) async {
    try {
      // doc id is the other user's uid, so both directions delete directly.
      final batch = _firestore.batch();
      batch.delete(_familyMembersOf(userId).doc(memberId));
      batch.delete(_familyMembersOf(memberId).doc(userId));
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
      await _familyMembersOf(userId)
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
      // Single equality filter → Firestore auto-indexes it; no setup needed.
      final snapshot =
          await _invites.where('inviterUserId', isEqualTo: userId).get();

      final invites = <FamilyInvite>[];
      for (final doc in snapshot.docs) {
        final invite = FamilyInvite.fromMap({...doc.data(), 'id': doc.id});
        if (invite.status == FamilyInviteStatus.pending &&
            !invite.isExpired) {
          invites.add(invite);
        }
      }
      // Newest first.
      invites.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return invites;
    } catch (e) {
      throw Exception('Failed to fetch pending invites: $e');
    }
  }

  @override
  Future<void> cancelInvite(String userId, String inviteId) async {
    try {
      // inviteId is the code (doc id). Only the inviter may revoke it.
      final code = inviteId.trim().toUpperCase();
      final ref = _invites.doc(code);
      final snap = await ref.get();
      if (snap.exists && snap.data()?['inviterUserId'] == userId) {
        await ref.update({'status': 'revoked'});
      }
    } catch (e) {
      throw Exception('Failed to cancel invite: $e');
    }
  }
}
