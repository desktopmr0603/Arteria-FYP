import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:arteria/features/trends/domain/entities/trend_data.dart';
import 'package:arteria/features/trends/domain/entities/time_range.dart';
import 'package:arteria/features/trends/domain/entities/chart_config.dart';
import 'package:arteria/features/trends/domain/repositories/trends_repository.dart';
import 'package:arteria/features/trends/data/models/trend_data_model.dart';

/// Implementation of TrendsRepository using Firestore
class TrendsRepositoryImpl implements TrendsRepository {
  final FirebaseFirestore _firestore;

  TrendsRepositoryImpl({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<List<TrendData>> getTrendData({
    required String userId,
    required TimeRange timeRange,
  }) async {
    try {
      final userReadingsRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('readings')
          .where(
            'date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(timeRange.start),
          )
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(timeRange.end))
          .orderBy('date', descending: true);

      final snapshot = await userReadingsRef.get();

      return snapshot.docs.map((doc) {
        final model = TrendDataModel.fromFirestore(
          documentId: doc.id,
          data: doc.data(),
          userId: userId,
        );
        return model.toEntity();
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch trend data: $e');
    }
  }

  @override
  Future<TrendAnalysis> getTrendAnalysis({
    required String userId,
    required TimeRange timeRange,
  }) async {
    try {
      final trendData = await getTrendData(
        userId: userId,
        timeRange: timeRange,
      );

      if (trendData.isEmpty) {
        return TrendAnalysis(
          rawData: [],
          statistics: TrendStatistics(
            totalReadings: 0,
            systolicAverage: 0,
            diastolicAverage: 0,
            systolicMin: 0,
            systolicMax: 0,
            diastolicMin: 0,
            diastolicMax: 0,
            standardDeviationSystolic: 0,
            standardDeviationDiastolic: 0,
          ),
          direction: TrendDirection.insufficient,
          averageSystolic: 0,
          averageDiastolic: 0,
          categoryDistribution: [],
          lastReadingDate: null,
          hasEnoughData: false,
          summary: 'No data available for analysis',
        );
      }

      final statistics = _calculateStatistics(trendData);
      final direction = _analyzeTrend(trendData);
      final categoryDistribution = _calculateCategoryDistribution(trendData);

      return TrendAnalysis(
        rawData: trendData,
        statistics: statistics,
        direction: direction,
        averageSystolic: statistics.systolicAverage,
        averageDiastolic: statistics.diastolicAverage,
        categoryDistribution: categoryDistribution,
        lastReadingDate: trendData.first.timestamp,
        hasEnoughData: true,
        summary: _generateSummary(trendData, statistics, direction),
      );
    } catch (e) {
      throw Exception('Failed to analyze trends: $e');
    }
  }

  @override
  Future<List<AggregatedTrendData>> getAggregatedData({
    required String userId,
    required TimeRange timeRange,
    required AggregationType aggregationType,
  }) async {
    try {
      final trendData = await getTrendData(
        userId: userId,
        timeRange: timeRange,
      );
      return _aggregateData(trendData, aggregationType);
    } catch (e) {
      throw Exception('Failed to get aggregated data: $e');
    }
  }

  @override
  Future<ExportResult> exportTrendData({
    required String userId,
    required TimeRange timeRange,
    required ExportFormat format,
  }) async {
    try {
      // For now, we'll create a placeholder export result
      // In a real implementation, this would handle actual file creation
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename =
          'bp_trends_${timeRange.type.name}_$timestamp${format.fileExtension}';

      return ExportResult(
        filePath: '/exports/$filename',
        fileName: filename,
        format: format,
        fileSize: 1024, // Placeholder
        exportDate: DateTime.now(),
      );
    } catch (e) {
      throw Exception('Failed to export trends data: $e');
    }
  }

  @override
  Stream<List<TrendData>> getTrendDataStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('readings')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final model = TrendDataModel.fromFirestore(
              documentId: doc.id,
              data: doc.data(),
              userId: userId,
            );
            return model.toEntity();
          }).toList();
        });
  }

  @override
  Future<void> saveChartConfig({
    required String userId,
    required ChartConfig config,
  }) async {
    try {
      final model = ChartConfigModel.fromEntity(config, userId);
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('chartConfigs')
          .doc(model.id)
          .set(model.toFirestore());
    } catch (e) {
      throw Exception('Failed to save chart config: $e');
    }
  }

  @override
  Future<ChartConfig> getChartConfig(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('chartConfigs')
          .orderBy('updatedAt', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        // Return default config if none exists
        return ChartConfig.simpleView();
      }

      final doc = snapshot.docs.first;
      final model = ChartConfigModel.fromFirestore(
        documentId: doc.id,
        data: doc.data(),
        userId: userId,
      );
      return model.toEntity();
    } catch (e) {
      throw Exception('Failed to get chart config: $e');
    }
  }

  /// Calculate statistics from trend data
  TrendStatistics _calculateStatistics(List<TrendData> data) {
    final systolicValues = data.map((d) => d.systolic).toList();
    final diastolicValues = data.map((d) => d.diastolic).toList();

    final avgSystolic =
        systolicValues.reduce((a, b) => a + b) / systolicValues.length;
    final avgDiastolic =
        diastolicValues.reduce((a, b) => a + b) / diastolicValues.length;

    final stdDevSystolic = _calculateStandardDeviation(
      systolicValues,
      avgSystolic,
    );
    final stdDevDiastolic = _calculateStandardDeviation(
      diastolicValues,
      avgDiastolic,
    );

    return TrendStatistics(
      totalReadings: data.length,
      systolicAverage: avgSystolic,
      diastolicAverage: avgDiastolic,
      systolicMin: systolicValues.reduce((a, b) => a < b ? a : b),
      systolicMax: systolicValues.reduce((a, b) => a > b ? a : b),
      diastolicMin: diastolicValues.reduce((a, b) => a < b ? a : b),
      diastolicMax: diastolicValues.reduce((a, b) => a > b ? a : b),
      standardDeviationSystolic: stdDevSystolic,
      standardDeviationDiastolic: stdDevDiastolic,
    );
  }

  /// Calculate standard deviation
  double _calculateStandardDeviation(List<int> values, double mean) {
    final squaredDiffs = values.map((v) => (v - mean) * (v - mean)).toList();
    final avgSquaredDiff = squaredDiffs.reduce((a, b) => a + b) / values.length;
    return avgSquaredDiff > 0 ? sqrt(avgSquaredDiff) : 0;
  }

  /// Analyze trend direction
  TrendDirection _analyzeTrend(List<TrendData> data) {
    if (data.length < 3) return TrendDirection.insufficient;

    // Split data into two halves
    final midPoint = data.length ~/ 2;
    final firstHalf = data.sublist(0, midPoint);
    final secondHalf = data.sublist(midPoint);

    final firstHalfAvg =
        firstHalf.map((d) => d.systolic).reduce((a, b) => a + b) /
        firstHalf.length;
    final secondHalfAvg =
        secondHalf.map((d) => d.systolic).reduce((a, b) => a + b) /
        secondHalf.length;

    final difference = secondHalfAvg - firstHalfAvg;
    final threshold = 5.0; // 5 mmHg threshold for significant change

    if (difference > threshold) {
      return TrendDirection.increasing;
    } else if (difference < -threshold) {
      return TrendDirection.decreasing;
    } else {
      return TrendDirection.stable;
    }
  }

  /// Calculate category distribution
  List<BPCategoryDistribution> _calculateCategoryDistribution(
    List<TrendData> data,
  ) {
    final categoryCounts = <BPCategory, int>{};

    for (final reading in data) {
      categoryCounts[reading.category] =
          (categoryCounts[reading.category] ?? 0) + 1;
    }

    return categoryCounts.entries.map((entry) {
      final percentage = (entry.value / data.length) * 100;
      return BPCategoryDistribution(
        category: entry.key,
        count: entry.value,
        percentage: percentage,
      );
    }).toList();
  }

  /// Generate analysis summary
  String _generateSummary(
    List<TrendData> data,
    TrendStatistics statistics,
    TrendDirection direction,
  ) {
    switch (direction) {
      case TrendDirection.increasing:
        return 'Your blood pressure has been trending upward recently. Consider lifestyle changes or consulting your doctor.';
      case TrendDirection.decreasing:
        return 'Your blood pressure has been trending downward recently. Keep up the good work!';
      case TrendDirection.stable:
        return 'Your blood pressure has remained stable. Continue monitoring regularly.';
      case TrendDirection.insufficient:
        return 'Insufficient data for trend analysis. Continue regular readings.';
    }
  }

  /// Aggregate data by time period
  List<AggregatedTrendData> _aggregateData(
    List<TrendData> data,
    AggregationType aggregationType,
  ) {
    switch (aggregationType) {
      case AggregationType.daily:
        return _aggregateByDay(data);
      case AggregationType.weekly:
        return _aggregateByWeek(data);
      case AggregationType.monthly:
        return _aggregateByMonth(data);
    }
  }

  /// Aggregate data by day
  List<AggregatedTrendData> _aggregateByDay(List<TrendData> data) {
    final groupedData = <DateTime, List<TrendData>>{};

    for (final reading in data) {
      final day = DateTime(
        reading.timestamp.year,
        reading.timestamp.month,
        reading.timestamp.day,
      );
      groupedData[day] = (groupedData[day] ?? [])..add(reading);
    }

    return groupedData.entries.map((entry) {
      final dayData = entry.value;
      final avgSystolic =
          dayData.map((d) => d.systolic).reduce((a, b) => a + b) /
          dayData.length;
      final avgDiastolic =
          dayData.map((d) => d.diastolic).reduce((a, b) => a + b) /
          dayData.length;

      return AggregatedTrendData(
        period: entry.key,
        averageSystolic: avgSystolic,
        averageDiastolic: avgDiastolic,
        readingCount: dayData.length,
        averageCategory: TrendDataModel.classifyBP(
          avgSystolic.round(),
          avgDiastolic.round(),
        ),
      );
    }).toList();
  }

  /// Aggregate data by week
  List<AggregatedTrendData> _aggregateByWeek(List<TrendData> data) {
    // Similar implementation for weekly aggregation
    // For now, return daily aggregation
    return _aggregateByDay(data);
  }

  /// Aggregate data by month
  List<AggregatedTrendData> _aggregateByMonth(List<TrendData> data) {
    // Similar implementation for monthly aggregation
    // For now, return daily aggregation
    return _aggregateByDay(data);
  }
}
