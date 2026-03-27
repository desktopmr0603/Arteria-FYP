import 'package:equatable/equatable.dart';

/// Base class for all microphone transcribe events
abstract class MicrophoneTranscribeEvent extends Equatable {
  const MicrophoneTranscribeEvent();

  @override
  List<Object?> get props => [];
}

/// User taps microphone button to start recording
class StartRecordingEvent extends MicrophoneTranscribeEvent {
  const StartRecordingEvent();
}

/// User taps stop button to end recording
class StopRecordingEvent extends MicrophoneTranscribeEvent {
  const StopRecordingEvent();
}

/// Recording timer tick (update elapsed time)
class RecordingTickEvent extends MicrophoneTranscribeEvent {
  final int secondsElapsed;

  const RecordingTickEvent(this.secondsElapsed);

  @override
  List<Object?> get props => [secondsElapsed];
}

/// Transcription completed successfully
class TranscriptionCompletedEvent extends MicrophoneTranscribeEvent {
  final String transcribedText;

  const TranscriptionCompletedEvent(this.transcribedText);

  @override
  List<Object?> get props => [transcribedText];
}

/// Transcription failed
class TranscriptionFailedEvent extends MicrophoneTranscribeEvent {
  final String error;

  const TranscriptionFailedEvent(this.error);

  @override
  List<Object?> get props => [error];
}

/// LLM analysis started
class LLMAnalysisStartedEvent extends MicrophoneTranscribeEvent {
  const LLMAnalysisStartedEvent();
}

/// LLM analysis completed successfully
class LLMAnalysisCompletedEvent extends MicrophoneTranscribeEvent {
  final String analysisText;
  final int systolic;
  final int diastolic;
  final String category;
  final String severity;
  final List<String> followUpQuestions;

  const LLMAnalysisCompletedEvent({
    required this.analysisText,
    required this.systolic,
    required this.diastolic,
    required this.category,
    required this.severity,
    required this.followUpQuestions,
  });

  @override
  List<Object?> get props => [
        analysisText,
        systolic,
        diastolic,
        category,
        severity,
        followUpQuestions,
      ];
}

/// LLM analysis failed
class LLMAnalysisFailedEvent extends MicrophoneTranscribeEvent {
  final String error;

  const LLMAnalysisFailedEvent(this.error);

  @override
  List<Object?> get props => [error];
}

/// TTS playback started
class TTSPlaybackStartedEvent extends MicrophoneTranscribeEvent {
  const TTSPlaybackStartedEvent();
}

/// TTS playback completed
class TTSPlaybackCompletedEvent extends MicrophoneTranscribeEvent {
  const TTSPlaybackCompletedEvent();
}

/// TTS playback failed
class TTSPlaybackFailedEvent extends MicrophoneTranscribeEvent {
  final String error;

  const TTSPlaybackFailedEvent(this.error);

  @override
  List<Object?> get props => [error];
}

/// Auto-save triggered (2-second delay completed)
class AutoSaveTriggeredEvent extends MicrophoneTranscribeEvent {
  const AutoSaveTriggeredEvent();
}

/// Reset to initial state
class ResetStateEvent extends MicrophoneTranscribeEvent {
  const ResetStateEvent();
}
