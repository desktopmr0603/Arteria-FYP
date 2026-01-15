import 'package:arteria/features/trends/domain/entities/trend_data.dart';
import 'package:arteria/features/trends/domain/entities/time_range.dart';
import 'package:arteria/features/trends/domain/entities/chart_config.dart';
import 'package:arteria/features/trends/domain/repositories/trends_repository.dart';

/// Parameters for exporting trends data use case
class ExportTrendsParams {
  final String userId;
  final TimeRange timeRange;
  final ExportFormat format;
  final List<TrendData>? trendData; // Optional pre-fetched data

  const ExportTrendsParams({
    required this.userId,
    required this.timeRange,
    required this.format,
    this.trendData,
  });
}

/// Use case for exporting trends data
class ExportTrendsUseCase {
  final TrendsRepository _repository;

  ExportTrendsUseCase(this._repository);

  /// Execute export use case
  ///
  /// [params] - Parameters for exporting data
  /// Returns [ExportResult] with export information
  Future<ExportResult> call(ExportTrendsParams params) async {
    try {
      // Use provided trend data or fetch from repository
      final data =
          params.trendData ??
          await _repository.getTrendData(
            userId: params.userId,
            timeRange: params.timeRange,
          );

      // Validate data for export
      if (data.isEmpty) {
        throw Exception(
          'No data available for export in the specified time range',
        );
      }

      // Export data based on format
      final result = await _repository.exportTrendData(
        userId: params.userId,
        timeRange: params.timeRange,
        format: params.format,
      );

      return result;
    } catch (e) {
      throw Exception('Failed to export trends data: $e');
    }
  }

}
