import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// On-device BP Risk Predictor using TensorFlow Lite
/// 
/// Provides hypertension risk predictions without requiring network access.
/// Model files should be placed in assets/models/
class BPPredictorService {
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
      _interpreter = await Interpreter.fromAsset('models/bp_predictor.tflite');
      
      // Load model metadata
      final metadataJson = await rootBundle.loadString('assets/models/model_metadata.json');
      _metadata = jsonDecode(metadataJson);
      
      // Extract feature names and scaling parameters
      if (_metadata.containsKey('feature_names')) {
        _featureNames = List<String>.from(_metadata['feature_names']);
      }
      if (_metadata.containsKey('feature_means')) {
        _featureMeans = List<double>.from(_metadata['feature_means'].map((e) => e.toDouble()));
      }
      if (_metadata.containsKey('feature_stds')) {
        _featureStds = List<double>.from(_metadata['feature_stds'].map((e) => e.toDouble()));
      }
      
      _isLoaded = true;
      print('✅ BP Predictor model loaded with ${_featureNames.length} features');
    } catch (e) {
      print('❌ Failed to load BP Predictor model: $e');
      _isLoaded = false;
      rethrow;
    }
  }

  /// Predict hypertension risk from user features
  /// 
  /// Returns a probability value between 0.0 and 1.0
  double predictRisk(Map<String, dynamic> features) {
    if (!_isLoaded || _interpreter == null) {
      throw StateError('Model not loaded. Call loadModel() first.');
    }

    // Build feature vector in correct order
    final featureVector = <double>[];
    for (final fname in _featureNames) {
      final value = (features[fname] ?? _getDefaultValue(fname)).toDouble();
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

  /// Normalize features using stored mean/std
  List<double> _normalizeFeatures(List<double> features) {
    if (_featureMeans.isEmpty || _featureStds.isEmpty) {
      return features; // No normalization available
    }

    return List.generate(features.length, (i) {
      final std = _featureStds[i] != 0 ? _featureStds[i] : 1.0;
      return (features[i] - _featureMeans[i]) / std;
    });
  }

  /// Get default value for missing features
  double _getDefaultValue(String featureName) {
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
