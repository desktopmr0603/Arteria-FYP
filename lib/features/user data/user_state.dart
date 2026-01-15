abstract class UserState {}

class UserLoading extends UserState {}

class UserError extends UserState {
  final String message;
  UserError(this.message);
}

class UserLoaded extends UserState {
  final String firstName;
  final Map<String, dynamic>? latestReading;
  final List<Map<String, dynamic>> weeklyReadings;
  final bool isFirstTimeUser;

  UserLoaded({
    required this.firstName,
    required this.latestReading,
    required this.weeklyReadings,
    required this.isFirstTimeUser,
  });
}
