import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// On-device BP Risk Predictor using TensorFlow Lite
/// Provides hypertension risk predictions without requiring network access.
class BPPredictorRemoteDataSource {
  Interpreter? _interpreter;
  List<String> _featureNames = [];
  List<double> _featureMeans = [];
  List<double> _featureStds = [];
  Map<String, dynamic> _metadata = {};
  bool _isLoaded = false;

  /// Check if the model is loaded and ready
  bool get isLoaded => _isLoaded;

  /// Load the TFLite model and feature configuration
  Future<void> loadModel() async {
    try {
      // Load TFLite model
      _interpreter = await Interpreter.fromAsset(
        'assets/models/bp_predictor.tflite',
      );

      // Load model metadata
      final metadataJson = await rootBundle.loadString(
        'assets/models/model_metadata.json',
      );
      _metadata = jsonDecode(metadataJson);

      // Extract feature names and scaling parameters
      // Note: metadata uses 'input_features' key, not 'feature_names'
      if (_metadata.containsKey('input_features')) {
        _featureNames = List<String>.from(_metadata['input_features']);
      } else if (_metadata.containsKey('feature_names')) {
        _featureNames = List<String>.from(_metadata['feature_names']);
      }
      if (_metadata.containsKey('feature_means')) {
        _featureMeans = List<double>.from(
          _metadata['feature_means'].map((e) => e.toDouble()),
        );
      }
      if (_metadata.containsKey('feature_stds')) {
        _featureStds = List<double>.from(
          _metadata['feature_stds'].map((e) => e.toDouble()),
        );
      }

      _isLoaded = true;
      debugPrint(
        'BP Predictor model loaded with ${_featureNames.length} features',
      );
    } catch (e) {
      debugPrint('Failed to load BP Predictor model: $e');
      _isLoaded = false;
      rethrow;
    }
  }

  /// Predict hypertension risk from user features
  /// Returns a probability value between 0.0 and 1.0
  double predictRisk(Map<String, dynamic> features) {
    if (!_isLoaded || _interpreter == null) {
      throw StateError('Model not loaded. Call loadModel() first.');
    }

    // Build feature vector in correct order
    final featureVector = <double>[];
    for (final fname in _featureNames) {
      final rawValue = features[fname] ?? getDefaultValue(fname);
      final value = _parseFeatureValue(fname, rawValue);
      featureVector.add(value);
    }

    // Normalize features
    final normalizedVector = _normalizeFeatures(featureVector);

    // Prepare input tensor
    final input = Float32List.fromList(normalizedVector);
    final inputShape = [1, _featureNames.length];
    final inputTensor = input.reshape(inputShape);

    // Prepare output tensor
    final output = List.filled(1, 0.0).reshape([1, 1]);

    // Run inference
    _interpreter!.run(inputTensor, output);

    return output[0][0].clamp(0.0, 1.0);
  }

  /// Safely parse feature value to double, handling strings and categorical mappings
  double _parseFeatureValue(String featureName, dynamic value) {
    if (value is num) return value.toDouble();

    if (value is String) {
      final lowerValue = value.toLowerCase();

      // Categorical Mapping: Gender
      if (featureName == 'gender') {
        if (lowerValue.contains('female')) return 1.0;
        if (lowerValue.contains('male')) return 0.0;
        return 0.5; // Unknown/Other
      }

      // Categorical Mapping: Boolean types (has_diabetes, etc)
      if (lowerValue == 'true' || lowerValue == 'yes') return 1.0;
      if (lowerValue == 'false' || lowerValue == 'no') return 0.0;

      // Attempt generic parse
      return double.tryParse(value) ?? getDefaultValue(featureName);
    }

    return getDefaultValue(featureName);
  }

  /// Normalize features using stored mean/std
  /// If metadata lacks normalization params, use built-in population statistics
  List<double> _normalizeFeatures(List<double> features) {
    // If metadata has normalization params, use them
    if (_featureMeans.isNotEmpty && _featureStds.isNotEmpty) {
      return List.generate(features.length, (i) {
        final std = _featureStds[i] != 0 ? _featureStds[i] : 1.0;
        return (features[i] - _featureMeans[i]) / std;
      });
    }

    // Built-in normalization based on NHANES population statistics
    // These are approximate mean/std values for each feature
    final builtInMeans = <String, double>{
      'age': 50.0,
      'avg_systolic': 125.0,
      'avg_diastolic': 75.0,
      'avg_pulse': 72.0,
      'sodium_intake': 3400.0,
      'potassium_intake': 2600.0,
      'total_cholesterol': 195.0,
      'hdl_cholesterol': 53.0,
      'triglycerides': 130.0,
      'fasting_glucose': 105.0,
      'calories': 2000.0,
      'sedentary_minutes': 480.0,
      'income_poverty_ratio': 2.5,
      'gender': 0.5,
      'race_ethnicity': 2.5,
      'education': 3.0,
      'marital_status': 1.5,
      'smoker_status': 0.2,
      'alcohol_use': 0.3,
      'has_diabetes': 0.15,
      'takes_bp_medication': 0.25,
      'has_heart_condition': 0.1,
      'physical_activity_score': 1.5,
    };

    final builtInStds = <String, double>{
      'age': 18.0,
      'avg_systolic': 18.0,
      'avg_diastolic': 12.0,
      'avg_pulse': 12.0,
      'sodium_intake': 1200.0,
      'potassium_intake': 900.0,
      'total_cholesterol': 40.0,
      'hdl_cholesterol': 15.0,
      'triglycerides': 80.0,
      'fasting_glucose': 30.0,
      'calories': 700.0,
      'sedentary_minutes': 180.0,
      'income_poverty_ratio': 1.5,
      'gender': 0.5,
      'race_ethnicity': 1.5,
      'education': 1.2,
      'marital_status': 1.0,
      'smoker_status': 0.4,
      'alcohol_use': 0.5,
      'has_diabetes': 0.35,
      'takes_bp_medication': 0.45,
      'has_heart_condition': 0.3,
      'physical_activity_score': 0.8,
    };

    // Normalize each feature using built-in stats
    return List.generate(features.length, (i) {
      final featureName = _featureNames[i];
      final mean = builtInMeans[featureName] ?? 0.0;
      final std = builtInStds[featureName] ?? 1.0;
      return (features[i] - mean) / (std != 0 ? std : 1.0);
    });
  }

  /// Get default value for missing features
  double getDefaultValue(String featureName) {
    final defaults = <String, double>{
      'age': 40,
      'gender': 0,
      'avg_systolic': 120,
      'avg_diastolic': 80,
      'avg_pulse': 72,
      'sodium_intake': 2300,
      'potassium_intake': 3000,
      'total_cholesterol': 200,
      'hdl_cholesterol': 50,
      'triglycerides': 150,
      'fasting_glucose': 100,
      'calories': 2000,
      'sedentary_minutes': 360,
      'income_poverty_ratio': 2.0,
      'race_ethnicity': 3,
      'education': 4,
      'marital_status': 1,
      'smoker_status': 0,
      'alcohol_use': 0,
      'has_diabetes': 0,
      'takes_bp_medication': 0,
      'has_heart_condition': 0,
      'physical_activity_score': 1,
    };
    return defaults[featureName] ?? 0.0;
  }

  /// Classify risk level from probability
  String classifyRisk(double probability) {
    if (probability < 0.3) return 'low';
    if (probability < 0.6) return 'moderate';
    return 'high';
  }

  /// Get risk color based on probability
  int getRiskColor(double probability) {
    if (probability < 0.3) return 0xFF4CAF50; // Green
    if (probability < 0.6) return 0xFFFFA726; // Orange
    return 0xFFF44336; // Red
  }

  /// Get model info
  Map<String, dynamic> get modelInfo => _metadata;

  /// Dispose of resources
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isLoaded = false;
  }
}
