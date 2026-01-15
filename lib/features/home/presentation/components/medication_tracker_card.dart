import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:arteria/features/home/domain/entities/medication.dart';
import 'package:arteria/features/home/domain/repositories/medication_repository.dart';
import 'package:arteria/features/home/data/repositories/medication_repository_impl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'package:arteria/l10n/app_localizations.dart';

class MedicationTrackerCard extends StatefulWidget {
  const MedicationTrackerCard({super.key});

  @override
  State<MedicationTrackerCard> createState() => _MedicationTrackerCardState();
}

class _MedicationTrackerCardState extends State<MedicationTrackerCard> {
  final MedicationRepository _repository = MedicationRepositoryImpl();
  late Stream<List<Medication>> _medicationsStream;

  @override
  void initState() {
    super.initState();
    final userId = FirebaseAuth.instance.currentUser?.uid ?? 'default_user';
    _medicationsStream = _repository.watchMedications(userId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return StreamBuilder<List<Medication>>(
      stream: _medicationsStream,
      builder: (context, snapshot) {
        final medications = snapshot.data ?? [];
        final activeMedications = medications.where((m) => m.isActive).toList();

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [const Color(0xFF1A1A24), const Color(0xFF12121A)]
                  : [Colors.white, const Color(0xFFF8FAFB)],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.3)
                    : Colors.black.withValues(alpha: 0.06),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF10B981,
                                ).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.medication_rounded,
                                size: 22,
                                color: Color(0xFF10B981),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              AppLocalizations.of(context)!.medicationTodaysMedications,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                        _buildAddButton(isDark),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (activeMedications.isEmpty) ...[
                      _buildEmptyState(isDark),
                    ] else ...[
                      ...activeMedications
                          .take(3)
                          .map((med) => _buildMedicationItem(med, isDark)),
                      if (activeMedications.length > 3) ...[
                        const SizedBox(height: 8),
                        Text(
                          AppLocalizations.of(context)!.medicationMoreMedications(activeMedications.length - 3),
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.5)
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAddButton(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF6366F1).withValues(alpha: 0.1),
            const Color(0xFF8B5CF6).withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showAddMedicationDialog(context),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.all(8),
            child: const Icon(
              Icons.add_rounded,
              size: 20,
              color: Color(0xFF6366F1),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.medication_outlined,
                size: 32,
                color: Color(0xFF10B981),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context)!.medicationNoMedicationsAdded,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.6)
                    : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              AppLocalizations.of(context)!.medicationTapToAdd,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.4)
                    : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicationItem(Medication med, bool isDark) {
    final now = DateTime.now();
    final currentHour = now.hour;

    bool isPending = false;
    String? nextTime;
    for (final time in med.times) {
      final timeParts = time.split(':');
      final medHour = int.parse(timeParts[0]);
      if (medHour <= currentHour && !med.takenToday) {
        isPending = true;
        nextTime = time;
        break;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : const Color(0xFFF8FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: med.takenToday
                    ? [
                        const Color(0xFF10B981).withValues(alpha: 0.2),
                        const Color(0xFF10B981).withValues(alpha: 0.1),
                      ]
                    : isPending
                    ? [
                        const Color(0xFFF59E0B).withValues(alpha: 0.2),
                        const Color(0xFFF59E0B).withValues(alpha: 0.1),
                      ]
                    : [
                        const Color(0xFF6366F1).withValues(alpha: 0.2),
                        const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                      ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              med.takenToday
                  ? Icons.check_circle_rounded
                  : isPending
                  ? Icons.schedule_rounded
                  : Icons.alarm_rounded,
              size: 24,
              color: med.takenToday
                  ? const Color(0xFF10B981)
                  : isPending
                  ? const Color(0xFFF59E0B)
                  : const Color(0xFF6366F1),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      med.name,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                        decoration: med.takenToday
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color:
                            med.color?.withValues(alpha: 0.1) ??
                            const Color(0xFF6366F1).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        med.dosage,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: med.color ?? const Color(0xFF6366F1),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  med.takenToday
                      ? AppLocalizations.of(context)!.medicationTaken
                      : nextTime != null
                      ? AppLocalizations.of(context)!.medicationDueAt(nextTime)
                      : _getNextDueTime(context, med.times),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: med.takenToday
                        ? const Color(0xFF10B981)
                        : isPending
                        ? const Color(0xFFF59E0B)
                        : isDark
                        ? Colors.white.withValues(alpha: 0.5)
                        : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          _buildActionButton(med, isDark),
        ],
      ),
    );
  }

  String _getNextDueTime(BuildContext context, List<String> times) {
    final l10n = AppLocalizations.of(context)!;
    if (times.isEmpty) return l10n.medicationAsNeeded;
    final now = DateTime.now();
    final currentHour = now.hour;

    for (final time in times) {
      final timeParts = time.split(':');
      final medHour = int.parse(timeParts[0]);
      if (medHour > currentHour) {
        return l10n.medicationNext(time);
      }
    }
    return l10n.medicationCompletedForToday;
  }

  Widget _buildActionButton(Medication med, bool isDark) {
    return GestureDetector(
      onTap: () => _toggleMedication(med),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          gradient: med.takenToday
              ? null
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [const Color(0xFF10B981), const Color(0xFF059669)],
                ),
          color: med.takenToday ? Colors.transparent : null,
          borderRadius: BorderRadius.circular(10),
          border: med.takenToday
              ? Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : const Color(0xFFE2E8F0),
                )
              : null,
          boxShadow: med.takenToday
              ? null
              : [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Icon(
          med.takenToday ? Icons.check_rounded : Icons.add_rounded,
          size: 20,
          color: med.takenToday
              ? isDark
                    ? Colors.white.withValues(alpha: 0.4)
                    : const Color(0xFF94A3B8)
              : Colors.white,
        ),
      ),
    );
  }

  void _toggleMedication(Medication med) {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? 'default_user';

    if (med.takenToday) {
      _repository.updateMedication(userId, med.copyWith(takenToday: false));
    } else {
      _repository.markMedicationTaken(userId, med.id);
    }
  }

  void _showAddMedicationDialog(BuildContext context) {
    final nameController = TextEditingController();
    final dosageController = TextEditingController();
    String selectedFrequency = 'onceDaily';
    final timesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        child: Container(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.medication_rounded,
                        color: Color(0xFF6366F1),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      AppLocalizations.of(context)!.medicationAddMedication,
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildTextField(
                  controller: nameController,
                  label: AppLocalizations.of(context)!.medicationName,
                  icon: Icons.medication_rounded,
                  hint: 'e.g., Amlodipine',
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: dosageController,
                  label: AppLocalizations.of(context)!.medicationDosage,
                  icon: Icons.scale_rounded,
                  hint: 'e.g., 5mg',
                ),
                const SizedBox(height: 16),
                _buildFrequencyDropdown(context, selectedFrequency, (value) {
                  setState(() => selectedFrequency = value!);
                }),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: timesController,
                  label: AppLocalizations.of(context)!.medicationTimes,
                  icon: Icons.access_time_rounded,
                  hint: 'e.g., 08:00, 20:00',
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _saveMedication(
                      context,
                      nameController.text,
                      dosageController.text,
                      selectedFrequency,
                      timesController.text,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Save Medication'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      AppLocalizations.of(context)!.cancel,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white.withValues(alpha: 0.6)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 20, color: Colors.grey.shade400),
            hintText: hint,
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFrequencyDropdown(
    BuildContext context,
    String selectedValue,
    void Function(String?) onChanged,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final frequencies = [
      ('onceDaily', l10n.frequencyOnceDaily),
      ('twiceDaily', l10n.frequencyTwiceDaily),
      ('threeTimesDaily', l10n.frequencyThreeTimesDaily),
      ('weekly', l10n.frequencyWeekly),
      ('asNeeded', l10n.frequencyAsNeeded),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.medicationFrequency,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: selectedValue,
          onChanged: onChanged,
          items: frequencies
              .map((e) => DropdownMenuItem(value: e.$1, child: Text(e.$2)))
              .toList(),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
          ),
        ),
      ],
    );
  }

  void _saveMedication(
    BuildContext context,
    String name,
    String dosage,
    String frequency,
    String times,
  ) {
    if (name.isEmpty || dosage.isEmpty) return;

    final userId = FirebaseAuth.instance.currentUser?.uid ?? 'default_user';
    final timeList = times.isEmpty
        ? <String>[]
        : times.split(',').map((e) => e.trim()).toList();

    final medication = Medication(
      id: const Uuid().v4(),
      name: name,
      dosage: dosage,
      frequency: MedicationFrequency.values.firstWhere(
        (e) => e.name == frequency,
        orElse: () => MedicationFrequency.onceDaily,
      ),
      times: timeList,
      isActive: true,
      takenToday: false,
      createdAt: DateTime.now(),
      color: const Color(0xFF6366F1),
    );

    _repository.addMedication(userId, medication);
    Navigator.pop(context);
  }
}
