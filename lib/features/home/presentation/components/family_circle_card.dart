import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:arteria/l10n/app_localizations.dart';
import 'package:arteria/features/home/presentation/components/premium_dashboard_card.dart';
import 'package:arteria/features/home/domain/entities/family_member.dart';
import 'package:arteria/features/home/domain/repositories/family_member_repository.dart';
import 'package:arteria/features/home/data/repositories/family_member_repository_impl.dart';

class FamilyCircleCard extends StatefulWidget {
  const FamilyCircleCard({super.key});

  @override
  State<FamilyCircleCard> createState() => _FamilyCircleCardState();
}

class _FamilyCircleCardState extends State<FamilyCircleCard> {
  final FamilyRepository _repo = FamilyMemberRepositoryImpl();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _redeemController = TextEditingController();
  String _selectedPermission = 'viewOnly';
  String? _generatedInviteCode;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _redeemController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final userId = FirebaseAuth.instance.currentUser?.uid ?? 'default_user';

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('familyMembers')
          .snapshots(),
      builder: (context, snapshot) {
        final members = snapshot.data?.docs ?? [];
        final familyMembers = members.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            'name': data['name'] ?? '',
            'permission': data['permission'] ?? 'viewOnly',
            'status': data['status'] ?? 'accepted',
          };
        }).toList();

        return PremiumDashboardCard(
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
                          color: const Color(0xFFF76C5E).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.family_restroom_rounded,
                          size: 22,
                          color: Color(0xFFF76C5E),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.familyCircle,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1E293B),
                            ),
                          ),
                          Text(
                            AppLocalizations.of(
                              context,
                            )!.familyConnected(familyMembers.length),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.5)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  _buildAddButton(isDark),
                ],
              ),
              const SizedBox(height: 16),
              if (familyMembers.isEmpty) ...[
                _buildEmptyState(isDark),
              ] else ...[
                ...familyMembers.map(
                  (member) => _buildMemberItem(member, isDark),
                ),
              ],
              const SizedBox(height: 12),
              _buildInviteSection(isDark),
              _buildJoinAction(isDark),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAddButton(bool isDark) {
    return GestureDetector(
      onTap: () => _showInviteDialog(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFF76C5E).withValues(alpha: 0.1),
              const Color(0xFFF76C5E).withValues(alpha: 0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_rounded, size: 18, color: Color(0xFFF76C5E)),
            const SizedBox(width: 4),
            Text(
              AppLocalizations.of(context)!.familyInvite,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFF76C5E),
              ),
            ),
          ],
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
                color: const Color(0xFFF76C5E).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.family_restroom_rounded,
                size: 32,
                color: Color(0xFFF76C5E),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context)!.familyNoMembers,
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
              AppLocalizations.of(context)!.familyInviteDescription,
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

  Widget _buildMemberItem(Map<String, dynamic> member, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : const Color(0xFFF8FAFB),
        borderRadius: BorderRadius.circular(14),
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
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF76C5E), Color(0xFFF76C5E)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                _getInitials(member['name'] as String),
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member['name'] as String,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF76C5E).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _getPermissionLabel(member['permission'] as String),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFF76C5E),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.check_circle_rounded,
            size: 20,
            color: const Color(0xFF10B981),
          ),
        ],
      ),
    );
  }

  Widget _buildInviteSection(bool isDark) {
    if (_generatedInviteCode == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFF76C5E).withValues(alpha: 0.1),
            const Color(0xFFF76C5E).withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFF76C5E).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Invite Code',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: _generatedInviteCode!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Code copied to clipboard')),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF76C5E).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.content_copy_rounded,
                        size: 14,
                        color: const Color(0xFFF76C5E),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Copy',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFF76C5E),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2D2D3A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFF76C5E).withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.qr_code_2_rounded,
                      size: 24,
                      color: const Color(0xFFF76C5E),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Invite Code',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1A1A24) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _generatedInviteCode!,
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFF76C5E),
                      letterSpacing: 2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Share this code with family members',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.5)
                        : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    final first = parts[0];
    return (first.length >= 2 ? first.substring(0, 2) : first).toUpperCase();
  }

  String _getPermissionLabel(String permission) {
    switch (permission) {
      case 'viewOnly':
        return 'View Only';
      case 'viewAndExport':
        return 'View & Export';
      case 'fullAccess':
        return 'Full Access';
      default:
        return 'View Only';
    }
  }

  // ── Dialog theme palette ───────────────────────────────────────────
  // Hardcoded light-theme colours previously made this dialog unreadable
  // in dark mode (near-white field fills on a dark surface, low-contrast
  // text). These resolve per-theme so every surface reads correctly.
  static const _accent = Color(0xFFF76C5E);

  Color _dialogSurface(bool isDark) =>
      isDark ? const Color(0xFF1E1E24) : Colors.white;
  Color _dialogFieldFill(bool isDark) =>
      isDark ? const Color(0xFF2A2A33) : const Color(0xFFF1F5F9);
  Color _dialogTextPrimary(bool isDark) =>
      isDark ? Colors.white : const Color(0xFF1E293B);
  Color _dialogTextMuted(bool isDark) =>
      isDark ? Colors.white.withValues(alpha: 0.55) : const Color(0xFF64748B);
  Color _dialogTextFaint(bool isDark) =>
      isDark ? Colors.white.withValues(alpha: 0.38) : const Color(0xFF94A3B8);
  Color _dialogBorder(bool isDark) =>
      isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0);

  void _showInviteDialog(BuildContext context) {
    // Reset in case a previous attempt was dismissed mid-request — keeps
    // the Send button enabled on re-open.
    _isLoading = false;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = _dialogSurface(isDark);
    final textPrimary = _dialogTextPrimary(isDark);
    final textMuted = _dialogTextMuted(isDark);
    final border = _dialogBorder(isDark);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: StatefulBuilder(
          builder: (context, dialogSetState) => Container(
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
                          color: _accent.withValues(
                            alpha: isDark ? 0.18 : 0.10,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.share_rounded,
                          color: _accent,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Invite Family Member',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Share your health data with family members',
                    style: GoogleFonts.inter(fontSize: 14, color: textMuted),
                  ),
                  const SizedBox(height: 24),
                  _buildTextField(
                    isDark: isDark,
                    controller: _emailController,
                    label: 'Email (optional)',
                    icon: Icons.email_rounded,
                    hint: 'family@email.com',
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    isDark: isDark,
                    controller: _phoneController,
                    label: 'Phone (optional)',
                    icon: Icons.phone_rounded,
                    hint: '59123456',
                  ),
                  const SizedBox(height: 16),
                  _buildPermissionDropdown(isDark, dialogSetState),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : () => _sendInvite(context, dialogSetState),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: _accent.withValues(alpha: 0.5),
                        disabledForegroundColor: Colors.white.withValues(
                          alpha: 0.8,
                        ),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Send Invite',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: Divider(color: border, height: 1)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'or',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: _dialogTextFaint(isDark),
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: border, height: 1)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading
                          ? null
                          : () => _generateQRCode(context, dialogSetState),
                      icon: const Icon(Icons.qr_code_2_rounded, size: 20),
                      label: Text(
                        'Generate Invite Code',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _accent,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        side: BorderSide(
                          color: _accent.withValues(alpha: 0.55),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: textMuted,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required bool isDark,
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
  }) {
    final fieldFill = _dialogFieldFill(isDark);
    final textPrimary = _dialogTextPrimary(isDark);
    final textMuted = _dialogTextMuted(isDark);
    final textFaint = _dialogTextFaint(isDark);
    final border = _dialogBorder(isDark);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: textMuted,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          cursorColor: _accent,
          style: GoogleFonts.inter(fontSize: 14, color: textPrimary),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 20, color: textFaint),
            hintText: hint,
            hintStyle: GoogleFonts.inter(fontSize: 14, color: textFaint),
            filled: true,
            fillColor: fieldFill,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _accent, width: 1.5),
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

  Widget _buildPermissionDropdown(
    bool isDark,
    void Function(void Function()) dialogSetState,
  ) {
    final permissions = [
      ('viewOnly', 'View Only', 'Can view your readings'),
      ('viewAndExport', 'View & Export', 'Can view and share reports'),
      ('fullAccess', 'Full Access', 'Full access to your data'),
    ];

    final fieldFill = _dialogFieldFill(isDark);
    final textPrimary = _dialogTextPrimary(isDark);
    final textMuted = _dialogTextMuted(isDark);
    final border = _dialogBorder(isDark);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Permission Level',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: textMuted,
          ),
        ),
        const SizedBox(height: 8),
        ...permissions.map((p) {
          final selected = _selectedPermission == p.$1;
          return GestureDetector(
            onTap: () => dialogSetState(() => _selectedPermission = p.$1),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: selected
                    ? _accent.withValues(alpha: isDark ? 0.16 : 0.09)
                    : fieldFill,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? _accent : border,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  // Custom selection indicator — replaces the Radio so it
                  // is fully theme-controlled and never low-contrast.
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? _accent : Colors.transparent,
                      border: Border.all(
                        color: selected
                            ? _accent
                            : (isDark
                                  ? Colors.white.withValues(alpha: 0.3)
                                  : const Color(0xFFCBD5E1)),
                        width: 2,
                      ),
                    ),
                    child: selected
                        ? const Icon(
                            Icons.check_rounded,
                            size: 14,
                            color: Colors.white,
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.$2,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: selected ? _accent : textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          p.$3,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  // ── Sending invites ─────────────────────────────────────────────────

  bool _isValidEmail(String email) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);

  SharePermission _permissionFromString(String name) =>
      SharePermission.values.firstWhere(
        (e) => e.name == name,
        orElse: () => SharePermission.viewOnly,
      );

  /// Resolves the signed-in user's display name for the invite payload so
  /// the recipient sees who invited them.
  Future<String> _currentUserName(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      final data = doc.data() ?? {};
      final first = ((data['firstName'] as String?) ?? '').trim();
      final last = ((data['lastName'] as String?) ?? '').trim();
      final full = [first, last].where((s) => s.isNotEmpty).join(' ');
      return full.isEmpty ? 'A family member' : full;
    } catch (_) {
      return 'A family member';
    }
  }

  /// Strips the `Exception: ` prefix so repository validation messages read
  /// as plain sentences in the UI.
  String _friendlyError(Object e) {
    var msg = e.toString();
    if (msg.startsWith('Exception: ')) msg = msg.substring(11);
    return msg.trim().isEmpty
        ? 'Something went wrong. Please try again.'
        : msg.trim();
  }

  void _showSnack(
    BuildContext context,
    String message, {
    bool success = false,
  }) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        backgroundColor: success
            ? const Color(0xFF10B981)
            : const Color(0xFF334155),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  String _composeInviteMessage(String inviterName, String code) {
    return '$inviterName invited you to their Arteria family circle, so you '
        'can follow blood-pressure readings together.\n\n'
        'Invite code: $code\n\n'
        'How to join:\n'
        '1. Install or open the Arteria app.\n'
        '2. On the Home screen, find the Family Circle card.\n'
        '3. Tap "Have an invite code?" and enter the code above.\n\n'
        'This invite expires in 7 days.';
  }

  String _encodeQueryParameters(Map<String, String> params) => params.entries
      .map(
        (e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
      )
      .join('&');

  /// Hands the invite to the device mail / SMS app so it is genuinely
  /// delivered — there is no server-side mailer. Returns true when a
  /// compose window opens; the code is still shown on the card as a
  /// fallback when no app can be launched.
  Future<bool> _deliverInvite({
    required String email,
    required String phone,
    required String inviterName,
    required String code,
  }) async {
    final body = _composeInviteMessage(inviterName, code);
    try {
      if (email.isNotEmpty) {
        final uri = Uri(
          scheme: 'mailto',
          path: email,
          query: _encodeQueryParameters({
            'subject': 'Join my Arteria family circle',
            'body': body,
          }),
        );
        if (await canLaunchUrl(uri)) {
          return await launchUrl(uri);
        }
      }
      if (phone.isNotEmpty) {
        final uri = Uri(
          scheme: 'sms',
          path: phone,
          query: _encodeQueryParameters({'body': body}),
        );
        if (await canLaunchUrl(uri)) {
          return await launchUrl(uri);
        }
      }
    } catch (_) {
      // Ignored — fall back to showing the code on the card.
    }
    return false;
  }

  Future<void> _sendInvite(
    BuildContext context,
    void Function(void Function()) dialogSetState,
  ) async {
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();

    if (email.isEmpty && phone.isEmpty) {
      _showSnack(context, 'Enter an email or phone number to send the invite.');
      return;
    }
    if (email.isNotEmpty && !_isValidEmail(email)) {
      _showSnack(context, "That email address doesn't look right.");
      return;
    }

    dialogSetState(() => _isLoading = true);
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        throw Exception('You need to be signed in to invite family.');
      }
      final inviterName = await _currentUserName(userId);
      final code = await _repo.sendInvite(
        userId,
        inviterName,
        email.isEmpty ? null : email,
        phone.isEmpty ? null : phone,
        _permissionFromString(_selectedPermission),
      );
      final delivered = await _deliverInvite(
        email: email,
        phone: phone,
        inviterName: inviterName,
        code: code,
      );

      if (!context.mounted) return;
      Navigator.pop(context);
      setState(() {
        _generatedInviteCode = code;
        _isLoading = false;
        _emailController.clear();
        _phoneController.clear();
      });
      _showSnack(
        context,
        delivered
            ? 'Invite ready — finish sending it in the app that just opened.'
            : 'Invite created. Share code $code with your family member.',
        success: true,
      );
    } catch (e) {
      dialogSetState(() => _isLoading = false);
      _showSnack(context, _friendlyError(e));
    }
  }

  Future<void> _generateQRCode(
    BuildContext context,
    void Function(void Function()) dialogSetState,
  ) async {
    dialogSetState(() => _isLoading = true);
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        throw Exception('You need to be signed in to create an invite.');
      }
      final inviterName = await _currentUserName(userId);
      final code = await _repo.sendInvite(
        userId,
        inviterName,
        null,
        null,
        _permissionFromString(_selectedPermission),
      );

      if (!context.mounted) return;
      Navigator.pop(context);
      setState(() {
        _generatedInviteCode = code;
        _isLoading = false;
      });
      _showSnack(
        context,
        'Invite code created. Share it with your family member.',
        success: true,
      );
    } catch (e) {
      dialogSetState(() => _isLoading = false);
      _showSnack(context, _friendlyError(e));
    }
  }

  // ── Redeeming invites ───────────────────────────────────────────────

  Widget _buildJoinAction(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: InkWell(
        onTap: () => _showRedeemDialog(context),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.vpn_key_rounded,
                size: 16,
                color: Color(0xFFF76C5E),
              ),
              const SizedBox(width: 6),
              Text(
                'Have an invite code?',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFF76C5E),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Two-step redeem flow: enter a code → preview the invite (who sent it,
  /// what they're sharing) → accept and connect.
  void _showRedeemDialog(BuildContext rootContext) {
    final isDark = Theme.of(rootContext).brightness == Brightness.dark;
    final surface = _dialogSurface(isDark);
    final textPrimary = _dialogTextPrimary(isDark);
    final textMuted = _dialogTextMuted(isDark);
    final textFaint = _dialogTextFaint(isDark);
    final fieldFill = _dialogFieldFill(isDark);
    final border = _dialogBorder(isDark);

    _redeemController.clear();
    FamilyInvite? preview;
    bool busy = false;
    String? error;

    showDialog(
      context: rootContext,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: StatefulBuilder(
          builder: (dialogContext, dialogSetState) {
            Future<void> findInvite() async {
              final code = _redeemController.text.trim().toUpperCase();
              if (code.isEmpty) {
                dialogSetState(
                  () => error = 'Enter the invite code you received.',
                );
                return;
              }
              dialogSetState(() {
                busy = true;
                error = null;
              });
              try {
                final invite = await _repo.getInviteByCode(code);
                final myId = FirebaseAuth.instance.currentUser?.uid;
                String? problem;
                if (invite == null) {
                  problem =
                      'No invite matches that code. Check it and try again.';
                } else if (invite.status == FamilyInviteStatus.accepted) {
                  problem = 'This invite has already been used.';
                } else if (invite.status != FamilyInviteStatus.pending ||
                    invite.isExpired) {
                  problem = 'This invite is no longer valid.';
                } else if (myId != null && invite.inviterUserId == myId) {
                  problem = "That's your own invite code.";
                }
                dialogSetState(() {
                  busy = false;
                  if (problem != null) {
                    error = problem;
                  } else {
                    preview = invite;
                  }
                });
              } catch (e) {
                dialogSetState(() {
                  busy = false;
                  error = _friendlyError(e);
                });
              }
            }

            Future<void> acceptInvite() async {
              dialogSetState(() {
                busy = true;
                error = null;
              });
              try {
                final myId = FirebaseAuth.instance.currentUser?.uid;
                if (myId == null) {
                  throw Exception('You need to be signed in to join a family.');
                }
                await _repo.acceptInvite(myId, preview!.inviteCode);
                final name = preview!.inviterName;
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                _showSnack(
                  rootContext,
                  "Connected with $name's family circle.",
                  success: true,
                );
              } catch (e) {
                dialogSetState(() {
                  busy = false;
                  error = _friendlyError(e);
                });
              }
            }

            return Container(
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
                            color: _accent.withValues(
                              alpha: isDark ? 0.18 : 0.10,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.group_add_rounded,
                            color: _accent,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Join a Family Circle',
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      preview == null
                          ? 'Enter the invite code a family member shared '
                                'with you.'
                          : 'Review the invite below before connecting.',
                      style: GoogleFonts.inter(fontSize: 14, color: textMuted),
                    ),
                    const SizedBox(height: 20),
                    if (preview == null)
                      TextField(
                        controller: _redeemController,
                        cursorColor: _accent,
                        textCapitalization: TextCapitalization.characters,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                          color: textPrimary,
                        ),
                        onSubmitted: (_) => busy ? null : findInvite(),
                        decoration: InputDecoration(
                          prefixIcon: Icon(
                            Icons.vpn_key_rounded,
                            size: 20,
                            color: textFaint,
                          ),
                          hintText: 'ART-XXXXXXXX',
                          hintStyle: GoogleFonts.inter(
                            fontSize: 16,
                            color: textFaint,
                          ),
                          filled: true,
                          fillColor: fieldFill,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: _accent,
                              width: 1.5,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                      )
                    else
                      _buildInvitePreview(isDark, preview!),
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            size: 16,
                            color: Color(0xFFEF4444),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              error!,
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFFEF4444),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: busy
                            ? null
                            : (preview == null ? findInvite : acceptInvite),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accent,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: _accent.withValues(
                            alpha: 0.5,
                          ),
                          disabledForegroundColor: Colors.white.withValues(
                            alpha: 0.8,
                          ),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                preview == null
                                    ? 'Find Invite'
                                    : 'Accept & Connect',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: busy
                            ? null
                            : () {
                                if (preview == null) {
                                  Navigator.pop(dialogContext);
                                } else {
                                  dialogSetState(() {
                                    preview = null;
                                    error = null;
                                  });
                                }
                              },
                        child: Text(
                          preview == null ? 'Cancel' : 'Use a different code',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: textMuted,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInvitePreview(bool isDark, FamilyInvite invite) {
    final textPrimary = _dialogTextPrimary(isDark);
    final textMuted = _dialogTextMuted(isDark);
    final fieldFill = _dialogFieldFill(isDark);
    final border = _dialogBorder(isDark);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: fieldFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFF76C5E), Color(0xFFF98E82)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    _getInitials(invite.inviterName),
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invite.inviterName,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'invited you to their family circle',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: isDark ? 0.16 : 0.09),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_rounded, size: 18, color: _accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invite.permission.displayName,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                      Text(
                        invite.permission.description,
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
