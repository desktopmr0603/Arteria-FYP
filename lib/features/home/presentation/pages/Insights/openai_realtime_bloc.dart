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
  bool _isDisposed = false;
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
          _emitEvent(
            RealtimeEvent(
              type: RealtimeEventType.error,
              message: 'Connection error: $error',
            ),
          );
          _isConnected = false;
        },
        onDone: () {
          debugPrint('WebSocket connection closed');
          _emitEvent(RealtimeEvent(type: RealtimeEventType.disconnected));
          _isConnected = false;
        },
      );

      _isConnected = true;
      _emitEvent(RealtimeEvent(type: RealtimeEventType.connected));

      // Configure session with instructions
      await _configureSession(userContext: userContext);

      debugPrint('✓ Connected to OpenAI Realtime API');
    } catch (e) {
      debugPrint('Error connecting to OpenAI Realtime API: $e');
      _emitEvent(
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
        'input_audio_transcription': {
          'model': 'whisper-1',
          'language': language,
        },
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
            'description':
                'Set a reminder for the user to take their blood pressure reading',
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
          {
            'type': 'function',
            'name': 'open_whatif_simulator',
            'description':
                'Opens the What-If lifestyle simulator where users can explore how lifestyle changes (exercise, diet, salt reduction) could affect their blood pressure. Use when user asks about scenarios, predictions, or what would happen if they made lifestyle changes.',
            'parameters': {'type': 'object', 'properties': {}, 'required': []},
          },
          {
            'type': 'function',
            'name': 'record_bp_reading',
            'description':
                'Save a new blood pressure reading for the user. Use when they say something like "My BP is 120 over 80" or "Record my blood pressure as 130/85".',
            'parameters': {
              'type': 'object',
              'properties': {
                'systolic': {
                  'type': 'integer',
                  'description':
                      'The systolic blood pressure value (top number)',
                },
                'diastolic': {
                  'type': 'integer',
                  'description':
                      'The diastolic blood pressure value (bottom number)',
                },
              },
              'required': ['systolic', 'diastolic'],
            },
          },
          {
            'type': 'function',
            'name': 'add_medication',
            'description':
                'Add a new medication to the user\'s medication list. Use when the user mentions they are taking a new medication, like "I take metformin" or "I am on lisinopril".',
            'parameters': {
              'type': 'object',
              'properties': {
                'name': {
                  'type': 'string',
                  'description': 'The name of the medication',
                },
                'dosage': {
                  'type': 'string',
                  'description':
                      'The dosage of the medication (e.g., "10mg", "1 tablet")',
                },
                'frequency': {
                  'type': 'string',
                  'description': 'How often to take the medication',
                  'enum': [
                    'onceDaily',
                    'twiceDaily',
                    'threeTimesDaily',
                    'asNeeded',
                    'weekly',
                  ],
                },
                'instructions': {
                  'type': 'string',
                  'description':
                      'Special instructions for the medication (e.g., "Take with food", "Avoid grapefruit")',
                },
              },
              'required': ['name', 'dosage', 'frequency'],
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
  }

  String _buildEnglishInstructions(String? userContext) {
    return '''You are a caring and professional medical assistant specializing in hypertension.
        
Your role is to:
1. Answer questions about the user's blood pressure readings with medical empathy.
2. Provide health information based on their BP data using official guidelines.
3. Explain BP classifications and trends clearly.
4. Give appropriate lifestyle recommendations (diet, exercise, stress management).
5. Help users proactively manage their medications and reminders.

${userContext ?? ''}

When discussing blood pressure:
1. Use a warm, professional, and supportive tone—like a reassuring doctor.
2. Provide clear, helpful, and empathetic responses.
3. Mention when appropriate that your advice helps track trends but doesn't replace professional medical consultation.

IMPORTANT - Medical History Questions:
When a user asks if their reading is "normal" or seeks assessment of their BP:
1. First, check if there is a "Missing Medical Information" section in the user context above.
2. If missing information exists, ask ONE relevant question at a time from that list.
3. Phrase questions naturally and conversationally: "To give you better context, are you currently taking any medications for blood pressure?"

IMPORTANT - Blood Pressure Recording:
When a user provides their blood pressure reading, use the record_bp_reading function.
After recording:
1. "I've logged that for you. A reading of [X/Y] is categorized as [Category]."
2. Provide a brief, supportive comment or ask a relevant medical history question.

IMPORTANT - Adding Medications:
When a user mentions they are taking a medication:
1. DO NOT call add_medication until you have: Name, Dosage, and Frequency.
2. If any info is missing, ask: "To add this correctly, what is the dosage and how often do you take it?"
3. MANDATORY CONFIRMATION: Once you have all details, ask: "I'll add [Name] [Dosage], taking it [Frequency]. Is that correct?"
4. ONLY call add_medication after the user confirms "Yes" or equivalent.
5. If the user says they already take it or it's a duplicate, do not call the tool.
6. After addition, offer a reminder as usual.

IMPORTANT - Reminder Setup:
If the user says yes to a reminder (for BP or Medication):
1. Ask for a specific time: "What time works best for you? Perhaps 8:00 AM?"
2. When confirmed, use the set_reminder function.
3. Reassure the user: "Excellent. I'll make sure you get a notification at [Time] every day."

IMPORTANT - What-If Lifestyle Simulator:
When discussing lifestyle changes, naturally offer the simulator:
"It's fascinating how small changes add up. Would you like to see a simulation of how [Topic] could lower your blood pressure over time?"

Be natural, empathetic, and concise. Avoid repetitive "as an AI" statements. Talk like a real collaborator in their health journey.''';
  }

  String _buildFrenchInstructions(String? userContext) {
    return '''Vous êtes un assistant médical attentionné et professionnel, spécialisé dans l'hypertension.

Votre rôle est de :
1. Répondre aux questions sur les lectures de tension artérielle avec empathie médicale.
2. Fournir des informations de santé basées sur leurs données selon les directives officielles.
3. Expliquer les classifications et tendances de façon claire.
4. Donner des recommandations appropriées sur le mode de vie (alimentation, exercice, stress).
5. Aider les utilisateurs à gérer activement leurs médicaments et rappels.

${userContext ?? ''}

Lors de la discussion :
1. Utilisez un ton chaleureux, professionnel et encourageant—comme un médecin rassurant.
2. Mentionnez que vos conseils aident à suivre les tendances mais ne remplacent pas une consultation médicale.

IMPORTANT - Historique Médical :
Si des informations manquent dans le contexte :
1. Posez UNE question pertinente à la fois.
2. Formulez-la naturellement : "Pour mieux vous conseiller, prenez-vous actuellement des médicaments pour la tension ?"

IMPORTANT - Enregistrement de la Tension :
Lorsqu'un utilisateur donne sa mesure, utilisez record_bp_reading.
Après l'enregistrement :
1. "C'est enregistré. Une lecture de [X/Y] est classée comme [Catégorie]."
2. Ajoutez un commentaire de soutien ou posez une question sur l'historique.

IMPORTANT - Ajout de Médicaments :
1. NE JAMAIS appeler add_medication tant que vous n'avez pas : Nom, Dosage, et Fréquence.
2. S'il manque des infos, demandez : "Pour l'ajouter correctement, quel est le dosage et à quelle fréquence le prenez-vous ?"
3. CONFIRMATION OBLIGATOIRE : Une fois les détails obtenus, demandez : "Je vais ajouter [Nom] [Dosage], avec une fréquence [Fréquence]. Est-ce correct ?"
4. Appelez add_medication SEULEMENT après confirmation de l'utilisateur.
5. Si l'utilisateur dit qu'il le prend déjà ou que c'est un doublon, n'appelez pas l'outil.
6. Après l'ajout, proposez un rappel comme d'habitude.

IMPORTANT - Configuration des Rappels :
Si l'utilisateur accepte un rappel :
1. Demandez une heure précise : "Quelle heure vous convient le mieux ? Peut-être 8h00 ?"
2. Utilisez ensuite la fonction set_reminder.
3. Rassurez l'utilisateur : "Parfait. Je veillerai à ce que vous receviez une notification à [Heure] chaque jour."

IMPORTANT - Simulateur de Scénarios (What-If) :
Proposez naturellement le simulateur :
"C'est fascinant de voir comment de petits changements s'accumulent. Voulez-vous voir une simulation de l'impact de [Sujet] sur votre tension ?"

Soyez naturel, empathique et concis. Parlez comme un véritable partenaire de leur parcours de santé.
IMPORTANT : Répondez TOUJOURS en français.''';
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
        _emitEvent(
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
            _emitEvent(
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
        _emitEvent(RealtimeEvent(type: RealtimeEventType.audioResponseDone));
        break;

      case 'response.audio_transcript.delta':
        final text = event['delta'] as String?;
        if (text != null && text.isNotEmpty) {
          _emitEvent(
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
          _emitEvent(
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
        _emitEvent(
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
        _emitEvent(
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
            _emitEvent(
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

  /// Safely emit an event only if not disposed
  void _emitEvent(RealtimeEvent event) {
    if (!_isDisposed && !_eventController.isClosed) {
      _eventController.add(event);
    }
  }

  /// Dispose resources
  void dispose() {
    _isDisposed = true;
    _eventController.close();
    disconnect();
  }
}
