import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:arteria/l10n/app_localizations.dart';

class EmergencyAlertCard extends StatefulWidget {
  const EmergencyAlertCard({super.key});

  @override
  State<EmergencyAlertCard> createState() => _EmergencyAlertCardState();
}

class _EmergencyAlertCardState extends State<EmergencyAlertCard> {
  Map<String, dynamic>? _latestReading;
  Map<String, dynamic>? _primaryContact;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? 'default_user';

    final readingsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('readings')
        .orderBy('date', descending: true)
        .limit(1)
        .get();

    if (readingsSnapshot.docs.isNotEmpty && mounted) {
      setState(() {
        _latestReading = readingsSnapshot.docs.first.data();
      });
    }

    if (!mounted) return;

    final contactsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('emergencyContacts')
        .where('isPrimary', isEqualTo: true)
        .limit(1)
        .get();

    if (contactsSnapshot.docs.isNotEmpty && mounted) {
      setState(() {
        _primaryContact = contactsSnapshot.docs.first.data();
      });
    }
  }

  bool get _isCritical {
    if (_latestReading == null) return false;
    final systolic = _latestReading?['systolic'] as int? ?? 0;
    final diastolic = _latestReading?['diastolic'] as int? ?? 0;
    return systolic >= 180 || diastolic >= 120;
  }

  bool get _isHigh {
    if (_latestReading == null) return false;
    if (_isCritical) return false;
    final systolic = _latestReading?['systolic'] as int? ?? 0;
    final diastolic = _latestReading?['diastolic'] as int? ?? 0;
    return systolic >= 140 || diastolic >= 90;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (!_isCritical && !_isHigh) {
      return const SizedBox.shrink();
    }

    final isCritical = _isCritical;
    final borderColor = isCritical
        ? const Color(0xFFDC2626)
        : const Color(0xFFF97316);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          // Slightly more opaque than before (was 0.8/0.9) because the
          // BackdropFilter that used to soften the see-through area was
          // forcing a full gaussian re-blur every scroll frame and was
          // contributing to homepage scroll stutter.
          colors: isDark
              ? [
                  const Color(0xFF2D1111).withValues(alpha: 0.96),
                  const Color(0xFF1A0A0A).withValues(alpha: 0.98),
                ]
              : [const Color(0xFFFFEBEB), const Color(0xFFFFF5F5)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: borderColor.withValues(alpha: 0.5), width: 2),
        boxShadow: [
          BoxShadow(
            color: borderColor.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: borderColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: borderColor.withValues(alpha: 0.3),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      isCritical
                          ? Icons.warning_rounded
                          : Icons.warning_amber_rounded,
                      size: 28,
                      color: borderColor,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isCritical
                              ? AppLocalizations.of(
                                  context,
                                )!.emergencyHypertensiveCrisis
                              : AppLocalizations.of(
                                  context,
                                )!.emergencyHighBloodPressure,
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_latestReading?['systolic'] ?? '--'}/${_latestReading?['diastolic'] ?? '--'} mmHg',
                          style: GoogleFonts.inter(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: borderColor,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: borderColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isCritical
                      ? AppLocalizations.of(context)!.emergencySeekImmediate
                      : AppLocalizations.of(context)!.emergencyContactProvider,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: borderColor,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      context,
                      label: AppLocalizations.of(context)!.emergencyCall911,
                      icon: Icons.call_rounded,
                      isEmergency: true,
                      onTap: () => launchUrl(Uri.parse('tel:114')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionButton(
                      context,
                      label: AppLocalizations.of(context)!.emergencyCallContact,
                      icon: Icons.person_rounded,
                      isEmergency: false,
                      onTap: _primaryContact != null
                          ? () => launchUrl(
                              Uri.parse('tel:${_primaryContact!['phone']}'),
                            )
                          : null,
                    ),
                  ),
                ],
              ),
              if (_primaryContact == null) ...[
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => _showAddContactDialog(context),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_rounded,
                          size: 18,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.6)
                              : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          AppLocalizations.of(context)!.emergencyAddContact,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.6)
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required bool isEmergency,
    required VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isEmergency
        ? const Color(0xFFDC2626)
        : isDark
        ? const Color(0xFF2D2D3A)
        : const Color(0xFFF1F5F9);
    final iconColor = isEmergency
        ? Colors.white
        : (isDark ? Colors.white : const Color(0xFF1E293B));
    final textColor = isEmergency
        ? Colors.white
        : (isDark ? Colors.white : const Color(0xFF1E293B));

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          gradient: isEmergency
              ? LinearGradient(
                  colors: [const Color(0xFFDC2626), const Color(0xFFB91C1C)],
                )
              : null,
          color: isEmergency ? null : bgColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: isEmergency
              ? [
                  BoxShadow(
                    color: const Color(0xFFDC2626).withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddContactDialog(BuildContext context) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final relationshipController = TextEditingController();

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
                        color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.contact_emergency_rounded,
                        color: Color(0xFFDC2626),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)!.emergencyAddContactTitle,
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context)!.emergencyContactNotified,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 24),
                _buildTextField(
                  controller: nameController,
                  label: AppLocalizations.of(context)!.emergencyContactName,
                  icon: Icons.person_rounded,
                  hint: 'e.g., John Doe',
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: phoneController,
                  label: AppLocalizations.of(context)!.emergencyPhoneNumber,
                  icon: Icons.call_rounded,
                  hint: '+230 5789 1234',
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: relationshipController,
                  label: AppLocalizations.of(context)!.emergencyRelationship,
                  icon: Icons.family_restroom_rounded,
                  hint: 'e.g., Son, Daughter, Spouse',
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _saveContact(
                      context,
                      nameController.text,
                      phoneController.text,
                      relationshipController.text,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      AppLocalizations.of(context)!.emergencySaveContact,
                    ),
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
                        color: Colors.grey.shade600,
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
    TextInputType? keyboardType,
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
          keyboardType: keyboardType,
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

  void _saveContact(
    BuildContext context,
    String name,
    String phone,
    String relationship,
  ) {
    if (name.isEmpty || phone.isEmpty) return;

    final userId = FirebaseAuth.instance.currentUser?.uid ?? 'default_user';
    FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('emergencyContacts')
        .add({
          'name': name,
          'phone': phone,
          'relationship': relationship,
          'isPrimary': false,
          'createdAt': DateTime.now().toIso8601String(),
        });

    Navigator.pop(context);
    _loadData();
  }
}
