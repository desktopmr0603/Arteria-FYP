import 'package:equatable/equatable.dart';
import 'reminder_model.dart';

/// Base class for reminder states
abstract class ReminderState extends Equatable {
  const ReminderState();

  @override
  List<Object?> get props => [];
}

/// Initial loading state
class RemindersLoading extends ReminderState {}

/// Reminders loaded successfully
class RemindersLoaded extends ReminderState {
  final List<Reminder> reminders;
  final DateTime? nextReminderTime;

  const RemindersLoaded({
    required this.reminders,
    this.nextReminderTime,
  });

  /// Check if there are any enabled reminders
  bool get hasActiveReminders => reminders.any((r) => r.isEnabled);

  @override
  List<Object?> get props => [reminders, nextReminderTime];
}

/// Error loading reminders
class RemindersError extends ReminderState {
  final String message;

  const RemindersError(this.message);

  @override
  List<Object?> get props => [message];
}

/// Operation in progress (adding, updating, deleting)
class ReminderOperationInProgress extends ReminderState {
  final List<Reminder> currentReminders;
  final String operation;

  const ReminderOperationInProgress({
    required this.currentReminders,
    required this.operation,
  });

  @override
  List<Object?> get props => [currentReminders, operation];
}
