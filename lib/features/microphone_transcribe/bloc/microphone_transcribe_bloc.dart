import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dart_openai/dart_openai.dart';
import 'package:arteria/env/env.dart';
import 'microphone_transcribe_event.dart';
import 'microphone_transcribe_state.dart';

class MicrophoneTranscribeBloc
    extends Bloc<MicrophoneTranscribeEvent, MicrophoneTranscribeState> {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  String? _audioPath;
  Timer? _recordingTimer;
  StreamSubscription? _audioPlayerSubscription;

  // OpenAI Configuration
  static const String _openAIModel = 'gpt-4.1-mini-2025-04-14';
  static const String _whisperModel = 'whisper-1';
  static const String _ttsModel = 'tts-1';
  static const String _ttsVoice = 'alloy';

  String _selectedLanguage = 'en';
  Map<String, dynamic>? _userProfile;


  MicrophoneTranscribeBloc({String language = 'en'}) : _selectedLanguage = language, super(const MicrophoneTranscribeInitialState()) {
    on<StartRecordingEvent>(_onStartRecording);
    on<StopRecordingEvent>(_onStopRecording);
    on<RecordingTickEvent>(_onRecordingTick);
    on<TranscriptionCompletedEvent>(_onTranscriptionCompleted);
    on<TranscriptionFailedEvent>(_onTranscriptionFailed);
    on<LLMAnalysisStartedEvent>(_onLLMAnalysisStarted);
    on<LLMAnalysisCompletedEvent>(_onLLMAnalysisCompleted);
    on<LLMAnalysisFailedEvent>(_onLLMAnalysisFailed);
    on<TTSPlaybackStartedEvent>(_onTTSPlaybackStarted);
    on<TTSPlaybackCompletedEvent>(_onTTSPlaybackCompleted);
    on<TTSPlaybackFailedEvent>(_onTTSPlaybackFailed);
    on<AutoSaveTriggeredEvent>(_onAutoSaveTriggered);
    on<ResetStateEvent>(_onResetState);

    _initialize();
  }

  Future<void> _initialize() async {
    await _recorder.openRecorder();
    await _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists) return;

      final data = doc.data();
      if (data == null) return;

      _userProfile = {
        'age': data['age'] as int?,
        'gender': data['gender'] as String?,
        'weight_kg': (data['weight'] as num?)?.toDouble(),
        'height_cm': (data['height'] as num?)?.toDouble(),
        'smoker': data['smoker'] as bool?,
        'is_pregnant': data['isPregnant'] as bool?,
        'has_diabetes': data['hasDiabetes'] as bool?,
        'medications': data['medications'] as String?,
        'physical_activity': data['physicalActivity'] as String?,
      };
    } catch (e) {
      debugPrint('❌ Failed to load user profile: $e');
    }
  }

  Future<void> _onStartRecording(
    StartRecordingEvent event,
    Emitter<MicrophoneTranscribeState> emit,
  ) async {
    try {
      final dir = await getTemporaryDirectory();
      // Use .wav extension for full backend compatibility (OpenAI Whisper + librosa)
      _audioPath =
          '${dir.path}/bp_recording_${DateTime.now().millisecondsSinceEpoch}.wav';

      // Use pcm16WAV codec which produces WAV files natively supported by python backends
      await _recorder.startRecorder(toFile: _audioPath, codec: Codec.pcm16WAV);

      emit(const RecordingState(secondsElapsed: 0));

      // Start timer
      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (state is RecordingState) {
          final currentState = state as RecordingState;
          add(RecordingTickEvent(currentState.secondsElapsed + 1));
        }
      });
    } catch (e) {
      emit(
        ErrorState(
          errorMessage: e.toString(),
          displayText: 'Recording error: ${e.toString()}',
        ),
      );
    }
  }

  void _onRecordingTick(
    RecordingTickEvent event,
    Emitter<MicrophoneTranscribeState> emit,
  ) {
    if (state is RecordingState) {
      emit(RecordingState(secondsElapsed: event.secondsElapsed));
    }
  }

  Future<void> _onStopRecording(
    StopRecordingEvent event,
    Emitter<MicrophoneTranscribeState> emit,
  ) async {
    try {
      _recordingTimer?.cancel();
      await _recorder.stopRecorder();

      if (_audioPath != null && await File(_audioPath!).exists()) {
        emit(const ProcessingTranscriptionState());
        await _transcribeAudio();
      } else {
        emit(
          const ErrorState(
            errorMessage: 'No audio recorded',
            displayText: 'No audio recorded.',
          ),
        );
      }
    } catch (e) {
      emit(
        ErrorState(
          errorMessage: e.toString(),
          displayText: 'Error stopping recording: ${e.toString()}',
        ),
      );
    }
  }

  Future<void> _transcribeAudio() async {
    final openaiKey = Env.openaiApiKey;
    if (openaiKey.isEmpty) {
      add(const TranscriptionFailedEvent('OpenAI API key missing'));
      return;
    }

    try {
      final audioFile = File(_audioPath!);
      final bytes = await audioFile.readAsBytes();
      if (bytes.isEmpty) {
        add(const TranscriptionFailedEvent('Empty audio file'));
        return;
      }

      debugPrint('🎤 Transcribing audio: ${bytes.length} bytes');

      // Use OpenAI Whisper API
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.openai.com/v1/audio/transcriptions'),
      );
      
      request.headers['Authorization'] = 'Bearer $openaiKey';
      request.fields['model'] = _whisperModel;
      request.fields['language'] = _selectedLanguage;
      request.fields['response_format'] = 'text';
      
      // CRITICAL: Include contentType for OpenAI to accept the file
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: 'audio.m4a',
          contentType: MediaType('audio', 'mp4'),
        ),
      );

      final streamedResponse = await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('📝 OpenAI Whisper response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final text = response.body.trim();
        if (text.isEmpty) {
          add(const TranscriptionFailedEvent('No speech detected'));
        } else {
          debugPrint('✅ Transcription: $text');
          add(TranscriptionCompletedEvent(text));
        }
      } else {
        debugPrint('❌ OpenAI Whisper error: ${response.body}');
        add(
          TranscriptionFailedEvent(
            'Transcription failed (${response.statusCode}): ${response.body}',
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Transcription exception: $e');
      add(TranscriptionFailedEvent('Transcription error: ${e.toString()}'));
    } finally {
      // Clean up audio file
      if (_audioPath != null && await File(_audioPath!).exists()) {
        try {
          await File(_audioPath!).delete();
        } catch (_) {}
      }
    }
  }

  Future<void> _onTranscriptionCompleted(
    TranscriptionCompletedEvent event,
    Emitter<MicrophoneTranscribeState> emit,
  ) async {
    // Parse blood pressure from transcribed text
    await _parseAndAnalyze(event.transcribedText, emit);
  }

  void _onTranscriptionFailed(
    TranscriptionFailedEvent event,
    Emitter<MicrophoneTranscribeState> emit,
  ) {
    emit(ErrorState(errorMessage: event.error, displayText: event.error));
  }

  Future<void> _parseAndAnalyze(
    String text,
    Emitter<MicrophoneTranscribeState> emit,
  ) async {
    // First, parse BP values
    Map<String, int> parsedBP = await _parseBloodPressure(text);

    // Emit reasoning state
    emit(
      ReasoningState(
        systolic: parsedBP['systolic'],
        diastolic: parsedBP['diastolic'],
      ),
    );

    // Start LLM analysis
    add(const LLMAnalysisStartedEvent());
    await _analyzeWithLLM(parsedBP);
  }

  Future<Map<String, int>> _parseBloodPressure(String text) async {
    final openaiKey = Env.openaiApiKey;
    if (openaiKey.isEmpty) {
      return _manualParse(text);
    }

    try {
      OpenAI.apiKey = openaiKey;

      final completion = await OpenAI.instance.chat.create(
        model: 'gpt-4o-mini',
        temperature: 0.1,
        maxTokens: 80,
        messages: [
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.system,
            content: [
              OpenAIChatCompletionChoiceMessageContentItemModel.text(
                'Extract systolic and diastolic from text. Respond only with JSON: {"systolic":120,"diastolic":80}.',
              ),
            ],
          ),
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.user,
            content: [
              OpenAIChatCompletionChoiceMessageContentItemModel.text(text),
            ],
          ),
        ],
      );

      final raw = completion.choices.first.message.content
          ?.map((c) => c.text)
          .join(' ')
          .trim();

      Map<String, dynamic> parsed = {};
      try {
        parsed = jsonDecode(raw ?? '');
      } catch (_) {
        return _manualParse(text);
      }

      int sys = (parsed['systolic'] as num?)?.toInt() ?? 120;
      int dia = (parsed['diastolic'] as num?)?.toInt() ?? 80;
      sys = sys.clamp(70, 250);
      dia = dia.clamp(40, 150);

      return {'systolic': sys, 'diastolic': dia};
    } catch (e) {
      return _manualParse(text);
    }
  }

  Map<String, int> _manualParse(String text) {
    final match = RegExp(r'(\d{2,3})\s*[\/-]\s*(\d{2,3})').firstMatch(text);
    if (match != null) {
      int sys = int.tryParse(match.group(1)!) ?? 120;
      int dia = int.tryParse(match.group(2)!) ?? 80;
      sys = sys.clamp(70, 250);
      dia = dia.clamp(40, 150);
      return {'systolic': sys, 'diastolic': dia};
    }
    return {'systolic': 120, 'diastolic': 80};
  }

  Future<void> _onLLMAnalysisStarted(
    LLMAnalysisStartedEvent event,
    Emitter<MicrophoneTranscribeState> emit,
  ) async {
    // State already set in _parseAndAnalyze
  }

  Future<void> _analyzeWithLLM(Map<String, int> parsedBP) async {
    final sys = parsedBP['systolic'] ?? 120;
    final dia = parsedBP['diastolic'] ?? 80;
    final openaiKey = Env.openaiApiKey;

    if (openaiKey.isEmpty) {
      add(const LLMAnalysisFailedEvent('OpenAI API key missing'));
      return;
    }

    try {
      // Build user context from profile
      String userContext = '';
      if (_userProfile != null) {
        final parts = <String>[];
        if (_userProfile!['age'] != null) parts.add('Age: ${_userProfile!['age']}');
        if (_userProfile!['gender'] != null) parts.add('Gender: ${_userProfile!['gender']}');
        if (_userProfile!['smoker'] == true) parts.add('Smoker');
        if (_userProfile!['has_diabetes'] == true) parts.add('Has diabetes');
        if (_userProfile!['is_pregnant'] == true) parts.add('Pregnant');
        if (_userProfile!['medications'] != null && 
            _userProfile!['medications'].toString().isNotEmpty) {
          parts.add('Medications: ${_userProfile!['medications']}');
        }
        userContext = parts.join(', ');
      }

      // Build system prompt with AHA/ACC 2025 guidelines
      final systemPrompt = '''You are Arteria, a compassionate medical assistant specializing in blood pressure.

BLOOD PRESSURE CLASSIFICATION (AHA/ACC 2025 Guidelines - applies uniformly to all adults 18+):
- Normal: Systolic ≤120 AND Diastolic ≤80 mmHg (120/80 is Normal)
- Elevated: Systolic 121-129 AND Diastolic ≤80 mmHg (e.g., 125/78)
- Stage 1 Hypertension: Systolic 130-139 OR Diastolic 81-89 mmHg (e.g., 130/82, 135/85)
- Stage 2 Hypertension: Systolic ≥140 OR Diastolic ≥90 mmHg
- Hypertensive Crisis: Systolic >180 OR Diastolic >120 mmHg (EMERGENCY)

IMPORTANT: 120/80 mmHg is classified as NORMAL, not elevated or hypertensive.

Respond in JSON format:
{
  "classification": "Normal/Elevated/Stage 1 Hypertension/Stage 2 Hypertension/Hypertensive Crisis",
  "severity": "normal/elevated/high/critical",
  "analysis": "Brief, empathetic analysis (2-3 sentences)",
  "recommendations": ["Recommendation 1", "Recommendation 2"]
}

User context: ${userContext.isNotEmpty ? userContext : 'None provided'}
Language: ${_selectedLanguage == 'fr' ? 'French' : 'English'}''';

      OpenAI.apiKey = openaiKey;

      final completion = await OpenAI.instance.chat.create(
        model: _openAIModel,
        temperature: 0.7,
        maxTokens: 500,
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
              OpenAIChatCompletionChoiceMessageContentItemModel.text(
                'My blood pressure reading is $sys/$dia mmHg. Please analyze.',
              ),
            ],
          ),
        ],
      );

      final raw = completion.choices.first.message.content
          ?.map((c) => c.text)
          .join(' ')
          .trim() ?? '';

      // Parse JSON response
      Map<String, dynamic> parsed = {};
      try {
        // Extract JSON from response (handle markdown code blocks)
        String jsonStr = raw;
        if (raw.contains('```json')) {
          jsonStr = raw.split('```json')[1].split('```')[0].trim();
        } else if (raw.contains('```')) {
          jsonStr = raw.split('```')[1].split('```')[0].trim();
        }
        parsed = jsonDecode(jsonStr);
      } catch (_) {
        // Fallback if JSON parsing fails
        parsed = {
          'classification': _classifyBP(sys, dia),
          'severity': _getSeverity(sys, dia),
          'analysis': raw,
          'recommendations': ['Consult your healthcare provider.'],
        };
      }

      final analysis = (parsed['analysis'] ?? raw).toString();
      final category = (parsed['classification'] ?? _classifyBP(sys, dia)).toString();
      final severity = (parsed['severity'] ?? _getSeverity(sys, dia)).toString();

      add(
        LLMAnalysisCompletedEvent(
          analysisText: analysis,
          systolic: sys,
          diastolic: dia,
          category: category,
          severity: severity,
          followUpQuestions: [],
        ),
      );
    } on SocketException {
      add(
        const LLMAnalysisFailedEvent(
          'Network error — please check your internet connection.',
        ),
      );
    } on TimeoutException {
      add(
        const LLMAnalysisFailedEvent(
          'The server took too long to respond. Try again.',
        ),
      );
    } catch (e) {
      add(LLMAnalysisFailedEvent('An unexpected error occurred: $e'));
    }
  }

  /// Classifies blood pressure according to AHA/ACC 2025 guidelines.
  /// Normal: ≤120/≤80 (includes 120/80)
  /// Elevated: 121-129 AND ≤80
  /// Stage 1: ≥130 OR 81-89 diastolic
  /// Stage 2: ≥140 OR ≥90
  String _classifyBP(int sys, int dia) {
    // Hypertensive Crisis - EMERGENCY
    if (sys > 180 || dia > 120) return 'Hypertensive Crisis';
    // Stage 2 Hypertension
    if (sys >= 140 || dia >= 90) return 'Stage 2 Hypertension';
    // Stage 1 Hypertension (sys ≥130 OR dia 81-89)
    if (sys >= 130 || dia > 80) return 'Stage 1 Hypertension';
    // Elevated (sys 121-129 AND dia ≤80)
    if (sys > 120 && dia <= 80) return 'Elevated';
    // Normal (sys ≤120 AND dia ≤80, includes 120/80)
    return 'Normal';
  }

  String _getSeverity(int sys, int dia) {
    if (sys > 180 || dia > 120) return 'critical';
    if (sys >= 140 || dia >= 90) return 'high';
    // Stage 1: sys ≥130 OR dia > 80
    if (sys >= 130 || dia > 80) return 'elevated';
    // Normal includes 120/80
    return 'normal';
  }

  Future<void> _onLLMAnalysisCompleted(
    LLMAnalysisCompletedEvent event,
    Emitter<MicrophoneTranscribeState> emit,
  ) async {
    // Start TTS playback - emit PlayingTTSState first
    if (event.analysisText.isNotEmpty) {
      emit(
        PlayingTTSState(
          analysisText: event.analysisText,
          systolic: event.systolic,
          diastolic: event.diastolic,
          category: event.category,
          severity: event.severity,
        ),
      );

      await _fetchSpeakAndPlay(event.analysisText);
    } else {
      // No TTS, go straight to completed
      emit(
        CompletedState(
          analysisText: event.analysisText,
          systolic: event.systolic,
          diastolic: event.diastolic,
          category: event.category,
          severity: event.severity,
        ),
      );
      // Trigger auto-save after 2 seconds
      await Future.delayed(const Duration(seconds: 2));
      add(const AutoSaveTriggeredEvent());
    }
  }

  void _onLLMAnalysisFailed(
    LLMAnalysisFailedEvent event,
    Emitter<MicrophoneTranscribeState> emit,
  ) {
    emit(
      ErrorState(errorMessage: event.error, displayText: '❌ ${event.error}'),
    );
  }

  Future<void> _fetchSpeakAndPlay(String text) async {
    final openaiKey = Env.openaiApiKey;
    if (openaiKey.isEmpty) {
      add(const TTSPlaybackFailedEvent('OpenAI API key missing'));
      return;
    }

    try {
      // Use OpenAI TTS API
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/audio/speech'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $openaiKey',
        },
        body: jsonEncode({
          'model': _ttsModel,
          'input': text,
          'voice': _ttsVoice,
          'response_format': 'mp3',
          'speed': 1.0,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        add(TTSPlaybackFailedEvent('TTS failed: ${response.statusCode}'));
        return;
      }

      final bytes = response.bodyBytes;
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/tts_${DateTime.now().millisecondsSinceEpoch}.mp3',
      );
      await file.writeAsBytes(bytes);

      await _audioPlayer.setFilePath(file.path);
      await _audioPlayer.play();

      // Listen for playback completion
      _audioPlayerSubscription?.cancel();
      _audioPlayerSubscription = _audioPlayer.playerStateStream.listen((
        playerState,
      ) async {
        if (playerState.processingState == ProcessingState.completed) {
          try {
            if (await file.exists()) await file.delete();
          } catch (_) {}
          add(const TTSPlaybackCompletedEvent());
          _audioPlayerSubscription?.cancel();
        }
      });
    } catch (e) {
      add(TTSPlaybackFailedEvent('TTS error: $e'));
    }
  }

  void _onTTSPlaybackStarted(
    TTSPlaybackStartedEvent event,
    Emitter<MicrophoneTranscribeState> emit,
  ) {
    // Handled in _onLLMAnalysisCompleted
  }

  Future<void> _onTTSPlaybackCompleted(
    TTSPlaybackCompletedEvent event,
    Emitter<MicrophoneTranscribeState> emit,
  ) async {
    // Transition to completed state
    if (state is PlayingTTSState) {
      final playingState = state as PlayingTTSState;
      emit(
        CompletedState(
          analysisText: playingState.analysisText,
          systolic: playingState.systolic,
          diastolic: playingState.diastolic,
          category: playingState.category,
          severity: playingState.severity,
        ),
      );

      // Wait 2 seconds then auto-save
      await Future.delayed(const Duration(seconds: 2));
      add(const AutoSaveTriggeredEvent());
    }
  }

  void _onTTSPlaybackFailed(
    TTSPlaybackFailedEvent event,
    Emitter<MicrophoneTranscribeState> emit,
  ) {
    emit(
      ErrorState(
        errorMessage: event.error,
        displayText: 'TTS Playback Error: ${event.error}',
      ),
    );
  }

  Future<void> _onAutoSaveTriggered(
    AutoSaveTriggeredEvent event,
    Emitter<MicrophoneTranscribeState> emit,
  ) async {
    if (state is CompletedState) {
      final completedState = state as CompletedState;
      emit(
        SavingAndReturningState(
          systolic: completedState.systolic,
          diastolic: completedState.diastolic,
        ),
      );

      // Save to Firestore
      await _saveBPReading(completedState.systolic, completedState.diastolic);
    }
  }

  Future<void> _saveBPReading(int systolic, int diastolic) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('bp_readings')
          .add({
            'systolic': systolic,
            'diastolic': diastolic,
            'date': Timestamp.now(),
          });
    } catch (e) {
      debugPrint('Failed to save BP reading: $e');
    }
  }

  void _onResetState(
    ResetStateEvent event,
    Emitter<MicrophoneTranscribeState> emit,
  ) {
    emit(const MicrophoneTranscribeInitialState());
  }

  @override
  Future<void> close() {
    _recordingTimer?.cancel();
    _audioPlayerSubscription?.cancel();
    _recorder.closeRecorder();
    _audioPlayer.dispose();
    return super.close();
  }

  // Helper to update language (can be called from UI)
  void setLanguage(String language) {
    _selectedLanguage = language;
  }
}
