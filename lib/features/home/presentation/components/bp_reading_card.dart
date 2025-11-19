import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Enhanced BP reading card with status indicator
class BPReadingCard extends StatelessWidget {
  final int? systolic;
  final int? diastolic;
  final DateTime? readingDate;
  final String category;
  final bool isFirstTime;

  const BPReadingCard({
    super.key,
    this.systolic,
    this.diastolic,
    this.readingDate,
    this.category = 'normal',
    this.isFirstTime = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Determine status color and emoji
    final statusInfo = _getStatusInfo();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: statusInfo['borderColor'] as Color,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: (statusInfo['borderColor'] as Color).withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: isFirstTime ? _buildFirstTimeContent(theme) : _buildReadingContent(theme, statusInfo, isDark),
    );
  }

  Widget _buildFirstTimeContent(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.celebration, color: Color(0xFFFF6F61), size: 28),
            const SizedBox(width: 12),
            Text(
              "You're all set!",
              style: GoogleFonts.montserrat(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: theme.textTheme.titleLarge?.color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          "Record your first blood pressure reading to begin tracking your health journey with AI-powered insights.",
          style: GoogleFonts.openSans(
            fontSize: 15,
            height: 1.5,
            color: theme.textTheme.bodyMedium?.color,
          ),
        ),
      ],
    );
  }

  Widget _buildReadingContent(ThemeData theme, Map<String, dynamic> statusInfo, bool isDark) {
    final dateText = readingDate != null
        ? _formatDate(readingDate!)
        : 'No date recorded';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  statusInfo['emoji'] as String,
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 10),
                Text(
                  'Latest Reading',
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: theme.textTheme.titleLarge?.color,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: (statusInfo['borderColor'] as Color).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                statusInfo['label'] as String,
                style: GoogleFonts.openSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: statusInfo['borderColor'] as Color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildBPValue(
              value: systolic?.toString() ?? '--',
              label: 'Systolic',
              theme: theme,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '/',
                style: GoogleFonts.montserrat(
                  fontSize: 48,
                  fontWeight: FontWeight.w300,
                  color: theme.textTheme.bodyLarge?.color?.withOpacity(0.5),
                ),
              ),
            ),
            _buildBPValue(
              value: diastolic?.toString() ?? '--',
              label: 'Diastolic',
              theme: theme,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.access_time,
                size: 16,
                color: theme.textTheme.bodySmall?.color,
              ),
              const SizedBox(width: 6),
              Text(
                dateText,
                style: GoogleFonts.openSans(
                  fontSize: 13,
                  color: theme.textTheme.bodySmall?.color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBPValue({
    required String value,
    required String label,
    required ThemeData theme,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.montserrat(
            fontSize: 48,
            fontWeight: FontWeight.w700,
            color: theme.textTheme.titleLarge?.color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.openSans(
            fontSize: 13,
            color: theme.textTheme.bodyMedium?.color,
          ),
        ),
        Text(
          'mmHg',
          style: GoogleFonts.openSans(
            fontSize: 11,
            color: theme.textTheme.bodySmall?.color,
          ),
        ),
      ],
    );
  }

  Map<String, dynamic> _getStatusInfo() {
    final sys = systolic ?? 0;
    final dia = diastolic ?? 0;

    if (sys >= 180 || dia >= 120) {
      return {
        'emoji': '🚨',
        'label': 'Critical',
        'borderColor': const Color(0xFFD32F2F),
      };
    } else if (sys >= 140 || dia >= 90) {
      return {
        'emoji': '🟠',
        'label': 'High',
        'borderColor': const Color(0xFFFF6F00),
      };
    } else if (sys >= 130 || dia >= 80) {
      return {
        'emoji': '🟡',
        'label': 'Elevated',
        'borderColor': const Color(0xFFFFA726),
      };
    } else {
      return {
        'emoji': '🟢',
        'label': 'Normal',
        'borderColor': const Color(0xFF4CAF50),
      };
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
