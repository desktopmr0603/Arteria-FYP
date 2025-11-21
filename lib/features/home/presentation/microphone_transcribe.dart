import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dart_openai/dart_openai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:just_audio/just_audio.dart';
import 'package:siri_wave/siri_wave.dart';
import 'package:arteria/env/env.dart';

class MicrophoneTranscribe extends StatefulWidget {
  const MicrophoneTranscribe({super.key});

  @override
  State<MicrophoneTranscribe> createState() => _MicrophoneTranscribeState();
}

class _MicrophoneTranscribeState extends State<MicrophoneTranscribe> {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  String? _audioPath;
  bool _isRecording = false;
  String _displayText = 'Press and hold to record your blood pressure';
  Map<String, int>? _parsedBP;
  bool _isProcessing = false;
  bool _showReturnButton = false;
  IOS9SiriWaveformController? _waveController;
  bool _isPlayingTTS = false;

  Timer? _timer;
  int _secondsElapsed = 0;

  // Endpoints
  static const String _whisperEndpoint =
      'https://api.runpod.ai/v2/qpo2u2i4x2rutp/runsync';
  static const String _fastApiEndpoint = 'http://192.168.100.48:8000/analyze';
  static const String _speakEndpoint = 'http://192.168.100.48:8000/speak';

  String _selectedLanguage = 'en';

  // User profile and conversation state
  Map<String, dynamic>? _userProfile;
  final List<Map<String, String>> _conversationHistory = [];

  // 🆕 Track if we need to ask follow-up questions
  bool _isFirstReading = false;
  List<String> _pendingQuestions = [];
  int _currentQuestionIndex = 0;

  @override
  void initState() {
    super.initState();
    _waveController = IOS9SiriWaveformController(
      amplitude: 0.2,
      color1: Colors.blueAccent,
      color2: Colors.purpleAccent,
      color3: Colors.pinkAccent,
      speed: 0.2,
    );

    _initializeRecorder();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_recorder.isRecording) {
      _recorder.stopRecorder();
    }
    _recorder.closeRecorder();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _initializeRecorder() async {
    try {
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        setState(() => _displayText = 'Microphone permission denied');
        return;
      }

      if (!_recorder.isRecording) {
        await _recorder.openRecorder();
      }

      bool supported = await _recorder.isEncoderSupported(Codec.aacADTS);
      if (!supported) {
        debugPrint('⚠️ AAC codec not supported, switching to default');
      }

      await _loadApiKeys();
    } catch (e) {
      debugPrint('Recorder init failed: $e');
      setState(() => _displayText = 'Recorder init failed: ${e.toString()}');
    }
  }

  // 🆕 Enhanced profile loading with completeness check
  Future<void> _loadUserProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('⚠️ No user logged in');
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        debugPrint('⚠️ User document does not exist');
        return;
      }

      final data = doc.data();
      if (data == null) {
        debugPrint('⚠️ User document is empty');
        return;
      }

      setState(() {
        _userProfile = {
          // Basic info (from signup)
          'age': data['age'] as int?,
          'gender': data['gender'] as String?,
          'weight_kg': (data['weight'] as num?)?.toDouble(),
          'height_cm': (data['height'] as num?)?.toDouble(),

          // Health profile (may be null - LLM will ask)
          'smoker': data['smoker'] as bool?,
          'is_pregnant': data['isPregnant'] as bool?,
          'has_diabetes': data['hasDiabetes'] as bool?,
          'medications': data['medications'] as String?,
          'physical_activity': data['physicalActivity'] as String?,
        };
      });

      // 🆕 Check if this is first reading (health profile incomplete)
      _isFirstReading = _checkIfFirstReading();

      debugPrint('✅ User profile loaded: $_userProfile');
      debugPrint('📊 Is first reading: $_isFirstReading');
    } catch (e) {
      debugPrint('❌ Failed to load user profile: $e');
    }
  }

  // 🆕 Check if health profile is incomplete
  bool _checkIfFirstReading() {
    if (_userProfile == null) return true;

    // Check if key health fields are missing
    return _userProfile!['smoker'] == null ||
        _userProfile!['physical_activity'] == null ||
        _userProfile!['has_diabetes'] == null;
  }

  Future<void> _loadApiKeys() async {
    final runpodKey = await Env.runpodApiKey;
    if (runpodKey == null || runpodKey.isEmpty) {
      setState(() {
        _displayText = '⚠️ Error: RunPod API key not configured';
      });
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _secondsElapsed = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _secondsElapsed++);
    });
  }

  void _stopTimer() => _timer?.cancel();

  String _formatDuration(int seconds) {
    final d = Duration(seconds: seconds);
    return '${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';
  }

  Future<void> _startRecording() async {
    if (!await Permission.microphone.isGranted) {
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        setState(() => _displayText = 'Microphone permission denied');
        return;
      }
    }

    if (!_recorder.isRecording) {
      try {
        await _recorder.openRecorder();
      } catch (e) {
        debugPrint('Recorder open failed: $e');
      }
    }

    try {
      final dir = await getTemporaryDirectory();
      _audioPath =
          '${dir.path}/bp_recording_${DateTime.now().millisecondsSinceEpoch}.aac';

      bool supported = await _recorder.isEncoderSupported(Codec.aacADTS);
      final codec = supported ? Codec.aacADTS : Codec.aacMP4;

      await _recorder.startRecorder(toFile: _audioPath, codec: codec);

      setState(() {
        _isRecording = true;
        // 🆕 Dynamic prompt based on conversation state
        if (_pendingQuestions.isNotEmpty &&
            _currentQuestionIndex < _pendingQuestions.length) {
          _displayText =
              'Recording… ${_pendingQuestions[_currentQuestionIndex]}';
        } else {
          _displayText = 'Recording… Speak your blood pressure clearly.';
        }
        _parsedBP = null;
        _isProcessing = false;
        _showReturnButton = false;
      });

      _startTimer();
    } catch (e) {
      debugPrint('Recording error: $e');
      setState(() => _displayText = 'Recording error: ${e.toString()}');
    }
  }

  Future<void> _stopRecordingAndTranscribe() async {
    try {
      await _recorder.stopRecorder();
    } catch (_) {}
    _stopTimer();

    if (_audioPath != null && await File(_audioPath!).exists()) {
      setState(() {
        _isRecording = false;
        _displayText = 'Transcribing your voice…';
      });
      await _transcribeAudio();
    } else {
      setState(() {
        _isRecording = false;
        _displayText = 'No audio recorded.';
      });
    }
  }

  Future<void> _transcribeAudio() async {
    final runpodKey = Env.runpodApiKey;
    if (runpodKey.isEmpty) {
      setState(() => _displayText = 'Error: RunPod key missing');
      return;
    }

    try {
      final bytes = await File(_audioPath!).readAsBytes();
      if (bytes.isEmpty) throw Exception('Empty audio file');

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

      debugPrint('📡 [WHISPER] Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = (data['output']?['transcription'] as String?)?.trim();
        if (text == null || text.isEmpty) {
          setState(() => _displayText = 'No speech detected');
        } else {
          // 🆕 Route to appropriate handler
          if (_pendingQuestions.isNotEmpty &&
              _currentQuestionIndex < _pendingQuestions.length) {
            await _processFollowUpAnswer(text);
          } else {
            await _parseBloodPressure(text);
          }
        }
      } else {
        setState(
          () => _displayText = 'Transcription failed (${response.statusCode})',
        );
      }
    } catch (e) {
      setState(() => _displayText = 'Transcription error: ${e.toString()}');
    } finally {
      if (_audioPath != null && await File(_audioPath!).exists()) {
        try {
          await File(_audioPath!).delete();
        } catch (_) {}
      }
    }
  }

  // 🆕 Process follow-up answers
  Future<void> _processFollowUpAnswer(String answer) async {
    final currentQuestion = _pendingQuestions[_currentQuestionIndex];

    // Store answer in conversation history
    _conversationHistory.add({'role': 'assistant', 'content': currentQuestion});
    _conversationHistory.add({'role': 'user', 'content': answer});

    // 🆕 Parse and save answer to Firestore
    await _parseAndSaveAnswer(currentQuestion, answer);

    // Move to next question
    setState(() => _currentQuestionIndex++);

    if (_currentQuestionIndex < _pendingQuestions.length) {
      // Ask next question
      final nextQuestion = _pendingQuestions[_currentQuestionIndex];
      setState(() => _displayText = nextQuestion);
      await _fetchSpeakAndPlay(nextQuestion);
    } else {
      // All questions answered - show final analysis
      setState(() {
        _displayText =
            'Thank you! Generating your personalized blood pressure analysis...';
        _pendingQuestions = [];
        _currentQuestionIndex = 0;
      });

      // Reload profile with new data
      await _loadUserProfile();

      // Generate final analysis with complete profile
      if (_parsedBP != null) {
        await _analyzeWithLLM();
      }
    }
  }

  // 🆕 Parse answer and save to Firestore
  Future<void> _parseAndSaveAnswer(String question, String answer) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final answerLower = answer.toLowerCase();
    final userDoc = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);

    try {
      // Detect what the question was about and save appropriately
      if (question.contains('smoke') || question.contains('tobacco')) {
        final bool isSmoker =
            answerLower.contains('yes') ||
            answerLower.contains('i do') ||
            answerLower.contains('i smoke');
        await userDoc.set({'smoker': isSmoker}, SetOptions(merge: true));
        debugPrint('✅ Saved smoker status: $isSmoker');
      } else if (question.contains('diabetes') ||
          question.contains('diabetic')) {
        final bool hasDiabetes =
            answerLower.contains('yes') ||
            answerLower.contains('i do') ||
            answerLower.contains('i have');
        await userDoc.set({
          'hasDiabetes': hasDiabetes,
        }, SetOptions(merge: true));
        debugPrint('✅ Saved diabetes status: $hasDiabetes');
      } else if (question.contains('pregnant') ||
          question.contains('pregnancy')) {
        final bool isPregnant =
            answerLower.contains('yes') || answerLower.contains('i am');
        await userDoc.set({'isPregnant': isPregnant}, SetOptions(merge: true));
        debugPrint('✅ Saved pregnancy status: $isPregnant');
      } else if (question.contains('physical activity') ||
          question.contains('exercise')) {
        String activity = 'moderate'; // default

        if (answerLower.contains('sedentary') ||
            answerLower.contains('not much') ||
            answerLower.contains('rarely') ||
            answerLower.contains('no')) {
          activity = 'sedentary';
        } else if (answerLower.contains('light') ||
            answerLower.contains('occasionally') ||
            answerLower.contains('sometimes')) {
          activity = 'light';
        } else if (answerLower.contains('very active') ||
            answerLower.contains('athlete') ||
            answerLower.contains('daily')) {
          activity = 'active';
        }

        await userDoc.set({
          'physicalActivity': activity,
        }, SetOptions(merge: true));
        debugPrint('✅ Saved physical activity: $activity');
      } else if (question.contains('medication') ||
          question.contains('medicine')) {
        if (answerLower.contains('no') ||
            answerLower.contains('none') ||
            answerLower.contains("don't") ||
            answerLower.contains('not taking')) {
          await userDoc.set({'medications': ''}, SetOptions(merge: true));
        } else {
          await userDoc.set({'medications': answer}, SetOptions(merge: true));
        }
        debugPrint('✅ Saved medications: $answer');
      }
    } catch (e) {
      debugPrint('❌ Failed to save answer: $e');
    }
  }

  Future<void> _parseBloodPressure(String text) async {
    final openaiKey = Env.openaiApiKey;
    if (openaiKey.isEmpty) {
      _parsedBP = _manualParse(text);
      await _analyzeWithLLM();
      return;
    }

    setState(() {
      _isProcessing = true;
      _displayText = 'Extracting blood pressure values…';
    });

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
        parsed = _manualParse(text);
      }

      int sys = (parsed['systolic'] as num?)?.toInt() ?? 120;
      int dia = (parsed['diastolic'] as num?)?.toInt() ?? 80;
      sys = sys.clamp(70, 250);
      dia = dia.clamp(40, 150);

      _parsedBP = {'systolic': sys, 'diastolic': dia};
      await _analyzeWithLLM();
    } catch (e) {
      _parsedBP = _manualParse(text);
      await _analyzeWithLLM();
    } finally {
      setState(() => _isProcessing = false);
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

  Future<void> _analyzeWithLLM() async {
    final sys = _parsedBP?['systolic'] ?? 120;
    final dia = _parsedBP?['diastolic'] ?? 80;

    setState(() {
      _isProcessing = true;
      _displayText = 'Analyzing your blood pressure...';
    });

    try {
      // Build user_profile with ALL available data
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

      debugPrint(
        '📤 Sending to LLM: $sys/$dia with profile: $userProfilePayload',
      );

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

      debugPrint('📥 LLM Response Status: ${response.statusCode}');

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
        final providedInfo =
            (data['provided_info'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [];

        String emoji = '✅';
        if (severity == 'critical') {
          emoji = '🚨';
        } else if (severity == 'high') {
          emoji = '⚠️';
        } else if (severity == 'elevated') {
          emoji = '⚠️';
        }

        final systolic = data['systolic'] ?? sys;
        final diastolic = data['diastolic'] ?? dia;

        // 🆕 If this is first reading and profile incomplete, trigger follow-up flow
        if (_isFirstReading && questions.isNotEmpty) {
          await _startFollowUpFlow(analysis, questions, systolic, diastolic);
          return;
        }

        // Regular display for subsequent readings
        String result = '$emoji Blood Pressure: $systolic/$diastolic mmHg\n\n';

        if (analysis.isNotEmpty) {
          result += '$analysis\n';
        }

        if (providedInfo.isNotEmpty) {
          result += '\n📊 Analysis based on: ${providedInfo.join(", ")}\n';
        } else {
          result += '\n📊 Analysis based on: BP reading only\n';
        }

        setState(() => _displayText = result.trim());

        if (analysis.isNotEmpty) {
          try {
            await _fetchSpeakAndPlay(analysis);
          } catch (e) {
            debugPrint('TTS/playback failed: $e');
          }
        }

        setState(() => _showReturnButton = true);
      } else {
        setState(
          () => _displayText =
              '❌ Analysis failed (status ${response.statusCode})',
        );
      }
    } on SocketException {
      setState(
        () => _displayText =
            '⚠️ Network error — please check your internet connection.',
      );
    } on TimeoutException {
      setState(
        () =>
            _displayText = '⏳ The server took too long to respond. Try again.',
      );
    } catch (e) {
      debugPrint('Error contacting FastAPI: $e');
      setState(
        () => _displayText = '⚠️ An unexpected error occurred: ${e.toString()}',
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  // 🆕 Start conversational follow-up flow
  Future<void> _startFollowUpFlow(
    String initialAnalysis,
    List<String> questions,
    int systolic,
    int diastolic,
  ) async {
    // Store initial analysis
    _conversationHistory.add({'role': 'assistant', 'content': initialAnalysis});

    // Set up questions
    setState(() {
      _pendingQuestions = questions;
      _currentQuestionIndex = 0;
      _isFirstReading = false; // Mark as handled
    });

    // Display initial analysis + first question
    final firstQuestion = questions.isNotEmpty ? questions[0] : '';
    final displayText =
        '''
Blood Pressure: $systolic/$diastolic mmHg

$initialAnalysis

To give you better advice, I'd like to know more about you:

$firstQuestion

Press and hold the mic to answer.
''';

    setState(() => _displayText = displayText.trim());

    // Speak the analysis + first question
    try {
      final ttsText = '$initialAnalysis. $firstQuestion';
      await _fetchSpeakAndPlay(ttsText);
    } catch (e) {
      debugPrint('TTS failed: $e');
    }
  }

  Future<void> _fetchSpeakAndPlay(String text) async {
    try {
      setState(() => _isPlayingTTS = true);
      _waveController?.amplitude = 0.5;

      final uri = Uri.parse(_speakEndpoint);
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text}),
      );

      if (resp.statusCode != 200) {
        debugPrint('TTS server responded ${resp.statusCode}');
        setState(() {
          _isPlayingTTS = false;
          _waveController?.amplitude = 0.0;
        });
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

      _audioPlayer.playerStateStream.listen((state) async {
        if (state.processingState == ProcessingState.completed) {
          try {
            if (await file.exists()) await file.delete();
          } catch (_) {}
          setState(() {
            _isPlayingTTS = false;
            _waveController?.amplitude = 0.0;
          });
        }
      });
    } catch (e) {
      debugPrint('fetchSpeakAndPlay error: $e');
      setState(() {
        _isPlayingTTS = false;
        _waveController?.amplitude = 0.0;
      });
    }
  }

  void _returnResult() {
    Navigator.pop(context, {
      'systolic': _parsedBP?['systolic'] ?? 120,
      'diastolic': _parsedBP?['diastolic'] ?? 80,
      'date': DateTime.now(),
    });
  }

  void _toggleLanguage() {
    setState(() {
      _selectedLanguage = _selectedLanguage == 'en' ? 'fr' : 'en';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.black, Color(0xFF1A1A1A)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 16),
                _buildLanguageToggle(),
                const SizedBox(height: 30),
                SizedBox(
                  height: 100,
                  child: Center(
                    child: _isRecording
                        ? _buildRecordingIndicator()
                        : const SizedBox.shrink(),
                  ),
                ),
                Flexible(
                  fit: FlexFit.loose,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orangeAccent.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: _isPlayingTTS
                            ? SiriWaveform.ios9(
                                controller: _waveController!,
                                options: const IOS9SiriWaveformOptions(
                                  height: 150,
                                  width: double.infinity,
                                ),
                              )
                            : SingleChildScrollView(
                                child: Text(
                                  _displayText,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 16,
                                    color: Colors.white.withOpacity(0.95),
                                    height: 1.5,
                                  ),
                                  textAlign: TextAlign.left,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (_isProcessing)
                  const CircularProgressIndicator(color: Colors.orangeAccent),
                if (_showReturnButton) _buildReturnButton(),
                const SizedBox(height: 40),
                _buildRecordButton(),
                const SizedBox(height: 20),
                Text(
                  _isRecording ? 'Recording…' : 'Hold to record',
                  style: GoogleFonts.montserrat(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageToggle() => GestureDetector(
    onTap: _toggleLanguage,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.orangeAccent,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.orangeAccent.withOpacity(0.5),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Text(
        _selectedLanguage == 'en' ? 'English' : 'Français',
        style: GoogleFonts.montserrat(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.black,
        ),
      ),
    ),
  );

  Widget _buildRecordingIndicator() => Column(
    children: [
      Text(
        'Recording',
        style: GoogleFonts.montserrat(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.orangeAccent,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        _formatDuration(_secondsElapsed),
        style: GoogleFonts.montserrat(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      const SizedBox(height: 20),
    ],
  );

  Widget _buildReturnButton() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    child: ElevatedButton(
      onPressed: _returnResult,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.greenAccent,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
      ),
      child: Text(
        'Save & Return',
        style: GoogleFonts.montserrat(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );

  Widget _buildRecordButton() => GestureDetector(
    onTapDown: (_) => _startRecording(),
    onTapUp: (_) => _stopRecordingAndTranscribe(),
    onTapCancel: _stopRecordingAndTranscribe,
    child: Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: _isRecording
              ? [Colors.redAccent, Colors.red]
              : [Colors.greenAccent, Colors.teal],
        ),
        boxShadow: [
          BoxShadow(
            color: (_isRecording ? Colors.red : Colors.greenAccent).withValues(
              alpha: 0.6,
            ),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Icon(
        _isRecording ? Icons.stop : Icons.mic,
        size: 40,
        color: Colors.black,
      ),
    ),
  );
}
