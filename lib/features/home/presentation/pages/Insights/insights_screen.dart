import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';

import 'package:arteria/env/env.dart';
import 'package:arteria/features/reminders/reminder_bloc.dart';
import 'package:arteria/features/reminders/reminder_event.dart';
import 'package:arteria/features/reminders/reminder_model.dart';

import '../settings/settings_bloc.dart';
import '../../components/talking_avatar_widget.dart';
import 'openai_realtime_bloc.dart';
import 'bp_data_bloc.dart';

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

    final combined =
        Uint8List.fromList(_audioChunks.expand((e) => e).toList());
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
    header.setUint8(8, 0x57);  // 'W'
    header.setUint8(9, 0x41);  // 'A'
    header.setUint8(10, 0x56); // 'V'
    header.setUint8(11, 0x45); // 'E'
    
    // fmt sub-chunk
    header.setUint8(12, 0x66); // 'f'
    header.setUint8(13, 0x6D); // 'm'
    header.setUint8(14, 0x74); // 't'
    header.setUint8(15, 0x20); // ' '
    header.setUint32(16, 16, Endian.little); // Subchunk1 size (16 for PCM)
    header.setUint16(20, 1, Endian.little);  // Audio format (1 = PCM)
    header.setUint16(22, numChannels, Endian.little); // Number of channels
    header.setUint32(24, sampleRate, Endian.little);  // Sample rate
    header.setUint32(28, byteRate, Endian.little);    // Byte rate
    header.setUint16(32, blockAlign, Endian.little);  // Block align
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
    final latest = await _bpDataService.getLatestReading(widget.userId);
    return 'Latest BP reading: $latest';
  }

  void _handleFunctionCall(dynamic data) {
    if (data is! Map<String, dynamic>) return;
    if (data['name'] != 'set_reminder') return;

    final args = data['arguments'];
    context.read<ReminderBloc>().add(
          AddReminder(
            time: TimeOfDay(hour: args['hour'], minute: args['minute']),
            repeatType: RepeatType.daily,
          ),
        );
  }

  // ─────────────── UI ───────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
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
        border: Border.all(
          color: color.withValues(alpha: 0.5),
          width: 1.5,
        ),
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
