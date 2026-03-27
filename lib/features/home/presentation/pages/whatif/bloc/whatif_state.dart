import 'package:equatable/equatable.dart';

/// State for What-If Simulator BLoC
class WhatIfState extends Equatable {
  final WhatIfStatus status;
  final Map<String, dynamic> baselineProfile;
  final Map<String, double> modifications;
  final double baselineRisk;
  final double projectedRisk;
  final String? selectedScenarioId;
  final List<WhatIfScenario> availableScenarios;
  final List<SliderConfig> sliderConfigs;
  final String? errorMessage;
  final ProjectionResult? projection;

  const WhatIfState({
    this.status = WhatIfStatus.initial,
    this.baselineProfile = const {},
    this.modifications = const {},
    this.baselineRisk = 0.0,
    this.projectedRisk = 0.0,
    this.selectedScenarioId,
    this.availableScenarios = const [],
    this.sliderConfigs = const [],
    this.errorMessage,
    this.projection,
  });

  /// Get risk reduction percentage
  double get riskReduction => baselineRisk - projectedRisk;

  /// Get relative improvement as percentage
  double get relativeImprovement =>
      baselineRisk > 0 ? (riskReduction / baselineRisk) * 100 : 0;

  /// Get risk level label
  String get baselineRiskLevel => _classifyRisk(baselineRisk);
  String get projectedRiskLevel => _classifyRisk(projectedRisk);

  String _classifyRisk(double prob) {
    if (prob < 0.3) return 'Low';
    if (prob < 0.6) return 'Moderate';
    return 'High';
  }

  WhatIfState copyWith({
    WhatIfStatus? status,
    Map<String, dynamic>? baselineProfile,
    Map<String, double>? modifications,
    double? baselineRisk,
    double? projectedRisk,
    String? selectedScenarioId,
    List<WhatIfScenario>? availableScenarios,
    List<SliderConfig>? sliderConfigs,
    String? errorMessage,
    ProjectionResult? projection,
  }) {
    return WhatIfState(
      status: status ?? this.status,
      baselineProfile: baselineProfile ?? this.baselineProfile,
      modifications: modifications ?? this.modifications,
      baselineRisk: baselineRisk ?? this.baselineRisk,
      projectedRisk: projectedRisk ?? this.projectedRisk,
      selectedScenarioId: selectedScenarioId ?? this.selectedScenarioId,
      availableScenarios: availableScenarios ?? this.availableScenarios,
      sliderConfigs: sliderConfigs ?? this.sliderConfigs,
      errorMessage: errorMessage,
      projection: projection,
    );
  }

  @override
  List<Object?> get props => [
        status,
        baselineProfile,
        modifications,
        baselineRisk,
        projectedRisk,
        selectedScenarioId,
        availableScenarios,
        sliderConfigs,
        errorMessage,
        projection,
      ];
}

enum WhatIfStatus {
  initial,
  loading,
  ready,
  calculating,
  error,
}

/// Represents a preset lifestyle scenario
class WhatIfScenario {
  final String id;
  final String name;
  final String description;
  final String icon;
  final Map<String, double> modifications;
  final double expectedBpChange;

  const WhatIfScenario({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.modifications,
    required this.expectedBpChange,
  });
}

/// Configuration for interactive sliders
class SliderConfig {
  final String feature;
  final String label;
  final String description;
  final String icon;
  final double min;
  final double max;
  final double defaultValue;
  final String unit;
  final bool isReduction; // True if lower = better

  const SliderConfig({
    required this.feature,
    required this.label,
    required this.description,
    required this.icon,
    required this.min,
    required this.max,
    required this.defaultValue,
    required this.unit,
    this.isReduction = false,
  });
}

/// Result of a what-if projection
class ProjectionResult {
  final double riskReduction;
  final double relativeImprovement;
  final int estimatedSystolicChange;
  final String timeframe;
  final String recommendation;
  final List<String> tips;

  const ProjectionResult({
    required this.riskReduction,
    required this.relativeImprovement,
    required this.estimatedSystolicChange,
    required this.timeframe,
    required this.recommendation,
    required this.tips,
  });
}
