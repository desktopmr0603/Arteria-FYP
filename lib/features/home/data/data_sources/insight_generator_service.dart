import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dart_openai/dart_openai.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:arteria/env/env.dart';

class InsightGeneratorService {
  static const String _openAIModel = 'gpt-4.1-mini-2025-04-14';

  /// Triggers a background generation of a personalized health insight 
  /// using the most recent BP context and safely persists it to the dashboard.
  static Future<void> generateAndSaveInsight({
    required String uid,
    required double newSystolic,
    required double newDiastolic,
    required double avgSystolic,
    required double avgDiastolic,
    required bool hasSymptoms,
  }) async {
    try {
      final openaiKey = Env.openaiApiKey;
      if (openaiKey.isEmpty) {
        debugPrint('⚠️ Cannot generate insight: OpenAI API key missing.');
        return;
      }

      OpenAI.apiKey = openaiKey;

      // Ensure the model uses STRICT data grounding to prevent hallucination.
      // Must only return specific schema parameters.
      final systemPrompt = '''
You are a highly analytical and supportive health assistant. 
Your task is to analyze the user's latest blood pressure reading and generate a brief, personalized insight.

CRÍTICAL RULES:
1. ONLY use the data provided in this prompt. NEVER invent metrics about sleep, heart rate, recovery, or other unavailable data.
2. Be concise, supportive, grounded, non-diagnostic, and medically appropriate. DO NOT speak like a doctor making a diagnosis. 
3. Return the response EXCLUSIVELY as valid JSON matching this schema:
{
  "title": "Short descriptive title (e.g., Daily Insight, Elevated Reading)",
  "message": "1-2 sentences. Supportive and grounded.",
  "status": "OPTIMAL" | "ELEVATED" | "WARNING",
  "type": "blood_pressure" | "trend" | "medication" | "symptom" | "general",
  "icon": "blood_pressure" | "trend" | "medication" | "symptom"
}
''';

      final userPrompt = '''
NEW READING: $newSystolic / $newDiastolic mmHg
RECENT AVERAGE (last 30 days): ${avgSystolic.round()} / ${avgDiastolic.round()} mmHg
SYMPTOMS REPORTED: ${hasSymptoms ? 'Yes' : 'No'}

Please generate the JSON insight.
''';

      final completion = await OpenAI.instance.chat.create(
        model: _openAIModel,
        responseFormat: const {"type": "json_object"},
        messages: [
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.system,
            content: [
              OpenAIChatCompletionChoiceMessageContentItemModel.text(systemPrompt),
            ],
          ),
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.user,
            content: [
              OpenAIChatCompletionChoiceMessageContentItemModel.text(userPrompt),
            ],
          ),
        ],
      );

      final responseText = completion.choices.first.message.content?.first.text;
      if (responseText == null || responseText.isEmpty) {
        throw Exception('OpenAI returned an empty response.');
      }

      final parsed = jsonDecode(responseText) as Map<String, dynamic>;

      // Validate JSON fields aggressively
      final title = parsed['title']?.toString() ?? 'Daily Insight';
      final message = parsed['message']?.toString() ?? 'Keep monitoring your health.';
      final statusStr = parsed['status']?.toString().toUpperCase() ?? 'OPTIMAL';
      final type = parsed['type']?.toString().toLowerCase() ?? 'general';
      final iconStr = parsed['icon']?.toString().toLowerCase() ?? 'blood_pressure';

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('insights')
          .add({
        'title': title,
        'message': message,
        'status': statusStr,
        'type': type,
        'icon': iconStr,
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Dashboard Insight generated and saved successfully.');
    } catch (e) {
      // Intentionally swallow errors so the primary reading save is NEVER blocked
      debugPrint('⚠️ AI Insight Generation failed smoothly: $e');
    }
  }
}
