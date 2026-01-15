import 'package:arteria/features/home/domain/entities/medication.dart';

abstract class MedicationRepository {
  Future<List<Medication>> getMedications(String userId);
  Stream<List<Medication>> watchMedications(String userId);
  Future<Medication?> getMedication(String userId, String medicationId);
  Future<String> addMedication(String userId, Medication medication);
  Future<bool> updateMedication(String userId, Medication medication);
  Future<bool> deleteMedication(String userId, String medicationId);
  Future<bool> markMedicationTaken(String userId, String medicationId);
  Future<bool> markMedicationSkipped(String userId, String medicationId);
  Future<List<MedicationLog>> getMedicationLogs(
    String userId,
    String medicationId,
  );
  Future<void> resetDailyMedications(String userId);
  Future<List<Medication>> getTodayMedications(String userId);
}
