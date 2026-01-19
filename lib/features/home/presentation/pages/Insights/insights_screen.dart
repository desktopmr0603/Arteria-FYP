import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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

import '../settings/settings_bloc.dart';
import '../../components/talking_avatar_widget.dart';
import 'openai_realtime_bloc.dart';
import 'bp_data_bloc.dart';
import 'whatif_screen.dart';

class InsightsScreen extends StatefulWidget {
  final String userId;
  final int? userAge;

  const InsightsScreen({super.key, this.userId = 'default_user', this.userAge});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  // ─────────────── State ───────────────
  bool _isListening = false;
  bool _isSpeaking = false;
  bool _isConversationActive = false;

  String _statusText = 'Connecting...';

  // ─────────────── Premium UI State ───────────────
  Medication? _addedMedication;
  bool _showPrescription = false;
  Timer? _prescriptionTimer;

  // ─────────────── Services ───────────────
  late OpenAIRealtimeService _realtimeService;
  final BPDataService _bpDataService = BPDataService();

  // ─────────────── Audio ───────────────
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  StreamSubscription<Uint8List>? _audioStreamSub;
  StreamSubscription<RealtimeEvent>? _realtimeEventSub;

  final List<Uint8List> _audioChunks = [];
  bool _hasRecordedAudio = false;

  // ─────────────── Language ───────────────
  String _language = 'en';

  // ─────────────── Lifecycle ───────────────
  @override
  void initState() {
    super.initState();
    _initLanguageAndRealtime();
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _audioStreamSub?.cancel();
    _realtimeEventSub?.cancel();
    _realtimeService.dispose();
    _prescriptionTimer?.cancel();
    super.dispose();
  }

  // ─────────────── Initialization ───────────────
  void _initLanguageAndRealtime() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = context.read<SettingsBloc>().state;
      _language = settings.locale.languageCode;
      _initializeRealtimeService();
    });
  }

  Future<void> _initializeRealtimeService() async {
    _realtimeService = OpenAIRealtimeService(
      apiKey: Env.openaiApiKey,
      model: 'gpt-realtime-mini-2025-10-06',
      voice: 'alloy',
      language: _language,
    );

    _realtimeEventSub = _realtimeService.events.listen(_handleRealtimeEvent);

    final contextText = await _buildUserContext();
    await _realtimeService.connect(userContext: contextText);

    if (mounted) {
      setState(() => _statusText = 'Tap to speak');
    }
  }

  // ─────────────── Realtime Events ───────────────
  void _handleRealtimeEvent(RealtimeEvent event) {
    if (!mounted) return;

    switch (event.type) {
      case RealtimeEventType.audioResponse:
        final chunk = event.data as Uint8List;
        _audioChunks.add(chunk);
        _isSpeaking = true;
        break;

      case RealtimeEventType.audioResponseDone:
        _playBufferedAudio();
        break;

      case RealtimeEventType.ready:
        _resetUI(autoRestart: true);
        break;

      case RealtimeEventType.functionCall:
        _handleFunctionCall(event.data);
        break;

      default:
        break;
    }

    if (mounted) {
      setState(() {});
    }
  }

  // ─────────────── Audio Playback ───────────────
  Future<void> _playBufferedAudio() async {
    if (_audioChunks.isEmpty) return;

    final combined = Uint8List.fromList(_audioChunks.expand((e) => e).toList());
    _audioChunks.clear();

    await _audioPlayer.play(BytesSource(_pcm16ToWav(combined)));
    await _audioPlayer.onPlayerComplete.first;

    _resetUI(autoRestart: true);
  }

  Uint8List _pcm16ToWav(Uint8List pcm) {
    const sampleRate = 24000;
    const numChannels = 1;
    const bitsPerSample = 16;
    const byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
    const blockAlign = numChannels * bitsPerSample ~/ 8;

    final dataSize = pcm.length;
    final fileSize = 36 + dataSize;

    final header = ByteData(44);

    // RIFF chunk descriptor
    header.setUint8(0, 0x52); // 'R'
    header.setUint8(1, 0x49); // 'I'
    header.setUint8(2, 0x46); // 'F'
    header.setUint8(3, 0x46); // 'F'
    header.setUint32(4, fileSize, Endian.little); // File size - 8
    header.setUint8(8, 0x57); // 'W'
    header.setUint8(9, 0x41); // 'A'
    header.setUint8(10, 0x56); // 'V'
    header.setUint8(11, 0x45); // 'E'

    // fmt sub-chunk
    header.setUint8(12, 0x66); // 'f'
    header.setUint8(13, 0x6D); // 'm'
    header.setUint8(14, 0x74); // 't'
    header.setUint8(15, 0x20); // ' '
    header.setUint32(16, 16, Endian.little); // Subchunk1 size (16 for PCM)
    header.setUint16(20, 1, Endian.little); // Audio format (1 = PCM)
    header.setUint16(22, numChannels, Endian.little); // Number of channels
    header.setUint32(24, sampleRate, Endian.little); // Sample rate
    header.setUint32(28, byteRate, Endian.little); // Byte rate
    header.setUint16(32, blockAlign, Endian.little); // Block align
    header.setUint16(34, bitsPerSample, Endian.little); // Bits per sample

    // data sub-chunk
    header.setUint8(36, 0x64); // 'd'
    header.setUint8(37, 0x61); // 'a'
    header.setUint8(38, 0x74); // 't'
    header.setUint8(39, 0x61); // 'a'
    header.setUint32(40, dataSize, Endian.little); // Data size

    final out = Uint8List(44 + pcm.length);
    out.setRange(0, 44, header.buffer.asUint8List());
    out.setRange(44, out.length, pcm);
    return out;
  }

  // ─────────────── Recording ───────────────
  Future<void> _startListening() async {
    if (!await _audioRecorder.hasPermission()) return;

    _isConversationActive = true;
    _isListening = true;
    _hasRecordedAudio = false;
    _statusText = 'Listening...';

    final stream = await _audioRecorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 24000,
        numChannels: 1,
      ),
    );

    _audioStreamSub = stream.listen((data) {
      _hasRecordedAudio = true;
      _realtimeService.sendAudio(data);
    });

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _stopListening() async {
    await _audioRecorder.stop();
    await _audioStreamSub?.cancel();

    _isListening = false;
    _statusText = 'Processing...';

    if (_hasRecordedAudio) {
      await _realtimeService.commitAudio();
    }

    if (mounted) {
      setState(() {});
    }
  }

  // ─────────────── Helpers ───────────────
  void _resetUI({bool autoRestart = false}) {
    _isSpeaking = false;
    _statusText = 'Tap to speak';

    if (autoRestart && _isConversationActive) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) _startListening();
      });
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<String> _buildUserContext() async {
    final latestReading = await _bpDataService.getLatestReading(widget.userId);
    final history = await _bpDataService.getHistory(widget.userId, days: 7);
    final userProfile = await _bpDataService.getUserProfile(widget.userId);

    return _bpDataService.formatBPContext(
      userId: widget.userId,
      latestReading: latestReading,
      weeklyReadings: history,
      userAge: widget.userAge ?? userProfile?['age'],
      gender: userProfile?['gender'],
      medicalProfile: userProfile,
    );
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
      context.read<UserBloc>().add(
        SaveBPReading(systolic: args['systolic'], diastolic: args['diastolic']),
      );
    } else if (name == 'add_medication') {
      final args = data['arguments'];
      _addMedication(args);
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
    final name = args['name'] as String? ?? '';
    final dosage = args['dosage'] as String? ?? '1 tablet';
    final frequencyStr = args['frequency'] as String? ?? 'onceDaily';
    final instructions = args['instructions'] as String?;

    if (name.isEmpty) return;

    try {
      final MedicationFrequency frequency = MedicationFrequency.values
          .firstWhere(
            (e) => e.name == frequencyStr,
            orElse: () => MedicationFrequency.onceDaily,
          );

      final medication = Medication(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        dosage: dosage,
        frequency: frequency,
        times: frequency.defaultTimes,
        isActive: true,
        takenToday: false,
        createdAt: DateTime.now(),
        color: const Color(0xFF6366F1),
        instructions: instructions,
      );

      final repository = MedicationRepositoryImpl();
      
      // ─────────────── Duplicate Detection ───────────────
      final existingMeds = await repository.getMedications(widget.userId);
      final isDuplicate = existingMeds.any(
        (m) => m.name.toLowerCase().trim() == name.toLowerCase().trim(),
      );

      if (isDuplicate) {
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

      await repository.addMedication(widget.userId, medication);

      if (!mounted) return;

      // Show Premium Prescription UI
      setState(() {
        _addedMedication = medication;
        _showPrescription = true;
      });

      // Auto-hide after 6 seconds
      _prescriptionTimer?.cancel();
      _prescriptionTimer = Timer(const Duration(seconds: 6), () {
        if (mounted) {
          setState(() => _showPrescription = false);
        }
      });
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

              const SizedBox(height: 24),

              // Footer CTA
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.check_circle_outline_rounded,
                      color: Color(0xFF6366F1),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.viewOnHome,
                      style: const TextStyle(
                        color: Color(0xFF6366F1),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrescriptionDetail(String label, String value, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: isDark ? Colors.white54 : Colors.black45,
        ),
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

  // ─────────────── UI ───────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [
                        const Color(0xFF1A1A2E),
                        const Color(0xFF16213E),
                        const Color(0xFF0F3460),
                      ]
                    : [
                        const Color(0xFFE8F5E9),
                        const Color(0xFFB2DFDB),
                        const Color(0xFF80CBC4),
                      ],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 32),

                  // Status Text with styled container
                  _buildStatusChip(),

                  const SizedBox(height: 24),

                  // 3D Avatar
                  Expanded(
                    child: Center(
                      child: TalkingAvatarWidget(
                        isSpeaking: _isSpeaking,
                        onLoaded: () {},
                        width: MediaQuery.of(context).size.width * 0.85,
                        height: MediaQuery.of(context).size.height * 0.5,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Microphone Button
                  _buildMicButton(),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),

          // Prescrition Overlay
          if (_showPrescription)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.3),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: _buildPrescriptionOverlay(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusChip() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    IconData icon;
    Color color;

    if (_statusText.contains('Listening')) {
      icon = Icons.hearing;
      color = Colors.green;
    } else if (_statusText.contains('Processing')) {
      icon = Icons.sync;
      color = Colors.orange;
    } else if (_statusText.contains('Connecting')) {
      icon = Icons.cloud_sync;
      color = Colors.blue;
    } else {
      icon = Icons.touch_app;
      color = Theme.of(context).primaryColor;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Text(
            _statusText,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMicButton() {
    return GestureDetector(
      onTap: _isListening ? _stopListening : _startListening,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: _isListening ? 80 : 72,
        height: _isListening ? 80 : 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _isListening
                ? [Colors.red.shade400, Colors.red.shade700]
                : [
                    Theme.of(context).primaryColor,
                    Theme.of(context).primaryColor.withBlue(200),
                  ],
          ),
          boxShadow: [
            BoxShadow(
              color: _isListening
                  ? Colors.red.withValues(alpha: 0.4)
                  : Theme.of(context).primaryColor.withValues(alpha: 0.4),
              blurRadius: _isListening ? 25 : 15,
              spreadRadius: _isListening ? 3 : 1,
            ),
          ],
        ),
        child: Icon(
          _isListening ? Icons.stop : Icons.mic,
          color: Colors.white,
          size: 32,
        ),
      ),
    );
  }
}
