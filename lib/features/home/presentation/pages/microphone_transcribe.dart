import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:siri_wave/siri_wave.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:arteria/l10n/app_localizations.dart';
import '../bloc/microphone_transcribe_bloc.dart';
import '../bloc/microphone_transcribe_event.dart';
import '../bloc/microphone_transcribe_state.dart';
import 'settings/settings_bloc.dart';

class MicrophoneTranscribe extends StatefulWidget {
  const MicrophoneTranscribe({super.key});

  @override
  State<MicrophoneTranscribe> createState() => _MicrophoneTranscribeState();
}

class _MicrophoneTranscribeState extends State<MicrophoneTranscribe> {
  IOS9SiriWaveformController? _waveController;
  MicrophoneTranscribeBloc? _bloc;

  @override
  void initState() {
    super.initState();
    _waveController = IOS9SiriWaveformController(
      amplitude: 0.5,
      color1: Colors.blueAccent,
      color2: Colors.purpleAccent,
      color3: Colors.pinkAccent,
      speed: 0.2,
    );
    _requestPermissions();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Create bloc once with current language
    if (_bloc == null) {
      final settingsState = context.read<SettingsBloc>().state;
      final language = settingsState.locale.languageCode;
      _bloc = MicrophoneTranscribeBloc(language: language);
    }
  }

  Future<void> _requestPermissions() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted && mounted) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.microphonePermissionDenied)),
      );
    }
  }

  @override
  void dispose() {
    _bloc?.close();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final d = Duration(seconds: seconds);
    return '${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';
  }

  String _getEmojiForSeverity(String severity) {
    if (severity == 'critical') return '🚨';
    if (severity == 'high') return '⚠️';
    if (severity == 'elevated') return '⚠️';
    return '✅';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    if (_bloc == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    return BlocProvider.value(
      value: _bloc!,
      child: BlocConsumer<MicrophoneTranscribeBloc, MicrophoneTranscribeState>(
        listener: (context, state) {
          // Handle navigation on saving state
          if (state is SavingAndReturningState) {
            // Navigate back after a brief moment
            Future.delayed(const Duration(milliseconds: 1500), () {
              if (mounted) {
                Navigator.pop(context, {
                  'systolic': state.systolic,
                  'diastolic': state.diastolic,
                  'date': DateTime.now(),
                });
              }
            });
          }

          // Set waveform amplitude based on state
          if (state is PlayingTTSState) {
            _waveController?.amplitude = 0.5;
          } else {
            _waveController?.amplitude = 0.0;
          }
        },
        builder: (context, state) {
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
                      _buildHeader(l10n),
                      const SizedBox(height: 30),
                      if (state is RecordingState)
                        _buildRecordingIndicator(state, l10n),
                      if (state is RecordingState)
                        const SizedBox(height: 20)
                      else
                        const SizedBox(height: 100),
                      Flexible(
                        fit: FlexFit.loose,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _buildContentArea(state, l10n),
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (state is ProcessingTranscriptionState ||
                          state is ReasoningState)
                        _buildLoadingIndicator(),
                      const SizedBox(height: 40),
                      if (_shouldShowMicrophoneButton(state))
                        _buildMicrophoneButton(context, state),
                      if (state is RecordingState ||
                          state is MicrophoneTranscribeInitialState)
                        const SizedBox(height: 20),
                      if (state is RecordingState ||
                          state is MicrophoneTranscribeInitialState)
                        _buildInstructionText(state, l10n),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const SizedBox(width: 48),
        Text(
          l10n.bloodPressure,
          style: GoogleFonts.montserrat(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _buildRecordingIndicator(RecordingState state, AppLocalizations l10n) {
    return Column(
      children: [
        Text(
          l10n.recording,
          style: GoogleFonts.montserrat(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.orangeAccent,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _formatDuration(state.secondsElapsed),
          style: GoogleFonts.montserrat(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildContentArea(MicrophoneTranscribeState state, AppLocalizations l10n) {
    return Container(
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
        child: state is PlayingTTSState
            ? SiriWaveform.ios9(
                controller: _waveController!,
                options: const IOS9SiriWaveformOptions(
                  height: 150,
                  width: double.infinity,
                ),
              )
            : SingleChildScrollView(
                child: Text(
                  _getDisplayText(state, l10n),
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.95),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.left,
                ),
              ),
      ),
    );
  }

  String _getDisplayText(MicrophoneTranscribeState state, AppLocalizations l10n) {
    if (state is MicrophoneTranscribeInitialState) {
      return l10n.tapMicrophoneToRecord;
    } else if (state is RecordingState) {
      return l10n.recordingSpeakClearly;
    } else if (state is ProcessingTranscriptionState) {
      return l10n.transcribingVoice;
    } else if (state is ReasoningState) {
      return l10n.analyzingBP;
    } else if (state is PlayingTTSState) {
      final emoji = _getEmojiForSeverity(state.severity);
      return '$emoji ${l10n.bloodPressure}: ${state.systolic}/${state.diastolic} mmHg\n\n${state.analysisText}';
    } else if (state is CompletedState) {
      final emoji = _getEmojiForSeverity(state.severity);
      return '$emoji ${l10n.bloodPressure}: ${state.systolic}/${state.diastolic} mmHg\n\n${state.analysisText}';
    } else if (state is SavingAndReturningState) {
      return l10n.returningHome;
    } else if (state is ErrorState) {
      return state.displayText;
    }
    return '';
  }

  Widget _buildLoadingIndicator() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          CircularProgressIndicator(
            color: Colors.orangeAccent,
            strokeWidth: 3,
          ),
          SizedBox(height: 12),
        ],
      ),
    );
  }

  bool _shouldShowMicrophoneButton(MicrophoneTranscribeState state) {
    return state is MicrophoneTranscribeInitialState ||
        state is RecordingState ||
        state is ErrorState ||
        state is CompletedState ||
        state is SavingAndReturningState;
  }

  Widget _buildMicrophoneButton(
    BuildContext context,
    MicrophoneTranscribeState state,
  ) {
    final isRecording = state is RecordingState;
    final isCompleted = state is CompletedState ||
        state is SavingAndReturningState;

    return GestureDetector(
      onTap: () {
        if (isRecording) {
          context
              .read<MicrophoneTranscribeBloc>()
              .add(const StopRecordingEvent());
        } else if (!isCompleted) {
          context
              .read<MicrophoneTranscribeBloc>()
              .add(const StartRecordingEvent());
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: isRecording
                ? [Colors.redAccent, Colors.red]
                : [Colors.greenAccent, Colors.teal],
          ),
          boxShadow: [
            BoxShadow(
              color: (isRecording ? Colors.red : Colors.greenAccent)
                  .withValues(alpha: 0.6),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(
          isRecording ? Icons.stop : Icons.mic,
          size: 40,
          color: Colors.black,
        ),
      ),
    );
  }

  Widget _buildInstructionText(MicrophoneTranscribeState state, AppLocalizations l10n) {
    final isRecording = state is RecordingState;
    return Text(
      isRecording ? l10n.tapToStop : l10n.tapToRecord,
      style: GoogleFonts.montserrat(
        color: Colors.white70,
        fontSize: 14,
      ),
    );
  }
}
