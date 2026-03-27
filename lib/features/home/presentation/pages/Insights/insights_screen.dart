import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
import '../../components/voice_stress_indicator.dart';
import 'qwen_arteria_service.dart';
import 'hybrid_arteria_service.dart';
import '../../bloc/bp_data_bloc.dart';
import '../whatif/pages/whatif_screen.dart';
import '../../../data/data_sources/bp_anomaly_remote_data_source.dart';
import '../../../data/data_sources/health_risk_score_service.dart';
import 'novel_ai_service.dart';
import 'package:arteria/services/natural_language_health_service.dart';
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

class _InsightsScreenState extends State<InsightsScreen> {
  // ─────────────── State ───────────────
  bool _isListening = false;
  bool _isSpeaking = false;

  String _statusText = '';

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
  late NaturalLanguageHealthService _nlHealthService;
  late HealthNotificationService _notificationService;

  // ─────────────── Voice Stress Analysis (Novel Feature) ───────────────
  late NovelAIService _novelAIService;
  VoiceStressResult? _lastStressAnalysis;
  bool _showStressIndicator = false;

  // ─────────────── Medication Optimizer (Novel Feature) ───────────────

  StreamSubscription<QwenEvent>? _qwenEventSub;
  StreamSubscription<HybridEvent>? _hybridEventSub;
  String? _recordingPath;

  final List<Uint8List> _recordedChunks = [];
  bool _hasRecordedAudio = false;

  // ─────────────── VAD (Voice Activity Detection) ───────────────
  static const double _silenceThreshold = 0.02;
  static const Duration _silenceDuration = Duration(milliseconds: 1200);
  Timer? _silenceDetectionTimer;
  Timer? _amplitudeMonitorTimer;
  double _currentAmplitude = 0;
  bool _wasSpeaking = false;
  bool _speechStarted = false;

  // ─────────────── Language ───────────────
  String _language = 'en';

  // ─────────────── Lifecycle ───────────────
  @override
  void initState() {
    super.initState();
    _initLanguageAndRealtime();
    // Defer novel AI services init to avoid blocking startup
    Future.microtask(() => _initNovelAIServices());
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

    // Initialize Enhanced Voice Health Coach
    _nlHealthService = NaturalLanguageHealthService(
      serverUrl: Env.qwenServerUrl,
      userId: widget.userId,
    );

    // Initialize Health Notification Service
    _notificationService = HealthNotificationService(
      userId: widget.userId,
      riskScoreService: _riskScoreService,
      anomalyService: _anomalyService,
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
        setState(
          () => _statusText =
              AppLocalizations.of(context)?.statusResponseReceived ??
              'Response received',
        );
        _resetUI(); // Reset UI immediately since no TTS
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
    _currentAmplitude = 0;
    _statusText =
        AppLocalizations.of(context)?.statusListening ?? 'Listening...';

    final dir = await getTemporaryDirectory();
    _recordingPath =
        '${dir.path}/qwen_recording_${DateTime.now().millisecondsSinceEpoch}.aac';

    await _audioRecorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
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

  void _onAmplitudeChanged(double amplitude) {
    if (!_isListening) return;

    _currentAmplitude = amplitude.abs();
    final isSpeaking = _currentAmplitude > _silenceThreshold;

    if (isSpeaking) {
      if (!_wasSpeaking) {
        _speechStarted = true;
        if (mounted)
          setState(
            () => _statusText =
                AppLocalizations.of(context)?.statusListening ?? 'Listening...',
          );
      }
      _wasSpeaking = true;
      _silenceDetectionTimer?.cancel();
      _silenceDetectionTimer = null;
    } else if (_speechStarted && _wasSpeaking) {
      if (_silenceDetectionTimer == null) {
        if (mounted)
          setState(
            () => _statusText =
                AppLocalizations.of(context)?.statusDetectingSilence ??
                'Detecting silence...',
          );
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
    _statusText =
        AppLocalizations.of(context)?.statusProcessing ?? 'Processing...';

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

          // ENHANCED: Process through Natural Language Health Service
          final transcript = result['transcription'] as String? ?? '';
          final responseType = result['type'] as String? ?? '';
          final responseText = result['response'] as String? ?? '';
          if (responseType.isEmpty &&
              responseText.isEmpty &&
              transcript.isNotEmpty) {
            await _processNaturalLanguageQuery(transcript);
            return; // Skip the rest since we handled it with NL service
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
            try {
              debugPrint('🔊 Generating TTS for: "$responseText"');
              final ttsAudio = await _qwenService.speak(responseText);
              debugPrint(
                '🔊 TTS audio generated, size: ${ttsAudio.length} bytes',
              );
              await _playMp3Audio(ttsAudio);
              debugPrint('🔊 Audio playback completed');
            } catch (e) {
              debugPrint('❌ TTS playback error: $e');
              if (mounted) {
                setState(() => _statusText = 'Audio playback error');
              }
            }
          } else {
            debugPrint('⚠️ No response text to convert to speech');
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

        if (functionCalls.isNotEmpty && mounted) {
          // Show success message for function calls
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

    // Show analyzing indicator
    setState(() {
      _showStressIndicator = true;
      _lastStressAnalysis = VoiceStressResult(
        stressScore: 0,
        stressLevel: 'low',
        contributingFactors: [],
        confidence: 0,
        transcription: '',
        response: '',
      ); // Placeholder while loading
    });

    try {
      final file = File(audioPath);
      if (!await file.exists()) return;

      final bytes = await file.readAsBytes();
      final base64Audio = base64Encode(bytes);

      final result = await _novelAIService.analyzeVoiceStress(base64Audio);

      if (mounted && result != null) {
        setState(() {
          _lastStressAnalysis = result;
          // Keep showing for a while, or until new recording
        });

        // If high stress detected, update avatar emotion
        if (result.stressScore > 70) {
          setState(() => _currentEmotion = AvatarEmotion.concerned);
        }
      }
    } catch (e) {
      debugPrint('Error in background stress analysis: $e');
    }
  }

  // ─────────────── Helpers ───────────────
  void _resetUI() {
    _isSpeaking = false;
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
    if (mounted)
      setState(
        () => _statusText =
            AppLocalizations.of(context)?.statusGeneratingReport ??
            'Generating report...',
      );

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
      if (mounted)
        setState(
          () => _statusText =
              AppLocalizations.of(context)?.statusErrorGeneratingReport ??
              'Error generating report',
        );
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

  // ─────────────── Enhanced Natural Language Processing ───────────────
  Future<void> _processNaturalLanguageQuery(String transcript) async {
    try {
      setState(
        () => _statusText =
            AppLocalizations.of(context)?.statusUnderstandingQuery ??
            'Understanding your health query...',
      );

      // Get current locale
      final locale = Localizations.localeOf(context);
      final languageCode = locale.languageCode; // 'en' or 'fr'

      // Analyze the natural language query with language
      final intent = await _nlHealthService.analyzeHealthQuery(
        transcript,
        language: languageCode,
      );

      // Generate contextual health response with language
      final response = await _nlHealthService.generateHealthResponse(
        intent,
        language: languageCode,
      );

      // Update avatar emotion based on query type
      _updateAvatarEmotion(intent.intent);

      // Convert response to speech
      setState(
        () => _statusText =
            AppLocalizations.of(context)?.statusSpeaking ??
            'Speaking response...',
      );
      if (!_qwenService.isConnected) {
        await _qwenService.connect();
      }
      final audioResponse = await _qwenService.speak(response);
      await _playMp3Audio(audioResponse);

      debugPrint('🤖 Natural Language Query: "$transcript"');
      debugPrint('🌐 Language: $languageCode');
      debugPrint('🎯 Intent: ${intent.intent.name}');
      debugPrint('💬 Response: "$response"');
    } catch (e) {
      debugPrint('❌ Error processing natural language query: $e');
      setState(
        () => _statusText =
            AppLocalizations.of(context)?.statusErrorProcessingAudio ??
            'Error processing query',
      );

      // Fallback response - localized
      final locale = Localizations.localeOf(context);
      final fallbackResponse = locale.languageCode == 'fr'
          ? 'Je n\'ai pas pu comprendre cela. Vous pouvez poser des questions sur votre état de santé, votre score de risque, vos lectures de tension artérielle ou les tendances de santé.'
          : 'I had trouble understanding that. You can ask about your health status, risk score, blood pressure readings, or health trends.';
      if (!_qwenService.isConnected) {
        await _qwenService.connect();
      }
      final audioResponse = await _qwenService.speak(fallbackResponse);
      await _playMp3Audio(audioResponse);
    }
  }

  void _updateAvatarEmotion(HealthIntentType intent) {
    AvatarEmotion newEmotion = AvatarEmotion.neutral;

    switch (intent) {
      case HealthIntentType.healthStatus:
      case HealthIntentType.recommendations:
        newEmotion = AvatarEmotion.helpful;
        break;
      case HealthIntentType.riskScore:
      case HealthIntentType.anomalies:
        newEmotion = AvatarEmotion.concerned;
        break;
      case HealthIntentType.trends:
      case HealthIntentType.comparison:
        newEmotion = AvatarEmotion.analytical;
        break;
      case HealthIntentType.bpReadings:
      case HealthIntentType.medication:
        newEmotion = AvatarEmotion.informative;
        break;
    }

    setState(() => _currentEmotion = newEmotion);

    // Return to neutral after 5 seconds
    Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _currentEmotion = AvatarEmotion.neutral);
    });
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

  // ─────────────── Premium UI: Luxury Concierge Style ───────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);

    // Deep rich background for dark mode, soft pearl/off-white for light mode
    final bgGradient = isDark
        ? const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF12121A), Color(0xFF0A0A0F)],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF8F9FA), Color(0xFFF2F2F7)],
          );

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF8F9FA),
      body: Stack(
        children: [
          // ── Background Gradient ──
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(gradient: bgGradient),
          ),

          // ── Soft Radial Depth Glow (Light Mode) ──
          if (!isDark)
            Positioned(
              top: size.height * 0.15,
              left: -size.width * 0.2,
              right: -size.width * 0.2,
              child: Container(
                height: size.height * 0.6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      theme.colorScheme.primary.withValues(alpha: 0.04),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

          // ── Main UI Stack ──
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Elegant "Insights" Title
                _buildLuxuryTitle(theme),

                // 2. Avatar Hero (Seamlessly Blended)
                Expanded(
                  flex: 6,
                  child: Center(
                    child: _buildBlendedAvatar(isDark, size, theme),
                  ),
                ),

                // 3. Lower Content Spacer
                const Spacer(flex: 1),

                // 4. Elegant Text Prompt
                _buildElegantPrompt(isDark, theme),

                const SizedBox(height: 36),

                // 5. Luxury Custom Microphone Button
                Center(
                  child: _buildLuxuryMicButton(isDark, theme),
                ),

                const SizedBox(height: 48),
              ],
            ),
          ),

          // ── Prescription Overlay ──
          if (_showPrescription)
            Positioned.fill(
              child: Container(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.7)
                    : Colors.black.withValues(alpha: 0.3),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: _buildPrescriptionOverlay(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLuxuryTitle(ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    // Use the translated insightsPageTitle, but we will update the arb files
    // so it simply says "Insights" or "Aperçus" instead of "Health Assistant".
    final titleText = l10n?.insightsPageTitle ?? 'Insights';

    return Padding(
      padding: const EdgeInsets.only(top: 24.0, left: 32.0, right: 32.0, bottom: 16.0),
      child: Text(
        titleText,
        style: TextStyle(
          color: theme.colorScheme.onSurface,
          fontSize: 34,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.0,
        ),
      ),
    );
  }

  Widget _buildBlendedAvatar(bool isDark, Size size, ThemeData theme) {
    // The avatar must blend seamlessly. We give it massive breathing room
    // and a very soft, premium underlying shadow that adapts to the theme.
    final avatarSize = size.width * 0.75;

    return Container(
      width: avatarSize,
      height: avatarSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          // Deep wide shadow for depth
          BoxShadow(
            color: isDark 
                ? Colors.black.withValues(alpha: 0.5) 
                : theme.colorScheme.primary.withValues(alpha: 0.08),
            blurRadius: 50,
            spreadRadius: 5,
          ),
          // Subtle accent glow for dark mode
          if (isDark)
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              blurRadius: 40,
              spreadRadius: -10,
            ),
        ],
      ),
      child: ClipOval(
        child: TalkingAvatarWidget(
          isSpeaking: _isSpeaking,
          isListening: _isListening,
          emotion: _currentEmotion,
          onLoaded: () {},
          width: avatarSize,
          height: avatarSize,
        ),
      ),
    );
  }

  Widget _buildElegantPrompt(bool isDark, ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    
    // Smooth elegant localized strings
    final fallbackTapToSpeak = l10n?.statusTapToSpeak ?? 'Tap to speak';
    final fallbackListening = l10n?.statusListening ?? 'Listening...';
    
    String promptText = _isListening ? fallbackListening : _statusText;
    if (promptText.isEmpty || promptText == fallbackTapToSpeak) {
      promptText = fallbackTapToSpeak;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Text(
          promptText,
          key: ValueKey(promptText),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isDark 
                ? Colors.grey.shade500 
                : theme.colorScheme.onSurface.withValues(alpha: 0.6),
            fontSize: 16,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildLuxuryMicButton(bool isDark, ThemeData theme) {
    final bool listening = _isListening;
    
    // Luxury sizing Custom Container
    final double buttonSize = listening ? 88.0 : 80.0;
    
    // Rich, deliberate colors
    // Dark mode: a dark, sleek glassmorphic container / rich dark accent 
    final Color darkBgColor = listening ? const Color(0xFFE53935) : const Color(0xFF1E293B);
    // Light mode: clean frosty white / soft accent
    final Color lightBgColor = listening ? const Color(0xFFEF5350) : Colors.white;
    
    final Color darkIconColor = Colors.white;
    final Color lightIconColor = listening ? Colors.white : theme.colorScheme.primary;
    
    // Multi-layered refined shadows
    final List<BoxShadow> darkShadows = listening
      ? [
          BoxShadow(color: const Color(0xFFE53935).withValues(alpha: 0.4), blurRadius: 30, spreadRadius: 5),
        ]
      : [
          BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 20, offset: const Offset(0, 10)),
          BoxShadow(color: theme.colorScheme.primary.withValues(alpha: 0.15), blurRadius: 30, spreadRadius: 2),
        ];
        
    final List<BoxShadow> lightShadows = listening
      ? [
          BoxShadow(color: const Color(0xFFEF5350).withValues(alpha: 0.35), blurRadius: 24, spreadRadius: 4),
        ]
      : [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 10)),
          BoxShadow(color: theme.colorScheme.primary.withValues(alpha: 0.05), blurRadius: 30, spreadRadius: 5),
        ];

    return GestureDetector(
      onTap: listening ? _stopListening : _startListening,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutBack,
        width: buttonSize,
        height: buttonSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? darkBgColor : lightBgColor,
          boxShadow: isDark ? darkShadows : lightShadows,
          border: isDark && !listening 
              ? Border.all(color: Colors.white.withValues(alpha: 0.05), width: 1.5) 
              : null,
        ),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              listening ? Icons.stop_rounded : Icons.mic_none_rounded,
              key: ValueKey(listening),
              color: isDark ? darkIconColor : lightIconColor,
              size: 34,
            ),
          ),
        ),
      ),
    );
  }

  // Hidden/Removed Stress indicator from main UI but kept for compat
  // ignore: unused_element
  Widget _buildStressIndicator(bool isDark) {
    return Container();
  }
}
