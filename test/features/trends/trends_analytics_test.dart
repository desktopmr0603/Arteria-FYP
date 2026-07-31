import 'dart:math' as math;

import 'package:arteria/features/trends/data/trends_analytics.dart';
import 'package:arteria/features/trends/domain/entities/trend_data.dart';
import 'package:arteria/features/trends/domain/repositories/trends_repository.dart';
import 'package:flutter_test/flutter_test.dart';

TrendData _r({
  required DateTime ts,
  required int sys,
  required int dia,
  BPCategory category = BPCategory.normal,
  String id = 'x',
}) {
  return TrendData(
    timestamp: ts,
    systolic: sys,
    diastolic: dia,
    category: category,
    id: id,
  );
}

void main() {
  group('standardDeviation', () {
    test('returns 0 for empty list', () {
      expect(TrendsAnalytics.standardDeviation(const [], 0), 0);
    });

    test('returns 0 for constant values', () {
      expect(TrendsAnalytics.standardDeviation([10, 10, 10], 10), 0);
    });

    test('computes population SD for known values', () {
      // values 2,4,4,4,5,5,7,9 — mean 5, pop SD = 2
      final values = [2, 4, 4, 4, 5, 5, 7, 9];
      final sd = TrendsAnalytics.standardDeviation(values, 5);
      expect(sd, closeTo(2.0, 1e-9));
    });
  });

  group('calculateStatistics', () {
    test('computes mean/min/max/SD for a small set', () {
      final now = DateTime(2026, 1, 1);
      final readings = [
        _r(ts: now, sys: 120, dia: 80),
        _r(ts: now.add(const Duration(days: 1)), sys: 130, dia: 85),
        _r(ts: now.add(const Duration(days: 2)), sys: 140, dia: 90),
      ];

      final s = TrendsAnalytics.calculateStatistics(readings);
      expect(s.totalReadings, 3);
      expect(s.systolicAverage, closeTo(130, 1e-9));
      expect(s.diastolicAverage, closeTo(85, 1e-9));
      expect(s.systolicMin, 120);
      expect(s.systolicMax, 140);
      expect(s.diastolicMin, 80);
      expect(s.diastolicMax, 90);
      // sys SD: mean 130, deviations -10,0,10 → sqrt(200/3)
      expect(
        s.standardDeviationSystolic,
        closeTo(math.sqrt(200 / 3), 1e-9),
      );
    });
  });

  group('analyzeTrend', () {
    test('returns insufficient when < 3 readings', () {
      final now = DateTime(2026, 1, 1);
      final readings = [
        _r(ts: now, sys: 120, dia: 80),
        _r(ts: now.add(const Duration(days: 1)), sys: 130, dia: 85),
      ];
      expect(
        TrendsAnalytics.analyzeTrend(readings),
        TrendDirection.insufficient,
      );
    });

    test('detects increasing trend even when passed newest-first', () {
      final base = DateTime(2026, 1, 1);
      // Chronologically: 115, 118, 120, 135, 140, 142 → clearly up
      final chronological = [
        _r(ts: base, sys: 115, dia: 75),
        _r(ts: base.add(const Duration(days: 1)), sys: 118, dia: 76),
        _r(ts: base.add(const Duration(days: 2)), sys: 120, dia: 78),
        _r(ts: base.add(const Duration(days: 3)), sys: 135, dia: 85),
        _r(ts: base.add(const Duration(days: 4)), sys: 140, dia: 88),
        _r(ts: base.add(const Duration(days: 5)), sys: 142, dia: 90),
      ];
      final newestFirst = chronological.reversed.toList();
      expect(
        TrendsAnalytics.analyzeTrend(newestFirst),
        TrendDirection.increasing,
      );
    });

    test('detects decreasing trend', () {
      final base = DateTime(2026, 1, 1);
      final chronological = [
        _r(ts: base, sys: 150, dia: 95),
        _r(ts: base.add(const Duration(days: 1)), sys: 148, dia: 94),
        _r(ts: base.add(const Duration(days: 2)), sys: 145, dia: 92),
        _r(ts: base.add(const Duration(days: 3)), sys: 130, dia: 85),
        _r(ts: base.add(const Duration(days: 4)), sys: 125, dia: 82),
        _r(ts: base.add(const Duration(days: 5)), sys: 122, dia: 80),
      ];
      expect(
        TrendsAnalytics.analyzeTrend(chronological.reversed.toList()),
        TrendDirection.decreasing,
      );
    });

    test('detects stable trend when diff within threshold', () {
      final base = DateTime(2026, 1, 1);
      final readings = [
        _r(ts: base, sys: 120, dia: 80),
        _r(ts: base.add(const Duration(days: 1)), sys: 122, dia: 81),
        _r(ts: base.add(const Duration(days: 2)), sys: 121, dia: 80),
        _r(ts: base.add(const Duration(days: 3)), sys: 123, dia: 81),
      ];
      expect(
        TrendsAnalytics.analyzeTrend(readings),
        TrendDirection.stable,
      );
    });
  });

  group('categoryDistribution', () {
    test('returns empty for empty list', () {
      expect(TrendsAnalytics.categoryDistribution(const []), isEmpty);
    });

    test('counts and percentages sum to 100', () {
      final now = DateTime(2026, 1, 1);
      final readings = [
        _r(ts: now, sys: 110, dia: 70, category: BPCategory.normal),
        _r(ts: now, sys: 112, dia: 72, category: BPCategory.normal),
        _r(ts: now, sys: 135, dia: 85, category: BPCategory.hypertensionStage1),
        _r(ts: now, sys: 145, dia: 95, category: BPCategory.hypertensionStage2),
      ];
      final dist = TrendsAnalytics.categoryDistribution(readings);
      final total = dist.fold<double>(0, (acc, d) => acc + d.percentage);
      expect(total, closeTo(100.0, 1e-9));

      final normal = dist.firstWhere((d) => d.category == BPCategory.normal);
      expect(normal.count, 2);
      expect(normal.percentage, closeTo(50.0, 1e-9));
    });
  });

  group('aggregateByDay', () {
    test('groups readings sharing a calendar day and averages them', () {
      final d1 = DateTime(2026, 1, 1, 8);
      final d1b = DateTime(2026, 1, 1, 20);
      final d2 = DateTime(2026, 1, 2, 9);
      final out = TrendsAnalytics.aggregateByDay([
        _r(ts: d1, sys: 120, dia: 80),
        _r(ts: d1b, sys: 130, dia: 90),
        _r(ts: d2, sys: 140, dia: 88),
      ]);
      expect(out.length, 2);
      expect(out[0].period, DateTime(2026, 1, 1));
      expect(out[0].averageSystolic, closeTo(125, 1e-9));
      expect(out[0].averageDiastolic, closeTo(85, 1e-9));
      expect(out[0].readingCount, 2);
      expect(out[1].period, DateTime(2026, 1, 2));
      expect(out[1].readingCount, 1);
    });
  });

  group('aggregateByWeek', () {
    test('anchors buckets to Monday of each ISO week', () {
      // 2026-01-05 is a Monday, 2026-01-07 Wed → same bucket (Mon 2026-01-05)
      // 2026-01-12 Mon → new bucket
      final out = TrendsAnalytics.aggregateByWeek([
        _r(ts: DateTime(2026, 1, 5, 10), sys: 120, dia: 80),
        _r(ts: DateTime(2026, 1, 7, 10), sys: 130, dia: 90),
        _r(ts: DateTime(2026, 1, 12, 10), sys: 140, dia: 88),
      ]);
      expect(out.length, 2);
      expect(out[0].period, DateTime(2026, 1, 5));
      expect(out[0].readingCount, 2);
      expect(out[1].period, DateTime(2026, 1, 12));
    });

    test('Sunday reading anchors to previous Monday', () {
      // 2026-01-11 is a Sunday → bucket Monday 2026-01-05
      final out = TrendsAnalytics.aggregateByWeek([
        _r(ts: DateTime(2026, 1, 11, 10), sys: 120, dia: 80),
      ]);
      expect(out.single.period, DateTime(2026, 1, 5));
    });
  });

  group('aggregateByMonth', () {
    test('groups readings by calendar month', () {
      final out = TrendsAnalytics.aggregateByMonth([
        _r(ts: DateTime(2026, 1, 5), sys: 120, dia: 80),
        _r(ts: DateTime(2026, 1, 25), sys: 130, dia: 82),
        _r(ts: DateTime(2026, 2, 3), sys: 140, dia: 90),
      ]);
      expect(out.length, 2);
      expect(out[0].period, DateTime(2026, 1, 1));
      expect(out[0].readingCount, 2);
      expect(out[1].period, DateTime(2026, 2, 1));
      expect(out[1].readingCount, 1);
    });
  });

  group('summarize', () {
    test('returns a non-empty string for every direction', () {
      for (final d in TrendDirection.values) {
        expect(TrendsAnalytics.summarize(d), isNotEmpty);
      }
    });
  });
}
