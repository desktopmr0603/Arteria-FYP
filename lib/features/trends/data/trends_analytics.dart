import 'dart:math';

import 'package:arteria/features/trends/data/models/trend_data_model.dart';
import 'package:arteria/features/trends/domain/entities/trend_data.dart';
import 'package:arteria/features/trends/domain/repositories/trends_repository.dart';

/// Pure, side-effect-free analytics used by [TrendsRepositoryImpl].
///
/// Kept separate from the repository so the math can be unit-tested without
/// any Firebase dependency.
class TrendsAnalytics {
  const TrendsAnalytics._();

  /// Descriptive statistics for a list of readings.
  /// Assumes `readings.isNotEmpty`.
  static TrendStatistics calculateStatistics(List<TrendData> readings) {
    assert(readings.isNotEmpty, 'calculateStatistics needs at least 1 reading');
    final sys = readings.map((r) => r.systolic).toList();
    final dia = readings.map((r) => r.diastolic).toList();

    final avgSys = sys.reduce((a, b) => a + b) / sys.length;
    final avgDia = dia.reduce((a, b) => a + b) / dia.length;

    return TrendStatistics(
      totalReadings: readings.length,
      systolicAverage: avgSys,
      diastolicAverage: avgDia,
      systolicMin: sys.reduce(min),
      systolicMax: sys.reduce(max),
      diastolicMin: dia.reduce(min),
      diastolicMax: dia.reduce(max),
      standardDeviationSystolic: standardDeviation(sys, avgSys),
      standardDeviationDiastolic: standardDeviation(dia, avgDia),
    );
  }

  /// Population standard deviation.
  static double standardDeviation(List<int> values, double mean) {
    if (values.isEmpty) return 0;
    final variance =
        values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) /
        values.length;
    return variance > 0 ? sqrt(variance) : 0;
  }

  /// Trend direction from a list of readings ordered newest-first (as the
  /// Firestore repository returns them). We split into chronological halves
  /// and compare mean systolic. Fewer than 3 readings is insufficient.
  static TrendDirection analyzeTrend(
    List<TrendData> newestFirst, {
    double threshold = 5.0,
  }) {
    if (newestFirst.length < 3) return TrendDirection.insufficient;

    // Work chronologically so "increasing" means genuinely trending up in
    // time, not "more recent readings are lower".
    final chron = [...newestFirst]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final midPoint = chron.length ~/ 2;
    final firstHalf = chron.sublist(0, midPoint);
    final secondHalf = chron.sublist(midPoint);
    if (firstHalf.isEmpty || secondHalf.isEmpty) {
      return TrendDirection.insufficient;
    }

    final firstAvg =
        firstHalf.map((r) => r.systolic).reduce((a, b) => a + b) /
        firstHalf.length;
    final secondAvg =
        secondHalf.map((r) => r.systolic).reduce((a, b) => a + b) /
        secondHalf.length;

    final diff = secondAvg - firstAvg;
    if (diff > threshold) return TrendDirection.increasing;
    if (diff < -threshold) return TrendDirection.decreasing;
    return TrendDirection.stable;
  }

  /// Distribution of readings across BP categories.
  static List<BPCategoryDistribution> categoryDistribution(
    List<TrendData> readings,
  ) {
    if (readings.isEmpty) return const [];
    final counts = <BPCategory, int>{};
    for (final r in readings) {
      counts[r.category] = (counts[r.category] ?? 0) + 1;
    }
    return counts.entries
        .map(
          (e) => BPCategoryDistribution(
            category: e.key,
            count: e.value,
            percentage: (e.value / readings.length) * 100,
          ),
        )
        .toList();
  }

  /// Aggregate readings by calendar day.
  static List<AggregatedTrendData> aggregateByDay(List<TrendData> data) {
    return _aggregateByKey(
      data,
      (ts) => DateTime(ts.year, ts.month, ts.day),
    );
  }

  /// Aggregate readings by ISO week (anchored to Monday).
  static List<AggregatedTrendData> aggregateByWeek(List<TrendData> data) {
    return _aggregateByKey(data, (ts) {
      final daysFromMonday = ts.weekday - DateTime.monday;
      return DateTime(ts.year, ts.month, ts.day)
          .subtract(Duration(days: daysFromMonday));
    });
  }

  /// Aggregate readings by calendar month.
  static List<AggregatedTrendData> aggregateByMonth(List<TrendData> data) {
    return _aggregateByKey(data, (ts) => DateTime(ts.year, ts.month, 1));
  }

  static List<AggregatedTrendData> _aggregateByKey(
    List<TrendData> data,
    DateTime Function(DateTime) bucketKey,
  ) {
    if (data.isEmpty) return const [];

    final grouped = <DateTime, List<TrendData>>{};
    for (final r in data) {
      grouped.putIfAbsent(bucketKey(r.timestamp), () => []).add(r);
    }

    final out = grouped.entries.map((e) {
      final readings = e.value;
      final avgSys =
          readings.map((d) => d.systolic).reduce((a, b) => a + b) /
          readings.length;
      final avgDia =
          readings.map((d) => d.diastolic).reduce((a, b) => a + b) /
          readings.length;
      return AggregatedTrendData(
        period: e.key,
        averageSystolic: avgSys,
        averageDiastolic: avgDia,
        readingCount: readings.length,
        averageCategory: TrendDataModel.classifyBP(
          avgSys.round(),
          avgDia.round(),
        ),
      );
    }).toList()
      ..sort((a, b) => a.period.compareTo(b.period));

    return out;
  }

  /// Human-readable summary for a [TrendDirection].
  static String summarize(TrendDirection direction) {
    switch (direction) {
      case TrendDirection.increasing:
        return 'Your blood pressure has been trending upward recently. '
            'Consider lifestyle changes or consulting your doctor.';
      case TrendDirection.decreasing:
        return 'Your blood pressure has been trending downward recently. '
            'Keep up the good work!';
      case TrendDirection.stable:
        return 'Your blood pressure has remained stable. '
            'Continue monitoring regularly.';
      case TrendDirection.insufficient:
        return 'Insufficient data for trend analysis. '
            'Continue regular readings.';
    }
  }
}
