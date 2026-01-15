import 'package:arteria/features/trends/domain/entities/trend_data.dart';
import 'package:arteria/features/trends/domain/entities/time_range.dart';
import 'package:arteria/features/trends/domain/entities/chart_config.dart';
import 'package:arteria/features/trends/domain/repositories/trends_repository.dart';

/// Parameters for getting trends data use case
class GetTrendsDataParams {
  final String userId;
  final TimeRange timeRange;
  final ViewMode viewMode;

  const GetTrendsDataParams({
    required this.userId,
    required this.timeRange,
    required this.viewMode,
  });
}

/// Result for getting trends data use case
class GetTrendsDataResult {
  final List<TrendData> trendData;
  final ChartConfig chartConfig;
  final TrendAnalysis analysis;

  const GetTrendsDataResult({
    required this.trendData,
    required this.chartConfig,
    required this.analysis,
  });
}

/// Use case for getting trends data with analysis
class GetTrendsDataUseCase {
  final TrendsRepository _repository;

  GetTrendsDataUseCase(this._repository);

  /// Execute the use case
  ///
  /// [params] - Parameters for getting trends data
  /// Returns [GetTrendsDataResult] with trend data and analysis
  Future<GetTrendsDataResult> call(GetTrendsDataParams params) async {
    try {
      // Get trend data for the specified time range
      final trendData = await _repository.getTrendData(
        userId: params.userId,
        timeRange: params.timeRange,
      );

      // Get trend analysis
      final analysis = await _repository.getTrendAnalysis(
        userId: params.userId,
        timeRange: params.timeRange,
      );

      // Get chart configuration for view mode
      ChartConfig chartConfig;
      switch (params.viewMode) {
        case ViewMode.simple:
          chartConfig = ChartConfig.simpleView();
          break;
        case ViewMode.medical:
          chartConfig = ChartConfig.medicalView();
          break;
        case ViewMode.caregiver:
          chartConfig = ChartConfig.caregiverView();
          break;
      }

      return GetTrendsDataResult(
        trendData: trendData,
        chartConfig: chartConfig,
        analysis: analysis,
      );
    } catch (e) {
      throw Exception('Failed to get trends data: $e');
    }
  }

}
