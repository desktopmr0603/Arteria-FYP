import 'package:equatable/equatable.dart';

/// Base class for all microphone transcribe states
abstract class MicrophoneTranscribeState extends Equatable {
  const MicrophoneTranscribeState();

  @override
  List<Object?> get props => [];
}

/// Initial state - ready to record
class MicrophoneTranscribeInitialState extends MicrophoneTranscribeState {
  final String displayText;

  const MicrophoneTranscribeInitialState({
    this.displayText = 'Tap the microphone to record your blood pressure',
  });

  @override
  List<Object?> get props => [displayText];
}

/// User is currently recording
class RecordingState extends MicrophoneTranscribeState {
  final int secondsElapsed;
  final String displayText;

  const RecordingState({
    required this.secondsElapsed,
    this.displayText = 'Recording… Speak your blood pressure clearly.',
  });

  @override
  List<Object?> get props => [secondsElapsed, displayText];

  RecordingState copyWith({int? secondsElapsed, String? displayText}) {
    return RecordingState(
      secondsElapsed: secondsElapsed ?? this.secondsElapsed,
      displayText: displayText ?? this.displayText,
    );
  }
}

/// Processing transcription (Whisper API)
class ProcessingTranscriptionState extends MicrophoneTranscribeState {
  final String displayText;

  const ProcessingTranscriptionState({
    this.displayText = 'Transcribing your voice…',
  });

  @override
  List<Object?> get props => [displayText];
}

/// LLM is analyzing the blood pressure
class ReasoningState extends MicrophoneTranscribeState {
  final String displayText;
  final int? systolic;
  final int? diastolic;

  const ReasoningState({
    this.displayText = 'Analyzing your blood pressure...',
    this.systolic,
    this.diastolic,
  });

  @override
  List<Object?> get props => [displayText, systolic, diastolic];
}

/// TTS audio is playing (show Siri waveform)
class PlayingTTSState extends MicrophoneTranscribeState {
  final String analysisText;
  final int systolic;
  final int diastolic;
  final String category;
  final String severity;

  const PlayingTTSState({
    required this.analysisText,
    required this.systolic,
    required this.diastolic,
    required this.category,
    required this.severity,
  });

  @override
  List<Object?> get props => [
        analysisText,
        systolic,
        diastolic,
        category,
        severity,
      ];
}

/// Analysis completed, waiting for auto-save
class CompletedState extends MicrophoneTranscribeState {
  final String analysisText;
  final int systolic;
  final int diastolic;
  final String category;
  final String severity;

  const CompletedState({
    required this.analysisText,
    required this.systolic,
    required this.diastolic,
    required this.category,
    required this.severity,
  });

  @override
  List<Object?> get props => [
        analysisText,
        systolic,
        diastolic,
        category,
        severity,
      ];
}

/// Saving and returning to homescreen
class SavingAndReturningState extends MicrophoneTranscribeState {
  final int systolic;
  final int diastolic;
  final String displayText;

  const SavingAndReturningState({
    required this.systolic,
    required this.diastolic,
    this.displayText = 'Returning to homescreen...',
  });

  @override
  List<Object?> get props => [systolic, diastolic, displayText];
}

/// Error state
class ErrorState extends MicrophoneTranscribeState {
  final String errorMessage;
  final String displayText;

  const ErrorState({
    required this.errorMessage,
    required this.displayText,
  });

  @override
  List<Object?> get props => [errorMessage, displayText];
}
