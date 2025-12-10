import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'reminder_event.dart';
import 'reminder_model.dart';
import 'reminder_service.dart';
import 'reminder_state.dart';

/// BLoC for managing reminder state with real-time Firestore updates
class ReminderBloc extends Bloc<ReminderEvent, ReminderState> {
  final ReminderService _reminderService;
  StreamSubscription<List<Reminder>>? _reminderSubscription;

  ReminderBloc({ReminderService? reminderService})
    : _reminderService = reminderService ?? ReminderService(),
      super(RemindersLoading()) {
    on<LoadReminders>(_onLoadReminders);
    on<WatchReminders>(_onWatchReminders);
    on<RemindersUpdated>(_onRemindersUpdated);
    on<AddReminder>(_onAddReminder);
    on<UpdateReminder>(_onUpdateReminder);
    on<ToggleReminder>(_onToggleReminder);
    on<DeleteReminder>(_onDeleteReminder);
  }

  /// Load reminders once (one-time fetch)
  Future<void> _onLoadReminders(
    LoadReminders event,
    Emitter<ReminderState> emit,
  ) async {
    emit(RemindersLoading());

    try {
      await _reminderService.initialize();
      final reminders = await _reminderService.loadReminders();
      final nextTime = await _reminderService.getNextReminderTime();

      emit(RemindersLoaded(reminders: reminders, nextReminderTime: nextTime));
      debugPrint('✓ Loaded ${reminders.length} reminders');
    } catch (e) {
      emit(RemindersError('Failed to load reminders: $e'));
      debugPrint('✗ Error loading reminders: $e');
    }
  }

  /// Watch reminders in real-time (KEY METHOD)
  Future<void> _onWatchReminders(
    WatchReminders event,
    Emitter<ReminderState> emit,
  ) async {
    debugPrint('🎯 WatchReminders event received');

    // Cancel existing subscription
    await _reminderSubscription?.cancel();

    try {
      await _reminderService.initialize();

      // Listen to real-time updates from Firestore
      _reminderSubscription = _reminderService.watchReminders().listen(
        (reminders) {
          debugPrint('📥 Received ${reminders.length} reminders from stream');
          add(RemindersUpdated(reminders));
        },
        onError: (error) {
          debugPrint('❌ Stream error: $error');
          add(RemindersUpdated([]));
        },
      );

      debugPrint('👁️ Now watching reminders in real-time');
    } catch (e) {
      emit(RemindersError('Failed to watch reminders: $e'));
      debugPrint('✗ Error watching reminders: $e');
    }
  }

  /// Handle real-time reminder updates from Firestore
  Future<void> _onRemindersUpdated(
    RemindersUpdated event,
    Emitter<ReminderState> emit,
  ) async {
    try {
      final nextTime = await _reminderService.getNextReminderTime();
      emit(
        RemindersLoaded(reminders: event.reminders, nextReminderTime: nextTime),
      );
      debugPrint('📊 State updated: ${event.reminders.length} reminders');
    } catch (e) {
      debugPrint('⚠️ Error calculating next reminder time: $e');
      emit(RemindersLoaded(reminders: event.reminders, nextReminderTime: null));
    }
  }

  /// Add a new reminder
  Future<void> _onAddReminder(
    AddReminder event,
    Emitter<ReminderState> emit,
  ) async {
    final currentReminders = _getCurrentReminders();

    emit(
      ReminderOperationInProgress(
        currentReminders: currentReminders,
        operation: 'Adding reminder...',
      ),
    );

    try {
      debugPrint('📝 BLoC: Attempting to add reminder...');
      debugPrint(
        '   Time: ${event.time.hour}:${event.time.minute.toString().padLeft(2, '0')}',
      );
      debugPrint('   Repeat: ${event.repeatType.name}');

      final newReminder = await _reminderService.addReminder(
        time: event.time,
        repeatType: event.repeatType,
        customDays: event.customDays,
        label: event.label,
      );

      if (newReminder != null) {
        debugPrint(
          '✅ BLoC: Reminder added successfully with ID: ${newReminder.id}',
        );

        // If using streams, Firestore will auto-update
        if (_reminderSubscription == null) {
          debugPrint('ℹ️ Not using streams, updating state manually');
          final updatedReminders = [...currentReminders, newReminder];
          final nextTime = await _reminderService.getNextReminderTime();

          emit(
            RemindersLoaded(
              reminders: updatedReminders,
              nextReminderTime: nextTime,
            ),
          );
        } else {
          debugPrint('ℹ️ Using streams, Firestore will auto-update');
        }
      } else {
        debugPrint('❌ BLoC: Failed to add reminder - service returned null');
        emit(RemindersError('Failed to add reminder'));

        Future.delayed(const Duration(seconds: 2), () {
          if (!isClosed) {
            add(LoadReminders());
          }
        });
      }
    } catch (e, stackTrace) {
      debugPrint('❌ BLoC: Exception adding reminder: $e');
      debugPrint('Stack trace: $stackTrace');
      emit(RemindersError('Failed to add reminder: $e'));

      Future.delayed(const Duration(seconds: 2), () {
        if (!isClosed) {
          add(LoadReminders());
        }
      });
    }
  }

  /// Update an existing reminder
  Future<void> _onUpdateReminder(
    UpdateReminder event,
    Emitter<ReminderState> emit,
  ) async {
    final currentReminders = _getCurrentReminders();

    emit(
      ReminderOperationInProgress(
        currentReminders: currentReminders,
        operation: 'Updating reminder...',
      ),
    );

    try {
      debugPrint('📝 BLoC: Updating reminder ${event.reminder.id}');

      final success = await _reminderService.updateReminder(event.reminder);

      if (success) {
        debugPrint('✅ BLoC: Reminder updated successfully');

        if (_reminderSubscription == null) {
          final updatedReminders = currentReminders.map((r) {
            return r.id == event.reminder.id ? event.reminder : r;
          }).toList();

          final nextTime = await _reminderService.getNextReminderTime();

          emit(
            RemindersLoaded(
              reminders: updatedReminders,
              nextReminderTime: nextTime,
            ),
          );
        }
      } else {
        debugPrint('❌ BLoC: Failed to update reminder');
        emit(RemindersError('Failed to update reminder'));

        Future.delayed(const Duration(seconds: 2), () {
          if (!isClosed) {
            add(LoadReminders());
          }
        });
      }
    } catch (e) {
      debugPrint('❌ BLoC: Error updating reminder: $e');
      emit(RemindersError('Failed to update reminder: $e'));

      Future.delayed(const Duration(seconds: 2), () {
        if (!isClosed) {
          add(LoadReminders());
        }
      });
    }
  }

  /// Toggle reminder enabled state
  Future<void> _onToggleReminder(
    ToggleReminder event,
    Emitter<ReminderState> emit,
  ) async {
    final currentReminders = _getCurrentReminders();

    // Optimistic update
    final updatedReminders = currentReminders.map((r) {
      return r.id == event.reminderId
          ? r.copyWith(isEnabled: event.isEnabled)
          : r;
    }).toList();

    emit(RemindersLoaded(reminders: updatedReminders, nextReminderTime: null));

    try {
      final success = await _reminderService.toggleReminder(
        event.reminderId,
        event.isEnabled,
      );

      if (success) {
        final nextTime = await _reminderService.getNextReminderTime();
        emit(
          RemindersLoaded(
            reminders: updatedReminders,
            nextReminderTime: nextTime,
          ),
        );
        debugPrint('✓ BLoC: Toggle successful');
      } else {
        debugPrint('⚠️ BLoC: Toggle failed, reverting');
        emit(
          RemindersLoaded(reminders: currentReminders, nextReminderTime: null),
        );
      }
    } catch (e) {
      debugPrint('❌ BLoC: Error toggling: $e');
      emit(
        RemindersLoaded(reminders: currentReminders, nextReminderTime: null),
      );
    }
  }

  /// Delete a reminder
  Future<void> _onDeleteReminder(
    DeleteReminder event,
    Emitter<ReminderState> emit,
  ) async {
    final currentReminders = _getCurrentReminders();

    // Optimistic delete
    final updatedReminders = currentReminders
        .where((r) => r.id != event.reminderId)
        .toList();

    emit(RemindersLoaded(reminders: updatedReminders, nextReminderTime: null));

    try {
      debugPrint('🗑️ BLoC: Deleting reminder ${event.reminderId}');

      final success = await _reminderService.deleteReminder(event.reminderId);

      if (success) {
        final nextTime = await _reminderService.getNextReminderTime();
        emit(
          RemindersLoaded(
            reminders: updatedReminders,
            nextReminderTime: nextTime,
          ),
        );
        debugPrint('✓ BLoC: Delete successful');
      } else {
        debugPrint('⚠️ BLoC: Delete failed, reverting');
        emit(
          RemindersLoaded(reminders: currentReminders, nextReminderTime: null),
        );
      }
    } catch (e) {
      debugPrint('❌ BLoC: Error deleting: $e');
      emit(
        RemindersLoaded(reminders: currentReminders, nextReminderTime: null),
      );
    }
  }

  /// Get current reminders from state
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

  @override
  Future<void> close() {
    debugPrint('🔌 ReminderBloc closing, cancelling subscriptions');
    _reminderSubscription?.cancel();
    return super.close();
  }
}
