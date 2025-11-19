abstract class UserEvent {}

class LoadUserData extends UserEvent {}

class SaveBPReading extends UserEvent {
  final int systolic;
  final int diastolic;

  SaveBPReading({required this.systolic, required this.diastolic});
}
