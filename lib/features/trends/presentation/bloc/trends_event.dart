import 'package:equatable/equatable.dart';
import 'package:arteria/features/trends/domain/entities/time_range.dart';
import 'package:arteria/features/trends/domain/entities/chart_config.dart';

/// Base class for all trends events
abstract class TrendsEvent extends Equatable {
  const TrendsEvent();

  @override
  List<Object> get props => [];
}

/// Event to load trends data
class LoadTrendsData extends TrendsEvent {
  final TimeRange timeRange;
  final ViewMode viewMode;

  const LoadTrendsData({required this.timeRange, required this.viewMode});

  @override
  List<Object> get props => [timeRange, viewMode];
}

/// Event to refresh trends data
class RefreshTrendsData extends TrendsEvent {
  final TimeRange timeRange;
  final ViewMode viewMode;

  const RefreshTrendsData({required this.timeRange, required this.viewMode});

  @override
  List<Object> get props => [timeRange, viewMode];
}

/// Event to change time range
class ChangeTimeRange extends TrendsEvent {
  final TimeRange newTimeRange;

  const ChangeTimeRange(this.newTimeRange);

  @override
  List<Object> get props => [newTimeRange];
}

/// Event to change view mode
class ChangeViewMode extends TrendsEvent {
  final ViewMode newViewMode;

  const ChangeViewMode(this.newViewMode);

  @override
  List<Object> get props => [newViewMode];
}

/// Event to change chart type
class ChangeChartType extends TrendsEvent {
  final ChartType newChartType;

  const ChangeChartType(this.newChartType);

  @override
  List<Object> get props => [newChartType];
}

/// Event to export trends data
class ExportTrendsData extends TrendsEvent {
  final ExportFormat format;
  final TimeRange timeRange;

  const ExportTrendsData({required this.format, required this.timeRange});

  @override
  List<Object> get props => [format, timeRange];
}

/// Event to save chart configuration
class SaveChartConfig extends TrendsEvent {
  final ChartConfig config;

  const SaveChartConfig(this.config);

  @override
  List<Object> get props => [config];
}

/// Event to toggle chart features
class ToggleChartFeature extends TrendsEvent {
  final ChartFeature feature;

  const ToggleChartFeature(this.feature);

  @override
  List<Object> get props => [feature];
}

/// Event to reset to default settings
class ResetToDefaults extends TrendsEvent {
  const ResetToDefaults();

  @override
  List<Object> get props => [];
}

/// Chart features that can be toggled
enum ChartFeature {
  grid,
  annotations,
  averageLine,
  animation,
  legend;

  String get displayName {
    switch (this) {
      case ChartFeature.grid:
        return 'Grid';
      case ChartFeature.annotations:
        return 'Annotations';
      case ChartFeature.averageLine:
        return 'Average Line';
      case ChartFeature.animation:
        return 'Animation';
      case ChartFeature.legend:
        return 'Legend';
    }
  }
}
