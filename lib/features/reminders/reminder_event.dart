import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'reminder_model.dart';

/// Base class for reminder events
abstract class ReminderEvent extends Equatable {
  const ReminderEvent();

  @override
  List<Object?> get props => [];
}

/// Load all reminders
class LoadReminders extends ReminderEvent {}

/// Add a new reminder
class AddReminder extends ReminderEvent {
  final TimeOfDay time;
  final RepeatType repeatType;
  final List<int> customDays;
  final String? label;

  const AddReminder({
    required this.time,
    this.repeatType = RepeatType.daily,
    this.customDays = const [],
    this.label,
  });

  @override
  List<Object?> get props => [time, repeatType, customDays, label];
}

/// Update an existing reminder
class UpdateReminder extends ReminderEvent {
  final Reminder reminder;

  const UpdateReminder(this.reminder);

  @override
  List<Object?> get props => [reminder];
}

/// Toggle a reminder's enabled state
class ToggleReminder extends ReminderEvent {
  final String reminderId;
  final bool isEnabled;

  const ToggleReminder({
    required this.reminderId,
    required this.isEnabled,
  });

  @override
  List<Object?> get props => [reminderId, isEnabled];
}

/// Delete a reminder
class DeleteReminder extends ReminderEvent {
  final String reminderId;

  const DeleteReminder(this.reminderId);

  @override
  List<Object?> get props => [reminderId];
}
