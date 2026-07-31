import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:arteria/features/home/data/data_sources/daily_risk_score_service.dart';
import 'package:arteria/features/trends/data/data_sources/trend_summary_service.dart';
import 'package:arteria/l10n/app_localizations.dart';

/// Conversational trend headline at the top of the Trends page.
///
/// Shows a single LLM-generated sentence summarizing the week's trends
/// (in the user's current locale), plus three plain-language metric
/// cards (Systolic / Diastolic / Risk score) with explicit deltas so
/// laymen don't have to decode arrows and naked numbers.
class TrendHeadlineCard extends StatefulWidget {
  const TrendHeadlineCard({
    super.key,
    required this.userId,
    required this.dailyRiskScoreService,
    required this.trendSummaryService,
    required this.isDark,
  });

  final String userId;
  final DailyRiskScoreService dailyRiskScoreService;
  final TrendSummaryService trendSummaryService;
  final bool isDark;

  @override
  State<TrendHeadlineCard> createState() => _TrendHeadlineCardState();
}

class _TrendHeadlineCardState extends State<TrendHeadlineCard> {
  TrendSummary? _summary;
  bool _loading = true;
  String? _loadedForLocale;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context).languageCode;
    if (_loadedForLocale != locale) {
      _loadedForLocale = locale;
      _load(locale);
    }
  }

  Future<void> _load(String languageCode) async {
    setState(() => _loading = true);
    try {
      final series = await widget.dailyRiskScoreService.getDailySeries(
        userId: widget.userId,
        days: 14,
      );
      final summary = await widget.trendSummaryService.getSummary(
        userId: widget.userId,
        dailySeries: series,
        languageCode: languageCode,
      );
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_loading) return _shell(child: _loadingBody(l10n));
    final s = _summary;
    if (s == null) return const SizedBox.shrink();
    return _shell(child: _filledBody(s, l10n));
  }

  Widget _shell({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: widget.isDark
              ? [
                  const Color(0xFF1A1F36).withValues(alpha: 0.85),
                  const Color(0xFF0E1225).withValues(alpha: 0.85),
                ]
              : [Colors.white, const Color(0xFFF8FAFF)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF667EEA).withValues(alpha: 0.18),
        ),
      ),
      child: child,
    );
  }

  Widget _loadingBody(AppLocalizations l10n) {
    return Row(
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              widget.isDark ? Colors.white60 : const Color(0xFF667EEA),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          l10n.trendHeadlineLoading,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: widget.isDark ? Colors.white60 : Colors.black54,
          ),
        ),
      ],
    );
  }

  Widget _filledBody(TrendSummary s, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF667EEA).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                size: 14,
                color: Color(0xFF667EEA),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              l10n.trendHeadlineTagline,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: const Color(0xFF667EEA),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          s.headline,
          style: GoogleFonts.inter(
            fontSize: 16,
            height: 1.45,
            fontWeight: FontWeight.w600,
            color: widget.isDark ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _metricTile(
                label: l10n.trendHeadlineLabelSystolic,
                value: '${s.sbpCurrent}',
                unit: 'mmHg',
                delta: s.sbpDelta.toDouble(),
                improvedWhen: _TrendDirection.decreasing,
                l10n: l10n,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _metricTile(
                label: l10n.trendHeadlineLabelDiastolic,
                value: '${s.dbpCurrent}',
                unit: 'mmHg',
                delta: s.dbpDelta.toDouble(),
                improvedWhen: _TrendDirection.decreasing,
                l10n: l10n,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _metricTile(
                label: l10n.trendHeadlineLabelRisk,
                value: s.drsCurrent.toStringAsFixed(0),
                unit: '/100',
                delta: s.drsDelta,
                improvedWhen: _TrendDirection.decreasing,
                l10n: l10n,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Stacked metric tile: small label on top, big value in the middle,
  /// plain-language delta line at the bottom. Drops the cryptic arrows
  /// and never shows a bare "→ 0" when nothing changed.
  Widget _metricTile({
    required String label,
    required String value,
    required String unit,
    required double delta,
    required _TrendDirection improvedWhen,
    required AppLocalizations l10n,
  }) {
    final isFlat = delta.abs() < 0.5;
    final isImprovement = !isFlat &&
        ((improvedWhen == _TrendDirection.decreasing && delta < 0) ||
            (improvedWhen == _TrendDirection.increasing && delta > 0));
    final deltaColor = isFlat
        ? (widget.isDark ? Colors.white54 : const Color(0xFF64748B))
        : (isImprovement
            ? const Color(0xFF10B981)
            : const Color(0xFFF59E0B));

    final deltaText = isFlat
        ? l10n.trendHeadlineDeltaStable
        : (delta > 0
            ? l10n.trendHeadlineDeltaUp(_formatDelta(delta))
            : l10n.trendHeadlineDeltaDown(_formatDelta(delta)));

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: widget.isDark
            ? Colors.white.withValues(alpha: 0.04)
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isDark
              ? Colors.white.withValues(alpha: 0.06)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: widget.isDark ? Colors.white60 : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              style: GoogleFonts.inter(
                color: widget.isDark ? Colors.white : const Color(0xFF1E293B),
              ),
              children: [
                TextSpan(
                  text: value,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: widget.isDark
                        ? Colors.white
                        : const Color(0xFF1E293B),
                  ),
                ),
                TextSpan(
                  text: ' $unit',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: widget.isDark
                        ? Colors.white54
                        : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            deltaText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: deltaColor,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  /// Absolute value, one decimal only when small enough to matter.
  String _formatDelta(double delta) {
    final abs = delta.abs();
    return abs >= 10 ? abs.toStringAsFixed(0) : abs.toStringAsFixed(1);
  }
}

enum _TrendDirection { increasing, decreasing }
