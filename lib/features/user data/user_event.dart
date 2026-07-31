abstract class UserEvent {}

class LoadUserData extends UserEvent {}

class SaveBPReading extends UserEvent {
  final int systolic;
  final int diastolic;

  /// When true, the reading has already been written to `readings` by the
  /// caller (e.g. the voice-entry flow persists the raw spoken value itself),
  /// so the bloc must NOT write it again — it only computes the risk score and
  /// reloads. Prevents the double-write that produced duplicate daily readings.
  final bool alreadyPersisted;

  SaveBPReading({
    required this.systolic,
    required this.diastolic,
    this.alreadyPersisted = false,
  });
}
