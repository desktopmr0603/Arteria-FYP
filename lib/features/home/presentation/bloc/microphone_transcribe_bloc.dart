import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:http/http.dart' as http;
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

  // Endpoints
  static const String _whisperEndpoint =
      'https://api.runpod.ai/v2/qpo2u2i4x2rutp/runsync';
  static const String _apiBaseUrl = 'https://arteriamain.share.zrok.io';
  static String get _fastApiEndpoint => '$_apiBaseUrl/analyze/smart'; // 2025: LangGraph + RAG
  static String get _speakEndpoint => '$_apiBaseUrl/speak';

  String _selectedLanguage = 'en';
  Map<String, dynamic>? _userProfile;
  final List<Map<String, String>> _conversationHistory = [];

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
      print('❌ Failed to load user profile: $e');
    }
  }

  Future<void> _onStartRecording(
    StartRecordingEvent event,
    Emitter<MicrophoneTranscribeState> emit,
  ) async {
    try {
      final dir = await getTemporaryDirectory();
      _audioPath =
          '${dir.path}/bp_recording_${DateTime.now().millisecondsSinceEpoch}.aac';

      bool supported = await _recorder.isEncoderSupported(Codec.aacADTS);
      final codec = supported ? Codec.aacADTS : Codec.aacMP4;

      await _recorder.startRecorder(toFile: _audioPath, codec: codec);

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
    final runpodKey = Env.runpodApiKey;
    if (runpodKey.isEmpty) {
      add(const TranscriptionFailedEvent('RunPod API key missing'));
      return;
    }

    try {
      final bytes = await File(_audioPath!).readAsBytes();
      if (bytes.isEmpty) {
        add(const TranscriptionFailedEvent('Empty audio file'));
        return;
      }

      final response = await http
          .post(
            Uri.parse(_whisperEndpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $runpodKey',
            },
            body: jsonEncode({
              'input': {
                'audio_base64': base64Encode(bytes),
                'model': 'turbo',
                'transcription': 'plain_text',
                'language': _selectedLanguage,
              },
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = (data['output']?['transcription'] as String?)?.trim();
        if (text == null || text.isEmpty) {
          add(const TranscriptionFailedEvent('No speech detected'));
        } else {
          add(TranscriptionCompletedEvent(text));
        }
      } else {
        add(
          TranscriptionFailedEvent(
            'Transcription failed (${response.statusCode})',
          ),
        );
      }
    } catch (e) {
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

    try {
      final Map<String, dynamic> userProfilePayload = {};

      if (_userProfile != null) {
        if (_userProfile!['age'] != null) {
          userProfilePayload['age'] = _userProfile!['age'];
        }
        if (_userProfile!['gender'] != null) {
          userProfilePayload['gender'] = _userProfile!['gender'];
        }
        if (_userProfile!['weight_kg'] != null) {
          userProfilePayload['weight_kg'] = _userProfile!['weight_kg'];
        }
        if (_userProfile!['height_cm'] != null) {
          userProfilePayload['height_cm'] = _userProfile!['height_cm'];
        }
        if (_userProfile!['smoker'] != null) {
          userProfilePayload['smoker'] = _userProfile!['smoker'];
        }
        if (_userProfile!['is_pregnant'] != null) {
          userProfilePayload['is_pregnant'] = _userProfile!['is_pregnant'];
        }
        if (_userProfile!['has_diabetes'] != null) {
          userProfilePayload['has_diabetes'] = _userProfile!['has_diabetes'];
        }
        if (_userProfile!['medications'] != null &&
            _userProfile!['medications'].toString().isNotEmpty) {
          userProfilePayload['medications'] = _userProfile!['medications'];
        }
        if (_userProfile!['physical_activity'] != null &&
            _userProfile!['physical_activity'].toString().isNotEmpty) {
          userProfilePayload['physical_activity'] =
              _userProfile!['physical_activity'];
        }
      }

      final requestBody = {
        'bp_reading': '$sys/$dia',
        'user_profile': userProfilePayload.isEmpty ? null : userProfilePayload,
        'conversation_history': _conversationHistory,
        'language': _selectedLanguage,
      };

      final response = await http
          .post(
            Uri.parse(_fastApiEndpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final analysis = (data['analysis_text'] ?? '').toString().trim();
        final questions =
            (data['follow_up_questions'] as List?)
                ?.map((q) => q.toString().trim())
                .where((q) => q.isNotEmpty)
                .toList() ??
            [];
        final category = (data['category'] ?? 'unknown').toString();
        final severity = (data['severity'] ?? 'normal').toString();

        final systolic = data['systolic'] ?? sys;
        final diastolic = data['diastolic'] ?? dia;

        add(
          LLMAnalysisCompletedEvent(
            analysisText: analysis,
            systolic: systolic,
            diastolic: diastolic,
            category: category,
            severity: severity,
            followUpQuestions: questions,
          ),
        );
      } else {
        add(
          LLMAnalysisFailedEvent(
            'Analysis failed (status ${response.statusCode})',
          ),
        );
      }
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
    try {
      final uri = Uri.parse(_speakEndpoint);
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text, 'language': _selectedLanguage}),
      );

      if (resp.statusCode != 200) {
        add(TTSPlaybackFailedEvent('TTS server responded ${resp.statusCode}'));
        return;
      }

      final bytes = resp.bodyBytes;
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
      print('Failed to save BP reading: $e');
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
