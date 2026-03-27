import 'package:equatable/equatable.dart';

/// Events for What-If Simulator BLoC
abstract class WhatIfEvent extends Equatable {
  const WhatIfEvent();

  @override
  List<Object?> get props => [];
}

/// Initialize the simulator with user profile
class InitializeWhatIf extends WhatIfEvent {
  final Map<String, dynamic> userProfile;

  const InitializeWhatIf({required this.userProfile});

  @override
  List<Object?> get props => [userProfile];
}

/// Update a slider value
class UpdateSlider extends WhatIfEvent {
  final String feature;
  final double value;

  const UpdateSlider({required this.feature, required this.value});

  @override
  List<Object?> get props => [feature, value];
}

/// Select a preset scenario
class SelectScenario extends WhatIfEvent {
  final String scenarioId;

  const SelectScenario({required this.scenarioId});

  @override
  List<Object?> get props => [scenarioId];
}

/// Reset all modifications to baseline
class ResetModifications extends WhatIfEvent {
  const ResetModifications();
}

/// Calculate projection with current modifications
class CalculateProjection extends WhatIfEvent {
  const CalculateProjection();
}
