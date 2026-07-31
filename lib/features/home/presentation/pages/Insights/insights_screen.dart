import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';

import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';

import 'package:arteria/env/env.dart';
import 'package:arteria/l10n/app_localizations.dart';
import 'package:arteria/features/reminders/reminder_bloc.dart';
import 'package:arteria/features/reminders/reminder_event.dart';
import 'package:arteria/features/reminders/reminder_model.dart';
import 'package:arteria/features/user%20data/user_bloc.dart';
import 'package:arteria/features/user%20data/user_event.dart';
import 'package:arteria/features/home/domain/entities/medication.dart';
import 'package:arteria/features/home/data/repositories/medication_repository_impl.dart';

import '../settings/bloc/settings_bloc.dart';
import '../../components/talking_avatar_widget.dart';
import '../../components/medication_feedback_toast.dart';
import 'qwen_arteria_service.dart';
import 'hybrid_arteria_service.dart';
import '../../bloc/bp_data_bloc.dart';
import '../whatif/pages/whatif_screen.dart';
import '../../../data/data_sources/bp_anomaly_remote_data_source.dart';
import '../../../data/data_sources/health_risk_score_service.dart';
import 'novel_ai_service.dart';
import 'package:arteria/services/health_notification_service.dart';

class InsightsScreen extends StatefulWidget {
  final String userId;
  final int? userAge;
  final VoidCallback? onNavigateToHome;

  const InsightsScreen({
    super.key,
    this.userId = 'default_user',
    this.userAge,
    this.onNavigateToHome,
  });

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen>
    with TickerProviderStateMixin {
  // ─────────────── State ───────────────
  bool _isListening = false;
  bool _isSpeaking = false;
  // Bridges the gap between "thinking" and audible speech: true while the
  // response is ready and TTS is being generated, before playback begins.
  bool _isPreparingSpeech = false;

  String _statusText = '';

  // ─────────────── Animation Controllers ───────────────
  late AnimationController _breathingController;
  late Animation<double> _breathingAnimation;
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  late AnimationController _rippleController;
  late Animation<double> _rippleAnimation;

  // ─────────────── Premium UI State ───────────────
  Medication? _addedMedication;
  bool _showPrescription = false;
  Timer? _prescriptionTimer;
  int _remindersAdded = 0;

  // ─────────────── Services ───────────────
  late QwenArteriaService _qwenService;
  late HybridArteriaService _hybridService;
  final BPDataService _bpDataService = BPDataService();

  // Use hybrid system by default
  final bool _useHybridSystem = true;

  // ─────────────── Audio ───────────────
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // ─────────────── Novel AI Services ───────────────
  final BPAnomalyRemoteDataSource _anomalyService = BPAnomalyRemoteDataSource();
  final HealthRiskScoreService _riskScoreService = HealthRiskScoreService();
  AvatarEmotion _currentEmotion = AvatarEmotion.neutral;

  // ─────────────── Enhanced Voice Health Coach ───────────────
  late HealthNotificationService _notificationService;

  // ─────────────── Voice Stress Analysis (Novel Feature) ───────────────
  late NovelAIService _novelAIService;

  StreamSubscription<QwenEvent>? _qwenEventSub;
  StreamSubscription<HybridEvent>? _hybridEventSub;
  String? _recordingPath;

  final List<Uint8List> _recordedChunks = [];
  bool _hasRecordedAudio = false;

  // ─────────────── VAD (Voice Activity Detection) ───────────────
  // record's getAmplitude() reports the current loudness in dBFS: 0 dB is the
  // loudest possible signal and quieter sounds are increasingly negative (a
  // quiet room's noise floor sits around -45 to -55 dB). Speech is therefore a
  // RISE above the ambient floor — not a tiny linear value.
  //
  // We track the noise floor as the quietest level seen so far, starting from a
  // safe default. This works whether the user pauses before talking OR talks
  // the instant they tap: the floor only ever drops toward true silence, so the
  // END of speech is always detectable. Anything more than [_speechMarginDb]
  // above that floor counts as the user talking.
  static const double _speechMarginDb = 14.0; // dB above floor that counts as speech
  static const double _defaultFloorDb = -45.0; // assumed quiet-room floor at start
  static const Duration _silenceDuration = Duration(milliseconds: 1200);
  Timer? _silenceDetectionTimer;
  Timer? _amplitudeMonitorTimer;
  double _noiseFloorDb = _defaultFloorDb;
  bool _wasSpeaking = false;
  bool _speechStarted = false;

  // ─────────────── Language ───────────────
  String _language = 'en';

  // ─────────────── Lifecycle ───────────────
  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initLanguageAndRealtime();
    Future.microtask(() => _initNovelAIServices());
  }

  void _initAnimations() {
    _breathingController = AnimationController(
      duration: const Duration(milliseconds: 3500),
      vsync: this,
    )..repeat(reverse: true);

    _breathingAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _breathingController, curve: Curves.easeInOut),
    );

    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _rippleController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    _rippleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeOut),
    );
  }

  List<String> _resolveMedicationTimes(
    dynamic timesArg,
    MedicationFrequency frequency,
  ) {
    if (timesArg is List && timesArg.isNotEmpty) {
      return timesArg
          .map((entry) {
            if (entry is Map<String, dynamic>) {
              final hour = entry['hour'];
              final minute = entry['minute'] ?? 0;
              if (hour is int && minute is int) {
                return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
              }
            }
            return null;
          })
          .whereType<String>()
          .toList();
    }

    return <String>[];
  }

  Future<void> _initNovelAIServices() async {
    await _anomalyService.initialize(widget.userId);
    await _riskScoreService.initialize();

    // Initialize Health Notification Service
    _notificationService = HealthNotificationService(
      userId: widget.userId,
      riskScoreService: _riskScoreService,
    );

    await _notificationService.initialize();
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _qwenEventSub?.cancel();
    _hybridEventSub?.cancel();
    _qwenService.dispose();
    _hybridService.dispose();
    _prescriptionTimer?.cancel();
    _notificationService.dispose();
    _breathingController.dispose();
    _glowController.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  // ─────────────── Initialization ───────────────
  void _initLanguageAndRealtime() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = context.read<SettingsBloc>().state;
      _language = settings.locale.languageCode;
      final l10n = AppLocalizations.of(context);
      if (l10n != null) {
        setState(() => _statusText = l10n.statusConnecting);
      }
      _initializeRealtimeService();
    });
  }

  Future<void> _initializeRealtimeService() async {
    // Initialize both services
    _qwenService = QwenArteriaService(
      serverUrl: Env.qwenServerUrl,
      userId: widget.userId,
      language: _language,
    );

    _hybridService = HybridArteriaService(
      serverUrl: Env.qwenServerUrl,
      userId: widget.userId,
      language: _language,
    );

    // Initialize Novel AI Service
    _novelAIService = NovelAIService(
      serverUrl: Env.qwenServerUrl,
      userId: widget.userId,
    );

    // Subscribe to events based on which service is active
    if (_useHybridSystem) {
      _hybridEventSub = _hybridService.events.listen(_handleHybridEvent);
    } else {
      _qwenEventSub = _qwenService.events.listen(_handleQwenEvent);
    }

    try {
      // Connect both services in parallel for faster startup
      await Future.wait([_hybridService.connect(), _qwenService.connect()]);

      if (mounted) {
        final l10n = AppLocalizations.of(context);
        setState(() => _statusText = l10n?.statusTapToSpeak ?? 'Tap to speak');
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        setState(
          () => _statusText = l10n?.statusConnectionError ?? 'Connection error',
        );
      }
    }
  }

  // ─────────────── Qwen Events ───────────────
  void _handleQwenEvent(QwenEvent event) {
    if (!mounted) return;

    switch (event.type) {
      case QwenEventType.transcribing:
        setState(
          () => _statusText =
              AppLocalizations.of(context)?.statusTranscribing ??
              'Transcribing...',
        );
        break;

      case QwenEventType.generating:
        setState(
          () => _statusText =
              AppLocalizations.of(context)?.statusThinking ?? 'Thinking...',
        );
        break;

      case QwenEventType.responseReceived:
        setState(
          () => _statusText =
              AppLocalizations.of(context)?.statusResponseReceived ??
              'Response received',
        );
        _resetUI(); // Reset UI immediately since no TTS
        break;

      case QwenEventType.ready:
        setState(
          () => _statusText =
              AppLocalizations.of(context)?.statusTapToSpeak ?? 'Tap to speak',
        );
        break;

      case QwenEventType.functionCall:
        _handleFunctionCall(event.data);
        break;

      case QwenEventType.error:
        setState(() => _statusText = 'Error: ${event.message}');
        debugPrint('Qwen error: ${event.message}');
        break;

      default:
        break;
    }
  }

  // ─────────────── Hybrid Events ───────────────
  void _handleHybridEvent(HybridEvent event) {
    if (!mounted) return;

    switch (event.type) {
      case HybridEventType.processing:
        setState(
          () => _statusText =
              AppLocalizations.of(context)?.statusProcessing ??
              'Processing with AI...',
        );
        break;

      case HybridEventType.responseReceived:
        // A response is ready; TTS generation + playback still follow in
        // _stopListening. Don't reset to idle here (that left a dead, silent
        // gap). Instead show a clear "preparing to speak" state so the user
        // always has feedback right up until the assistant starts talking.
        setState(() {
          _isPreparingSpeech = true;
          _isListening = false;
          _statusText =
              AppLocalizations.of(context)?.statusSpeaking ?? 'Speaking…';
        });
        break;

      case HybridEventType.ready:
        setState(
          () => _statusText =
              AppLocalizations.of(context)?.statusTapToSpeak ?? 'Tap to speak',
        );
        break;

      case HybridEventType.clarification:
        setState(
          () => _statusText =
              AppLocalizations.of(context)?.statusClarificationNeeded ??
              'Clarification needed',
        );
        break;

      case HybridEventType.error:
        setState(() => _statusText = 'Error: ${event.message}');
        debugPrint('Hybrid error: ${event.message}');
        break;

      default:
        break;
    }
  }

  // ─────────────── Audio Playback ───────────────
  Future<void> _playMp3Audio(Uint8List audioBytes) async {
    if (audioBytes.isEmpty) {
      debugPrint('❌ No audio bytes to play');
      return;
    }

    debugPrint('🔊 Starting audio playback...');
    // Hand off from "preparing" dots to the live speaking wave.
    _isPreparingSpeech = false;
    _isSpeaking = true;
    setState(() {});

    try {
      await _audioPlayer.play(BytesSource(audioBytes));
      debugPrint('🔊 Audio player started, waiting for completion...');
      await _audioPlayer.onPlayerComplete.first;
      debugPrint('🔊 Audio playback completed successfully');
    } catch (e) {
      debugPrint('❌ Audio player error: $e');
    } finally {
      _isSpeaking = false;
      _resetUI();
    }
  }

  // ─────────────── Recording ───────────────
  Future<void> _startListening() async {
    if (!await _audioRecorder.hasPermission()) return;

    _isListening = true;
    _hasRecordedAudio = false;
    _recordedChunks.clear();
    _speechStarted = false;
    _wasSpeaking = false;
    _noiseFloorDb = _defaultFloorDb;
    if (mounted) {
      _statusText =
          AppLocalizations.of(context)?.statusListening ?? 'Listening...';
    }

    final dir = await getTemporaryDirectory();
    _recordingPath =
        '${dir.path}/qwen_recording_${DateTime.now().millisecondsSinceEpoch}.wav';

    // Record uncompressed 16 kHz mono WAV (PCM). The backend decodes WAV
    // natively (via the `wave` module) — AAC/M4A would need ffmpeg, which
    // is why voice stress analysis was being skipped. WAV also keeps
    // Whisper transcription accurate. 16 kHz mono keeps the clip small.
    await _audioRecorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: _recordingPath!,
    );

    _hasRecordedAudio = true;

    _startAmplitudeMonitoring();

    if (mounted) {
      setState(() {});
    }
  }

  void _startAmplitudeMonitoring() {
    _amplitudeMonitorTimer = Timer.periodic(const Duration(milliseconds: 100), (
      _,
    ) async {
      if (!_isListening) return;
      try {
        final amplitude = await _audioRecorder.getAmplitude();
        _onAmplitudeChanged(amplitude.current);
      } catch (e) {
        debugPrint('Amplitude monitoring error: $e');
      }
    });
  }

  void _stopAmplitudeMonitoring() {
    _amplitudeMonitorTimer?.cancel();
    _amplitudeMonitorTimer = null;
  }

  void _onAmplitudeChanged(double amplitudeDb) {
    if (!_isListening) return;
    // Guard against -inf/NaN some platforms emit before the first audio frame.
    if (amplitudeDb.isNaN || amplitudeDb.isInfinite) return;

    // Continuously track the quietest level seen as the ambient noise floor.
    // It only drops toward true silence, so speech is detected immediately
    // (even if the user talks the instant they tap) and the end of speech is
    // reliably caught when the level falls back near the floor.
    _noiseFloorDb = math.min(_noiseFloorDb, amplitudeDb);

    final speechThresholdDb = _noiseFloorDb + _speechMarginDb;
    final isSpeaking = amplitudeDb > speechThresholdDb;

    debugPrint(
      '🎙️ VAD amp=${amplitudeDb.toStringAsFixed(1)}dB '
      'floor=${_noiseFloorDb.toStringAsFixed(1)} '
      'thr=${speechThresholdDb.toStringAsFixed(1)} '
      'speaking=$isSpeaking started=$_speechStarted',
    );

    if (isSpeaking) {
      if (!_wasSpeaking) {
        _speechStarted = true;
        if (mounted) {
          setState(
            () => _statusText =
                AppLocalizations.of(context)?.statusListening ?? 'Listening...',
          );
        }
      }
      _wasSpeaking = true;
      _silenceDetectionTimer?.cancel();
      _silenceDetectionTimer = null;
    } else if (_speechStarted && _wasSpeaking) {
      if (_silenceDetectionTimer == null) {
        if (mounted) {
          setState(
            () => _statusText =
                AppLocalizations.of(context)?.statusDetectingSilence ??
                'Detecting silence...',
          );
        }
        _silenceDetectionTimer = Timer(_silenceDuration, () {
          if (mounted && _isListening && _speechStarted) {
            _stopListening();
          }
        });
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _stopListening() async {
    _stopAmplitudeMonitoring();
    _silenceDetectionTimer?.cancel();
    _silenceDetectionTimer = null;

    if (!_speechStarted || !_hasRecordedAudio) {
      _isListening = false;
      _statusText =
          AppLocalizations.of(context)?.statusTapToSpeak ?? 'Tap to speak';
      if (mounted) setState(() {});
      return;
    }

    final path = await _audioRecorder.stop();

    _isListening = false;
    if (mounted) {
      _statusText =
          AppLocalizations.of(context)?.statusProcessing ?? 'Processing...';
    }

    if (mounted) {
      setState(() {});
    }

    if (path != null && await File(path).exists()) {
      try {
        final audioBytes = await File(path).readAsBytes();

        // Use hybrid system if enabled
        Map<String, dynamic> result;

        // NOVEL FEATURE: Trigger voice stress analysis in parallel
        _analyzeStressInParallel(path);

        if (_useHybridSystem) {
          // Process audio directly through hybrid system (STT + reasoning)
          result = await _hybridService.processAudioInput(audioBytes);

          // Fallback: if hybrid returned only a transcript but no response,
          // re-send the transcript through the hybrid TEXT path. We used to
          // route to NaturalLanguageHealthService here, but that service
          // re-templates the answer client-side (judging by 30-day average,
          // English/French fragments interleaved), which discards the
          // doctor-mode + language-native response from the orchestrator.
          final transcript = result['transcription'] as String? ?? '';
          final responseType = result['type'] as String? ?? '';
          final responseText = result['response'] as String? ?? '';
          if (responseType.isEmpty &&
              responseText.isEmpty &&
              transcript.isNotEmpty) {
            result = await _hybridService.processUserInput(transcript);
          }
        } else {
          // Legacy path: full voice interaction handled by Qwen service
          result = await _qwenService.processVoiceInteraction(audioBytes);
        }

        // In hybrid mode, we generate TTS on the server via /speak
        if (_useHybridSystem) {
          final responseText =
              (result['response'] as String?) ??
              (result['question'] as String?) ??
              '';
          if (responseText.isNotEmpty) {
            // Show the "preparing to speak" state for the whole duration of
            // TTS generation, so the user never sees a silent dead gap
            // between thinking and the assistant talking.
            if (mounted) {
              setState(() {
                _isPreparingSpeech = true;
                _statusText =
                    AppLocalizations.of(context)?.statusSpeaking ?? 'Speaking…';
              });
            }
            try {
              debugPrint('🔊 Generating TTS for: "$responseText"');
              final ttsAudio = await _qwenService.speak(responseText);
              debugPrint(
                '🔊 TTS audio generated, size: ${ttsAudio.length} bytes',
              );
              await _playMp3Audio(ttsAudio);
              debugPrint('🔊 Audio playback completed');
            } catch (e) {
              // TTS failed (e.g. timeout) — return to idle instead of
              // stranding the UI in the "preparing" state.
              debugPrint('❌ TTS playback error: $e');
              _resetUI();
            }
          } else {
            debugPrint('⚠️ No response text to convert to speech');
            _resetUI(); // Nothing to speak — return to idle.
          }
        } else {
          // Non-hybrid path already includes audio_response from processVoiceInteraction
          if (result['audio_response'] != null) {
            await _playMp3Audio(result['audio_response'] as Uint8List);
          }
        }

        final functionCalls = result['function_calls'] as List? ?? [];
        for (final call in functionCalls) {
          debugPrint('🔧 Function call result: $call');
        }

        // The "action completed" toast is only for genuine state-changing
        // actions. Read-only lookups (get_medications, analyze_bp_trend, …)
        // also arrive in function_calls — they answer a question but
        // complete no action, so they must not trigger the toast.
        const actionTools = <String>{
          'record_bp_reading',
          'add_medication',
          'set_reminder',
        };
        final didPerformAction = functionCalls.any(
          (call) => call is Map && actionTools.contains(call['tool']),
        );

        // Medication add / update / switch → rich animated confirmation toast.
        final medFeedback = result['medication_feedback'];
        if (medFeedback is Map && mounted) {
          MedicationFeedbackToast.show(
            context,
            feedback: Map<String, dynamic>.from(medFeedback),
          );
        } else if (didPerformAction && mounted) {
          // Genuine actions (BP recorded, reminders) keep a lightweight toast.
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Action completed successfully',
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: const Color(0xFF34D399),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }

        try {
          await File(path).delete();
        } catch (_) {}
      } catch (e) {
        debugPrint('Voice interaction error: $e');
        if (mounted) {
          final l10n = AppLocalizations.of(context);
          setState(
            () => _statusText =
                l10n?.statusErrorProcessingAudio ?? 'Error processing audio',
          );
        }
        _resetUI();
      }
    } else {
      _resetUI();
    }
  }

  Future<void> _analyzeStressInParallel(String audioPath) async {
    if (!mounted) return;

    try {
      final file = File(audioPath);
      if (!await file.exists()) return;

      final bytes = await file.readAsBytes();
      final base64Audio = base64Encode(bytes);

      final result = await _novelAIService.analyzeVoiceStress(base64Audio);

      // If high stress detected, update avatar emotion
      if (mounted && result != null && result.stressScore > 70) {
        setState(() => _currentEmotion = AvatarEmotion.concerned);
      }
    } catch (e) {
      debugPrint('Error in background stress analysis: $e');
    }
  }

  // ─────────────── Helpers ───────────────
  void _resetUI() {
    _isSpeaking = false;
    _isPreparingSpeech = false;
    _statusText =
        AppLocalizations.of(context)?.statusTapToSpeak ?? 'Tap to speak';
    // Don't hide stress indicator immediately, let it persist for user to see

    if (mounted) {
      setState(() {});
    }
  }

  void _handleFunctionCall(dynamic data) {
    if (data is! Map<String, dynamic>) return;

    final name = data['name'];

    if (name == 'set_reminder') {
      final args = data['arguments'];
      context.read<ReminderBloc>().add(
        AddReminder(
          time: TimeOfDay(hour: args['hour'], minute: args['minute']),
          repeatType: RepeatType.daily,
        ),
      );
    } else if (name == 'open_whatif_simulator') {
      _showWhatIfConfirmationDialog();
    } else if (name == 'record_bp_reading') {
      final args = data['arguments'];
      final systolic = args['systolic'] as int;
      final diastolic = args['diastolic'] as int;

      context.read<UserBloc>().add(
        SaveBPReading(systolic: systolic, diastolic: diastolic),
      );

      // Feature 1 Correlation: Run Anomaly Detection
      _checkAnomalies(systolic, diastolic);
    } else if (name == 'add_medication') {
      final args = data['arguments'];
      _addMedication(args);
    } else if (name == 'get_latest_reading') {
      _handleGetLatestReading();
    } else if (name == 'generate_health_report') {
      _generateHealthReport();
    }
  }

  Future<void> _checkAnomalies(int systolic, int diastolic) async {
    final result = _anomalyService.detectAnomaly(
      systolic: systolic,
      diastolic: diastolic,
    );

    if (result.isAnomaly) {
      debugPrint('🚨 Anomaly Detected: ${result.explanations.join(", ")}');

      // Update Avatar state to Concerned
      if (mounted) {
        setState(() => _currentEmotion = AvatarEmotion.concerned);
      }

      // Get AI to explain the anomaly specifically
      final explanation =
          'Note: I\'ve detected an unusual pattern. ${result.explanations.first} ${result.recommendation}';
      final audioResp = await _qwenService.speak(explanation);
      await _playMp3Audio(audioResp);
    } else {
      if (mounted) {
        setState(() => _currentEmotion = AvatarEmotion.reassuring);
      }
      // Return to neutral after 5 seconds
      Timer(const Duration(seconds: 5), () {
        if (mounted) setState(() => _currentEmotion = AvatarEmotion.neutral);
      });
    }
  }

  Future<void> _generateHealthReport() async {
    if (mounted) {
      setState(
        () => _statusText =
            AppLocalizations.of(context)?.statusGeneratingReport ??
            'Generating report...',
      );
    }

    try {
      final profile = await _buildUserProfile();
      final report = await _riskScoreService.calculateRiskScore(
        userId: widget.userId,
        userFeatures: profile,
      );

      if (!mounted) return;

      _showReportDialog(report);

      setState(
        () => _statusText =
            AppLocalizations.of(context)?.statusSpeaking ??
            'Speaking summary...',
      );
      final audio = await _qwenService.speak(report.toSpokenSummary());
      await _playMp3Audio(audio);
    } catch (e) {
      debugPrint('Error generating report: $e');
      if (mounted) {
        setState(
          () => _statusText =
              AppLocalizations.of(context)?.statusErrorGeneratingReport ??
              'Error generating report',
        );
      }
    }
  }

  void _showReportDialog(HealthRiskReport report) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Premium AI Health Report'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Overall Risk Score: ${report.overallScore}/100',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              Text('Category: ${report.category.name.toUpperCase()}'),
              const Divider(),
              const Text(
                'Why this score?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ...report.topFactors.map(
                (f) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    '• ${f.name}: ${f.contributionPercent}% impact (${f.status.name})',
                  ),
                ),
              ),
              const Divider(),
              const Text(
                'Recommendations:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ...report.recommendations.map(
                (r) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text('• ${r.title}: ${r.description}'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleGetLatestReading() async {
    try {
      final reading = await _bpDataService.getLatestReading(widget.userId);
      if (reading != null) {
        final systolic = reading['systolic'] as int?;
        final diastolic = reading['diastolic'] as int?;
        final pulse = reading['pulse'] as int?;
        final timestamp = reading['timestamp'];

        final classification = _bpDataService.classifyBP(
          systolic ?? 0,
          diastolic ?? 0,
        );

        final response =
            'Your latest reading was $systolic/$diastolic mmHg ${pulse != null ? 'with pulse $pulse bpm ' : ''}recorded on ${timestamp?.toString() ?? "unknown date"}. Classification: ${classification.categoryName}. ${classification.description}';

        setState(
          () => _statusText =
              AppLocalizations.of(context)?.statusSpeaking ?? 'Speaking...',
        );
        final audioResponse = await _qwenService.speak(response);
        await _playMp3Audio(audioResponse);
      } else {
        await _qwenService.speak(
          'I couldn\'t find any blood pressure readings in your history.',
        );
      }
    } catch (e) {
      debugPrint('Error getting latest reading: $e');
    }
  }

  Future<void> _navigateToWhatIfScreen() async {
    final profile = await _buildUserProfile();

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => WhatIfScreen(userProfile: profile)),
    );
  }

  void _showWhatIfConfirmationDialog() {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text(
          l10n.whatIfSimulator,
          style: TextStyle(
            color: Theme.of(context).textTheme.titleLarge?.color,
          ),
        ),
        content: Text(
          l10n.whatIfSimulatorDescription,
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text(
              l10n.whatIfSimulatorCancel,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _navigateToWhatIfScreen();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF667EEA),
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.whatIfSimulatorConfirm),
          ),
        ],
      ),
    );
  }

  Future<void> _addMedication(Map<String, dynamic> args) async {
    debugPrint('💊 _addMedication called with args: $args');

    final name = args['name'] as String? ?? '';
    final dosage = args['dosage'] as String? ?? '1 tablet';
    final frequencyStr = args['frequency'] as String? ?? 'onceDaily';
    final instructions = args['instructions'] as String?;
    final timesArg = args['times'];

    if (name.isEmpty) {
      debugPrint('❌ Medication name is empty, aborting');
      return;
    }

    try {
      final MedicationFrequency frequency = MedicationFrequency.values
          .firstWhere(
            (e) => e.name == frequencyStr,
            orElse: () => MedicationFrequency.onceDaily,
          );

      final List<String> resolvedTimes = _resolveMedicationTimes(
        timesArg,
        frequency,
      );

      final medication = Medication(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        dosage: dosage,
        frequency: frequency,
        times: resolvedTimes,
        isActive: true,
        takenToday: false,
        createdAt: DateTime.now(),
        color: const Color(0xFF6366F1),
        instructions: instructions,
      );

      debugPrint(
        '💊 Created medication: ${medication.name} (ID: ${medication.id})',
      );
      debugPrint('💊 Times: ${medication.times}');
      debugPrint('💊 UserId: ${widget.userId}');

      final repository = MedicationRepositoryImpl();

      // ─────────────── Duplicate Detection ───────────────
      final existingMeds = await repository.getMedications(widget.userId);
      debugPrint('💊 Existing medications count: ${existingMeds.length}');

      final isDuplicate = existingMeds.any(
        (m) => m.name.toLowerCase().trim() == name.toLowerCase().trim(),
      );

      if (isDuplicate) {
        debugPrint('⚠️ Medication "$name" already exists');
        if (!mounted) return;
        final l10n = AppLocalizations.of(context);
        if (l10n != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.medicationAlreadyExists(name)),
              backgroundColor: const Color(0xFFFFA000), // Amber for warning
            ),
          );
        }
        return;
      }

      debugPrint('💊 Saving medication to Firestore...');
      await repository.addMedication(widget.userId, medication);
      debugPrint('✅ Medication saved successfully!');

      if (mounted) {
        // Only add reminders if medication has specific times (not empty defaults)
        int reminderCount = 0;
        // Only create reminders if times are explicitly set (not default frequency times)
        if (medication.times.isNotEmpty) {
          for (final timeStr in medication.times) {
            final parts = timeStr.split(':');
            if (parts.length == 2) {
              final hour = int.tryParse(parts[0]);
              final minute = int.tryParse(parts[1]);

              if (hour != null && minute != null) {
                context.read<ReminderBloc>().add(
                  AddReminder(
                    time: TimeOfDay(hour: hour, minute: minute),
                    repeatType: RepeatType.daily,
                    label: 'Take ${medication.name}',
                  ),
                );
                reminderCount++;
              }
            }
          }
        }

        // Show Premium Prescription UI
        setState(() {
          _addedMedication = medication;
          _showPrescription = true;
          _remindersAdded = reminderCount;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${medication.name} added successfully. Tap to view on Home.',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: const Color(0xFF111827),
            behavior: SnackBarBehavior.floating,
            elevation: 8,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            action: SnackBarAction(
              label: 'View',
              textColor: const Color(0xFF34D399),
              onPressed: _navigateToHomeWithMedication,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      if (l10n == null) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.medicationAddError),
          backgroundColor: const Color(0xFFF44336),
        ),
      );
    }
  }

  Future<Map<String, dynamic>> _buildUserProfile() async {
    final userProfile = await _bpDataService.getUserProfile(widget.userId);
    final latestReading = await _bpDataService.getLatestReading(widget.userId);
    final history = await _bpDataService.getHistory(widget.userId, days: 30);

    return {
      'userId': widget.userId,
      'age': userProfile?['age'] ?? widget.userAge ?? 45,
      'gender': userProfile?['gender'] ?? 'Unknown',
      'avg_systolic': _calculateAverage(history, 'systolic') ?? 120,
      'avg_diastolic': _calculateAverage(history, 'diastolic') ?? 80,
      'avg_pulse': _calculateAverage(history, 'pulse') ?? 72,
      'latest_systolic': latestReading?['systolic'] ?? 120,
      'latest_diastolic': latestReading?['diastolic'] ?? 80,
    };
  }

  int? _calculateAverage(List<Map<String, dynamic>> readings, String field) {
    if (readings.isEmpty) return null;
    final values = readings
        .map((r) => (r[field] as num?)?.toInt() ?? 0)
        .toList();
    return (values.reduce((a, b) => a + b) / values.length).round();
  }

  // ─────────────── Premium UI Components ───────────────
  Widget _buildPrescriptionOverlay() {
    if (!_showPrescription || _addedMedication == null) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context);
    if (l10n == null) return const SizedBox.shrink();
    final med = _addedMedication!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: _showPrescription ? 1.0 : 0.0,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withValues(alpha: 0.8)
                : Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: const Color(0xFF6366F1).withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: Color(0xFF6366F1),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.prescriptionTitle.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF6366F1),
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          med.name,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _showPrescription = false),
                    icon: Icon(
                      Icons.close_rounded,
                      color: isDark ? Colors.white38 : Colors.black26,
                    ),
                  ),
                ],
              ),
              const Divider(height: 32, thickness: 1),

              // Details
              _buildPrescriptionDetail(
                l10n.medicationDosageLabel,
                med.dosage,
                Icons.scale_rounded,
              ),
              const SizedBox(height: 16),
              _buildPrescriptionDetail(
                l10n.medicationFrequencyLabel,
                med.frequency.displayName,
                Icons.repeat_rounded,
              ),
              if (med.instructions != null && med.instructions!.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildPrescriptionDetail(
                  l10n.medicationInstructionsLabel,
                  med.instructions!,
                  Icons.info_outline_rounded,
                ),
              ],

              const SizedBox(height: 16),

              // Reminders added indicator
              if (_remindersAdded > 0)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.alarm_on_rounded,
                        color: Color(0xFF10B981),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.remindersSetCount(_remindersAdded),
                          style: const TextStyle(
                            color: Color(0xFF10B981),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              // Footer CTA - Navigate to Home
              GestureDetector(
                onTap: _navigateToHomeWithMedication,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.home_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.viewOnHome,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToHomeWithMedication() {
    // Hide the prescription overlay
    setState(() => _showPrescription = false);
    _prescriptionTimer?.cancel();

    // Show success snackbar first
    if (mounted) {
      final l10n = AppLocalizations.of(context);
      final medName = _addedMedication?.name ?? 'Medication';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n?.medicationAddedMessage(medName) ??
                      '$medName added successfully!',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }

    // Navigate to home tab via callback
    widget.onNavigateToHome?.call();
  }

  Widget _buildPrescriptionDetail(String label, String value, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(icon, size: 20, color: isDark ? Colors.white54 : Colors.black45),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final screen = MediaQuery.of(context);
    final safeH = screen.size.height - screen.padding.top - screen.padding.bottom;

    // Responsive avatar: fills ~30% of safe height, clamped
    final avatarSize = (safeH * 0.30).clamp(160.0, 280.0);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF08080D) : const Color(0xFFF4F5F9),
      body: Stack(
        children: [
          // ── Ambient glow layer ──
          _buildAmbientGlow(isDark, avatarSize),

          // ── Content ──
          SafeArea(
            child: Column(
              children: [
                // ── Top: Avatar + Greeting (fills available space) ──
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildCenteredAvatar(isDark, avatarSize),
                      SizedBox(height: safeH * 0.03),
                      _buildGreeting(isDark, l10n),
                    ],
                  ),
                ),

                // ── Bottom dock: Chips → Status → Mic ──
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildSuggestionChips(isDark, l10n),
                      const SizedBox(height: 20),
                      _buildStatusIndicator(isDark),
                      const SizedBox(height: 14),
                      _buildMicButton(isDark),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Prescription Overlay ──
          _buildPrescriptionOverlay(),
        ],
      ),
    );
  }

  // ─────────────── Ambient Background ───────────────
  Widget _buildAmbientGlow(bool isDark, double avatarSize) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _breathingAnimation,
          builder: (context, _) {
            final accent = _isListening
                ? const Color(0xFF5CE1E6)
                : (_isSpeaking || _isPreparingSpeech)
                    ? const Color(0xFF818CF8)
                    : const Color(0xFF3D8B8F);
            final active = _isListening || _isSpeaking || _isPreparingSpeech;
            final glowSize = (avatarSize * 2.2) * _breathingAnimation.value;

            return Stack(
              children: [
                // Main glow
                Align(
                  alignment: const Alignment(0.0, -0.25),
                  child: Container(
                    width: glowSize,
                    height: glowSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          accent.withValues(alpha: isDark ? 0.14 : 0.07),
                          accent.withValues(alpha: isDark ? 0.04 : 0.02),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                ),
                // Focused inner glow when active
                if (active)
                  Align(
                    alignment: const Alignment(0.0, -0.25),
                    child: Container(
                      width: avatarSize * 1.4,
                      height: avatarSize * 1.4,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            accent.withValues(alpha: 0.1),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ─────────────── Avatar ───────────────
  Widget _buildCenteredAvatar(bool isDark, double size) {
    final containerSize = size + 12;

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, _) {
        final accent = _isListening
            ? const Color(0xFF5CE1E6)
            : (_isSpeaking || _isPreparingSpeech)
                ? const Color(0xFF818CF8)
                : const Color(0xFF3D8B8F);
        final active = _isListening || _isSpeaking || _isPreparingSpeech;

        return Container(
          width: containerSize,
          height: containerSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: accent.withValues(
                  alpha: active ? 0.4 * _glowAnimation.value : 0.05,
                ),
                blurRadius: active ? 56 : 20,
                spreadRadius: active ? 10 : 0,
              ),
            ],
          ),
          child: Container(
            padding: const EdgeInsets.all(3.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: [
                  accent.withValues(alpha: active ? 0.55 : 0.18),
                  accent.withValues(alpha: active ? 0.1 : 0.04),
                  accent.withValues(alpha: active ? 0.45 : 0.14),
                  accent.withValues(alpha: active ? 0.08 : 0.03),
                  accent.withValues(alpha: active ? 0.55 : 0.18),
                ],
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? const Color(0xFF0C0C14) : const Color(0xFFFBFBFD),
              ),
              child: ClipOval(
                child: TalkingAvatarWidget(
                  isSpeaking: _isSpeaking,
                  isListening: _isListening,
                  emotion: _currentEmotion,
                  bare: true,
                  onLoaded: () {},
                  width: size,
                  height: size,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ─────────────── Greeting ───────────────
  Widget _buildGreeting(bool isDark, AppLocalizations? l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Text(
        l10n?.insightsHeroPrompt ?? 'How are you feeling today?',
        textAlign: TextAlign.center,
        style: GoogleFonts.dmSans(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: isDark
              ? Colors.white.withValues(alpha: 0.9)
              : const Color(0xFF1B1D2A),
          height: 1.3,
          letterSpacing: -0.6,
        ),
      ),
    );
  }

  // ─────────────── Status ───────────────
  Widget _buildStatusIndicator(bool isDark) {
    final l10n = AppLocalizations.of(context);
    final defaultStatus = l10n?.statusTapToSpeak ?? 'Tap to speak';
    final displayText = _statusText.isNotEmpty ? _statusText : defaultStatus;

    final accent = _isListening
        ? const Color(0xFF5CE1E6)
        : (_isSpeaking || _isPreparingSpeech)
            ? const Color(0xFF818CF8)
            : isDark
                ? Colors.white.withValues(alpha: 0.3)
                : const Color(0xFF9BA3B5);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Text(
        displayText,
        key: ValueKey(displayText),
        style: GoogleFonts.dmSans(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: accent,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  // ─────────────── Suggestion Chips ───────────────
  Widget _buildSuggestionChips(bool isDark, AppLocalizations? l10n) {
    final chips = <_ChipData>[
      _ChipData(
        label: l10n?.insightsSuggestionLatest ?? 'Latest reading',
        icon: Icons.favorite_outline_rounded,
        accent: const Color(0xFFE85D75),
      ),
      _ChipData(
        label: l10n?.insightsSuggestionTrend ?? 'Weekly trend',
        icon: Icons.show_chart_rounded,
        accent: const Color(0xFF5CAEDB),
      ),
      _ChipData(
        label: l10n?.insightsSuggestionRisk ?? 'Risk signs',
        icon: Icons.shield_outlined,
        accent: const Color(0xFFD4993D),
      ),
      _ChipData(
        label: l10n?.insightsSuggestionMedication ?? 'Medications',
        icon: Icons.medication_outlined,
        accent: const Color(0xFF52C48A),
      ),
    ];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final chip = chips[index];
          return GestureDetector(
            onTap: () => _handleSuggestionTap(chip.label),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? chip.accent.withValues(alpha: 0.1)
                    : chip.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: chip.accent.withValues(alpha: isDark ? 0.2 : 0.22),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(chip.icon, size: 15, color: chip.accent),
                  const SizedBox(width: 6),
                  Text(
                    chip.label,
                    style: GoogleFonts.dmSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.72)
                          : const Color(0xFF3A3F4B),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Map a localized chip label to a clear natural-language question so the
  /// backend intent classifier has unambiguous input. We can't trust short
  /// labels like "Latest reading" — the question form ("What was my latest
  /// reading?") routes cleanly to UserIntent.LATEST_READING in the hybrid
  /// orchestrator, which has the doctor-mode + French-native fixes.
  String _chipToQuery(String chipLabel) {
    final l10n = AppLocalizations.of(context);
    final isFr = (Localizations.localeOf(context).languageCode == 'fr');
    if (l10n != null) {
      if (chipLabel == l10n.insightsSuggestionLatest) {
        return isFr
            ? 'Comment était ma dernière mesure de tension?'
            : 'How was my latest blood pressure reading?';
      }
      if (chipLabel == l10n.insightsSuggestionTrend) {
        return isFr
            ? 'Comment ma tension a-t-elle évolué cette semaine?'
            : 'How has my blood pressure trended this week?';
      }
      if (chipLabel == l10n.insightsSuggestionRisk) {
        return isFr
            ? 'Suis-je à risque selon mes mesures récentes?'
            : 'Am I at risk based on my recent readings?';
      }
      if (chipLabel == l10n.insightsSuggestionMedication) {
        return isFr
            ? 'Quels médicaments est-ce que je prends?'
            : 'What medications am I currently taking?';
      }
    }
    return chipLabel;
  }

  Future<void> _handleSuggestionTap(String suggestion) async {
    if (_isListening || _isSpeaking) return;

    setState(() {
      _statusText =
          AppLocalizations.of(context)?.statusProcessing ?? 'Processing...';
    });

    try {
      // Route chip taps through the hybrid backend (the same path voice
      // queries use) so the user gets the doctor-mode + language-native
      // response built in hybrid_orchestrator.py — NOT the legacy Dart
      // templates in NaturalLanguageHealthService, which judge by average
      // and overwrite the server's response.
      final query = _chipToQuery(suggestion);
      final result = await _hybridService.processUserInput(query);
      final responseText = (result['response'] as String?) ?? '';
      if (responseText.isEmpty) {
        _resetUI();
        return;
      }

      if (mounted) {
        setState(() {
          _isPreparingSpeech = true;
          _statusText =
              AppLocalizations.of(context)?.statusSpeaking ?? 'Speaking...';
        });
      }
      if (!_qwenService.isConnected) {
        await _qwenService.connect();
      }
      final audio = await _qwenService.speak(responseText);
      await _playMp3Audio(audio);
    } catch (e) {
      debugPrint('Error handling suggestion tap: $e');
      _resetUI();
    }
  }

  // ─────────────── Mic Button ───────────────
  Widget _buildMicButton(bool isDark) {
    final bool active = _isListening;
    final bool speaking = _isSpeaking;
    final bool preparing = _isPreparingSpeech;
    const double coreSize = 64.0;
    const double canvasSize = 120.0;

    final Color accent = active
        ? const Color(0xFF5CE1E6)
        : (speaking || preparing)
            ? const Color(0xFF818CF8)
            : const Color(0xFF3D8B8F);

    return GestureDetector(
      onTap: active ? _stopListening : _startListening,
      child: SizedBox(
        width: canvasSize,
        height: canvasSize,
        child: AnimatedBuilder(
          animation: Listenable.merge([_breathingAnimation, _rippleAnimation]),
          builder: (context, _) {
            return CustomPaint(
              painter: active || speaking || preparing
                  ? _MicRipplePainter(
                      progress: _rippleAnimation.value,
                      color: accent,
                      isDark: isDark,
                      ringCount: active ? 3 : 2,
                    )
                  : null,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  width: active ? coreSize + 4 : coreSize,
                  height: active ? coreSize + 4 : coreSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active
                        ? accent
                        : (isDark ? const Color(0xFF141420) : Colors.white),
                    boxShadow: [
                      BoxShadow(
                        color: active
                            ? accent.withValues(alpha: 0.45)
                            : (isDark
                                ? Colors.black.withValues(alpha: 0.5)
                                : Colors.black.withValues(alpha: 0.07)),
                        blurRadius: active ? 28 : 12,
                        spreadRadius: active ? 2 : 0,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: active
                        ? null
                        : Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : const Color(0xFFDFE3EB),
                            width: 1.2,
                          ),
                  ),
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      transitionBuilder: (child, anim) =>
                          ScaleTransition(scale: anim, child: child),
                      child: active
                          ? Icon(
                              Icons.stop_rounded,
                              key: const ValueKey('stop'),
                              color: const Color(0xFF0A0A0F),
                              size: 26,
                            )
                          : preparing
                              ? _buildPreparingDots(accent)
                              : speaking
                              ? _buildSpeakingWave(accent)
                              : Icon(
                                  Icons.mic_rounded,
                                  key: const ValueKey('mic'),
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.75)
                                      : accent,
                                  size: 24,
                                ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Staggered pulsing dots shown while the response is ready and TTS is
  /// being generated — the "about to speak" beat between thinking and the
  /// live speaking wave.
  Widget _buildPreparingDots(Color color) {
    return Row(
      key: const ValueKey('prep'),
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _glowController,
          builder: (context, _) {
            // Offset each dot's phase so the pulse ripples left → right.
            final phase = _glowController.value * math.pi * 2 + (i * 0.9);
            final t = (math.sin(phase) + 1) / 2; // 0..1
            final scale = 0.6 + 0.4 * t;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              width: 7 * scale,
              height: 7 * scale,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.4 + 0.5 * t),
                shape: BoxShape.circle,
              ),
            );
          },
        );
      }),
    );
  }

  Widget _buildSpeakingWave(Color color) {
    return Row(
      key: const ValueKey('wave'),
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return AnimatedBuilder(
          animation: _breathingAnimation,
          builder: (context, _) {
            final phase = _breathingAnimation.value * math.pi * 2 + (i * 0.7);
            final h = 6.0 + 12.0 * ((math.sin(phase) + 1) / 2);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              width: 3,
              height: h,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(1.5),
              ),
            );
          },
        );
      }),
    );
  }
}

// ─────────────── Data ───────────────
class _ChipData {
  final String label;
  final IconData icon;
  final Color accent;
  const _ChipData({required this.label, required this.icon, required this.accent});
}

// ─────────────── Ripple Painter ───────────────
class _MicRipplePainter extends CustomPainter {
  final double progress;
  final Color color;
  final bool isDark;
  final int ringCount;

  _MicRipplePainter({
    required this.progress,
    required this.color,
    required this.isDark,
    this.ringCount = 3,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.width / 2;

    for (int i = 0; i < ringCount; i++) {
      final t = (progress + i / ringCount) % 1.0;
      final r = 32.0 + (maxR - 32.0) * t;
      final opacity = (1.0 - t) * (isDark ? 0.22 : 0.18);

      canvas.drawCircle(
        center,
        r,
        Paint()
          ..color = color.withValues(alpha: opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4 * (1.0 - t * 0.6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MicRipplePainter old) =>
      old.progress != progress || old.color != color || old.ringCount != ringCount;
}
