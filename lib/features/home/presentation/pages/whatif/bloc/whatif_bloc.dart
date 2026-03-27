import 'package:flutter_bloc/flutter_bloc.dart';
import 'whatif_event.dart';
import 'whatif_state.dart';
import '../../../../data/data_sources/bp_predictor_remote_data_source.dart';

/// BLoC for What-If Lifestyle Simulator
///
/// Manages state for interactive lifestyle sliders and scenario simulations.
class WhatIfBloc extends Bloc<WhatIfEvent, WhatIfState> {
  final BPPredictorRemoteDataSource _predictorService;

  WhatIfBloc({required BPPredictorRemoteDataSource predictorService})
    : _predictorService = predictorService,
      super(const WhatIfState()) {
    on<InitializeWhatIf>(_onInitialize);
    on<UpdateSlider>(_onUpdateSlider);
    on<SelectScenario>(_onSelectScenario);
    on<ResetModifications>(_onReset);
    on<CalculateProjection>(_onCalculate);
  }

  /// Predefined lifestyle scenarios based on medical research
  static const List<WhatIfScenario> _scenarios = [
    WhatIfScenario(
      id: 'reduce_sodium_20',
      name: 'Reduce Sodium 20%',
      description: 'Cut ~500mg/day of sodium',
      icon: '🧂',
      modifications: {'sodium_intake': 0.8},
      expectedBpChange: -5,
    ),
    WhatIfScenario(
      id: 'increase_exercise',
      name: 'Exercise 4x/week',
      description: '30 min moderate exercise',
      icon: '🏃',
      modifications: {'physical_activity_score': 2.0, 'sedentary_minutes': 0.7},
      expectedBpChange: -5,
    ),
    WhatIfScenario(
      id: 'quit_smoking',
      name: 'Quit Smoking',
      description: 'Stop smoking completely',
      icon: '🚭',
      modifications: {'smoker_status': 0.0},
      expectedBpChange: -5,
    ),
    WhatIfScenario(
      id: 'reduce_alcohol',
      name: 'Limit Alcohol',
      description: 'Max 1-2 drinks/day',
      icon: '🍷',
      modifications: {'alcohol_use': 0.5},
      expectedBpChange: -4,
    ),
    WhatIfScenario(
      id: 'increase_potassium',
      name: 'More Potassium',
      description: 'Bananas, spinach, avocados',
      icon: '🍌',
      modifications: {'potassium_intake': 1.3},
      expectedBpChange: -4,
    ),
    WhatIfScenario(
      id: 'full_lifestyle',
      name: 'Full Lifestyle Change',
      description: 'Diet + Exercise + Habits',
      icon: '⭐',
      modifications: {
        'sodium_intake': 0.6,
        'potassium_intake': 1.2,
        'physical_activity_score': 2.0,
        'sedentary_minutes': 0.5,
      },
      expectedBpChange: -15,
    ),
  ];

  /// Slider configurations for interactive adjustment
  static const List<SliderConfig> _sliderConfigs = [
    SliderConfig(
      feature: 'sodium_intake',
      label: 'Sodium Intake',
      description: 'Reduce salt and processed foods',
      icon: '🧂',
      min: 0.5,
      max: 1.0,
      defaultValue: 1.0,
      unit: '%',
      isReduction: true,
    ),
    SliderConfig(
      feature: 'physical_activity_score',
      label: 'Exercise Level',
      description: 'Weekly exercise frequency',
      icon: '🏃',
      min: 1.0,
      max: 3.0,
      defaultValue: 1.0,
      unit: 'x',
    ),
    SliderConfig(
      feature: 'sedentary_minutes',
      label: 'Sitting Time',
      description: 'Daily sitting/screen time',
      icon: '🪑',
      min: 0.5,
      max: 1.0,
      defaultValue: 1.0,
      unit: '%',
      isReduction: true,
    ),
    SliderConfig(
      feature: 'potassium_intake',
      label: 'Potassium Intake',
      description: 'Eat more fruits and veggies',
      icon: '🍌',
      min: 1.0,
      max: 1.5,
      defaultValue: 1.0,
      unit: 'x',
    ),
  ];

  Future<void> _onInitialize(
    InitializeWhatIf event,
    Emitter<WhatIfState> emit,
  ) async {
    emit(state.copyWith(status: WhatIfStatus.loading));

    try {
      // Load model if not loaded
      if (!_predictorService.isLoaded) {
        await _predictorService.loadModel();
      }

      // Calculate baseline risk
      final baselineRisk = _predictorService.predictRisk(event.userProfile);

      emit(
        state.copyWith(
          status: WhatIfStatus.ready,
          baselineProfile: event.userProfile,
          baselineRisk: baselineRisk,
          projectedRisk: baselineRisk,
          availableScenarios: _scenarios,
          sliderConfigs: _sliderConfigs,
          modifications: {
            for (final config in _sliderConfigs)
              config.feature: config.defaultValue,
          },
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: WhatIfStatus.error,
          errorMessage: 'Failed to load prediction model: $e',
        ),
      );
    }
  }

  void _onUpdateSlider(UpdateSlider event, Emitter<WhatIfState> emit) {
    final newModifications = Map<String, double>.from(state.modifications);
    newModifications[event.feature] = event.value;

    emit(
      state.copyWith(
        modifications: newModifications,
        selectedScenarioId: null, // Clear scenario when manual adjustment
      ),
    );

    add(const CalculateProjection());
  }

  void _onSelectScenario(SelectScenario event, Emitter<WhatIfState> emit) {
    final scenario = _scenarios.firstWhere(
      (s) => s.id == event.scenarioId,
      orElse: () => _scenarios.first,
    );

    // Reset modifications to default, then apply scenario
    final newModifications = {
      for (final config in _sliderConfigs) config.feature: config.defaultValue,
    };

    // Apply scenario modifications
    for (final entry in scenario.modifications.entries) {
      newModifications[entry.key] = entry.value;
    }

    emit(
      state.copyWith(
        modifications: newModifications,
        selectedScenarioId: event.scenarioId,
      ),
    );

    add(const CalculateProjection());
  }

  void _onReset(ResetModifications event, Emitter<WhatIfState> emit) {
    emit(
      state.copyWith(
        modifications: {
          for (final config in _sliderConfigs)
            config.feature: config.defaultValue,
        },
        projectedRisk: state.baselineRisk,
        selectedScenarioId: null,
        projection: null,
      ),
    );
  }

  Future<void> _onCalculate(
    CalculateProjection event,
    Emitter<WhatIfState> emit,
  ) async {
    emit(state.copyWith(status: WhatIfStatus.calculating));

    try {
      // Apply modifications to baseline profile
      final modifiedProfile = Map<String, dynamic>.from(state.baselineProfile);

      for (final entry in state.modifications.entries) {
        // Apply modification (entry.value is a multiplier)
        // If profile doesn't have the key, start with the feature's default value
        final baseValue =
            modifiedProfile[entry.key] ??
            _predictorService.getDefaultValue(entry.key);

        if (baseValue is num) {
          modifiedProfile[entry.key] = baseValue * entry.value;
        }
      }

      // Calculate new risk
      final projectedRisk = _predictorService.predictRisk(modifiedProfile);
      final riskReduction = state.baselineRisk - projectedRisk;

      // Estimate systolic change based on risk reduction
      final estimatedSystolicChange = _estimateSystolicChange(riskReduction);

      final projection = ProjectionResult(
        riskReduction: riskReduction,
        relativeImprovement: state.baselineRisk > 0
            ? (riskReduction / state.baselineRisk) * 100
            : 0,
        estimatedSystolicChange: estimatedSystolicChange,
        timeframe: '1-3 months',
        recommendation: _generateRecommendation(riskReduction),
        tips: _generateTips(state.modifications),
      );

      emit(
        state.copyWith(
          status: WhatIfStatus.ready,
          projectedRisk: projectedRisk,
          projection: projection,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: WhatIfStatus.error,
          errorMessage: 'Calculation failed: $e',
        ),
      );
    }
  }

  int _estimateSystolicChange(double riskReduction) {
    // For users with significant risk, estimate based on risk reduction
    if (riskReduction > 0.2) return -15;
    if (riskReduction > 0.15) return -10;
    if (riskReduction > 0.1) return -8;
    if (riskReduction > 0.05) return -5;
    if (riskReduction > 0.02) return -3;
    if (riskReduction > 0) return -2;

    // For already-healthy users (low baseline risk),
    // lifestyle changes still provide maintenance benefit
    // Use selected scenario's expected change if available
    if (state.selectedScenarioId != null) {
      final scenario = state.availableScenarios.firstWhere(
        (s) => s.id == state.selectedScenarioId,
        orElse: () => state.availableScenarios.first,
      );
      // Scale down for healthy users (they get ~50% of max benefit)
      return (scenario.expectedBpChange * 0.5).round();
    }

    // Check if user made any slider modifications
    final hasModifications = state.modifications.entries.any((e) {
      final config = state.sliderConfigs.firstWhere(
        (c) => c.feature == e.key,
        orElse: () => state.sliderConfigs.first,
      );
      return e.value != config.defaultValue;
    });

    if (hasModifications) {
      return -2; // Minimal maintenance benefit for healthy users
    }

    return 0;
  }

  String _generateRecommendation(double riskReduction) {
    if (riskReduction > 0.15) {
      return 'These changes could significantly improve your BP. Highly recommended!';
    } else if (riskReduction > 0.05) {
      return 'Good progress! These changes can have a positive impact on your health.';
    } else if (riskReduction > 0) {
      return 'Every small change helps. Consider combining multiple lifestyle improvements.';
    }
    return 'Maintain your current healthy habits!';
  }

  List<String> _generateTips(Map<String, double> mods) {
    final tips = <String>[];

    if (mods['sodium_intake'] != null && mods['sodium_intake']! < 0.9) {
      tips.add('Read food labels and choose low-sodium options');
    }
    if (mods['physical_activity_score'] != null &&
        mods['physical_activity_score']! > 1.2) {
      tips.add('Start with 10-min walks and gradually increase');
    }
    if (mods['potassium_intake'] != null && mods['potassium_intake']! > 1.1) {
      tips.add('Add a banana or spinach salad to your daily meals');
    }
    if (mods['sedentary_minutes'] != null && mods['sedentary_minutes']! < 0.9) {
      tips.add('Take a 5-minute break every hour to move around');
    }

    if (tips.isEmpty) {
      tips.add('Consistency is key - small daily changes add up!');
    }

    return tips;
  }
}
