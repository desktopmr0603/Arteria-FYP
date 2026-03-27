import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:arteria/features/home/data/models/medication_model.dart';
import 'package:arteria/features/home/domain/entities/medication.dart';
import 'package:arteria/features/home/domain/repositories/medication_repository.dart';
import 'package:arteria/Core/Utils/firebase_helpers.dart';

class MedicationRepositoryImpl implements MedicationRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<List<Medication>> getMedications(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('medications')
          .where('isActive', isEqualTo: true)
          .get();

      return snapshot.docs
          .map((doc) => MedicationModel.fromDocument(doc.data(), documentId: doc.id).toEntity())
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch medications: $e');
    }
  }

  @override
  Stream<List<Medication>> watchMedications(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('medications')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MedicationModel.fromDocument(doc.data(), documentId: doc.id).toEntity())
              .toList(),
        );
  }

  @override
  Future<Medication?> getMedication(String userId, String medicationId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('medications')
          .doc(medicationId)
          .get();

      if (!doc.exists) return null;
      return MedicationModel.fromDocument(doc.data()!, documentId: doc.id).toEntity();
    } catch (e) {
      throw Exception('Failed to fetch medication: $e');
    }
  }

  @override
  Future<String> addMedication(String userId, Medication medication) async {
    try {
      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('medications')
          .doc(medication.id);

      await docRef.set(
        MedicationModel(
          id: medication.id,
          userId: userId,
          name: medication.name,
          dosage: medication.dosage,
          frequency: medication.frequency.name,
          times: medication.times,
          isActive: medication.isActive,
          takenToday: medication.takenToday,
          createdAt: medication.createdAt.toIso8601String(),
          instructions: medication.instructions,
          color: medication.color?.toARGB32() ?? 0xFF6366F1,
        ).toDocument(),
      );

      return medication.id;
    } catch (e) {
      throw Exception('Failed to add medication: $e');
    }
  }

  @override
  Future<bool> updateMedication(String userId, Medication medication) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('medications')
          .doc(medication.id)
          .update(
            MedicationModel(
              id: medication.id,
              userId: userId,
              name: medication.name,
              dosage: medication.dosage,
              frequency: medication.frequency.name,
              times: medication.times,
              isActive: medication.isActive,
              lastTakenAt: medication.lastTakenAt?.toIso8601String(),
              takenToday: medication.takenToday,
              createdAt: medication.createdAt.toIso8601String(),
              instructions: medication.instructions,
              color: medication.color?.toARGB32() ?? 0xFF6366F1,
            ).toDocument(),
          );

      return true;
    } catch (e) {
      throw Exception('Failed to update medication: $e');
    }
  }

  @override
  Future<bool> deleteMedication(String userId, String medicationId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('medications')
          .doc(medicationId)
          .update({'isActive': false});

      return true;
    } catch (e) {
      throw Exception('Failed to delete medication: $e');
    }
  }

  @override
  Future<bool> markMedicationTaken(String userId, String medicationId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('medications')
          .doc(medicationId)
          .update({
            'takenToday': true,
            'lastTakenAt': DateTime.now().toIso8601String(),
          });

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('medicationLogs')
          .add({
            'medicationId': medicationId,
            'takenAt': DateTime.now().toIso8601String(),
            'skipped': false,
          });

      return true;
    } catch (e) {
      throw Exception('Failed to mark medication as taken: $e');
    }
  }

  @override
  Future<bool> markMedicationSkipped(String userId, String medicationId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('medications')
          .doc(medicationId)
          .update({'takenToday': false});

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('medicationLogs')
          .add({
            'medicationId': medicationId,
            'takenAt': DateTime.now().toIso8601String(),
            'skipped': true,
          });

      return true;
    } catch (e) {
      throw Exception('Failed to mark medication as skipped: $e');
    }
  }

  @override
  Future<List<MedicationLog>> getMedicationLogs(
    String userId,
    String medicationId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('medicationLogs')
          .where('medicationId', isEqualTo: medicationId)
          .orderBy('takenAt', descending: true)
          .limit(30)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return MedicationLog(
          id: doc.id,
          medicationId: data['medicationId'] ?? '',
          takenAt: FirebaseHelpers.parseDateTime(data['takenAt']) ?? DateTime.now(),
          skipped: data['skipped'] ?? false,
          notes: data['notes'],
        );
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch medication logs: $e');
    }
  }

  @override
  Future<void> resetDailyMedications(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('medications')
          .where('isActive', isEqualTo: true)
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'takenToday': false});
      }
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to reset daily medications: $e');
    }
  }

  @override
  Future<List<Medication>> getTodayMedications(String userId) async {
    try {
      final now = DateTime.now();
      final currentHour = now.hour;

      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('medications')
          .where('isActive', isEqualTo: true)
          .get();

      final medications = snapshot.docs
          .map((doc) => MedicationModel.fromDocument(doc.data(), documentId: doc.id).toEntity())
          .where((med) {
            if (med.takenToday) return false;

            for (final time in med.times) {
              final timeParts = time.split(':');
              final medHour = int.parse(timeParts[0]);
              if (medHour <= currentHour) return true;
            }
            return false;
          })
          .toList();

      return medications;
    } catch (e) {
      throw Exception('Failed to fetch today medications: $e');
    }
  }
}
