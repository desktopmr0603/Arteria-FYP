import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:arteria/env/env.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Events emitted by the Qwen Arteria service
enum QwenEventType {
  connected,
  disconnected,
  ready,
  transcribing,
  transcriptionDone,
  generating,
  responseReceived,
  audioResponse,
  audioResponseDone,
  error,
  functionCall,
}

/// Event data from Qwen Arteria API
class QwenEvent {
  final QwenEventType type;
  final dynamic data;
  final String? message;

  QwenEvent({required this.type, this.data, this.message});
}

/// Service for managing Qwen Arteria API communication
/// Uses HTTP REST API with session-based conversation history
class QwenArteriaService {
  // Configuration
  final String serverUrl;
  final String userId;
  final String language;

  // RunPod Whisper endpoints (using async run + status polling)
  static const String _whisperRunEndpoint =
      'https://api.runpod.ai/v2/qpo2u2i4x2rutp/run';
  static const String _whisperStatusEndpoint =
      'https://api.runpod.ai/v2/qpo2u2i4x2rutp/status';

  // Session management
  String? _sessionId;
  bool _isConnected = false;
  bool _isDisposed = false;

  // Event stream
  final _eventController = StreamController<QwenEvent>.broadcast();
  Stream<QwenEvent> get events => _eventController.stream;

  // HTTP client
  final http.Client _httpClient = http.Client();

  // Firestore for BP data
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  QwenArteriaService({
    required this.serverUrl,
    required this.userId,
    this.language = 'en',
  });

  /// Check if connected to server
  bool get isConnected => _isConnected;

  /// Current session ID
  String? get sessionId => _sessionId;

  /// Connect to Qwen Arteria API
  Future<void> connect({String? userContext}) async {
    if (_isConnected) {
      debugPrint('Already connected to Qwen Arteria API');
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
        QwenEvent(
          type: QwenEventType.connected,
          message: 'Connected to ${healthData['backend']}',
        ),
      );

      debugPrint('✓ Connected to Qwen Arteria API');
      debugPrint('  Backend: ${healthData['backend']}');
      debugPrint('  Firebase: ${healthData['firebase_connected']}');

      _emitEvent(
        QwenEvent(type: QwenEventType.ready, message: 'Ready to speak'),
      );
    } catch (e) {
      debugPrint('Error connecting to Qwen Arteria API: $e');
      _emitEvent(
        QwenEvent(type: QwenEventType.error, message: 'Failed to connect: $e'),
      );
      _isConnected = false;
      rethrow;
    }
  }

  /// Transcribe audio using RunPod WhisperV3 Turbo
  Future<String> transcribeAudio(Uint8List audioData) async {
    final runpodKey = Env.runpodApiKey;
    if (runpodKey.isEmpty) {
      throw Exception('RunPod API key not configured');
    }

    _emitEvent(
      QwenEvent(
        type: QwenEventType.transcribing,
        message: 'Transcribing audio...',
      ),
    );

    try {
      debugPrint('Sending audio to RunPod WhisperV3 Turbo...');
      debugPrint('Audio size: ${audioData.length} bytes');

      // Step 1: Submit the job
      final runResponse = await _httpClient
          .post(
            Uri.parse(_whisperRunEndpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $runpodKey',
            },
            body: jsonEncode({
              'input': {
                'audio_base64': base64Encode(audioData),
                'model': 'turbo',
                'transcription': 'plain_text',
                'language': language,
                // Comprehensive medical terminology prompt for better recognition
                'initial_prompt': '''
Arteria blood pressure app. 
Context: Medical dictation, systolic/diastolic readings, pulse, medications.
Keywords: systolic, diastolic, mmHg, pulse, heart rate.
Meds: Telmisartan, Amlodipine, Lisinopril, Losartan, Losartan potassium, Metoprolol, Valsartan, Atenolol, Hydrochlorothiazide, Nifedipine.
Dosages: 5mg, 10mg, 20mg, 40mg, 80mg.
''',
                'enable_vad': true,
              },
            }),
          )
          .timeout(const Duration(seconds: 30));

      debugPrint('RunPod run response: ${runResponse.statusCode}');
      debugPrint('RunPod run body: ${runResponse.body}');

      if (runResponse.statusCode != 200) {
        throw Exception(
          'Failed to submit job: ${runResponse.statusCode} - ${runResponse.body}',
        );
      }

      final runData = jsonDecode(runResponse.body);
      final jobId = runData['id'] as String?;

      if (jobId == null) {
        throw Exception('No job ID returned from RunPod');
      }

      debugPrint('Job submitted: $jobId');

      // Step 2: Poll for result
      String? transcription;
      int attempts = 0;
      const maxAttempts = 60; // 60 seconds max wait

      while (attempts < maxAttempts) {
        await Future.delayed(const Duration(seconds: 1));
        attempts++;

        final statusResponse = await _httpClient.get(
          Uri.parse('$_whisperStatusEndpoint/$jobId'),
          headers: {'Authorization': 'Bearer $runpodKey'},
        );

        if (statusResponse.statusCode != 200) {
          debugPrint('Status check failed: ${statusResponse.statusCode}');
          continue;
        }

        final statusData = jsonDecode(statusResponse.body);
        final status = statusData['status'] as String?;

        debugPrint('Job status: $status (attempt $attempts)');

        if (status == 'COMPLETED') {
          final output = statusData['output'];
          if (output != null) {
            transcription = output['transcription'] as String?;
          }
          break;
        } else if (status == 'FAILED') {
          throw Exception('Transcription job failed: ${statusData['error']}');
        }
        // Continue polling for IN_QUEUE, IN_PROGRESS
      }

      if (transcription == null || transcription.isEmpty) {
        throw Exception('No speech detected in audio');
      }

      debugPrint('Transcription result: $transcription');

      _emitEvent(
        QwenEvent(
          type: QwenEventType.transcriptionDone,
          data: transcription,
          message: transcription,
        ),
      );

      return transcription;
    } catch (e) {
      debugPrint('Transcription error: $e');
      _emitEvent(
        QwenEvent(
          type: QwenEventType.error,
          message: 'Transcription error: $e',
        ),
      );
      rethrow;
    }
  }

  /// Get latest BP reading for the user
  Future<Map<String, dynamic>?> getLatestBPReading() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('readings')
          .orderBy('date', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      final doc = snapshot.docs.first;
      final data = doc.data();
      return {
        'id': doc.id,
        'systolic': data['systolic'],
        'diastolic': data['diastolic'],
        'pulse': data['pulse'],
        'timestamp': (data['date'] as Timestamp?)?.toDate().toString(),
      };
    } catch (e) {
      debugPrint('Error fetching latest BP reading: $e');
      return null;
    }
  }

  /// Get BP reading history
  Future<List<Map<String, dynamic>>> getBPHistory({int days = 7}) async {
    try {
      final startDate = DateTime.now().subtract(Duration(days: days));
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('readings')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'systolic': data['systolic'],
          'diastolic': data['diastolic'],
          'pulse': data['pulse'],
          'timestamp': (data['date'] as Timestamp?)?.toDate().toString(),
        };
      }).toList();
    } catch (e) {
      debugPrint('Error fetching BP history: $e');
      return [];
    }
  }

  /// Check if message is asking about BP readings
  bool _isAskingAboutBP(String message) {
    final lowerMessage = message.toLowerCase();
    return lowerMessage.contains('latest reading') ||
        lowerMessage.contains('last reading') ||
        lowerMessage.contains('recent reading') ||
        lowerMessage.contains('my blood pressure') ||
        lowerMessage.contains('my bp') ||
        lowerMessage.contains('what was my') ||
        lowerMessage.contains('how is my') ||
        lowerMessage.contains('reading today') ||
        lowerMessage.contains('reading yesterday');
  }

  /// Format BP data for AI context
  String _formatBPContext(Map<String, dynamic> reading) {
    final systolic = reading['systolic'] ?? 0;
    final diastolic = reading['diastolic'] ?? 0;
    final pulse = reading['pulse'];
    final timestamp = reading['timestamp'];

    final buffer = StringBuffer();
    buffer.writeln('\n[USER BP DATA]');
    buffer.writeln('Latest Reading: $systolic/$diastolic mmHg');
    if (pulse != null) {
      buffer.writeln('Pulse: $pulse bpm');
    }
    if (timestamp != null) {
      buffer.writeln('Recorded: $timestamp');
    }

    // Classification per 2025 AHA/ACC Guidelines
    if (systolic > 180 || diastolic > 120) {
      buffer.writeln(
        'Classification: Hypertensive Crisis - SEEK MEDICAL ATTENTION',
      );
    } else if (systolic >= 140 || diastolic >= 90) {
      buffer.writeln('Classification: Stage 2 Hypertension');
    } else if (systolic >= 130 || diastolic > 80) {
      buffer.writeln('Classification: Stage 1 Hypertension');
    } else if (systolic > 120 && diastolic <= 80) {
      buffer.writeln('Classification: Elevated');
    } else {
      buffer.writeln('Classification: Normal');
    }
    buffer.writeln('[/USER BP DATA]\n');

    return buffer.toString();
  }

  /// Send a chat message to Qwen and get response
  Future<Map<String, dynamic>> chat(String message) async {
    if (!_isConnected) {
      throw Exception('Not connected to Qwen Arteria API');
    }

    _emitEvent(
      QwenEvent(
        type: QwenEventType.generating,
        message: 'Generating response...',
      ),
    );

    try {
      // Check if asking about BP and get data if needed
      String messageWithContext = message;
      if (_isAskingAboutBP(message)) {
        final latestReading = await getLatestBPReading();
        if (latestReading != null) {
          messageWithContext = message + _formatBPContext(latestReading);
          debugPrint('BP Context added: $messageWithContext');
        }
      }

      final response = await _httpClient
          .post(
            Uri.parse('$serverUrl/chat'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'message': messageWithContext,
              'user_id': userId,
              'session_id': _sessionId,
              'language': language,
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Update session ID
        _sessionId = data['session_id'];

        final responseText = data['response'] as String;
        final functionCalls = data['function_calls'] as List? ?? [];

        _emitEvent(
          QwenEvent(
            type: QwenEventType.responseReceived,
            data: responseText,
            message: responseText,
          ),
        );

        // Emit function calls if any
        for (final call in functionCalls) {
          _emitEvent(
            QwenEvent(
              type: QwenEventType.functionCall,
              data: call,
              message: call['name'],
            ),
          );
        }

        return {
          'response': responseText,
          'session_id': _sessionId,
          'function_calls': functionCalls,
          'inference_time_ms': data['inference_time_ms'],
        };
      } else {
        throw Exception('Chat failed: ${response.statusCode}');
      }
    } catch (e) {
      _emitEvent(
        QwenEvent(type: QwenEventType.error, message: 'Chat error: $e'),
      );
      rethrow;
    }
  }

  /// Analyze a BP reading
  Future<Map<String, dynamic>> analyzeBP({
    required int systolic,
    required int diastolic,
    int? pulse,
  }) async {
    if (!_isConnected) {
      throw Exception('Not connected to Qwen Arteria API');
    }

    _emitEvent(
      QwenEvent(
        type: QwenEventType.generating,
        message: 'Analyzing BP reading...',
      ),
    );

    try {
      final response = await _httpClient
          .post(
            Uri.parse('$serverUrl/analyze'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'systolic': systolic,
              'diastolic': diastolic,
              'pulse': pulse,
              'user_id': userId,
              'session_id': _sessionId,
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _sessionId = data['session_id'];

        _emitEvent(
          QwenEvent(
            type: QwenEventType.responseReceived,
            data: data['response'],
            message: data['response'],
          ),
        );

        return data;
      } else {
        throw Exception('Analysis failed: ${response.statusCode}');
      }
    } catch (e) {
      _emitEvent(
        QwenEvent(type: QwenEventType.error, message: 'Analysis error: $e'),
      );
      rethrow;
    }
  }

  /// Generate TTS audio using ElevenLabs (via server)
  Future<Uint8List> speak(String text) async {
    if (!_isConnected) {
      throw Exception('Not connected to Qwen Arteria API');
    }

    try {
      final response = await _httpClient
          .post(
            Uri.parse('$serverUrl/speak'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'text': text, 'language': language}),
          )
          // Long, doctor-style answers take longer to synthesize. 30s was
          // tripping a TimeoutException on multi-sentence clinical replies.
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final audioBytes = response.bodyBytes;

        _emitEvent(
          QwenEvent(type: QwenEventType.audioResponse, data: audioBytes),
        );

        _emitEvent(QwenEvent(type: QwenEventType.audioResponseDone));

        return audioBytes;
      } else {
        throw Exception('TTS failed: ${response.statusCode}');
      }
    } catch (e) {
      _emitEvent(
        QwenEvent(type: QwenEventType.error, message: 'TTS error: $e'),
      );
      rethrow;
    }
  }

  /// Full voice interaction: transcribe -> chat -> speak
  Future<Map<String, dynamic>> processVoiceInteraction(
    Uint8List audioData,
  ) async {
    // 1. Transcribe audio
    final transcription = await transcribeAudio(audioData);

    // 2. Get Qwen response
    final chatResult = await chat(transcription);

    // 3. Generate TTS
    final audioResponse = await speak(chatResult['response']);

    return {
      ...chatResult,
      'transcription': transcription,
      'audio_response': audioResponse,
    };
  }

  /// Clear conversation session
  Future<void> clearSession() async {
    if (_sessionId != null) {
      try {
        await _httpClient.post(
          Uri.parse(
            '$serverUrl/session/clear?user_id=$userId&session_id=$_sessionId',
          ),
        );
        _sessionId = null;
      } catch (e) {
        debugPrint('Error clearing session: $e');
      }
    }
  }

  /// Disconnect from API
  Future<void> disconnect() async {
    _isConnected = false;
    _emitEvent(QwenEvent(type: QwenEventType.disconnected));
    debugPrint('✓ Disconnected from Qwen Arteria API');
  }

  /// Safely emit an event only if not disposed
  void _emitEvent(QwenEvent event) {
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
