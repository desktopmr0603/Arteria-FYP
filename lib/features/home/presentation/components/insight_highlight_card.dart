import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:arteria/features/home/data/models/daily_insight_model.dart';
import 'package:arteria/features/home/data/data_sources/insight_generator_service.dart';
import 'package:arteria/features/home/presentation/components/premium_dashboard_card.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Premium Home Insight Card (Matches Oura/health-tech reference exactly)
// ─────────────────────────────────────────────────────────────────────────────

/// A strictly reusable premium home insight card.
///
/// Features:
/// - Exact nested container left-edge accent stroke (clean, zero bleeding).
/// - Dynamic real Firestore mapping (`users/{uid}/insights`).
/// - No fake or hardcoded medical text.
/// - Oura/Whoop style breathing room and exact topographic proportions.
class InsightHighlightCard extends StatefulWidget {
  /// When null, the card auto-binds to `users/{uid}/insights`.
  final InsightModel? staticInsight;

  /// Optional tap callback.
  final VoidCallback? onTap;

  const InsightHighlightCard({super.key, this.staticInsight, this.onTap});

  @override
  State<InsightHighlightCard> createState() => _InsightHighlightCardState();
}

class _InsightHighlightCardState extends State<InsightHighlightCard> {
  /// Cached stream — created once in initState so parent rebuilds (e.g.
  /// the homepage BlocBuilder firing on UserState changes) don't tear
  /// down and re-subscribe to Firestore on every rebuild. The previous
  /// implementation called `_insightStream()` inside `build()`, which
  /// flashed the skeleton loader and contributed to homepage scroll jank.
  Stream<InsightModel?>? _insightStream;

  /// The locale we last kicked off a regeneration for, so a stale-language
  /// insight is re-generated at most once per language per card lifetime
  /// (prevents an API-call loop when generation fails or is slow).
  String? _regenRequestedForLang;

  @override
  void initState() {
    super.initState();
    _insightStream = _buildStream();
  }

  /// When the displayed insight was written in a different language than the
  /// app's current locale, regenerate it from the latest reading so the
  /// dashboard summary follows the language the user selected. The Firestore
  /// stream then surfaces the new (translated) document automatically.
  void _maybeRegenerateForLocale(String localeCode, InsightModel insight) {
    // Nothing to translate for the empty-state fallback (no real reading yet).
    if (insight.createdAt == null) return;
    if (insight.lang == localeCode) return;
    if (_regenRequestedForLang == localeCode) return;
    _regenRequestedForLang = localeCode;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _regenerateForLocale(localeCode);
    });
  }

  Future<void> _regenerateForLocale(String localeCode) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final readings = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('readings');

      final latestSnap =
          await readings.orderBy('date', descending: true).limit(1).get();
      if (latestSnap.docs.isEmpty) return;
      final latest = latestSnap.docs.first.data();
      final newSys = (latest['systolic'] as num?)?.toDouble();
      final newDia = (latest['diastolic'] as num?)?.toDouble();
      if (newSys == null || newDia == null) return;

      // 30-day average for grounding context.
      final monthAgo = DateTime.now().subtract(const Duration(days: 30));
      final histSnap = await readings
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(monthAgo))
          .get();
      final sys = <double>[];
      final dia = <double>[];
      for (final d in histSnap.docs) {
        final s = (d.data()['systolic'] as num?)?.toDouble();
        final di = (d.data()['diastolic'] as num?)?.toDouble();
        if (s != null) sys.add(s);
        if (di != null) dia.add(di);
      }
      final avgSys = sys.isNotEmpty ? sys.reduce((a, b) => a + b) / sys.length : newSys;
      final avgDia = dia.isNotEmpty ? dia.reduce((a, b) => a + b) / dia.length : newDia;

      await InsightGeneratorService.generateAndSaveInsight(
        uid: uid,
        newSystolic: newSys,
        newDiastolic: newDia,
        avgSystolic: avgSys,
        avgDiastolic: avgDia,
        hasSymptoms: false,
        language: localeCode,
      );
    } catch (e) {
      debugPrint('⚠️ Insight locale regeneration failed: $e');
    }
  }

  Stream<InsightModel?> _buildStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(null);

    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('insights')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return null;
      return InsightModel.fromFirestore(snap.docs.first);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Reading the locale here registers this widget as a dependent of
    // Localizations, so it rebuilds when the user switches language.
    final localeCode =
        Localizations.localeOf(context).languageCode.toLowerCase();

    if (widget.staticInsight != null) {
      return _buildCard(context, widget.staticInsight!);
    }

    return StreamBuilder<InsightModel?>(
      stream: _insightStream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return _buildSkeleton(context);
        }

        final insight = snap.data ?? InsightModel.emptyFallback();
        _maybeRegenerateForLocale(localeCode, insight);
        return _buildCard(context, insight);
      },
    );
  }

  // ── Core Card Implementation ─────────────────────────────────────────────
  Widget _buildCard(BuildContext context, InsightModel insight) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return PremiumDashboardCard(
      onTap: widget.onTap,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInsightHeader(context, insight, isDark),
          const SizedBox(height: 20),
          _buildTitle(insight, isDark),
          const SizedBox(height: 12),
          _buildMessage(insight, isDark),
        ],
      ),
    );
  }

  // ── Header: Icon and optional Status Label ──────────────────────────────
  Widget _buildInsightHeader(
    BuildContext context,
    InsightModel insight,
    bool isDark,
  ) {
    final Color iconBgColor =
        isDark ? const Color(0xFF162A30) : const Color(0xFFE2F6F8);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Small premium tile icon
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconBgColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Image.asset(
              'assets/illustrations/ai_icon.png',
              width: 22,
              height: 22,
            ),
          ),
        ),
        
        const Spacer(),
        
        // Status label (Matches exactly: "STATUS: OPTIMAL")
        if (insight.status != null && insight.status!.isNotEmpty)
          Text(
            'STATUS: ${insight.status!.toUpperCase()}',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFF00A29C) : const Color(0xFF007B85),
              letterSpacing: 1.2,
            ),
          ),
      ],
    );
  }

  // ── Title ─────────────────────────────────────────────────────────────
  Widget _buildTitle(InsightModel insight, bool isDark) {
    return Text(
      insight.title,
      // We fall back to standard translation if the title was generated as generic 'Insight'
      // But strictly use the database exact string if it is customized.
      style: GoogleFonts.inter(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        color: isDark ? Colors.white : const Color(0xFF1E293B),
        height: 1.2,
        letterSpacing: -0.4,
      ),
    );
  }

  // ── Body Message ──────────────────────────────────────────────────────
  Widget _buildMessage(InsightModel insight, bool isDark) {
    return Text(
      insight.message,
      style: GoogleFonts.inter(
        fontSize: 14.5,
        fontWeight: FontWeight.w400,
        color: isDark 
            ? Colors.white.withValues(alpha: 0.75) 
            : const Color(0xFF475569),
        height: 1.55,
      ),
    );
  }

  // ── Skeleton Loader ───────────────────────────────────────────────────
  Widget _buildSkeleton(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final shimmer = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.04);

    Widget bar(double w, double h) => Container(
          width: w,
          height: h,
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: shimmer,
            borderRadius: BorderRadius.circular(4),
          ),
        );

    return PremiumDashboardCard(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: shimmer,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const Spacer(),
              bar(80, 10),
            ],
          ),
          const SizedBox(height: 20),
          bar(200, 20),
          const SizedBox(height: 12),
          bar(double.infinity, 14),
          bar(double.infinity, 14),
          bar(140, 14),
        ],
      ),
    );
  }
}
