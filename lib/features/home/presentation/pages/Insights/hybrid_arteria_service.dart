import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class HybridArteriaService {
  // Configuration
  final String serverUrl;
  final String userId;
  final String language;

  // Session management
  String? _sessionId;
  bool _isConnected = false;
  bool _isDisposed = false;

  // Event stream
  final _eventController = StreamController<HybridEvent>.broadcast();
  Stream<HybridEvent> get events => _eventController.stream;

  // HTTP client
  final http.Client _httpClient = http.Client();

  // Firestore for BP data

  // Conversation history
  final List<Map<String, String>> _conversationHistory = [];

  HybridArteriaService({
    required this.serverUrl,
    required this.userId,
    this.language = 'en',
  });

  /// Check if connected to server
  bool get isConnected => _isConnected;

  /// Current session ID
  String? get sessionId => _sessionId;

  /// Connect to Hybrid Arteria API
  Future<void> connect({String? userContext}) async {
    if (_isConnected) {
      debugPrint('Already connected to Hybrid Arteria API');
      return;
    }

    try {
      // Health check
      final healthResponse = await _httpClient
          .get(Uri.parse('$serverUrl/health'))
          .timeout(const Duration(seconds: 10));

      if (healthResponse.statusCode != 200) {
        throw Exception('Server not healthy: ${healthResponse.statusCode}');
      }

      final healthData = jsonDecode(healthResponse.body);
      _isConnected = true;

      _emitEvent(
        HybridEvent(
          type: HybridEventType.connected,
          message: 'Connected to ${healthData['backend']}',
        ),
      );

      debugPrint('✓ Connected to Hybrid Arteria API');
      debugPrint('  Backend: ${healthData['backend']}');
      debugPrint('  Firebase: ${healthData['firebase_connected']}');

      _emitEvent(
        HybridEvent(type: HybridEventType.ready, message: 'Ready to speak'),
      );
    } catch (e) {
      debugPrint('Error connecting to Hybrid Arteria API: $e');
      _emitEvent(
        HybridEvent(
          type: HybridEventType.error,
          message: 'Failed to connect: $e',
        ),
      );
      _isConnected = false;
      rethrow;
    }
  }

  /// Process audio through hybrid system with OpenAI Whisper
  Future<Map<String, dynamic>> processAudioInput(Uint8List audioData) async {
    if (!_isConnected) {
      throw Exception('Not connected to Hybrid Arteria API');
    }

    _emitEvent(
      HybridEvent(
        type: HybridEventType.processing,
        message: 'Transcribing with OpenAI Whisper...',
      ),
    );

    try {
      // Convert audio to base64 for transmission
      final audioBase64 = base64Encode(audioData);

      final response = await _httpClient
          .post(
            Uri.parse('$serverUrl/hybrid/audio'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'audio_data': audioBase64,
              'user_id': userId,
              'language': language,
            }),
          )
          .timeout(
            const Duration(seconds: 90),
          ); // Longer timeout for hybrid processing

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Update session ID if provided
        if (data['session_id'] != null) {
          _sessionId = data['session_id'];
        }

        final responseText = data['response']?.toString();
        final transcription = data['transcription']?.toString();

        // Add transcription and response to conversation history
        if (transcription != null) {
          _conversationHistory.add({'role': 'user', 'content': transcription});
        }
        if (responseText != null) {
          _conversationHistory.add({
            'role': 'assistant',
            'content': responseText,
          });
        }

        _emitEvent(
          HybridEvent(
            type: HybridEventType.responseReceived,
            data: responseText,
            message: responseText,
          ),
        );

        return {
          'response': responseText,
          'transcription': transcription,
          'session_id': _sessionId,
          'inference_time_ms': data['inference_time_ms'],
          'is_hybrid_response': true,
          'type': data['type'],
          // Pass through so the UI can render action feedback (e.g. the
          // medication-saved toast). Previously dropped here, which left
          // the success feedback in InsightsScreen as dead code.
          'function_calls': data['function_calls'],
          'medication_feedback': data['medication_feedback'],
        };
      } else {
        throw Exception(
          'Hybrid audio processing failed: ${response.statusCode}',
        );
      }
    } catch (e) {
      _emitEvent(
        HybridEvent(
          type: HybridEventType.error,
          message: 'Hybrid audio error: $e',
        ),
      );
      rethrow;
    }
  }

  /// Process user input through hybrid system
  Future<Map<String, dynamic>> processUserInput(String userInput) async {
    if (!_isConnected) {
      throw Exception('Not connected to Hybrid Arteria API');
    }

    _emitEvent(
      HybridEvent(
        type: HybridEventType.processing,
        message: 'Processing through hybrid system...',
      ),
    );

    try {
      // Add user input to conversation history
      _conversationHistory.add({'role': 'user', 'content': userInput});

      // Get user context from Firestore
      // Get user context from Firestore (unused currently)
      // await _buildUserContext();

      final response = await _httpClient
          .post(
            Uri.parse('$serverUrl/chat'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'message': userInput,
              'user_id': userId,
              'session_id': _sessionId,
              'language': language,
            }),
          )
          .timeout(
            const Duration(seconds: 90),
          ); // Longer timeout for hybrid processing

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Update session ID
        _sessionId = data['session_id'];

        final responseText = data['response'] as String;

        // Add assistant response to conversation history
        _conversationHistory.add({
          'role': 'assistant',
          'content': responseText,
        });

        _emitEvent(
          HybridEvent(
            type: HybridEventType.responseReceived,
            data: responseText,
            message: responseText,
          ),
        );

        return {
          'response': responseText,
          'session_id': _sessionId,
          'inference_time_ms': data['inference_time_ms'],
          'is_hybrid_response': true,
        };
      } else {
        throw Exception('Hybrid chat failed: ${response.statusCode}');
      }
    } catch (e) {
      _emitEvent(
        HybridEvent(
          type: HybridEventType.error,
          message: 'Hybrid processing error: $e',
        ),
      );
      rethrow;
    }
  }

  /// Get conversation history
  List<Map<String, String>> get conversationHistory =>
      List.unmodifiable(_conversationHistory);

  /// Clear conversation history
  void clearHistory() {
    _conversationHistory.clear();
  }

  /// Disconnect from API
  Future<void> disconnect() async {
    _isConnected = false;
    _emitEvent(HybridEvent(type: HybridEventType.disconnected));
    debugPrint('✓ Disconnected from Hybrid Arteria API');
  }

  /// Safely emit an event only if not disposed
  void _emitEvent(HybridEvent event) {
    if (!_isDisposed && !_eventController.isClosed) {
      _eventController.add(event);
    }
  }

  /// Dispose resources
  void dispose() {
    _isDisposed = true;
    _eventController.close();
    _httpClient.close();
    disconnect();
  }
}

/// Events emitted by the Hybrid Arteria service
enum HybridEventType {
  connected,
  disconnected,
  ready,
  processing,
  responseReceived,
  error,
  clarification,
}

/// Event data from Hybrid Arteria API
class HybridEvent {
  final HybridEventType type;
  final dynamic data;
  final String? message;

  HybridEvent({required this.type, this.data, this.message});
}
