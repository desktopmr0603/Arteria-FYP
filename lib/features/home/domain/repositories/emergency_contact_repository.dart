import 'package:arteria/features/home/domain/entities/emergency_contact.dart';

abstract class EmergencyContactRepository {
  Future<List<EmergencyContact>> getContacts(String userId);
  Stream<List<EmergencyContact>> watchContacts(String userId);
  Future<EmergencyContact?> getPrimaryContact(String userId);
  Future<String> addContact(String userId, EmergencyContact contact);
  Future<bool> updateContact(String userId, EmergencyContact contact);
  Future<bool> deleteContact(String userId, String contactId);
  Future<bool> setPrimaryContact(String userId, String contactId);
}
