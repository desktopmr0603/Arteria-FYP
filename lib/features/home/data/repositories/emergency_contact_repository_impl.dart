import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:arteria/features/home/domain/entities/emergency_contact.dart';
import 'package:arteria/features/home/domain/repositories/emergency_contact_repository.dart';
import 'package:arteria/Core/Utils/firebase_helpers.dart';

class EmergencyContactRepositoryImpl implements EmergencyContactRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<List<EmergencyContact>> getContacts(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('emergencyContacts')
          .orderBy('createdAt', descending: false)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return EmergencyContact(
          id: doc.id,
          name: data['name'] ?? '',
          phone: data['phone'] ?? '',
          relationship: data['relationship'] ?? '',
          isPrimary: data['isPrimary'] ?? false,
          createdAt: FirebaseHelpers.parseDateTime(data['createdAt']) ?? DateTime.now(),
        );
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch contacts: $e');
    }
  }

  @override
  Stream<List<EmergencyContact>> watchContacts(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('emergencyContacts')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            return EmergencyContact(
              id: doc.id,
              name: data['name'] ?? '',
              phone: data['phone'] ?? '',
              relationship: data['relationship'] ?? '',
              isPrimary: data['isPrimary'] ?? false,
              createdAt: FirebaseHelpers.parseDateTime(data['createdAt']) ?? DateTime.now(),
            );
          }).toList(),
        );
  }

  @override
  Future<EmergencyContact?> getPrimaryContact(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('emergencyContacts')
          .where('isPrimary', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      final data = snapshot.docs.first.data();
      return EmergencyContact(
        id: snapshot.docs.first.id,
        name: data['name'] ?? '',
        phone: data['phone'] ?? '',
        relationship: data['relationship'] ?? '',
        isPrimary: true,
        createdAt: FirebaseHelpers.parseDateTime(data['createdAt']) ?? DateTime.now(),
      );
    } catch (e) {
      throw Exception('Failed to fetch primary contact: $e');
    }
  }

  @override
  Future<String> addContact(String userId, EmergencyContact contact) async {
    try {
      final contacts = await getContacts(userId);
      final isFirstContact = contacts.isEmpty;

      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('emergencyContacts')
          .doc();

      await docRef.set({
        'name': contact.name,
        'phone': contact.phone,
        'relationship': contact.relationship,
        'isPrimary': isFirstContact || contact.isPrimary,
        'createdAt': contact.createdAt.toIso8601String(),
      });

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to add contact: $e');
    }
  }

  @override
  Future<bool> updateContact(String userId, EmergencyContact contact) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('emergencyContacts')
          .doc(contact.id)
          .update({
            'name': contact.name,
            'phone': contact.phone,
            'relationship': contact.relationship,
            'isPrimary': contact.isPrimary,
          });

      return true;
    } catch (e) {
      throw Exception('Failed to update contact: $e');
    }
  }

  @override
  Future<bool> deleteContact(String userId, String contactId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('emergencyContacts')
          .doc(contactId)
          .delete();

      return true;
    } catch (e) {
      throw Exception('Failed to delete contact: $e');
    }
  }

  @override
  Future<bool> setPrimaryContact(String userId, String contactId) async {
    try {
      final batch = _firestore.batch();

      final contacts = await getContacts(userId);
      for (final contact in contacts) {
        batch.update(
          _firestore
              .collection('users')
              .doc(userId)
              .collection('emergencyContacts')
              .doc(contact.id),
          {'isPrimary': contact.id == contactId},
        );
      }

      await batch.commit();
      return true;
    } catch (e) {
      throw Exception('Failed to set primary contact: $e');
    }
  }
}
