import 'package:equatable/equatable.dart';

/// Chart configuration for different visualization types
class ChartConfig extends Equatable {
  final ChartType chartType;
  final ViewMode viewMode;
  final bool showGrid;
  final bool showAnnotations;
  final bool showAverageLine;
  final ChartTheme theme;
  final Duration animationDuration;

  const ChartConfig({
    required this.chartType,
    required this.viewMode,
    this.showGrid = true,
    this.showAnnotations = false,
    this.showAverageLine = false,
    this.theme = ChartTheme.defaultTheme,
    this.animationDuration = const Duration(milliseconds: 300),
  });

  /// Default configuration for simple view
  factory ChartConfig.simpleView() {
    return const ChartConfig(
      chartType: ChartType.line,
      viewMode: ViewMode.simple,
      showGrid: false,
      showAnnotations: true,
      showAverageLine: true,
      theme: ChartTheme.simple,
      animationDuration: Duration(milliseconds: 500),
    );
  }

  /// Default configuration for medical view
  factory ChartConfig.medicalView() {
    return const ChartConfig(
      chartType: ChartType.line,
      viewMode: ViewMode.medical,
      showGrid: true,
      showAnnotations: true,
      showAverageLine: false,
      theme: ChartTheme.medical,
      animationDuration: Duration(milliseconds: 200),
    );
  }

  /// Default configuration for caregiver view
  factory ChartConfig.caregiverView() {
    return const ChartConfig(
      chartType: ChartType.combo,
      viewMode: ViewMode.caregiver,
      showGrid: true,
      showAnnotations: true,
      showAverageLine: true,
      theme: ChartTheme.caregiver,
      animationDuration: Duration(milliseconds: 300),
    );
  }

  ChartConfig copyWith({
    ChartType? chartType,
    ViewMode? viewMode,
    bool? showGrid,
    bool? showAnnotations,
    bool? showAverageLine,
    ChartTheme? theme,
    Duration? animationDuration,
  }) {
    return ChartConfig(
      chartType: chartType ?? this.chartType,
      viewMode: viewMode ?? this.viewMode,
      showGrid: showGrid ?? this.showGrid,
      showAnnotations: showAnnotations ?? this.showAnnotations,
      showAverageLine: showAverageLine ?? this.showAverageLine,
      theme: theme ?? this.theme,
      animationDuration: animationDuration ?? this.animationDuration,
    );
  }

  @override
  List<Object> get props => [
    chartType,
    viewMode,
    showGrid,
    showAnnotations,
    showAverageLine,
    theme,
    animationDuration,
  ];

  @override
  String toString() {
    return 'ChartConfig(chartType: $chartType, viewMode: $viewMode, theme: $theme)';
  }
}

/// Available chart types
enum ChartType {
  line,
  bar,
  area,
  combo,
  distribution,
  progress;

  String get displayName {
    switch (this) {
      case ChartType.line:
        return 'Line Chart';
      case ChartType.bar:
        return 'Bar Chart';
      case ChartType.area:
        return 'Area Chart';
      case ChartType.combo:
        return 'Combo Chart';
      case ChartType.distribution:
        return 'Distribution';
      case ChartType.progress:
        return 'Progress';
    }
  }

  /// Check if chart supports multiple data series
  bool get supportsMultipleSeries {
    return this == ChartType.line ||
        this == ChartType.bar ||
        this == ChartType.combo ||
        this == ChartType.area;
  }

  /// Check if chart is suitable for elderly users
  bool get isElderlyFriendly {
    return this == ChartType.line ||
        this == ChartType.bar ||
        this == ChartType.progress;
  }
}

/// View modes for different user types
enum ViewMode {
  simple, // Elderly-friendly
  medical, // Doctor-focused
  caregiver; // Caregiver-focused

  String get displayName {
    switch (this) {
      case ViewMode.simple:
        return 'Simple View';
      case ViewMode.medical:
        return 'Medical View';
      case ViewMode.caregiver:
        return 'Caregiver View';
    }
  }

  /// Check if view requires detailed medical information
  bool get isMedicalView {
    return this == ViewMode.medical;
  }

  /// Check if view requires simplified interface
  bool get isSimpleView {
    return this == ViewMode.simple;
  }

  /// Check if view requires summary focus
  bool get isCaregiverView {
    return this == ViewMode.caregiver;
  }
}

/// Chart themes for different contexts
enum ChartTheme {
  defaultTheme,
  simple,
  medical,
  caregiver;

  String get displayName {
    switch (this) {
      case ChartTheme.defaultTheme:
        return 'Default';
      case ChartTheme.simple:
        return 'Simple';
      case ChartTheme.medical:
        return 'Medical';
      case ChartTheme.caregiver:
        return 'Caregiver';
    }
  }

  /// Check if theme is high contrast
  bool get isHighContrast {
    return this == ChartTheme.simple;
  }

  /// Check if theme has larger elements
  bool get hasLargerElements {
    return this == ChartTheme.simple;
  }

  /// Check if theme uses medical color palette
  bool get usesMedicalColors {
    return this == ChartTheme.medical;
  }
}

/// Chart export formats
enum ExportFormat {
  pdf,
  csv,
  png,
  json;

  String get displayName {
    switch (this) {
      case ExportFormat.pdf:
        return 'PDF Report';
      case ExportFormat.csv:
        return 'CSV Data';
      case ExportFormat.png:
        return 'Image';
      case ExportFormat.json:
        return 'JSON Data';
    }
  }

  String get fileExtension {
    switch (this) {
      case ExportFormat.pdf:
        return '.pdf';
      case ExportFormat.csv:
        return '.csv';
      case ExportFormat.png:
        return '.png';
      case ExportFormat.json:
        return '.json';
    }
  }

  String get mimeType {
    switch (this) {
      case ExportFormat.pdf:
        return 'application/pdf';
      case ExportFormat.csv:
        return 'text/csv';
      case ExportFormat.png:
        return 'image/png';
      case ExportFormat.json:
        return 'application/json';
    }
  }
}
