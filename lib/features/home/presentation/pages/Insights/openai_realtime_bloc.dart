import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:web_socket_channel/io.dart';
import 'package:flutter/foundation.dart';

/// Events emitted by the OpenAI Realtime service
enum RealtimeEventType {
  connected,
  disconnected,
  ready,
  audioResponse,
  audioResponseDone,
  textDelta,
  transcript,
  error,
  processing,
  functionCall,
}

/// Event data from OpenAI Realtime API
class RealtimeEvent {
  final RealtimeEventType type;
  final dynamic data;
  final String? message;

  RealtimeEvent({required this.type, this.data, this.message});
}

/// Service for managing OpenAI Realtime API WebSocket connection
class OpenAIRealtimeService {
  // WebSocket connection
  IOWebSocketChannel? _channel;
  bool _isConnected = false;
  String? _sessionId;

  // Configuration
  final String apiKey;
  final String model;
  final String voice;
  final String language;

  // Event stream
  final _eventController = StreamController<RealtimeEvent>.broadcast();
  Stream<RealtimeEvent> get events => _eventController.stream;

  // Audio buffer for streaming
  final List<Uint8List> _audioBuffer = [];

  OpenAIRealtimeService({
    required this.apiKey,
    this.model = 'gpt-4o-realtime', // Use 'gpt-realtime-mini' for lower cost
    this.voice = 'alloy',
    this.language = 'en',
  });

  /// Check if currently connected
  bool get isConnected => _isConnected;

  /// Connect to OpenAI Realtime API
  Future<void> connect({String? userContext}) async {
    if (_isConnected) {
      debugPrint('Already connected to OpenAI Realtime API');
      return;
    }

    try {
      // Build WebSocket URL with model parameter
      final wsUrl = 'wss://api.openai.com/v1/realtime?model=$model';

      // Create WebSocket with authorization headers
      final socket = await WebSocket.connect(
        wsUrl,
        headers: {
          'Authorization': 'Bearer $apiKey',
          'OpenAI-Beta': 'realtime=v1',
        },
      );

      _channel = IOWebSocketChannel(socket);

      // Listen for messages
      _channel!.stream.listen(
        _handleMessage,
        onError: (error) {
          debugPrint('WebSocket error: $error');
          _eventController.add(
            RealtimeEvent(
              type: RealtimeEventType.error,
              message: 'Connection error: $error',
            ),
          );
          _isConnected = false;
        },
        onDone: () {
          debugPrint('WebSocket connection closed');
          _eventController.add(
            RealtimeEvent(type: RealtimeEventType.disconnected),
          );
          _isConnected = false;
        },
      );

      _isConnected = true;
      _eventController.add(RealtimeEvent(type: RealtimeEventType.connected));

      // Configure session with instructions
      await _configureSession(userContext: userContext);

      debugPrint('✓ Connected to OpenAI Realtime API');
    } catch (e) {
      debugPrint('Error connecting to OpenAI Realtime API: $e');
      _eventController.add(
        RealtimeEvent(
          type: RealtimeEventType.error,
          message: 'Failed to connect: $e',
        ),
      );
      _isConnected = false;
      rethrow;
    }
  }

  /// Configure the session with instructions and tools
  Future<void> _configureSession({String? userContext}) async {
    if (!_isConnected || _channel == null) {
      throw Exception('Not connected to OpenAI Realtime API');
    }

    final instructions = language == 'fr' 
        ? _buildFrenchInstructions(userContext)
        : _buildEnglishInstructions(userContext);

    debugPrint('📋 User Context being sent to AI:');
    debugPrint(userContext ?? 'No context available');
    debugPrint('🌍 Language: $language');

    final sessionUpdate = {
      'type': 'session.update',
      'session': {
        'modalities': ['text', 'audio'],
        'instructions': instructions,
        'voice': voice,
        'input_audio_format': 'pcm16',
        'output_audio_format': 'pcm16',
        'input_audio_transcription': {'model': 'whisper-1', 'language': language},
        'turn_detection': {
          'type': 'server_vad',
          'threshold': 0.6,
          'prefix_padding_ms': 500,
          'silence_duration_ms': 1200,
        },
        'temperature': 0.8,
        'max_response_output_tokens': 4096,
        'tools': [
          {
            'type': 'function',
            'name': 'set_reminder',
            'description': 'Set a reminder for the user to take their blood pressure reading',
            'parameters': {
              'type': 'object',
              'properties': {
                'hour': {
                  'type': 'integer',
                  'description': 'Hour of the day (0-23) for the reminder',
                },
                'minute': {
                  'type': 'integer',
                  'description': 'Minute of the hour (0-59) for the reminder',
                },
                'repeat_type': {
                  'type': 'string',
                  'enum': ['daily', 'weekdays', 'weekends'],
                  'description': 'How often the reminder should repeat',
                },
              },
              'required': ['hour', 'minute', 'repeat_type'],
            },
          },
        ],
        'tool_choice': 'auto',
      },
    };

    _channel!.sink.add(jsonEncode(sessionUpdate));
    debugPrint('✓ Session configured with audio output and tools enabled');
    debugPrint('   Modalities: text, audio');
    debugPrint('   Output format: pcm16');
    debugPrint('   Voice: $voice');
    debugPrint('   Tools: set_reminder');
  }

  String _buildEnglishInstructions(String? userContext) {
    return '''You are a helpful blood pressure monitoring assistant.

Your role is to:
1. Answer questions about the user's blood pressure readings
2. Provide health information based on their BP data
3. Explain BP classifications and trends
4. Give appropriate health recommendations
5. Help users set up reminders to track their blood pressure regularly

${userContext ?? ''}

When discussing blood pressure:
1. Analyze the data using BP classification guidelines
2. Provide clear, helpful, and empathetic responses
3. Mention when appropriate that your advice doesn't replace professional medical consultation

IMPORTANT - Medical History Questions:
When a user asks if their reading is "normal" or seeks assessment of their BP:
1. First, check if there is a "Missing Medical Information" section in the user context above
2. If missing information exists, ask ONE relevant question at a time from that list
3. NEVER ask about information already listed in "Available Medical Information"
4. Only ask about pregnancy if the user's gender is Female
5. Phrase questions naturally and conversationally, like a caring doctor would ask:
   - "Are you currently taking any medications for blood pressure or other conditions?"
   - "Do you smoke or use any tobacco products?"
   - "Are you currently pregnant or planning to become pregnant?" (females only)
   - "Do you have diabetes or any other chronic health conditions?"
   - "Could you tell me about your typical diet and exercise routine?"
   - "How would you describe your stress levels lately?"

6. After the user answers a question, acknowledge their response and provide relevant context about how that factor relates to blood pressure
7. If multiple pieces of information are missing, ask questions one at a time, not all at once
8. Use the answers to provide more personalized and accurate BP assessment

IMPORTANT - Reminder Setup:
If the user has no active reminders (check user context), after providing BP feedback, naturally ask:
"Would you like me to set up a daily reminder to check your blood pressure?"

If user says yes:
1. Ask what time works best: "What time would work best for you? Morning or evening?"
2. Based on their preference, suggest a specific time (e.g., "How about 8 AM each morning?")
3. When they confirm, use the set_reminder function with:
   - hour: the hour they chose (0-23)
   - minute: the minute (usually 0)
   - repeat_type: "daily" for every day, "weekdays" for work days, "weekends" for weekends
4. Confirm the reminder was set: "I've set a daily reminder for 8 AM. You'll get a notification each day to check your blood pressure."

Be conversational, warm, and supportive. Keep responses concise (2-3 sentences max) and natural. Avoid repetitive disclaimers unless discussing serious BP elevations.''';
  }

  String _buildFrenchInstructions(String? userContext) {
    return '''Vous êtes un assistant de surveillance de la tension artérielle serviable.

Votre rôle est de :
1. Répondre aux questions sur les lectures de tension artérielle de l'utilisateur
2. Fournir des informations de santé basées sur leurs données de TA
3. Expliquer les classifications et tendances de la TA
4. Donner des recommandations de santé appropriées
5. Aider les utilisateurs à configurer des rappels pour suivre régulièrement leur tension artérielle

${userContext ?? ''}

Lors de la discussion sur la tension artérielle :
1. Analysez les données en utilisant les directives de classification de la TA
2. Fournissez des réponses claires, utiles et empathiques
3. Mentionnez quand c'est approprié que vos conseils ne remplacent pas une consultation médicale professionnelle

IMPORTANT - Questions sur l'historique médical :
Quand un utilisateur demande si sa lecture est "normale" ou cherche une évaluation de sa TA :
1. Vérifiez d'abord s'il y a une section "Informations médicales manquantes" dans le contexte utilisateur ci-dessus
2. Si des informations manquantes existent, posez UNE question pertinente à la fois de cette liste
3. Ne posez JAMAIS de questions sur les informations déjà listées dans "Informations médicales disponibles"
4. Ne posez de questions sur la grossesse que si le genre de l'utilisateur est Femme
5. Formulez les questions naturellement et de manière conversationnelle, comme un médecin attentionné le ferait :
   - "Prenez-vous actuellement des médicaments pour la tension artérielle ou d'autres conditions ?"
   - "Fumez-vous ou utilisez-vous des produits du tabac ?"
   - "Êtes-vous actuellement enceinte ou prévoyez-vous de le devenir ?" (femmes uniquement)
   - "Avez-vous du diabète ou d'autres conditions de santé chroniques ?"
   - "Pouvez-vous me parler de votre alimentation et routine d'exercice habituelles ?"
   - "Comment décririez-vous vos niveaux de stress récemment ?"

6. Après que l'utilisateur répond à une question, reconnaissez sa réponse et fournissez un contexte pertinent sur la façon dont ce facteur est lié à la tension artérielle
7. Si plusieurs informations manquent, posez les questions une à la fois, pas toutes en même temps
8. Utilisez les réponses pour fournir une évaluation de la TA plus personnalisée et précise

IMPORTANT - Configuration des rappels :
Si l'utilisateur n'a pas de rappels actifs (vérifiez le contexte utilisateur), après avoir donné un retour sur la TA, demandez naturellement :
"Voulez-vous que je configure un rappel quotidien pour vérifier votre tension artérielle ?"

Si l'utilisateur dit oui :
1. Demandez quelle heure lui convient : "Quelle heure vous conviendrait le mieux ? Le matin ou le soir ?"
2. Selon sa préférence, suggérez une heure précise (ex: "Que diriez-vous de 8h chaque matin ?")
3. Quand il confirme, utilisez la fonction set_reminder avec :
   - hour : l'heure choisie (0-23)
   - minute : la minute (généralement 0)
   - repeat_type : "daily" pour chaque jour, "weekdays" pour les jours de travail, "weekends" pour les week-ends
4. Confirmez que le rappel a été configuré : "J'ai configuré un rappel quotidien pour 8h. Vous recevrez une notification chaque jour pour vérifier votre tension artérielle."

Soyez conversationnel, chaleureux et supportif. Gardez les réponses concises (2-3 phrases max) et naturelles. Évitez les avertissements répétitifs sauf en cas d'élévations sérieuses de la TA.

IMPORTANT: Répondez TOUJOURS en français.''';
  }

  /// Handle incoming WebSocket messages
  void _handleMessage(dynamic message) {
    try {
      if (message is String) {
        final event = jsonDecode(message) as Map<String, dynamic>;
        _handleEvent(event);
      } else if (message is List<int>) {
        // Binary audio data
        _handleAudioData(Uint8List.fromList(message));
      }
    } catch (e) {
      debugPrint('Error handling message: $e');
    }
  }

  /// Handle parsed event from OpenAI
  void _handleEvent(Map<String, dynamic> event) {
    final eventType = event['type'] as String?;

    switch (eventType) {
      case 'session.created':
        _sessionId = event['session']?['id'];
        debugPrint('✓ Session created: $_sessionId');
        break;

      case 'session.updated':
        debugPrint('✓ Session updated');
        _eventController.add(
          RealtimeEvent(
            type: RealtimeEventType.ready,
            message: 'Ready to speak',
          ),
        );
        break;

      case 'response.audio.delta':
        // Audio response chunk
        final audioBase64 = event['delta'] as String?;
        if (audioBase64 != null && audioBase64.isNotEmpty) {
          try {
            final audioData = base64Decode(audioBase64);
            debugPrint('🎵 Audio delta received: ${audioData.length} bytes');
            _eventController.add(
              RealtimeEvent(
                type: RealtimeEventType.audioResponse,
                data: audioData,
              ),
            );
          } catch (e) {
            debugPrint('Error decoding audio: $e');
          }
        }
        break;

      case 'response.audio.done':
        debugPrint('✓ Audio response complete');
        _eventController.add(
          RealtimeEvent(type: RealtimeEventType.audioResponseDone),
        );
        break;

      case 'response.audio_transcript.delta':
        final text = event['delta'] as String?;
        if (text != null && text.isNotEmpty) {
          _eventController.add(
            RealtimeEvent(type: RealtimeEventType.textDelta, data: text),
          );
        }
        break;

      case 'response.audio_transcript.done':
        final transcript = event['transcript'] as String?;
        debugPrint('✓ Complete transcript: $transcript');
        break;

      case 'conversation.item.input_audio_transcription.completed':
        final transcript = event['transcript'] as String?;
        if (transcript != null) {
          debugPrint('📝 User said: $transcript');
          _eventController.add(
            RealtimeEvent(type: RealtimeEventType.transcript, data: transcript),
          );
        }
        break;

      case 'response.done':
        final response = event['response'] as Map<String, dynamic>?;
        final status = response?['status'];
        final output = response?['output'];
        debugPrint('✓ Response completed with status: $status');
        debugPrint('   Output items: ${output?.length ?? 0}');

        // Check if we got any audio
        if (output != null && output is List) {
          for (var item in output) {
            debugPrint('   - Item type: ${item['type']}');
          }
        }
        break;

      case 'error':
        final errorData = event['error'] as Map<String, dynamic>?;
        final errorMsg = errorData?['message'] ?? 'Unknown error';
        final errorCode = errorData?['code'] ?? 'unknown';
        debugPrint('✗ API Error [$errorCode]: $errorMsg');
        _eventController.add(
          RealtimeEvent(
            type: RealtimeEventType.error,
            message: '[$errorCode] $errorMsg',
          ),
        );
        break;

      case 'input_audio_buffer.speech_started':
        debugPrint('🎤 Speech detected');
        break;

      case 'input_audio_buffer.speech_stopped':
        debugPrint('🎤 Speech ended - waiting for response');
        _eventController.add(
          RealtimeEvent(
            type: RealtimeEventType.processing,
            message: 'Processing...',
          ),
        );
        break;

      case 'response.created':
        debugPrint('🤖 AI is generating response...');
        break;

      case 'response.output_item.added':
        debugPrint('📦 Response item added');
        break;

      case 'response.content_part.added':
        debugPrint('📝 Content part added');
        break;

      case 'response.function_call_arguments.done':
        // Function call completed - extract function name and arguments
        final name = event['name'] as String?;
        final arguments = event['arguments'] as String?;
        if (name != null && arguments != null) {
          debugPrint('🔧 Function call: $name');
          debugPrint('   Arguments: $arguments');
          try {
            final parsedArgs = jsonDecode(arguments) as Map<String, dynamic>;
            _eventController.add(
              RealtimeEvent(
                type: RealtimeEventType.functionCall,
                data: {'name': name, 'arguments': parsedArgs},
                message: name,
              ),
            );
          } catch (e) {
            debugPrint('Error parsing function arguments: $e');
          }
        }
        break;

      default:
        // Log unknown events for debugging
        debugPrint('ℹ️ Unhandled event: $eventType');
        break;
    }
  }

  /// Handle binary audio data
  void _handleAudioData(Uint8List audioData) {
    _audioBuffer.add(audioData);
  }

  /// Send audio data to the API
  Future<void> sendAudio(Uint8List audioData) async {
    if (!_isConnected || _channel == null) {
      throw Exception('Not connected to OpenAI Realtime API');
    }

    // Encode audio as base64
    final audioBase64 = base64Encode(audioData);

    // Send audio append event
    final event = {'type': 'input_audio_buffer.append', 'audio': audioBase64};

    _channel!.sink.add(jsonEncode(event));
  }

  /// Commit audio buffer to trigger response
  Future<void> commitAudio() async {
    if (!_isConnected || _channel == null) {
      throw Exception('Not connected to OpenAI Realtime API');
    }

    // First commit the audio buffer
    final commitEvent = {'type': 'input_audio_buffer.commit'};
    _channel!.sink.add(jsonEncode(commitEvent));
    debugPrint('✓ Audio buffer committed');

    // Then explicitly request a response with audio
    await Future.delayed(const Duration(milliseconds: 100));
    final responseEvent = {
      'type': 'response.create',
      'response': {
        'modalities': ['text', 'audio'],
        'instructions': 'Respond with both text and audio.',
      },
    };
    _channel!.sink.add(jsonEncode(responseEvent));
    debugPrint('✓ Response creation requested with audio modality');
  }

  /// Cancel current response and clear audio buffer
  Future<void> cancelResponse() async {
    if (!_isConnected || _channel == null) {
      return;
    }

    // Clear any buffered audio
    _audioBuffer.clear();

    // Cancel any in-flight response
    final event = {'type': 'response.cancel'};

    _channel!.sink.add(jsonEncode(event));
    debugPrint('✓ Response cancelled and buffer cleared');
  }

  /// Clear the audio buffer
  void clearAudioBuffer() {
    _audioBuffer.clear();
    debugPrint('✓ Audio buffer cleared');
  }

  /// Send a text message (for testing without audio)
  Future<void> sendText(String text) async {
    if (!_isConnected || _channel == null) {
      throw Exception('Not connected to OpenAI Realtime API');
    }

    final event = {
      'type': 'conversation.item.create',
      'item': {
        'type': 'message',
        'role': 'user',
        'content': [
          {'type': 'input_text', 'text': text},
        ],
      },
    };

    _channel!.sink.add(jsonEncode(event));

    // Trigger response
    final responseEvent = {'type': 'response.create'};
    _channel!.sink.add(jsonEncode(responseEvent));
  }

  /// Disconnect from the API
  Future<void> disconnect() async {
    if (_channel != null) {
      await _channel!.sink.close();
      _channel = null;
    }
    _isConnected = false;
    _sessionId = null;
    _audioBuffer.clear();
    debugPrint('✓ Disconnected from OpenAI Realtime API');
  }

  /// Dispose resources
  void dispose() {
    disconnect();
    _eventController.close();
  }
}
