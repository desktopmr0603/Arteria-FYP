import 'package:arteria/features/trends/domain/entities/trend_data.dart';
import 'package:arteria/features/trends/domain/entities/time_range.dart';
import 'package:arteria/features/trends/domain/entities/chart_config.dart';

/// Repository interface for trends data
abstract class TrendsRepository {
  /// Get trend data for a specific time range
  ///
  /// [userId] - The user ID to fetch data for
  /// [timeRange] - The time range to filter data
  /// Returns list of trend data, throws exception on error
  Future<List<TrendData>> getTrendData({
    required String userId,
    required TimeRange timeRange,
  });

  /// Get trend data with statistics and analysis
  ///
  /// [userId] - The user ID to fetch data for
  /// [timeRange] - The time range to filter data
  /// Returns trend analysis, throws exception on error
  Future<TrendAnalysis> getTrendAnalysis({
    required String userId,
    required TimeRange timeRange,
  });

  /// Get aggregated data for charts
  ///
  /// [userId] - The user ID to fetch data for
  /// [timeRange] - The time range to filter data
  /// [aggregationType] - Type of aggregation (daily, weekly, monthly)
  /// Returns aggregated data, throws exception on error
  Future<List<AggregatedTrendData>> getAggregatedData({
    required String userId,
    required TimeRange timeRange,
    required AggregationType aggregationType,
  });

  /// Export trend data in specified format
  ///
  /// [userId] - The user ID to fetch data for
  /// [timeRange] - The time range to export
  /// [format] - Export format (PDF, CSV, PNG, JSON)
  /// Returns export result, throws exception on error
  Future<ExportResult> exportTrendData({
    required String userId,
    required TimeRange timeRange,
    required ExportFormat format,
  });

  /// Get real-time trend data stream
  ///
  /// [userId] - The user ID to stream data for
  /// Returns stream of trend data updates
  Stream<List<TrendData>> getTrendDataStream(String userId);

  /// Save chart configuration
  ///
  /// [userId] - The user ID
  /// [config] - Chart configuration to save
  /// Returns success, throws exception on error
  Future<void> saveChartConfig({
    required String userId,
    required ChartConfig config,
  });

  /// Get saved chart configuration
  ///
  /// [userId] - The user ID
  /// Returns chart config, throws exception on error
  Future<ChartConfig> getChartConfig(String userId);
}

/// Trend analysis result
class TrendAnalysis {
  final List<TrendData> rawData;
  final TrendStatistics statistics;
  final TrendDirection direction;
  final double averageSystolic;
  final double averageDiastolic;
  final List<BPCategoryDistribution> categoryDistribution;
  final DateTime? lastReadingDate;
  final bool hasEnoughData;
  final String summary;

  const TrendAnalysis({
    required this.rawData,
    required this.statistics,
    required this.direction,
    required this.averageSystolic,
    required this.averageDiastolic,
    required this.categoryDistribution,
    this.lastReadingDate,
    required this.hasEnoughData,
    required this.summary,
  });
}

/// Trend statistics
class TrendStatistics {
  final int totalReadings;
  final double systolicAverage;
  final double diastolicAverage;
  final int systolicMin;
  final int systolicMax;
  final int diastolicMin;
  final int diastolicMax;
  final double standardDeviationSystolic;
  final double standardDeviationDiastolic;

  const TrendStatistics({
    required this.totalReadings,
    required this.systolicAverage,
    required this.diastolicAverage,
    required this.systolicMin,
    required this.systolicMax,
    required this.diastolicMin,
    required this.diastolicMax,
    required this.standardDeviationSystolic,
    required this.standardDeviationDiastolic,
  });
}

/// Trend direction
enum TrendDirection {
  increasing,
  decreasing,
  stable,
  insufficient;

  String get displayName {
    switch (this) {
      case TrendDirection.increasing:
        return 'Increasing';
      case TrendDirection.decreasing:
        return 'Decreasing';
      case TrendDirection.stable:
        return 'Stable';
      case TrendDirection.insufficient:
        return 'Insufficient Data';
    }
  }

  /// Get trend indicator color
  String get colorCode {
    switch (this) {
      case TrendDirection.increasing:
        return '#F44336'; // Red
      case TrendDirection.decreasing:
        return '#4CAF50'; // Green
      case TrendDirection.stable:
        return '#2196F3'; // Blue
      case TrendDirection.insufficient:
        return '#9E9E9E'; // Grey
    }
  }
}

/// Blood pressure category distribution
class BPCategoryDistribution {
  final BPCategory category;
  final int count;
  final double percentage;

  const BPCategoryDistribution({
    required this.category,
    required this.count,
    required this.percentage,
  });
}

/// Aggregated trend data
class AggregatedTrendData {
  final DateTime period;
  final double averageSystolic;
  final double averageDiastolic;
  final int readingCount;
  final BPCategory averageCategory;

  const AggregatedTrendData({
    required this.period,
    required this.averageSystolic,
    required this.averageDiastolic,
    required this.readingCount,
    required this.averageCategory,
  });

  /// Get formatted period display
  String get formattedPeriod {
    switch (period.day) {
      case 1:
        return '${period.month}/${period.year}';
      default:
        return '${period.day}/${period.month}';
    }
  }

  /// Get formatted BP reading
  String get formattedReading =>
      '${averageSystolic.round()}/${averageDiastolic.round()} mmHg';
}

/// Data aggregation types
enum AggregationType {
  daily,
  weekly,
  monthly;

  String get displayName {
    switch (this) {
      case AggregationType.daily:
        return 'Daily';
      case AggregationType.weekly:
        return 'Weekly';
      case AggregationType.monthly:
        return 'Monthly';
    }
  }
}

/// Export result
class ExportResult {
  final String filePath;
  final String fileName;
  final ExportFormat format;
  final int fileSize;
  final DateTime exportDate;

  const ExportResult({
    required this.filePath,
    required this.fileName,
    required this.format,
    required this.fileSize,
    required this.exportDate,
  });
}
