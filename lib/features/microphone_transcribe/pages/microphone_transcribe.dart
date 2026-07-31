import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:siri_wave/siri_wave.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:arteria/l10n/app_localizations.dart';
import '../bloc/microphone_transcribe_bloc.dart';
import '../bloc/microphone_transcribe_event.dart';
import '../bloc/microphone_transcribe_state.dart';
import '../../home/presentation/pages/settings/bloc/settings_bloc.dart';

/// Modern 2026 Microphone Transcribe Page
/// Features: Glassmorphism, gradient mesh, smooth animations, accessible design
class MicrophoneTranscribe extends StatefulWidget {
  const MicrophoneTranscribe({super.key});

  @override
  State<MicrophoneTranscribe> createState() => _MicrophoneTranscribeState();
}

class _MicrophoneTranscribeState extends State<MicrophoneTranscribe>
    with TickerProviderStateMixin {
  IOS9SiriWaveformController? _waveController;
  MicrophoneTranscribeBloc? _bloc;

  // Animation Controllers
  late AnimationController _pulseController;
  late AnimationController _gradientController;
  late AnimationController _scaleController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _gradientAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Pulse animation for microphone button
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Gradient animation for background
    _gradientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    _gradientAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _gradientController, curve: Curves.linear),
    );

    // Scale animation for cards
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutBack),
    );
    _scaleController.forward();

    _waveController = IOS9SiriWaveformController(
      amplitude: 0.5,
      color1: const Color(0xFF6366F1),
      color2: const Color(0xFFA855F7),
      color3: const Color(0xFFEC4899),
      speed: 0.25,
    );

    _requestPermissions();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bloc == null) {
      final settingsState = context.read<SettingsBloc>().state;
      final language = settingsState.locale.languageCode;
      _bloc = MicrophoneTranscribeBloc(
        language: language,
        l10n: AppLocalizations.of(context)!,
      );
    }
  }

  Future<void> _requestPermissions() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted && mounted) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.microphonePermissionDenied),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _gradientController.dispose();
    _scaleController.dispose();
    _bloc?.close();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final d = Duration(seconds: seconds);
    return '${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';
  }

  Color _getSeverityColor(String severity) {
    switch (severity) {
      case 'critical':
        return const Color(0xFFEF4444);
      case 'high':
        return const Color(0xFFF97316);
      case 'elevated':
        return const Color(0xFFFBBF24);
      case 'low':
        return const Color(0xFF3B82F6);
      default:
        return const Color(0xFF22C55E);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_bloc == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0A0F),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF6366F1)),
        ),
      );
    }

    return BlocProvider.value(
      value: _bloc!,
      child: BlocConsumer<MicrophoneTranscribeBloc, MicrophoneTranscribeState>(
        listener: (context, state) {
          if (state is SavingAndReturningState) {
            Future.delayed(const Duration(milliseconds: 1500), () {
              if (context.mounted) {
                Navigator.pop(context, {
                  'systolic': state.systolic,
                  'diastolic': state.diastolic,
                  'date': DateTime.now(),
                });
              }
            });
          }

          // Control animations based on state
          if (state is RecordingState) {
            _pulseController.repeat(reverse: true);
          } else {
            _pulseController.stop();
            _pulseController.reset();
          }

          if (state is PlayingTTSState) {
            _waveController?.amplitude = 0.6;
          } else {
            _waveController?.amplitude = 0.0;
          }
        },
        builder: (context, state) {
          return Scaffold(
            backgroundColor: const Color(0xFF0A0A0F),
            body: Stack(
              children: [
                // Animated gradient mesh background
                _buildAnimatedBackground(),

                // Content
                SafeArea(
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      _buildHeader(l10n),
                      const SizedBox(height: 24),

                      // Recording indicator
                      if (state is RecordingState)
                        _buildRecordingIndicator(state, l10n),

                      const SizedBox(height: 24),

                      // Main content card
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: ScaleTransition(
                            scale: _scaleAnimation,
                            child: _buildGlassCard(state, l10n),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Status indicator
                      if (state is ProcessingTranscriptionState ||
                          state is ReasoningState)
                        _buildProcessingIndicator(state, l10n),

                      const SizedBox(height: 20),

                      // Microphone button
                      if (_shouldShowMicrophoneButton(state))
                        _buildModernMicButton(context, state),

                      const SizedBox(height: 16),

                      // Instruction text
                      if (_shouldShowInstruction(state))
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

  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _gradientAnimation,
      builder: (context, child) {
        final value = _gradientAnimation.value;
        return CustomPaint(
          painter: _GradientMeshPainter(value),
          size: Size.infinite,
        );
      },
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back button with glassmorphism
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withAlpha(30),
                    width: 1,
                  ),
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),

          // Title
          Text(
            l10n.bloodPressure,
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),

          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildRecordingIndicator(RecordingState state, AppLocalizations l10n) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEF4444), Color(0xFFF97316)],
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFEF4444).withAlpha(100),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${l10n.recording.toUpperCase()} ${_formatDuration(state.secondsElapsed)}',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGlassCard(
    MicrophoneTranscribeState state,
    AppLocalizations l10n,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white.withAlpha(20), Colors.white.withAlpha(8)],
            ),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withAlpha(30), width: 1.5),
          ),
          child: state is PlayingTTSState
              ? _buildWaveformDisplay()
              : (state is CompletedState || state is PlayingTTSState)
              ? _buildResultDisplay(state, l10n)
              : _buildDefaultDisplay(state, l10n),
        ),
      ),
    );
  }

  Widget _buildWaveformDisplay() {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SiriWaveform.ios9(
          controller: _waveController!,
          options: const IOS9SiriWaveformOptions(
            height: 180,
            width: double.infinity,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          l10n.micProcessingReading,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Colors.white.withAlpha(200),
          ),
        ),
      ],
    );
  }

  Widget _buildResultDisplay(
    MicrophoneTranscribeState state,
    AppLocalizations l10n,
  ) {
    final String severity;
    final String category;
    final int systolic;
    final int diastolic;
    final String analysisText;

    if (state is CompletedState) {
      severity = state.severity;
      category = state.category;
      systolic = state.systolic;
      diastolic = state.diastolic;
      analysisText = state.analysisText;
    } else if (state is PlayingTTSState) {
      severity = state.severity;
      category = state.category;
      systolic = state.systolic;
      diastolic = state.diastolic;
      analysisText = state.analysisText;
    } else {
      return const SizedBox.shrink();
    }

    final severityColor = _getSeverityColor(severity);

    return SingleChildScrollView(
      child: Column(
        children: [
          // BP Reading Card - simple display without icon
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  severityColor.withAlpha(50),
                  severityColor.withAlpha(25),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: severityColor.withAlpha(100), width: 1),
            ),
            child: Column(
              children: [
                Text(
                  '$systolic/$diastolic',
                  style: GoogleFonts.inter(
                    fontSize: 56,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -2,
                  ),
                ),
                Text(
                  'mmHg',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withAlpha(180),
                  ),
                ),
                const SizedBox(height: 12),
                // Simple classification label
                Text(
                  category,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: severityColor,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Analysis text
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              analysisText,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: Colors.white.withAlpha(220),
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultDisplay(
    MicrophoneTranscribeState state,
    AppLocalizations l10n,
  ) {
    String text = l10n.tapMicrophoneToRecord;
    IconData icon = Icons.mic_none_rounded;

    if (state is RecordingState) {
      text = l10n.recordingSpeakClearly;
      icon = Icons.graphic_eq_rounded;
    } else if (state is ProcessingTranscriptionState) {
      text = l10n.transcribingVoice;
      icon = Icons.hearing_rounded;
    } else if (state is ReasoningState) {
      text = l10n.analyzingBP;
      icon = Icons.psychology_rounded;
    } else if (state is ErrorState) {
      text = state.displayText;
      icon = Icons.error_outline_rounded;
    } else if (state is SavingAndReturningState) {
      text = l10n.returningHome;
      icon = Icons.check_circle_outline_rounded;
    }

    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: Colors.white.withAlpha(100)),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                text,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withAlpha(180),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingIndicator(
    MicrophoneTranscribeState state,
    AppLocalizations l10n,
  ) {
    String text = '';
    if (state is ProcessingTranscriptionState) {
      text = l10n.transcribingVoice;
    } else if (state is ReasoningState) {
      text = l10n.analyzingBP;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(20), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(
                const Color(0xFF6366F1),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white.withAlpha(180),
            ),
          ),
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

  bool _shouldShowInstruction(MicrophoneTranscribeState state) {
    return state is MicrophoneTranscribeInitialState || state is RecordingState;
  }

  Widget _buildModernMicButton(
    BuildContext context,
    MicrophoneTranscribeState state,
  ) {
    final isRecording = state is RecordingState;
    final isCompleted =
        state is CompletedState || state is SavingAndReturningState;

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final scale = isRecording ? _pulseAnimation.value : 1.0;

        return GestureDetector(
          onTap: () {
            if (isRecording) {
              context.read<MicrophoneTranscribeBloc>().add(
                const StopRecordingEvent(),
              );
            } else if (!isCompleted) {
              context.read<MicrophoneTranscribeBloc>().add(
                const StartRecordingEvent(),
              );
            }
          },
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isRecording
                      ? [const Color(0xFFEF4444), const Color(0xFFDC2626)]
                      : [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        (isRecording
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF6366F1))
                            .withAlpha(150),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                size: 48,
                color: Colors.white,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInstructionText(
    MicrophoneTranscribeState state,
    AppLocalizations l10n,
  ) {
    final isRecording = state is RecordingState;
    return Text(
      isRecording ? l10n.tapToStop : l10n.tapToRecord,
      style: GoogleFonts.inter(
        color: Colors.white.withAlpha(120),
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

/// Custom gradient mesh painter for animated background
class _GradientMeshPainter extends CustomPainter {
  final double animationValue;

  _GradientMeshPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Dark base
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF0A0A0F),
    );

    // Animated gradient orbs
    final orb1Center = Offset(
      size.width * (0.3 + 0.2 * math.sin(animationValue * 2 * math.pi)),
      size.height * (0.2 + 0.1 * math.cos(animationValue * 2 * math.pi)),
    );
    final orb2Center = Offset(
      size.width * (0.7 + 0.15 * math.cos(animationValue * 2 * math.pi + 1)),
      size.height * (0.6 + 0.15 * math.sin(animationValue * 2 * math.pi + 1)),
    );
    final orb3Center = Offset(
      size.width * (0.5 + 0.2 * math.sin(animationValue * 2 * math.pi + 2)),
      size.height * (0.85 + 0.05 * math.cos(animationValue * 2 * math.pi + 2)),
    );

    // Orb 1 - Purple
    paint.shader =
        RadialGradient(
          colors: [
            const Color(0xFF6366F1).withAlpha(80),
            const Color(0xFF6366F1).withAlpha(0),
          ],
        ).createShader(
          Rect.fromCircle(center: orb1Center, radius: size.width * 0.5),
        );
    canvas.drawCircle(orb1Center, size.width * 0.5, paint);

    // Orb 2 - Pink
    paint.shader =
        RadialGradient(
          colors: [
            const Color(0xFFEC4899).withAlpha(60),
            const Color(0xFFEC4899).withAlpha(0),
          ],
        ).createShader(
          Rect.fromCircle(center: orb2Center, radius: size.width * 0.4),
        );
    canvas.drawCircle(orb2Center, size.width * 0.4, paint);

    // Orb 3 - Cyan
    paint.shader =
        RadialGradient(
          colors: [
            const Color(0xFF06B6D4).withAlpha(50),
            const Color(0xFF06B6D4).withAlpha(0),
          ],
        ).createShader(
          Rect.fromCircle(center: orb3Center, radius: size.width * 0.35),
        );
    canvas.drawCircle(orb3Center, size.width * 0.35, paint);
  }

  @override
  bool shouldRepaint(covariant _GradientMeshPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
