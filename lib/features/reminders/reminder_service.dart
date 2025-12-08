import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'reminder_model.dart';

/// Service for managing BP measurement reminders
class ReminderService {
  static final ReminderService _instance = ReminderService._internal();
  factory ReminderService() => _instance;
  ReminderService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isInitialized = false;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize timezone data
    tz_data.initializeTimeZones();

    // Android initialization settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request permissions on Android 13+
    if (Platform.isAndroid) {
      await _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }

    _isInitialized = true;
    debugPrint('✓ ReminderService initialized');
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    // Navigation to app is handled automatically
  }

  /// Get reference to user's reminders collection
  CollectionReference<Map<String, dynamic>> _remindersCollection(String userId) {
    return _firestore.collection('users').doc(userId).collection('reminders');
  }

  /// Get current user ID
  String? get _currentUserId => FirebaseAuth.instance.currentUser?.uid;

  /// Load all reminders for current user
  Future<List<Reminder>> loadReminders() async {
    final userId = _currentUserId;
    if (userId == null) return [];

    try {
      final snapshot = await _remindersCollection(userId)
          .orderBy('hour')
          .orderBy('minute')
          .get();

      return snapshot.docs.map((doc) => Reminder.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Error loading reminders: $e');
      return [];
    }
  }

  /// Check if user has any enabled reminders
  Future<bool> hasActiveReminders() async {
    final reminders = await loadReminders();
    return reminders.any((r) => r.isEnabled);
  }

  /// Add a new reminder
  Future<Reminder?> addReminder({
    required TimeOfDay time,
    RepeatType repeatType = RepeatType.daily,
    List<int> customDays = const [],
    String? label,
  }) async {
    final userId = _currentUserId;
    if (userId == null) return null;

    try {
      final reminder = Reminder(
        id: '', // Will be set by Firestore
        time: time,
        repeatType: repeatType,
        customDays: customDays,
        isEnabled: true,
        label: label,
        createdAt: DateTime.now(),
      );

      final docRef = await _remindersCollection(userId).add(reminder.toFirestore());
      final newReminder = reminder.copyWith(id: docRef.id);

      // Schedule the notification
      await _scheduleNotification(newReminder);

      debugPrint('✓ Reminder added: ${newReminder.formattedTime}');
      return newReminder;
    } catch (e) {
      debugPrint('Error adding reminder: $e');
      return null;
    }
  }

  /// Update an existing reminder
  Future<bool> updateReminder(Reminder reminder) async {
    final userId = _currentUserId;
    if (userId == null) return false;

    try {
      await _remindersCollection(userId).doc(reminder.id).update({
        'hour': reminder.time.hour,
        'minute': reminder.time.minute,
        'repeatType': reminder.repeatType.name,
        'customDays': reminder.customDays,
        'isEnabled': reminder.isEnabled,
        'label': reminder.label,
      });

      // Cancel existing notification and reschedule if enabled
      await _cancelNotification(reminder.id);
      if (reminder.isEnabled) {
        await _scheduleNotification(reminder);
      }

      debugPrint('✓ Reminder updated: ${reminder.formattedTime}');
      return true;
    } catch (e) {
      debugPrint('Error updating reminder: $e');
      return false;
    }
  }

  /// Toggle reminder enabled state
  Future<bool> toggleReminder(String reminderId, bool isEnabled) async {
    final userId = _currentUserId;
    if (userId == null) return false;

    try {
      await _remindersCollection(userId).doc(reminderId).update({
        'isEnabled': isEnabled,
      });

      if (isEnabled) {
        // Reload and reschedule
        final doc = await _remindersCollection(userId).doc(reminderId).get();
        if (doc.exists) {
          await _scheduleNotification(Reminder.fromFirestore(doc));
        }
      } else {
        await _cancelNotification(reminderId);
      }

      debugPrint('✓ Reminder ${isEnabled ? 'enabled' : 'disabled'}');
      return true;
    } catch (e) {
      debugPrint('Error toggling reminder: $e');
      return false;
    }
  }

  /// Delete a reminder
  Future<bool> deleteReminder(String reminderId) async {
    final userId = _currentUserId;
    if (userId == null) return false;

    try {
      await _remindersCollection(userId).doc(reminderId).delete();
      await _cancelNotification(reminderId);

      debugPrint('✓ Reminder deleted');
      return true;
    } catch (e) {
      debugPrint('Error deleting reminder: $e');
      return false;
    }
  }

  /// Schedule a notification for a reminder
  Future<void> _scheduleNotification(Reminder reminder) async {
    if (!_isInitialized) await initialize();

    final nextTrigger = reminder.getNextTriggerTime();
    if (nextTrigger == null) return;

    final notificationId = reminder.id.hashCode.abs() % 2147483647;

    const androidDetails = AndroidNotificationDetails(
      'bp_reminders',
      'BP Measurement Reminders',
      channelDescription: 'Reminders to measure your blood pressure',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Schedule recurring notification based on repeat type
    if (reminder.repeatType == RepeatType.daily) {
      // Use daily scheduling
      await _notifications.zonedSchedule(
        notificationId,
        'Time to check your BP! 💓',
        reminder.label ?? 'Record your blood pressure reading now',
        _nextInstanceOfTime(reminder.time),
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: reminder.id,
      );
    } else {
      // For weekdays/weekends/custom, schedule for next valid day
      await _notifications.zonedSchedule(
        notificationId,
        'Time to check your BP! 💓',
        reminder.label ?? 'Record your blood pressure reading now',
        tz.TZDateTime.from(nextTrigger, tz.local),
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: reminder.id,
      );
    }

    debugPrint('✓ Notification scheduled for ${reminder.formattedTime}');
  }

  /// Cancel a scheduled notification
  Future<void> _cancelNotification(String reminderId) async {
    final notificationId = reminderId.hashCode.abs() % 2147483647;
    await _notifications.cancel(notificationId);
    debugPrint('✓ Notification cancelled');
  }

  /// Get next instance of a time today or tomorrow
  tz.TZDateTime _nextInstanceOfTime(TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    return scheduled;
  }

  /// Reschedule all enabled reminders (call after app restart or time zone change)
  Future<void> rescheduleAllReminders() async {
    final reminders = await loadReminders();
    for (final reminder in reminders) {
      if (reminder.isEnabled) {
        await _scheduleNotification(reminder);
      }
    }
    debugPrint('✓ Rescheduled ${reminders.where((r) => r.isEnabled).length} reminders');
  }

  /// Get the next upcoming reminder time
  Future<DateTime?> getNextReminderTime() async {
    final reminders = await loadReminders();
    final enabledReminders = reminders.where((r) => r.isEnabled);

    DateTime? nextTime;
    for (final reminder in enabledReminders) {
      final triggerTime = reminder.getNextTriggerTime();
      if (triggerTime != null) {
        if (nextTime == null || triggerTime.isBefore(nextTime)) {
          nextTime = triggerTime;
        }
      }
    }

    return nextTime;
  }
}
