import 'package:arteria/features/home/domain/entities/family_member.dart';

abstract class FamilyRepository {
  Future<List<FamilyMember>> getFamilyMembers(String userId);
  Stream<List<FamilyMember>> watchFamilyMembers(String userId);
  Future<FamilyMember?> getFamilyMember(String userId, String memberId);
  Future<String> sendInvite(
    String userId,
    String inviterName,
    String? email,
    String? phone,
    SharePermission permission,
  );
  Future<bool> acceptInvite(String userId, String inviteCode);
  Future<bool> declineInvite(String userId, String inviteCode);
  Future<bool> removeFamilyMember(String userId, String memberId);
  Future<bool> updateMemberPermission(
    String userId,
    String memberId,
    SharePermission permission,
  );
  Future<List<FamilyInvite>> getPendingInvites(String userId);
  Future<void> cancelInvite(String userId, String inviteId);
  Future<String> generateInviteCode();
  Future<FamilyInvite?> getInviteByCode(String inviteCode);
}
