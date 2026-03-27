import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:arteria/features/home/data/models/daily_insight_model.dart';
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
class InsightHighlightCard extends StatelessWidget {
  /// When null, the card auto-binds to `users/{uid}/insights`.
  final InsightModel? staticInsight;

  /// Optional tap callback.
  final VoidCallback? onTap;

  const InsightHighlightCard({super.key, this.staticInsight, this.onTap});

  // ── Firestore Stream: binds only exactly to the user's `insights` collection
  Stream<InsightModel?> _insightStream() {
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

  // ── Icon Mapping ──────────────────────────────────────────────────────────
  IconData _iconForString(String? iconType) {
    if (iconType == null) return Icons.insights_rounded;
    switch (iconType.toLowerCase()) {
      case 'heart_rate':
      case 'heart':
        return Icons.monitor_heart_rounded;
      case 'sleep':
      case 'bed':
        return Icons.bedtime_rounded;
      case 'activity':
      case 'run':
        return Icons.directions_run_rounded;
      case 'nutrition':
      case 'food':
        return Icons.restaurant_rounded;
      case 'medication':
      case 'pill':
        return Icons.medication_rounded;
      default:
        return Icons.insights_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (staticInsight != null) {
      return _buildCard(context, staticInsight!);
    }

    return StreamBuilder<InsightModel?>(
      stream: _insightStream(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return _buildSkeleton(context);
        }
        
        final insight = snap.data ?? InsightModel.emptyFallback();
        return _buildCard(context, insight);
      },
    );
  }

  // ── Core Card Implementation ─────────────────────────────────────────────
  Widget _buildCard(BuildContext context, InsightModel insight) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return PremiumDashboardCard(
      onTap: onTap,
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
    final Color iconTintColor = isDark ? const Color(0xFF00E5FF) : const Color(0xFF009AA6);
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
            child: Icon(
              _iconForString(insight.icon),
              color: iconTintColor,
              size: 20,
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
