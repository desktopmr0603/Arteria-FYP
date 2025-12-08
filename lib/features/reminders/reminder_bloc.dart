import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'reminder_event.dart';
import 'reminder_model.dart';
import 'reminder_service.dart';
import 'reminder_state.dart';

/// BLoC for managing reminder state
class ReminderBloc extends Bloc<ReminderEvent, ReminderState> {
  final ReminderService _reminderService;

  ReminderBloc({ReminderService? reminderService})
      : _reminderService = reminderService ?? ReminderService(),
        super(RemindersLoading()) {
    on<LoadReminders>(_onLoadReminders);
    on<AddReminder>(_onAddReminder);
    on<UpdateReminder>(_onUpdateReminder);
    on<ToggleReminder>(_onToggleReminder);
    on<DeleteReminder>(_onDeleteReminder);
  }

  Future<void> _onLoadReminders(
    LoadReminders event,
    Emitter<ReminderState> emit,
  ) async {
    emit(RemindersLoading());

    try {
      await _reminderService.initialize();
      final reminders = await _reminderService.loadReminders();
      final nextTime = await _reminderService.getNextReminderTime();

      emit(RemindersLoaded(
        reminders: reminders,
        nextReminderTime: nextTime,
      ));
      debugPrint('✓ Loaded ${reminders.length} reminders');
    } catch (e) {
      emit(RemindersError('Failed to load reminders: $e'));
      debugPrint('✗ Error loading reminders: $e');
    }
  }

  Future<void> _onAddReminder(
    AddReminder event,
    Emitter<ReminderState> emit,
  ) async {
    final currentReminders = _getCurrentReminders();

    emit(ReminderOperationInProgress(
      currentReminders: currentReminders,
      operation: 'Adding reminder...',
    ));

    try {
      final newReminder = await _reminderService.addReminder(
        time: event.time,
        repeatType: event.repeatType,
        customDays: event.customDays,
        label: event.label,
      );

      if (newReminder != null) {
        final updatedReminders = [...currentReminders, newReminder];
        final nextTime = await _reminderService.getNextReminderTime();

        emit(RemindersLoaded(
          reminders: updatedReminders,
          nextReminderTime: nextTime,
        ));
        debugPrint('✓ Reminder added: ${newReminder.formattedTime}');
      } else {
        emit(RemindersError('Failed to add reminder'));
      }
    } catch (e) {
      emit(RemindersError('Failed to add reminder: $e'));
    }
  }

  Future<void> _onUpdateReminder(
    UpdateReminder event,
    Emitter<ReminderState> emit,
  ) async {
    final currentReminders = _getCurrentReminders();

    emit(ReminderOperationInProgress(
      currentReminders: currentReminders,
      operation: 'Updating reminder...',
    ));

    try {
      final success = await _reminderService.updateReminder(event.reminder);

      if (success) {
        final updatedReminders = currentReminders.map((r) {
          return r.id == event.reminder.id ? event.reminder : r;
        }).toList();

        final nextTime = await _reminderService.getNextReminderTime();

        emit(RemindersLoaded(
          reminders: updatedReminders,
          nextReminderTime: nextTime,
        ));
      } else {
        emit(RemindersError('Failed to update reminder'));
      }
    } catch (e) {
      emit(RemindersError('Failed to update reminder: $e'));
    }
  }

  Future<void> _onToggleReminder(
    ToggleReminder event,
    Emitter<ReminderState> emit,
  ) async {
    final currentReminders = _getCurrentReminders();

    // Optimistic update
    final updatedReminders = currentReminders.map((r) {
      return r.id == event.reminderId ? r.copyWith(isEnabled: event.isEnabled) : r;
    }).toList();

    emit(RemindersLoaded(
      reminders: updatedReminders,
      nextReminderTime: null, // Will be updated after toggle
    ));

    try {
      final success = await _reminderService.toggleReminder(
        event.reminderId,
        event.isEnabled,
      );

      if (success) {
        final nextTime = await _reminderService.getNextReminderTime();
        emit(RemindersLoaded(
          reminders: updatedReminders,
          nextReminderTime: nextTime,
        ));
      } else {
        // Revert on failure
        emit(RemindersLoaded(
          reminders: currentReminders,
          nextReminderTime: null,
        ));
      }
    } catch (e) {
      // Revert on error
      emit(RemindersLoaded(
        reminders: currentReminders,
        nextReminderTime: null,
      ));
    }
  }

  Future<void> _onDeleteReminder(
    DeleteReminder event,
    Emitter<ReminderState> emit,
  ) async {
    final currentReminders = _getCurrentReminders();

    // Optimistic delete
    final updatedReminders = currentReminders
        .where((r) => r.id != event.reminderId)
        .toList();

    emit(RemindersLoaded(
      reminders: updatedReminders,
      nextReminderTime: null,
    ));

    try {
      final success = await _reminderService.deleteReminder(event.reminderId);

      if (success) {
        final nextTime = await _reminderService.getNextReminderTime();
        emit(RemindersLoaded(
          reminders: updatedReminders,
          nextReminderTime: nextTime,
        ));
      } else {
        // Revert on failure
        emit(RemindersLoaded(
          reminders: currentReminders,
          nextReminderTime: null,
        ));
      }
    } catch (e) {
      // Revert on error
      emit(RemindersLoaded(
        reminders: currentReminders,
        nextReminderTime: null,
      ));
    }
  }

  List<Reminder> _getCurrentReminders() {
    final currentState = state;
    if (currentState is RemindersLoaded) {
      return currentState.reminders;
    }
    if (currentState is ReminderOperationInProgress) {
      return currentState.currentReminders;
    }
    return [];
  }
}
