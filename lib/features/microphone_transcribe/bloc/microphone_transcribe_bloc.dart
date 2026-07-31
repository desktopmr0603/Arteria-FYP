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
import 'package:arteria/services/health_notification_service.dart';
import 'package:arteria/l10n/app_localizations.dart';
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

  /// Readings taken within this window of one another are treated as a single
  /// measurement session and averaged, following AHA guidance (take at least
  /// two readings 1–2 minutes apart and average them for an accurate number).
  static const Duration _sessionWindow = Duration(minutes: 10);

  /// The verbatim reading the user just spoke. Stored separately from the
  /// session average so history keeps every real measurement and a later
  /// re-aggregation never double-counts an average.
  int? _pendingRawSys;
  int? _pendingRawDia;

  /// Number of readings (including the new one) folded into the current
  /// analysis. 1 means a lone reading was used exactly as spoken.
  int _sessionCount = 1;

  /// Localizations for user-facing messages (errors, category labels).
  /// Injected from the page where a BuildContext is available.
  final AppLocalizations _l10n;

  MicrophoneTranscribeBloc({
    required AppLocalizations l10n,
    String language = 'en',
  }) : _l10n = l10n,
       _selectedLanguage = language,
       super(const MicrophoneTranscribeInitialState()) {
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
          displayText: _l10n.micRecordingError,
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
          ErrorState(
            errorMessage: 'No audio recorded',
            displayText: _l10n.micNoAudioRecorded,
          ),
        );
      }
    } catch (e) {
      emit(
        ErrorState(
          errorMessage: e.toString(),
          displayText: _l10n.micRecordingError,
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

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 60),
      );
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('OpenAI Whisper response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final text = response.body.trim();
        if (text.isEmpty) {
          add(const TranscriptionFailedEvent('No speech detected'));
        } else {
          debugPrint('Transcription: $text');
          add(TranscriptionCompletedEvent(text));
        }
      } else {
        debugPrint('OpenAI Whisper error: ${response.body}');
        add(
          TranscriptionFailedEvent(
            'Transcription failed (${response.statusCode}): ${response.body}',
          ),
        );
      }
    } catch (e) {
      debugPrint('Transcription exception: $e');
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
    // Map technical failures to a localized, user-friendly message while
    // keeping the raw error for debugging.
    final bool noSpeech =
        event.error.toLowerCase().contains('no speech') ||
        event.error.toLowerCase().contains('empty audio');
    emit(
      ErrorState(
        errorMessage: event.error,
        displayText: noSpeech
            ? _l10n.micNoSpeechDetected
            : _l10n.micTranscriptionError,
      ),
    );
  }

  Future<void> _parseAndAnalyze(
    String text,
    Emitter<MicrophoneTranscribeState> emit,
  ) async {
    // Parse + validate the spoken reading. We never fabricate a value:
    // if nothing parseable was said, or the value is physiologically
    // implausible, we surface a clear "please repeat" message instead of
    // silently defaulting to 120/80 or clamping to a range — which would
    // otherwise be analyzed, spoken aloud, and auto-saved as if it were real.
    final BPParseResult result = await _parseBloodPressure(text);

    if (result.status != BPParseStatus.success) {
      emit(
        ErrorState(errorMessage: result.message, displayText: result.message),
      );
      return;
    }

    final int rawSys = result.systolic!;
    final int rawDia = result.diastolic!;

    // Persist the verbatim measurement; the analysis below may instead use
    // the session average, but storage always keeps the real reading.
    _pendingRawSys = rawSys;
    _pendingRawDia = rawDia;

    // Average this reading with any others from the current sitting. A lone
    // reading is returned unchanged (count 1).
    final session = await _sessionAverage(rawSys, rawDia);
    _sessionCount = session.count;
    final int sys = session.systolic;
    final int dia = session.diastolic;

    // Emit reasoning state (reflects the value we actually analyze)
    emit(ReasoningState(systolic: sys, diastolic: dia));

    // Start LLM analysis
    add(const LLMAnalysisStartedEvent());
    await _analyzeWithLLM({'systolic': sys, 'diastolic': dia});
  }

  /// Averages [newSys]/[newDia] with readings already saved within
  /// [_sessionWindow]. Returns the new reading untouched (count 1) when there
  /// are no recent readings, or on any error — averaging never blocks
  /// analysis. The new reading is not yet persisted when this runs, so it is
  /// seeded into the lists explicitly.
  Future<_SessionAverage> _sessionAverage(int newSys, int newDia) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return _SessionAverage(newSys, newDia, 1);

      final since = DateTime.now().subtract(_sessionWindow);
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('readings')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
          .orderBy('date', descending: true)
          .get();

      final sys = <int>[newSys];
      final dia = <int>[newDia];
      for (final doc in snap.docs) {
        final s = (doc.data()['systolic'] as num?)?.toInt();
        final d = (doc.data()['diastolic'] as num?)?.toInt();
        if (s != null && d != null) {
          sys.add(s);
          dia.add(d);
        }
      }

      if (sys.length == 1) return _SessionAverage(newSys, newDia, 1);

      final avgSys = (sys.reduce((a, b) => a + b) / sys.length).round();
      final avgDia = (dia.reduce((a, b) => a + b) / dia.length).round();
      return _SessionAverage(avgSys, avgDia, sys.length);
    } catch (e) {
      debugPrint('⚠️ Session averaging failed, using single reading: $e');
      return _SessionAverage(newSys, newDia, 1);
    }
  }

  Future<BPParseResult> _parseBloodPressure(String text) async {
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
                'Extract the systolic and diastolic blood pressure values from the text. '
                'If the text does NOT contain a blood pressure reading, respond with '
                '{"systolic":null,"diastolic":null}. '
                'Never guess or invent values. Respond ONLY with JSON, e.g. {"systolic":120,"diastolic":80}.',
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

      final num? sysNum = parsed['systolic'] as num?;
      final num? diaNum = parsed['diastolic'] as num?;

      // Model reported no reading present — fall back to a literal regex
      // scan before giving up, then validate.
      if (sysNum == null || diaNum == null) {
        return _manualParse(text);
      }

      return _validateReading(sysNum.toInt(), diaNum.toInt());
    } catch (e) {
      return _manualParse(text);
    }
  }

  BPParseResult _manualParse(String text) {
    final match = RegExp(r'(\d{2,3})\s*[\/-]\s*(\d{2,3})').firstMatch(text);
    if (match != null) {
      final int? sys = int.tryParse(match.group(1)!);
      final int? dia = int.tryParse(match.group(2)!);
      if (sys != null && dia != null) {
        return _validateReading(sys, dia);
      }
    }
    // No blood pressure reading could be found in the spoken text.
    return BPParseResult(
      status: BPParseStatus.notDetected,
      message: _l10n.micCouldNotDetectReading,
    );
  }

  /// Validates a parsed reading against plausible physiological limits.
  /// Real human readings (including hypertensive crises and hypotension)
  /// fall well within these bounds, so anything outside is almost certainly
  /// a mis-transcription. Rather than silently clamping, we ask the user to
  /// repeat so we never save an altered value.
  BPParseResult _validateReading(int sys, int dia) {
    const int sysMin = 60, sysMax = 260;
    const int diaMin = 30, diaMax = 160;

    final bool inRange =
        sys >= sysMin && sys <= sysMax && dia >= diaMin && dia <= diaMax;

    // Systolic must exceed diastolic; otherwise the two were likely swapped
    // or mis-heard.
    if (!inRange || sys <= dia) {
      return BPParseResult(
        status: BPParseStatus.outOfRange,
        systolic: sys,
        diastolic: dia,
        message: _l10n.micReadingOutOfRange(sys, dia),
      );
    }

    return BPParseResult(
      status: BPParseStatus.success,
      systolic: sys,
      diastolic: dia,
    );
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
      add(LLMAnalysisFailedEvent(_l10n.micUnexpectedError));
      return;
    }

    try {
      // Build user context from profile
      String userContext = '';
      if (_userProfile != null) {
        final parts = <String>[];
        if (_userProfile!['age'] != null)
          parts.add('Age: ${_userProfile!['age']}');
        if (_userProfile!['gender'] != null)
          parts.add('Gender: ${_userProfile!['gender']}');
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
      final systemPrompt =
          '''You are Arteria, a compassionate medical assistant specializing in blood pressure.

BLOOD PRESSURE CLASSIFICATION (AHA/ACC 2025 Guidelines - applies uniformly to all adults 18+):
- Low (Hypotension): Systolic <90 OR Diastolic <60 mmHg (e.g., 85/55). Treat as urgent if Systolic <80 or Diastolic <50, or if symptoms like dizziness, fainting, or confusion are present.
- Normal: Systolic ≤120 AND Diastolic ≤80 mmHg (120/80 is Normal)
- Elevated: Systolic 121-129 AND Diastolic ≤80 mmHg (e.g., 125/78)
- Stage 1 Hypertension: Systolic 130-139 OR Diastolic 81-89 mmHg (e.g., 130/82, 135/85)
- Stage 2 Hypertension: Systolic ≥140 OR Diastolic ≥90 mmHg
- Hypertensive Crisis: Systolic >180 OR Diastolic >120 mmHg (EMERGENCY)

IMPORTANT: 120/80 mmHg is classified as NORMAL, not elevated or hypertensive.

Respond in JSON format:
{
  "classification": "Low (Hypotension)/Normal/Elevated/Stage 1 Hypertension/Stage 2 Hypertension/Hypertensive Crisis",
  "severity": "low/normal/elevated/high/critical",
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
              OpenAIChatCompletionChoiceMessageContentItemModel.text(
                systemPrompt,
              ),
            ],
          ),
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.user,
            content: [
              OpenAIChatCompletionChoiceMessageContentItemModel.text(
                _sessionCount > 1
                    ? 'This is the average of $_sessionCount readings I took a '
                          'few minutes apart in one sitting: $sys/$dia mmHg. '
                          'Please analyze this averaged reading.'
                    : 'My blood pressure reading is $sys/$dia mmHg. Please analyze.',
              ),
            ],
          ),
        ],
      );

      final raw =
          completion.choices.first.message.content
              ?.map((c) => c.text)
              .join(' ')
              .trim() ??
          '';

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
      // When we averaged a multi-reading session, tell the user up front so
      // the spoken/displayed numbers aren't mistaken for a single reading.
      final sessionNote = _sessionCount > 1
          ? (_selectedLanguage == 'fr'
                ? 'Ceci est la moyenne de $_sessionCount mesures prises à '
                      'quelques minutes d\'intervalle. '
                : 'This is the average of $_sessionCount readings taken a few '
                      'minutes apart. ')
          : '';
      final analysisText = '$sessionNote$analysis';
      // Derive the category label and severity locally so they are always
      // correctly localized and guaranteed consistent with the numeric
      // reading, regardless of how the LLM phrased its classification.
      final category = _classifyBP(sys, dia);
      final severity = _getSeverity(sys, dia);

      add(
        LLMAnalysisCompletedEvent(
          analysisText: analysisText,
          systolic: sys,
          diastolic: dia,
          category: category,
          severity: severity,
          followUpQuestions: [],
        ),
      );
    } on SocketException {
      add(LLMAnalysisFailedEvent(_l10n.micNetworkError));
    } on TimeoutException {
      add(LLMAnalysisFailedEvent(_l10n.micServerTimeout));
    } catch (e) {
      debugPrint('❌ LLM analysis error: $e');
      add(LLMAnalysisFailedEvent(_l10n.micUnexpectedError));
    }
  }

  /// Classifies blood pressure according to AHA/ACC 2025 guidelines.
  /// Low (Hypotension): <90 systolic OR <60 diastolic
  /// Normal: ≤120/≤80 (includes 120/80)
  /// Elevated: 121-129 AND ≤80
  /// Stage 1: ≥130 OR 81-89 diastolic
  /// Stage 2: ≥140 OR ≥90
  String _classifyBP(int sys, int dia) {
    // Hypertensive Crisis - EMERGENCY
    if (sys > 180 || dia > 120) return _l10n.bpCategoryCrisis;
    // Stage 2 Hypertension
    if (sys >= 140 || dia >= 90) return _l10n.bpCategoryStage2;
    // Stage 1 Hypertension (sys ≥130 OR dia 81-89)
    if (sys >= 130 || dia > 80) return _l10n.bpCategoryStage1;
    // Low / Hypotension (sys <90 OR dia <60). Checked after the high tiers so
    // a wide pulse pressure (e.g. 135/55) is still flagged as hypertension.
    if (sys < 90 || dia < 60) return _l10n.bpCategoryLow;
    // Elevated (sys 121-129 AND dia ≤80)
    if (sys > 120 && dia <= 80) return _l10n.bpCategoryElevated;
    // Normal (sys ≤120 AND dia ≤80, includes 120/80)
    return _l10n.bpCategoryNormal;
  }

  String _getSeverity(int sys, int dia) {
    if (sys > 180 || dia > 120) return 'critical';
    if (sys >= 140 || dia >= 90) return 'high';
    // Stage 1: sys ≥130 OR dia > 80
    if (sys >= 130 || dia > 80) return 'elevated';
    // Severe hypotension can be an emergency (shock) — flag as critical.
    if (sys < 80 || dia < 50) return 'critical';
    // Mild hypotension
    if (sys < 90 || dia < 60) return 'low';
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
    // event.error is already a localized, user-facing message.
    emit(ErrorState(errorMessage: event.error, displayText: event.error));
  }

  Future<void> _fetchSpeakAndPlay(String text) async {
    final openaiKey = Env.openaiApiKey;
    if (openaiKey.isEmpty) {
      add(const TTSPlaybackFailedEvent('OpenAI API key missing'));
      return;
    }

    try {
      final body = jsonEncode({
        'model': _ttsModel,
        'input': text,
        'voice': _ttsVoice,
        'response_format': 'mp3',
        'speed': 1.0,
      });

      // The TTS request (first-connection + TLS + audio generation + binary
      // download) can stall well past a tight timeout on mobile data. Use the
      // same generous budget as the Whisper call and retry once on a timeout
      // before giving up, with logging so we can see where it stalls.
      http.Response? response;
      for (int attempt = 1; attempt <= 2; attempt++) {
        final sw = Stopwatch()..start();
        try {
          response = await http
              .post(
                Uri.parse('https://api.openai.com/v1/audio/speech'),
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $openaiKey',
                },
                body: body,
              )
              .timeout(const Duration(seconds: 60));
          debugPrint(
            'TTS attempt $attempt → ${response.statusCode} '
            'in ${sw.elapsedMilliseconds}ms (${response.bodyBytes.length} bytes)',
          );
          break;
        } on TimeoutException {
          debugPrint(
            'TTS attempt $attempt timed out after ${sw.elapsedMilliseconds}ms',
          );
          if (attempt == 2) rethrow;
        }
      }

      if (response == null) {
        add(const TTSPlaybackFailedEvent('TTS request returned no response'));
        return;
      }

      if (response.statusCode != 200) {
        debugPrint(' TTS error body: ${response.body}');
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

  Future<void> _onTTSPlaybackFailed(
    TTSPlaybackFailedEvent event,
    Emitter<MicrophoneTranscribeState> emit,
  ) async {
    // TTS is non-critical: the reading and its analysis are already computed
    // and shown on screen. Rather than discarding that result behind an error
    // screen, fall through to the completed/save flow so the reading is kept.
    debugPrint('🔇 TTS playback failed: ${event.error}');
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

      await Future.delayed(const Duration(seconds: 2));
      add(const AutoSaveTriggeredEvent());
    }
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

      // Persist the actual spoken measurement (not the session average) so the
      // day's history and any downstream aggregation stay honest.
      final saveSys = _pendingRawSys ?? completedState.systolic;
      final saveDia = _pendingRawDia ?? completedState.diastolic;
      await _saveBPReading(saveSys, saveDia);
    }
  }

  Future<void> _saveBPReading(int systolic, int diastolic) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // IMPORTANT: write to `readings` — the single collection the rest of the
      // app (home, Trends, history, risk score) reads from. Saving elsewhere
      // (previously `bp_readings`) made voice readings invisible everywhere.
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('readings')
          .add({
            'systolic': systolic,
            'diastolic': diastolic,
            'date': Timestamp.now(),
          });

      // Let the push-notification service react to this new reading (e.g. a
      // dangerous value or a sudden spike). Fire-and-forget; it de-duplicates.
      HealthNotificationService.runChecksForCurrentUser();
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

/// Outcome of attempting to parse a spoken blood pressure reading.
enum BPParseStatus {
  /// A valid, in-range reading was found.
  success,

  /// No blood pressure reading could be detected in the speech.
  notDetected,

  /// A number was found but it falls outside plausible physiological limits.
  outOfRange,
}

/// Result of parsing speech into a blood pressure reading. Carries an
/// explanatory [message] for the non-success cases so the UI can prompt the
/// user to repeat instead of saving a fabricated or altered value.
class BPParseResult {
  final BPParseStatus status;
  final int? systolic;
  final int? diastolic;
  final String message;

  const BPParseResult({
    required this.status,
    this.systolic,
    this.diastolic,
    this.message = '',
  });
}

/// Result of averaging a measurement session: the (possibly averaged)
/// systolic/diastolic to analyze, and how many readings were folded in.
class _SessionAverage {
  const _SessionAverage(this.systolic, this.diastolic, this.count);
  final int systolic;
  final int diastolic;
  final int count;
}
