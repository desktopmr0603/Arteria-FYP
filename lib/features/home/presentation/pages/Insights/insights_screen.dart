import 'package:arteria/env/env.dart';
import 'package:arteria/features/reminders/reminder_bloc.dart';
import 'package:arteria/features/reminders/reminder_event.dart';
import 'package:arteria/features/reminders/reminder_model.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:siri_wave/siri_wave.dart';
import 'openai_realtime_bloc.dart';
import 'bp_data_bloc.dart';
import '../settings/settings_bloc.dart';

class InsightsScreen extends StatefulWidget {
  final String userId;
  final int? userAge;

  const InsightsScreen({super.key, this.userId = 'default_user', this.userAge});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  // Voice interaction state
  bool _isListening = false;
  bool _isProcessing = false;
  bool _isSpeaking = false;
  String _statusText = 'Connecting...';

  // Services
  late OpenAIRealtimeService _realtimeService;
  final BPDataService _bpDataService = BPDataService();

  // Audio
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription<Uint8List>? _audioStreamSubscription;
  StreamSubscription<RealtimeEvent>? _eventSubscription;

  // Siri Wave controller
  final IOS9SiriWaveformController _waveController = IOS9SiriWaveformController(
    amplitude: 0.2,
    speed: 0.15,
  );

  // Audio buffer for playback - simplified approach
  final List<Uint8List> _audioChunks = [];
  bool _isAudioResponseActive = false;
  bool _hasRecordedAudio = false;
  bool _isConversationActive =
      false; // Track if we're in an active conversation

  // Language setting
  String _language = 'en';

  @override
  void initState() {
    super.initState();
    _initializeLanguageAndService();
  }

  void _initializeLanguageAndService() {
    // Get language from settings, but we need to delay until context is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final settingsState = context.read<SettingsBloc>().state;
        _language = settingsState.locale.languageCode;
        debugPrint('🌍 Insights screen using language: $_language');
        _initializeRealtimeService();
      }
    });
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _audioStreamSubscription?.cancel();
    _eventSubscription?.cancel();
    _realtimeService.dispose();
    super.dispose();
  }

  Future<void> _initializeRealtimeService() async {
    try {
      final apiKey = Env.openaiApiKey;
      if (apiKey == 'YOUR_OPENAI_API_KEY' || apiKey.isEmpty) {
        _setStatus('Error: Please set your OpenAI API key');
        debugPrint('❌ API key not configured!');
        return;
      }

      _realtimeService = OpenAIRealtimeService(
        apiKey: apiKey,
        model: 'gpt-realtime-mini-2025-10-06',
        voice: 'alloy',
        language: _language,
      );

      _eventSubscription = _realtimeService.events.listen(_handleRealtimeEvent);

      _setStatus('Loading your BP data...');
      final userContext = await _buildUserContext();

      _setStatus('Connecting to AI assistant...');
      await _realtimeService.connect(userContext: userContext);
    } catch (e) {
      _setStatus('Connection failed. Please try again.');
      debugPrint('❌ Error initializing: $e');
    }
  }

  Future<String> _buildUserContext() async {
    try {
      final profile = await _bpDataService.getUserProfile(widget.userId);
      final userAge = widget.userAge ?? profile?['age'] as int?;
      final gender = profile?['gender'] as String?;
      final latestReading = await _bpDataService.getLatestReading(
        widget.userId,
      );
      final weeklyReadings = await _bpDataService.getHistory(
        widget.userId,
        days: 7,
      );

      // Build medical profile map
      final medicalProfile = profile != null
          ? {
              'medications': profile['medications'],
              'smoker': profile['smoker'],
              'isPregnant': profile['isPregnant'],
              'hasDiabetes': profile['hasDiabetes'],
              'physicalActivity': profile['physicalActivity'],
              'weight': profile['weight'],
              'height': profile['height'],
            }
          : null;

      final context = _bpDataService.formatBPContext(
        userId: widget.userId,
        latestReading: latestReading,
        weeklyReadings: weeklyReadings.isNotEmpty ? weeklyReadings : null,
        userAge: userAge,
        gender: gender,
        medicalProfile: medicalProfile,
      );

      debugPrint('📊 BP Context built with medical history');
      return context;
    } catch (e) {
      debugPrint('Error building context: $e');
      return 'User ID: ${widget.userId}\nNote: Unable to fetch BP data.';
    }
  }

  void _handleRealtimeEvent(RealtimeEvent event) {
    if (!mounted) return;

    switch (event.type) {
      case RealtimeEventType.connected:
        _setStatus('Initializing...');
        break;

      case RealtimeEventType.ready:
        _setStatus('Ready! Tap to speak');
        setState(() => _isProcessing = false);
        break;

      case RealtimeEventType.audioResponse:
        if (event.data is Uint8List) {
          final audioData = event.data as Uint8List;
          if (audioData.isNotEmpty) {
            // Mark that we're receiving audio
            if (!_isAudioResponseActive) {
              debugPrint('🎵 Audio response started');
              setState(() {
                _isAudioResponseActive = true;
                _isProcessing = false;
                _isSpeaking = true;
                _statusText = 'Speaking...';
                _waveController.amplitude = 1.0;
              });
              // Clear old chunks
              _audioChunks.clear();
            }

            // Buffer the chunk
            _audioChunks.add(audioData);
            debugPrint(
              '📦 Buffered chunk: ${audioData.length} bytes (total chunks: ${_audioChunks.length})',
            );
          }
        }
        break;

      case RealtimeEventType.audioResponseDone:
        debugPrint('✓ Audio response complete - playing now');
        // Now play all the buffered audio
        _playAllBufferedAudio();
        break;

      case RealtimeEventType.textDelta:
        debugPrint('AI: ${event.data}');
        break;

      case RealtimeEventType.transcript:
        final transcript = event.data as String;
        debugPrint('📝 User said: $transcript');
        if (mounted) {
          setState(() {
            _statusText =
                'You: "${transcript.length > 50 ? '${transcript.substring(0, 50)}...' : transcript}"';
          });
        }
        break;

      case RealtimeEventType.processing:
        debugPrint('⏳ Processing...');
        // Stop recording when server starts processing (VAD detected end of speech)
        if (_isListening && _hasRecordedAudio) {
          _stopRecordingForProcessing();
        }
        setState(() {
          _isProcessing = true;
          _statusText = 'Processing...';
          _audioChunks.clear();
          _isAudioResponseActive = false;
        });
        break;

      case RealtimeEventType.error:
        final errorMsg = event.message ?? 'Unknown error';
        if (errorMsg.contains('buffer too small') && !_hasRecordedAudio) {
          debugPrint('ℹ️ Ignoring buffer_too_small (no audio recorded)');
          _resetToReady();
          return;
        }
        _setStatus('Error: ${event.message}');
        setState(() {
          _isProcessing = false;
          _isListening = false;
          _waveController.amplitude = 0.2;
        });
        break;

      case RealtimeEventType.functionCall:
        // Handle AI function calls (e.g., set_reminder)
        _handleFunctionCall(event.data);
        break;

      case RealtimeEventType.disconnected:
        _setStatus('Disconnected. Tap to reconnect.');
        setState(() {
          _isProcessing = false;
          _isListening = false;
        });
        break;
    }
  }

  Future<void> _playAllBufferedAudio() async {
    if (_audioChunks.isEmpty) {
      debugPrint('⚠️ No audio chunks to play');
      // Don't auto-restart on empty - something went wrong
      _resetToReady(autoRestart: false);
      return;
    }

    try {
      // Combine all buffered chunks
      final totalLength = _audioChunks.fold<int>(
        0,
        (sum, chunk) => sum + chunk.length,
      );
      final combinedAudio = Uint8List(totalLength);
      var offset = 0;
      for (final chunk in _audioChunks) {
        combinedAudio.setRange(offset, offset + chunk.length, chunk);
        offset += chunk.length;
      }

      debugPrint(
        '🔊 Playing combined audio: ${combinedAudio.length} bytes from ${_audioChunks.length} chunks',
      );

      // Convert to WAV
      final wavData = _convertPCM16ToWav(combinedAudio);

      // Play
      await _audioPlayer.stop(); // Stop any previous audio
      await _audioPlayer.play(BytesSource(wavData));

      // Wait for completion
      await _audioPlayer.onPlayerComplete.first.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('⚠️ Playback timeout');
          return;
        },
      );

      debugPrint('✓ Playback complete');

      if (mounted) {
        // Auto-restart listening after successful audio playback
        _resetToReady(autoRestart: true);
      }
    } catch (e) {
      debugPrint('❌ Playback error: $e');
      if (mounted) {
        _resetToReady(autoRestart: false);
      }
    }
  }

  /// Handle AI function calls (like set_reminder)
  void _handleFunctionCall(dynamic data) {
    if (data is! Map<String, dynamic>) return;

    final name = data['name'] as String?;
    final arguments = data['arguments'] as Map<String, dynamic>?;

    debugPrint('🔧 Handling function call: $name');
    debugPrint('   Arguments: $arguments');

    if (name == 'set_reminder' && arguments != null) {
      final hour = arguments['hour'] as int?;
      final minute = arguments['minute'] as int?;
      final repeatTypeStr = arguments['repeat_type'] as String?;

      if (hour != null && minute != null) {
        // Convert repeat_type string to RepeatType enum
        RepeatType repeatType;
        switch (repeatTypeStr) {
          case 'weekdays':
            repeatType = RepeatType.weekdays;
            break;
          case 'weekends':
            repeatType = RepeatType.weekends;
            break;
          default:
            repeatType = RepeatType.daily;
        }

        // Create the reminder via BLoC
        context.read<ReminderBloc>().add(
          AddReminder(
            time: TimeOfDay(hour: hour, minute: minute),
            repeatType: repeatType,
          ),
        );

        debugPrint('✓ Reminder created: $hour:$minute ($repeatTypeStr)');

        // Show a brief confirmation snackbar
        if (mounted) {
          final formattedTime = TimeOfDay(
            hour: hour,
            minute: minute,
          ).format(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Reminder set for $formattedTime'),
              duration: const Duration(seconds: 2),
              backgroundColor: const Color(0xFF1976D2),
            ),
          );
        }
      }
    }
  }

  Uint8List _convertPCM16ToWav(Uint8List pcmData) {
    const int sampleRate = 24000;
    const int numChannels = 1;
    const int bitsPerSample = 16;

    final int dataSize = pcmData.length;
    final int fileSize = 36 + dataSize;

    final ByteData header = ByteData(44);

    // RIFF header
    header.setUint8(0, 0x52); // 'R'
    header.setUint8(1, 0x49); // 'I'
    header.setUint8(2, 0x46); // 'F'
    header.setUint8(3, 0x46); // 'F'
    header.setUint32(4, fileSize, Endian.little);

    // WAVE header
    header.setUint8(8, 0x57); // 'W'
    header.setUint8(9, 0x41); // 'A'
    header.setUint8(10, 0x56); // 'V'
    header.setUint8(11, 0x45); // 'E'

    // fmt subchunk
    header.setUint8(12, 0x66); // 'f'
    header.setUint8(13, 0x6D); // 'm'
    header.setUint8(14, 0x74); // 't'
    header.setUint8(15, 0x20); // ' '
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little); // PCM
    header.setUint16(22, numChannels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(
      28,
      sampleRate * numChannels * bitsPerSample ~/ 8,
      Endian.little,
    );
    header.setUint16(32, numChannels * bitsPerSample ~/ 8, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);

    // data subchunk
    header.setUint8(36, 0x64); // 'd'
    header.setUint8(37, 0x61); // 'a'
    header.setUint8(38, 0x74); // 't'
    header.setUint8(39, 0x61); // 'a'
    header.setUint32(40, dataSize, Endian.little);

    final wavData = Uint8List(44 + dataSize);
    wavData.setRange(0, 44, header.buffer.asUint8List());
    wavData.setRange(44, 44 + dataSize, pcmData);

    return wavData;
  }

  void _resetToReady({bool autoRestart = false}) {
    setState(() {
      _isSpeaking = false;
      _isProcessing = false;
      _isAudioResponseActive = false;
      _waveController.amplitude = 0.2;
      _hasRecordedAudio = false;
    });
    _audioChunks.clear();

    // Auto-restart listening only if conversation is active AND we just played audio successfully
    if (autoRestart && _isConversationActive && mounted) {
      setState(() => _statusText = 'Listening...');
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && _isConversationActive && !_isListening && !_isSpeaking) {
          _startListening();
        }
      });
    } else {
      setState(() => _statusText = 'Tap to speak');
    }
  }

  /// Stop recording without committing (server VAD already handled this)
  Future<void> _stopRecordingForProcessing() async {
    if (!_isListening) return;

    try {
      await _audioRecorder.stop();
      await _audioStreamSubscription?.cancel();
      setState(() {
        _isListening = false;
        _waveController.amplitude = 0.2;
      });
      debugPrint('✓ Recording stopped for processing');
    } catch (e) {
      debugPrint('Error stopping recording: $e');
    }
  }

  void _setStatus(String status) {
    if (mounted) {
      setState(() => _statusText = status);
    }
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _stopListening();
    } else {
      await _startListening();
    }
  }

  Future<void> _startListening() async {
    // Cancel any active audio first
    await _audioPlayer.stop();
    _audioChunks.clear();
    _isAudioResponseActive = false;

    // Mark conversation as active
    _isConversationActive = true;

    if (!_realtimeService.isConnected) {
      _setStatus('Reconnecting...');
      await _initializeRealtimeService();
      await Future.delayed(const Duration(seconds: 1));

      if (!_realtimeService.isConnected) {
        _setStatus('Connection failed. Please try again.');
        _isConversationActive = false;
        return;
      }
    }

    try {
      if (await _audioRecorder.hasPermission()) {
        final stream = await _audioRecorder.startStream(
          const RecordConfig(
            encoder: AudioEncoder.pcm16bits,
            sampleRate: 24000,
            numChannels: 1,
          ),
        );

        setState(() {
          _isListening = true;
          _hasRecordedAudio = false;
          _waveController.amplitude = 0.5;
          _statusText = 'Listening...';
        });

        _audioStreamSubscription = stream.listen((data) {
          _realtimeService.sendAudio(data);
          _hasRecordedAudio = true;
        });

        _animateListeningWave();
      } else {
        _setStatus('Microphone permission denied');
        _isConversationActive = false;
      }
    } catch (e) {
      _setStatus('Error: $e');
      _isConversationActive = false;
      debugPrint('Recording error: $e');
    }
  }

  void _animateListeningWave() {
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!_isListening) {
        timer.cancel();
        return;
      }
      if (mounted) {
        setState(() {
          _waveController.amplitude =
              0.3 + (DateTime.now().millisecond % 500) / 1000;
        });
      }
    });
  }

  Future<void> _stopListening() async {
    // End the conversation when user explicitly stops
    _isConversationActive = false;

    try {
      await _audioRecorder.stop();
      await _audioStreamSubscription?.cancel();

      setState(() {
        _isListening = false;
        _isProcessing = true;
        _waveController.amplitude = 0.2;
        _statusText = 'Processing...';
      });

      if (_hasRecordedAudio) {
        await _realtimeService.commitAudio();
        debugPrint('✓ Audio committed');
      } else {
        debugPrint('ℹ️ No audio recorded');
        _resetToReady();
      }
    } catch (e) {
      _setStatus('Error: $e');
      setState(() {
        _isListening = false;
        _isProcessing = false;
        _waveController.amplitude = 0.2;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0E21) : Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),

            // Status text
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _statusText,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 60),

            // Siri Wave Animation
            Expanded(
              child: Center(
                child: GestureDetector(
                  onTap: _toggleListening,
                  child: SizedBox(
                    height: 180,
                    child: SiriWaveform.ios9(
                      controller: _waveController,
                      options: IOS9SiriWaveformOptions(
                        height: 180,
                        width: MediaQuery.of(context).size.width,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),

            // Microphone button
            GestureDetector(
              onTap: _toggleListening,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: _isListening
                        ? [Colors.red.shade400, Colors.red.shade600]
                        : [Colors.blue.shade400, Colors.blue.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (_isListening ? Colors.red : Colors.blue)
                          .withValues(alpha: 0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Icon(
                  _isListening ? Icons.mic : Icons.mic_none,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ),

            const SizedBox(height: 20),

            Text(
              _isListening ? 'Tap to stop' : 'Tap to speak',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
