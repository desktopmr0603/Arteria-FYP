import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
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
      // For iOS, copy asset to temp file first for more reliable loading
      String? modelPath;

      if (Platform.isIOS) {
        final tempDir = await getTemporaryDirectory();
        final modelFile = File('${tempDir.path}/bp_predictor.tflite');

        // Only copy if not already exists in temp
        if (!await modelFile.exists()) {
          final byteData = await rootBundle.load(
            'assets/models/bp_predictor.tflite',
          );
          await modelFile.writeAsBytes(byteData.buffer.asUint8List());
        }
        modelPath = modelFile.path;
        debugPrint('BP Predictor: Loading model from temp file: $modelPath');

        // Verify file exists and has content
        if (!await modelFile.exists() || await modelFile.length() == 0) {
          throw Exception('Model file is empty or does not exist');
        }

        // Try different interpreter options for better compatibility
        try {
          final options = InterpreterOptions()..threads = 1; // Reduce threads for compatibility
          _interpreter = Interpreter.fromFile(modelFile, options: options);
        } catch (e) {
          debugPrint('Failed with 1 thread, trying with default options: $e');
          final options = InterpreterOptions();
          _interpreter = Interpreter.fromFile(modelFile, options: options);
        }
      } else {
        // Android: use asset directly
        final options = InterpreterOptions()..threads = 1;
        _interpreter = await Interpreter.fromAsset(
          'assets/models/bp_predictor.tflite',
          options: options,
        );
      }

      // Log model input/output info for debugging
      if (_interpreter != null) {
        final inputTensors = _interpreter!.getInputTensors();
        final outputTensors = _interpreter!.getOutputTensors();
        debugPrint(
          'BP Predictor: ${inputTensors.length} inputs, ${outputTensors.length} outputs',
        );
        for (var tensor in inputTensors) {
          debugPrint('  Input: shape=${tensor.shape}, type=${tensor.type}');
        }
        for (var tensor in outputTensors) {
          debugPrint('  Output: shape=${tensor.shape}, type=${tensor.type}');
        }
      }

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
      debugPrint('This may be due to model incompatibility or missing assets.');
      debugPrint('The app will continue with limited functionality.');
      
      // Set fallback values for basic functionality
      _isLoaded = false;
      _interpreter = null;
      
      // Don't rethrow - allow app to continue with limited functionality
      // Instead, we'll provide fallback predictions
    }
  }

  /// Check if model is available for predictions
  bool get isModelAvailable => _isLoaded && _interpreter != null;

  /// Get fallback risk prediction when model is not available
  /// Uses simple rule-based approach as backup
  double getFallbackRisk(Map<String, dynamic> features) {
    double riskScore = 0.1; // Base risk
    
    // Age factor
    final age = (features['age'] as num?)?.toDouble() ?? 40.0;
    if (age > 60) {
      riskScore += 0.2;
    } else if (age > 50) {
      riskScore += 0.1;
    }
    
    // Blood pressure factors
    final systolic = (features['avg_systolic'] as num?)?.toDouble() ?? 120.0;
    final diastolic = (features['avg_diastolic'] as num?)?.toDouble() ?? 80.0;
    
    if (systolic > 140) {
      riskScore += 0.3;
    } else if (systolic > 130) {
      riskScore += 0.15;
    }
    
    if (diastolic > 90) {
      riskScore += 0.2;
    } else if (diastolic > 85) {
      riskScore += 0.1;
    }
    
    // Lifestyle factors
    final smokerStatus = (features['smoker_status'] as num?)?.toDouble() ?? 0.0;
    if (smokerStatus > 0) riskScore += 0.25;
    
    final hasDiabetes = (features['has_diabetes'] as num?)?.toDouble() ?? 0.0;
    if (hasDiabetes > 0) riskScore += 0.2;
    
    return riskScore.clamp(0.0, 1.0);
  }

  /// Predict hypertension risk from user features
  /// Returns a probability value between 0.0 and 1.0
  double predictRisk(Map<String, dynamic> features) {
    // Use fallback if model is not available
    if (!isModelAvailable) {
      debugPrint('Using fallback risk prediction (model not loaded)');
      return getFallbackRisk(features);
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
