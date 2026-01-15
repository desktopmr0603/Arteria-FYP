import 'package:equatable/equatable.dart';
import 'package:arteria/features/trends/domain/entities/trend_data.dart';
import 'package:arteria/features/trends/domain/entities/chart_config.dart';
import 'package:arteria/features/trends/domain/entities/time_range.dart';
import 'package:arteria/features/trends/domain/repositories/trends_repository.dart';

/// Base class for all trends states
abstract class TrendsState extends Equatable {
  const TrendsState();

  @override
  List<Object> get props => [];
}

/// Initial state when no data has been loaded
class TrendsInitial extends TrendsState {
  const TrendsInitial();

  @override
  String toString() => 'TrendsInitial';
}

/// Loading state while fetching data
class TrendsLoading extends TrendsState {
  final String? message;

  const TrendsLoading({this.message});

  @override
  List<Object> get props => [message ?? ''];

  @override
  String toString() => 'TrendsLoading(message: $message)';
}

/// State when trends data is successfully loaded
class TrendsLoaded extends TrendsState {
  final List<TrendData> trendData;
  final ChartConfig chartConfig;
  final TimeRange selectedTimeRange;
  final ViewMode viewMode;
  final TrendAnalysis analysis;
  final List<AggregatedTrendData> aggregatedData;
  final bool isRefreshing;

  const TrendsLoaded({
    required this.trendData,
    required this.chartConfig,
    required this.selectedTimeRange,
    required this.viewMode,
    required this.analysis,
    required this.aggregatedData,
    this.isRefreshing = false,
  });

  /// Create a copy with updated values
  TrendsLoaded copyWith({
    List<TrendData>? trendData,
    ChartConfig? chartConfig,
    TimeRange? selectedTimeRange,
    ViewMode? viewMode,
    TrendAnalysis? analysis,
    List<AggregatedTrendData>? aggregatedData,
    bool? isRefreshing,
  }) {
    return TrendsLoaded(
      trendData: trendData ?? this.trendData,
      chartConfig: chartConfig ?? this.chartConfig,
      selectedTimeRange: selectedTimeRange ?? this.selectedTimeRange,
      viewMode: viewMode ?? this.viewMode,
      analysis: analysis ?? this.analysis,
      aggregatedData: aggregatedData ?? this.aggregatedData,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }

  @override
  List<Object> get props => [
    trendData,
    chartConfig,
    selectedTimeRange,
    viewMode,
    analysis,
    aggregatedData,
    isRefreshing,
  ];

  @override
  String toString() {
    return 'TrendsLoaded(dataCount: ${trendData.length}, viewMode: $viewMode)';
  }
}

/// Error state when trends operation fails
class TrendsError extends TrendsState {
  final String message;
  final String? technicalDetails;
  final TrendsState? previousState;

  const TrendsError(this.message, {this.technicalDetails, this.previousState});

  @override
  List<Object> get props => [
    message,
    technicalDetails ?? '',
    previousState ?? '',
  ];

  @override
  String toString() => 'TrendsError(message: $message)';
}

/// State when exporting data
class TrendsExporting extends TrendsState {
  final ExportFormat format;
  final String fileName;

  const TrendsExporting({required this.format, required this.fileName});

  @override
  List<Object> get props => [format, fileName, ''];

  @override
  String toString() => 'TrendsExporting(format: $format)';
}

/// State when export is completed
class TrendsExported extends TrendsState {
  final String filePath;
  final String fileName;
  final ExportFormat format;
  final int fileSize;

  const TrendsExported({
    required this.filePath,
    required this.fileName,
    required this.format,
    required this.fileSize,
  });

  @override
  List<Object> get props => [filePath, fileName, format, fileSize];

  @override
  String toString() => 'TrendsExported(fileName: $fileName)';
}

/// State when changing view mode
class TrendsViewModeChanging extends TrendsState {
  final ViewMode newViewMode;
  final ViewMode previousViewMode;

  const TrendsViewModeChanging({
    required this.newViewMode,
    required this.previousViewMode,
  });

  @override
  List<Object> get props => [newViewMode, previousViewMode];

  @override
  String toString() =>
      'TrendsViewModeChanging(from: $previousViewMode, to: $newViewMode)';
}

/// State when changing time range
class TrendsTimeRangeChanging extends TrendsState {
  final TimeRange newTimeRange;
  final TimeRange previousTimeRange;

  const TrendsTimeRangeChanging({
    required this.newTimeRange,
    required this.previousTimeRange,
  });

  @override
  List<Object> get props => [newTimeRange, previousTimeRange];

  @override
  String toString() =>
      'TrendsTimeRangeChanging(from: $previousTimeRange, to: $newTimeRange)';
}

/// State when no data is available
class TrendsNoData extends TrendsState {
  final TimeRange timeRange;
  final String message;

  const TrendsNoData({
    required this.timeRange,
    this.message = 'No data available for the selected time range',
  });

  @override
  List<Object> get props => [timeRange, message];

  @override
  String toString() => 'TrendsNoData(timeRange: $timeRange)';
}

/// State when data is insufficient for analysis
class TrendsInsufficientData extends TrendsState {
  final List<TrendData> availableData;
  final int requiredMinimum;
  final String message;

  const TrendsInsufficientData({
    required this.availableData,
    required this.requiredMinimum,
    this.message = 'Insufficient data for meaningful analysis',
  });

  @override
  List<Object> get props => [availableData, requiredMinimum, message];

  @override
  String toString() =>
      'TrendsInsufficientData(count: ${availableData.length}, required: $requiredMinimum)';
}

/// Extension for state checking
extension TrendsStateExtension on TrendsState {
  /// Check if current state is loading
  bool get isLoading => this is TrendsLoading;

  /// Check if current state is loaded
  bool get isLoaded => this is TrendsLoaded;

  /// Check if current state has error
  bool get hasError => this is TrendsError;

  /// Check if current state is exporting
  bool get isExporting => this is TrendsExporting;

  /// Check if current state has no data
  bool get hasNoData => this is TrendsNoData;

  /// Check if current state has insufficient data
  bool get hasInsufficientData => this is TrendsInsufficientData;

  /// Get loaded state if available
  TrendsLoaded? get asLoaded =>
      this is TrendsLoaded ? this as TrendsLoaded : null;

  /// Get error state if available
  TrendsError? get asError => this is TrendsError ? this as TrendsError : null;

  /// Get message from error state
  String get errorMessage => hasError ? (this as TrendsError).message : '';
}
