import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Voice Stress Indicator Widget (Novel Feature)
/// 
/// Displays real-time voice stress analysis results during conversations.
/// Shows stress level, contributing factors, and trends over time.
class VoiceStressIndicator extends StatelessWidget {
  final int stressScore; // 0-100
  final String stressLevel; // low, moderate, high
  final List<String> contributingFactors;
  final double? confidence;
  final bool isAnalyzing;

  const VoiceStressIndicator({
    super.key,
    required this.stressScore,
    required this.stressLevel,
    this.contributingFactors = const [],
    this.confidence,
    this.isAnalyzing = false,
  });

  Color get _stressColor {
    if (stressLevel == 'low') return const Color(0xFF10B981); // Green
    if (stressLevel == 'moderate') return const Color(0xFFF59E0B); // Amber
    return const Color(0xFFEF4444); // Red
  }



  String get _stressEmoji {
    if (stressLevel == 'low') return '😌';
    if (stressLevel == 'moderate') return '😐';
    return '😰';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  _stressColor.withValues(alpha: 0.2),
                  const Color(0xFF1A1A2E),
                ]
              : [
                  _stressColor.withValues(alpha: 0.1),
                  Colors.white,
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _stressColor.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _stressColor.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _stressColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.mic,
                  color: _stressColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Voice Stress Analysis',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                    if (isAnalyzing)
                      Text(
                        'Analyzing...',
                        style: GoogleFonts.openSans(
                          fontSize: 12,
                          color: theme.textTheme.bodySmall?.color,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                _stressEmoji,
                style: const TextStyle(fontSize: 28),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Stress Score Bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Stress Level',
                    style: GoogleFonts.openSans(
                      fontSize: 12,
                      color: theme.textTheme.bodySmall?.color,
                    ),
                  ),
                  Text(
                    '$stressScore%',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _stressColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: stressScore / 100,
                  backgroundColor: isDark 
                      ? Colors.white.withValues(alpha: 0.1) 
                      : Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(_stressColor),
                  minHeight: 8,
                ),
              ),
            ],
          ),
          
          // Stress Level Label
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _stressColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              stressLevel.toUpperCase(),
              style: GoogleFonts.montserrat(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _stressColor,
                letterSpacing: 1.2,
              ),
            ),
          ),
          
          // Contributing Factors
          if (contributingFactors.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Contributing Factors',
              style: GoogleFonts.openSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: theme.textTheme.bodySmall?.color,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: contributingFactors.map((factor) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark 
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  factor,
                  style: GoogleFonts.openSans(
                    fontSize: 10,
                    color: theme.textTheme.bodyMedium?.color,
                  ),
                ),
              )).toList(),
            ),
          ],
          
          // Confidence indicator
          if (confidence != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.verified,
                  size: 12,
                  color: theme.textTheme.bodySmall?.color,
                ),
                const SizedBox(width: 4),
                Text(
                  'Confidence: ${(confidence! * 100).toStringAsFixed(0)}%',
                  style: GoogleFonts.openSans(
                    fontSize: 10,
                    color: theme.textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Compact Voice Stress Indicator for better space utilization
class CompactVoiceStressIndicator extends StatelessWidget {
  final int stressScore; // 0-100
  final String stressLevel; // low, moderate, high
  final List<String> contributingFactors;
  final double? confidence;
  final bool isAnalyzing;

  const CompactVoiceStressIndicator({
    super.key,
    required this.stressScore,
    required this.stressLevel,
    this.contributingFactors = const [],
    this.confidence,
    this.isAnalyzing = false,
  });

  Color get _stressColor {
    if (stressLevel == 'low') return const Color(0xFF10B981); // Green
    if (stressLevel == 'moderate') return const Color(0xFFF59E0B); // Amber
    return const Color(0xFFEF4444); // Red
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: 80, // Fixed compact height
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  _stressColor.withValues(alpha: 0.15),
                  const Color(0xFF1A1A2E),
                ]
              : [
                  _stressColor.withValues(alpha: 0.08),
                  Colors.white,
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _stressColor.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _stressColor.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon and progress
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _stressColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    value: isAnalyzing ? null : stressScore / 100,
                    strokeWidth: 2,
                    backgroundColor: isDark 
                        ? Colors.white.withValues(alpha: 0.2) 
                        : Colors.grey.shade300,
                    valueColor: AlwaysStoppedAnimation<Color>(_stressColor),
                  ),
                ),
                Icon(
                  Icons.mic,
                  size: 16,
                  color: _stressColor,
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Text(
                      'Voice Stress',
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _stressColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$stressScore%',
                        style: GoogleFonts.montserrat(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _stressColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  isAnalyzing ? 'Analyzing...' : stressLevel.toUpperCase(),
                  style: GoogleFonts.openSans(
                    fontSize: 10,
                    color: isAnalyzing 
                        ? theme.textTheme.bodySmall?.color
                        : _stressColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          
          // Status indicator
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isAnalyzing 
                  ? Colors.amber 
                  : _stressColor,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}
