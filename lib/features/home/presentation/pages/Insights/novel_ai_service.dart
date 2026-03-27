import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:arteria/env/env.dart';
import '../../components/medication_interaction_card.dart';


/// Service for Voice Stress and Medication Optimizer API calls
/// 
/// Connects Flutter to the novel AI features implemented in the Python backend.
class NovelAIService {
  final String _baseUrl;
  final String _userId;

  NovelAIService({
    String? serverUrl,
    required String userId,
  })  : _baseUrl = serverUrl ?? Env.qwenServerUrl,
        _userId = userId;

  // ============================================================================
  // VOICE STRESS ANALYSIS
  // ============================================================================

  /// Analyze voice stress from audio (base64 encoded)
  Future<VoiceStressResult?> analyzeVoiceStress(String audioBase64) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/chat/voice-aware'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'audio_base64': audioBase64,
          'user_id': _userId,
          'language': 'en',
          'analyze_stress': true,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final stressData = data['stress_analysis'];
        
        if (stressData != null) {
          return VoiceStressResult(
            stressScore: (stressData['stress_score'] ?? 0).toInt(),
            stressLevel: stressData['stress_level'] ?? 'low',
            contributingFactors: List<String>.from(stressData['contributing_factors'] ?? []),
            confidence: (stressData['confidence'] ?? 0.5).toDouble(),
            transcription: data['transcription'] ?? '',
            response: data['response'] ?? '',
          );
        }
      }
      return null;
    } catch (e) {
      debugPrint('Voice stress analysis error: $e');
      return null;
    }
  }

  /// Get historical stress-BP correlation
  Future<StressBPCorrelation?> getStressBPCorrelation({int days = 30}) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/voice/stress-correlation/$_userId?days=$days'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return StressBPCorrelation(
          correlation: (data['correlation'] ?? 0.0).toDouble(),
          dataPoints: data['data_points'] ?? 0,
          trend: data['trend'] ?? 'stable',
          insight: data['insight'] ?? '',
        );
      }
      return null;
    } catch (e) {
      debugPrint('Stress correlation error: $e');
      return null;
    }
  }

  // ============================================================================
  // MEDICATION INTERACTIONS
  // ============================================================================

  /// Check for drug-drug and food-drug interactions
  Future<MedicationInteractionResult?> checkInteractions({
    String? textInput,
    List<String>? foodItems,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/medication/interactions'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': _userId,
          'text_input': textInput,
          'food_items': foodItems,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final warningsList = data['interactions'] as List? ?? [];
        
        return MedicationInteractionResult(
          medications: List<String>.from(data['medications'] ?? []),
          warnings: warningsList
              .map((w) => InteractionWarning.fromJson(w))
              .toList(),
          hasHighSeverity: data['has_high_severity'] ?? false,
        );
      }
      return null;
    } catch (e) {
      debugPrint('Medication interaction check error: $e');
      return null;
    }
  }




}

// ============================================================================
// DATA MODELS
// ============================================================================

class VoiceStressResult {
  final int stressScore;
  final String stressLevel;
  final List<String> contributingFactors;
  final double confidence;
  final String transcription;
  final String response;

  VoiceStressResult({
    required this.stressScore,
    required this.stressLevel,
    required this.contributingFactors,
    required this.confidence,
    required this.transcription,
    required this.response,
  });
}

class StressBPCorrelation {
  final double correlation;
  final int dataPoints;
  final String trend;
  final String insight;

  StressBPCorrelation({
    required this.correlation,
    required this.dataPoints,
    required this.trend,
    required this.insight,
  });
}

class MedicationInteractionResult {
  final List<String> medications;
  final List<InteractionWarning> warnings;
  final bool hasHighSeverity;

  MedicationInteractionResult({
    required this.medications,
    required this.warnings,
    required this.hasHighSeverity,
  });
}




