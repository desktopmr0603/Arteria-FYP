import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:arteria/features/trends/presentation/bloc/trends_bloc.dart';
import 'package:arteria/features/trends/presentation/bloc/trends_event.dart';
import 'package:arteria/features/trends/presentation/bloc/trends_state.dart';
import 'package:arteria/features/trends/domain/entities/time_range.dart';
import 'package:arteria/features/trends/domain/entities/chart_config.dart';
import 'package:arteria/features/trends/domain/entities/trend_data.dart';
import 'package:arteria/features/trends/presentation/widgets/bp_line_chart.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:arteria/l10n/app_localizations.dart';
import '../../../home/data/data_sources/health_risk_score_service.dart';
import '../../../home/data/data_sources/bp_anomaly_remote_data_source.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/predictive_timeline.dart';
import '../widgets/risk_trend_analysis.dart';
import '../widgets/historical_patterns.dart';

class TrendsScreen extends StatefulWidget {
  const TrendsScreen({super.key});

  @override
  State<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends State<TrendsScreen>
    with TickerProviderStateMixin {
  late TimeRange _selectedTimeRange;
  late AnimationController _fadeController;
  late AnimationController _slideController;

  // Enhanced services for advanced visualizations
  final HealthRiskScoreService _riskScoreService = HealthRiskScoreService();
  final BPAnomalyRemoteDataSource _anomalyService = BPAnomalyRemoteDataSource();

  String get _userId =>
      FirebaseAuth.instance.currentUser?.uid ?? 'default_user';

  @override
  void initState() {
    super.initState();
    _selectedTimeRange = TimeRange.last30Days();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    // Initialize enhanced services
    _initializeEnhancedServices();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fadeController.forward();
      context.read<TrendsBloc>().add(
        LoadTrendsData(
          timeRange: _selectedTimeRange,
          viewMode: ViewMode.simple,
        ),
      );
    });
  }

  Future<void> _initializeEnhancedServices() async {
    try {
      await _riskScoreService.initialize();
      await _anomalyService.initialize(_userId);
      debugPrint('✅ Enhanced trends services initialized');
    } catch (e) {
      debugPrint('⚠️ Error initializing enhanced services: $e');
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0A0A0F)
          : const Color(0xFFF8FAFB),
      body: BlocConsumer<TrendsBloc, TrendsState>(
        listener: (context, state) {
          if (state.hasError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage),
                backgroundColor: const Color(0xFFEF4444),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          }
        },
        builder: (context, state) {
          return Stack(
            children: [
              _buildBackgroundDecorations(isDark),
              SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(isDark),
                    Expanded(
                      child: FadeTransition(
                        opacity: _fadeController,
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 16),
                              _buildTimeRangeSelector(),
                              if (state.isLoaded) ...[
                                const SizedBox(height: 20),
                                _buildChartCard(state, isDark),
                                const SizedBox(height: 20),
                                _buildSummarySection(state.asLoaded!, isDark),
                                const SizedBox(height: 20),
                                _buildReadingsSection(state.asLoaded!, isDark),
                                const SizedBox(height: 30),
                                _buildPredictiveTimeline(isDark),
                                const SizedBox(height: 30),
                                _buildRiskTrendAnalysis(
                                  state.asLoaded!,
                                  isDark,
                                ),
                                const SizedBox(height: 30),
                                _buildHistoricalPatterns(
                                  state.asLoaded!,
                                  isDark,
                                ),
                              ],
                              if (state.isLoading) ...[
                                const SizedBox(height: 40),
                                _buildShimmerLoading(),
                              ],
                              if (state.hasNoData) ...[
                                const SizedBox(height: 40),
                                _buildEmptyState(isDark),
                              ],
                              const SizedBox(height: 100),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBackgroundDecorations(bool isDark) {
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF6366F1).withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)!.trendsBloodPressure,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.6)
                      : const Color(0xFF64748B),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                AppLocalizations.of(context)!.trendsHistory,
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          _buildShareButton(isDark),
        ],
      ),
    );
  }

  Widget _buildShareButton(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF2D2D3A), const Color(0xFF1A1A24)]
              : [Colors.white, const Color(0xFFF1F5F9)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showExportDialog(context),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            child: Icon(
              Icons.ios_share,
              size: 22,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.8)
                  : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeRangeSelector() {
    return TimeRangeChipsModern(
      selectedRange: _selectedTimeRange,
      onRangeChanged: _onTimeRangeChanged,
    );
  }

  Widget _buildChartCard(TrendsState state, bool isDark) {
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
            child: _buildChartContent(state, isDark),
          ),
        ),
      ),
    );
  }

  Widget _buildChartContent(TrendsState state, bool isDark) {
    if (state.isLoading) {
      return SizedBox(
        height: 280,
        child: Center(
          child: SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: const Color(0xFF6366F1),
              backgroundColor: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : const Color(0xFFE2E8F0),
            ),
          ),
        ),
      );
    }

    if (state.isLoaded) {
      final loadedState = state.asLoaded!;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppLocalizations.of(context)!.trendsTrendAnalysis,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              _buildLegend(isDark),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 240,
            child: BPLineChart(
              data: loadedState.trendData,
              isSimpleView: false,
              primaryColor: const Color(0xFFEF4444),
              secondaryColor: const Color(0xFF3B82F6),
            ),
          ),
        ],
      );
    }

    if (state.hasNoData) {
      return SizedBox(
        height: 280,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.trending_flat,
                  size: 40,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.3)
                      : const Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)!.trendsNoDataAvailable,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.6)
                      : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildLegend(bool isDark) {
    return Row(
      children: [
        _buildLegendItem(const Color(0xFFEF4444), 'SYS', isDark),
        const SizedBox(width: 16),
        _buildLegendItem(const Color(0xFF3B82F6), 'DIA', isDark),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label, bool isDark) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark
                ? Colors.white.withValues(alpha: 0.5)
                : const Color(0xFF94A3B8),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildSummarySection(TrendsLoaded state, bool isDark) {
    final avgSystolic = _calculateAverage(
      state.trendData.map((d) => d.systolic),
    );
    final avgDiastolic = _calculateAverage(
      state.trendData.map((d) => d.diastolic),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.trendsOverview,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                AppLocalizations.of(context)!.trendsReadings,
                '${state.trendData.length}',
                Icons.stacked_line_chart_outlined,
                const Color(0xFF6366F1),
                isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                AppLocalizations.of(context)!.trendsSysAvg,
                '$avgSystolic',
                Icons.trending_up_outlined,
                const Color(0xFFEF4444),
                isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                AppLocalizations.of(context)!.trendsDiaAvg,
                '$avgDiastolic',
                Icons.trending_down_outlined,
                const Color(0xFF3B82F6),
                isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildBPGuideCard(isDark),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color accentColor,
    bool isDark,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1A1A24), const Color(0xFF12121A)]
              : [Colors.white, const Color(0xFFF8FAFB)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: accentColor),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.5)
                    : const Color(0xFF64748B),
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBPGuideCard(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1A1A24), const Color(0xFF12121A)]
              : [Colors.white, const Color(0xFFF8FAFB)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: Color(0xFF10B981),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  AppLocalizations.of(context)!.trendsBpGuide,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildBPGuideRow(
              AppLocalizations.of(context)!.trendsBpNormal,
              '≤ 120/80',
              const Color(0xFF10B981),
              isDark,
            ),
            _buildBPGuideRow(
              AppLocalizations.of(context)!.trendsBpElevated,
              '120‑129/< 80',
              const Color(0xFFF59E0B),
              isDark,
            ),
            _buildBPGuideRow(
              AppLocalizations.of(context)!.trendsBpHighStage1,
              '130‑139/80‑89',
              const Color(0xFFF97316),
              isDark,
            ),
            _buildBPGuideRow(
              AppLocalizations.of(context)!.trendsBpHighStage2,
              '≥ 140/≥ 90',
              const Color(0xFFEF4444),
              isDark,
            ),
            _buildBPGuideRow(
              AppLocalizations.of(context)!.trendsBpCrisis,
              '≥ 180/≥ 120',
              const Color(0xFFDC2626),
              isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBPGuideRow(
    String label,
    String range,
    Color color,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.8)
                    : const Color(0xFF475569),
              ),
            ),
          ),
          Text(
            range,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.4)
                  : const Color(0xFF94A3B8),
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadingsSection(TrendsLoaded state, bool isDark) {
    final readings = state.trendData.take(10).toList();
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              AppLocalizations.of(context)!.trendsRecentReadings,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
                letterSpacing: -0.3,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${readings.length}/${state.trendData.length}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF6366F1),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [const Color(0xFF1A1A24), const Color(0xFF12121A)]
                  : [Colors.white, const Color(0xFFF8FAFB)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              ...readings.map(
                (reading) => _buildReadingItem(reading, dateFormat, isDark),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReadingItem(
    TrendData reading,
    DateFormat dateFormat,
    bool isDark,
  ) {
    final category = reading.category;
    Color indicatorColor;
    switch (category) {
      case BPCategory.normal:
        indicatorColor = const Color(0xFF10B981);
      case BPCategory.elevated:
        indicatorColor = const Color(0xFFF59E0B);
      case BPCategory.hypertensionStage1:
        indicatorColor = const Color(0xFFF97316);
      case BPCategory.hypertensionStage2:
        indicatorColor = const Color(0xFFEF4444);
      case BPCategory.hypertensiveCrisis:
        indicatorColor = const Color(0xFFDC2626);
    }

    final isLast = reading == reading;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: isLast
              ? BorderSide.none
              : BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : const Color(0xFFE2E8F0),
                ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: indicatorColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: indicatorColor.withValues(alpha: 0.5),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${reading.systolic}/${reading.diastolic}',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1E293B),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'mmHg',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.4)
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: indicatorColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      category.displayName,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: indicatorColor,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              dateFormat.format(reading.timestamp),
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.4)
                    : const Color(0xFF94A3B8),
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(40),
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
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF6366F1).withValues(alpha: 0.1),
                    const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.show_chart_rounded,
                size: 48,
                color: const Color(0xFF6366F1).withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Readings Yet',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Start tracking your blood pressure to see your health trends and insights over time.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.5)
                    : const Color(0xFF64748B),
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onTimeRangeChanged(TimeRange newRange) {
    setState(() => _selectedTimeRange = newRange);
    _slideController.forward(from: 0);
    context.read<TrendsBloc>().add(ChangeTimeRange(newRange));
  }

  int _calculateAverage(Iterable<int> values) {
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) ~/ values.length;
  }

  void _showExportDialog(BuildContext context) {
    final state = context.read<TrendsBloc>().state;
    if (state is! TrendsLoaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No data to export'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: const Color(0xFF64748B),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.share_rounded,
                  color: Color(0xFF6366F1),
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Share Report',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Generate a report for your healthcare provider',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.5)
                      : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _generateTextReport(context, state),
                  icon: const Icon(Icons.description_rounded, size: 20),
                  label: const Text('View Text Report'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _generateSimpleReport(context, state),
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 20),
                  label: const Text('View Summary'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF2D2D3A)
                        : const Color(0xFFF1F5F9),
                    foregroundColor:
                        Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : const Color(0xFF1E293B),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withValues(alpha: 0.5)
                        : const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _generateTextReport(BuildContext context, TrendsLoaded state) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final avgSystolic = _calculateAverage(
      state.trendData.map((d) => d.systolic),
    );
    final avgDiastolic = _calculateAverage(
      state.trendData.map((d) => d.diastolic),
    );

    final report = StringBuffer();
    report.writeln('BLOOD PRESSURE REPORT');
    report.writeln('=====================');
    report.writeln('Period: ${_selectedTimeRange.displayName}');
    report.writeln('Generated: ${dateFormat.format(DateTime.now())}');
    report.writeln('');
    report.writeln('SUMMARY');
    report.writeln('-------');
    report.writeln('Total Readings: ${state.trendData.length}');
    report.writeln('Average Systolic: $avgSystolic mmHg');
    report.writeln('Average Diastolic: $avgDiastolic mmHg');
    report.writeln('');
    report.writeln('READINGS');
    report.writeln('--------');

    for (final reading in state.trendData) {
      report.writeln(
        '${dateFormat.format(reading.timestamp)}: ${reading.systolic}/${reading.diastolic} mmHg (${reading.category.displayName})',
      );
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppLocalizations.of(context)!.dialogTextReport,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: SelectableText(
                    report.toString(),
                    style: GoogleFonts.robotoMono(fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(AppLocalizations.of(context)!.dialogClose),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _generateSimpleReport(BuildContext context, TrendsLoaded state) {
    final avgSystolic = _calculateAverage(
      state.trendData.map((d) => d.systolic),
    );
    final avgDiastolic = _calculateAverage(
      state.trendData.map((d) => d.diastolic),
    );

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.health_and_safety_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                AppLocalizations.of(context)!.dialogSummaryForDoctor,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context)!.trendsAvgBp,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.5)
                      : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$avgSystolic/$avgDiastolic',
                style: GoogleFonts.inter(
                  fontSize: 48,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF6366F1),
                ),
              ),
              Text(
                'mmHg',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.5)
                      : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  AppLocalizations.of(context)!.trendsReadingsOver(
                    state.trendData.length,
                    _getLocalizedTimeRange(context, _selectedTimeRange),
                  ),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF6366F1),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(AppLocalizations.of(context)!.dialogClose),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────── Enhanced Visualizations ───────────────

  Widget _buildPredictiveTimeline(bool isDark) {
    return PredictiveTimeline(
      userId: _userId,
      riskScoreService: _riskScoreService,
      isDark: isDark,
    );
  }

  Widget _buildRiskTrendAnalysis(TrendsLoaded loaded, bool isDark) {
    return RiskTrendAnalysis(
      userId: _userId,
      riskScoreService: _riskScoreService,
      isDark: isDark,
      trendData: loaded.trendData,
    );
  }

  Widget _buildHistoricalPatterns(TrendsLoaded loaded, bool isDark) {
    return HistoricalPatterns(
      userId: _userId,
      anomalyService: _anomalyService,
      isDark: isDark,
      trendData: loaded.trendData,
    );
  }
}

String _getLocalizedTimeRange(BuildContext context, TimeRange range) {
  final l10n = AppLocalizations.of(context)!;
  switch (range.type) {
    case TimeRangeType.last7Days:
      return l10n.timeRangeLast7Days;
    case TimeRangeType.last30Days:
      return l10n.timeRangeLast30Days;
    case TimeRangeType.last90Days:
      return l10n.timeRangeLast90Days;
    case TimeRangeType.thisYear:
      return l10n.timeRangeThisYear;
    case TimeRangeType.custom:
      return l10n.timeRangeCustom;
  }
}

class TimeRangeChipsModern extends StatefulWidget {
  final TimeRange selectedRange;
  final Function(TimeRange) onRangeChanged;

  const TimeRangeChipsModern({
    super.key,
    required this.selectedRange,
    required this.onRangeChanged,
  });

  @override
  State<TimeRangeChipsModern> createState() => _TimeRangeChipsModernState();
}

class _TimeRangeChipsModernState extends State<TimeRangeChipsModern> {
  late final List<TimeRange> _ranges;

  @override
  void initState() {
    super.initState();
    _ranges = [
      TimeRange.last7Days(),
      TimeRange.last30Days(),
      TimeRange.last90Days(),
      TimeRange.thisYear(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _ranges.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final range = _ranges[index];
          final isSelected = widget.selectedRange == range;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    )
                  : null,
              borderRadius: BorderRadius.circular(14),
              border: isSelected
                  ? null
                  : Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : const Color(0xFFE2E8F0),
                    ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => widget.onRangeChanged(range),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _getLocalizedTimeRange(context, range),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : isDark
                          ? Colors.white.withValues(alpha: 0.7)
                          : const Color(0xFF64748B),
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
