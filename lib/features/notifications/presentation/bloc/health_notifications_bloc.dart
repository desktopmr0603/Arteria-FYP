import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

part 'health_notifications_event.dart';
part 'health_notifications_state.dart';

// Notification data classes
class HealthNotification {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final NotificationType type;
  final NotificationPriority priority;
  final bool isRead;
  final bool isResolved;
  final String? actionText;

  const HealthNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.type,
    required this.priority,
    required this.isRead,
    required this.isResolved,
    this.actionText,
  });

  @override
  List<Object> get props => [
        id,
        title,
        message,
        timestamp,
        type,
        priority,
        isRead,
        isResolved,
        actionText ?? '',
      ];
}

enum NotificationType {
  riskChange,
  anomaly,
  medication,
  trend,
  summary,
}

enum NotificationPriority {
  critical,
  high,
  medium,
  low,
}

class HealthNotificationsBloc extends Bloc<HealthNotificationsEvent, HealthNotificationsState> {
  HealthNotificationsBloc() : super(const HealthNotificationsInitial()) {
    on<LoadHealthNotifications>(_onLoadHealthNotifications);
    on<AddHealthNotification>(_onAddHealthNotification);
    on<MarkNotificationAsRead>(_onMarkNotificationAsRead);
    on<DismissNotification>(_onDismissNotification);
    on<ClearAllNotifications>(_onClearAllNotifications);
  }

  Future<void> _onLoadHealthNotifications(
    LoadHealthNotifications event,
    Emitter<HealthNotificationsState> emit,
  ) async {
    emit(const HealthNotificationsLoading());
    
    try {
      // Simulate API call
      await Future.delayed(const Duration(milliseconds: 800));
      
      final notifications = _generateSampleNotifications();
      emit(HealthNotificationsLoaded(notifications));
    } catch (e) {
      emit(HealthNotificationsError('Failed to load notifications: $e'));
    }
  }

  Future<void> _onAddHealthNotification(
    AddHealthNotification event,
    Emitter<HealthNotificationsState> emit,
  ) async {
    if (state is HealthNotificationsLoaded) {
      final currentNotifications = List<HealthNotification>.from((state as HealthNotificationsLoaded).notifications);
      currentNotifications.insert(0, event.notification);
      emit(HealthNotificationsLoaded(currentNotifications));
    }
  }

  Future<void> _onMarkNotificationAsRead(
    MarkNotificationAsRead event,
    Emitter<HealthNotificationsState> emit,
  ) async {
    if (state is HealthNotificationsLoaded) {
      final currentNotifications = (state as HealthNotificationsLoaded).notifications.map((notification) {
        if (notification.id == event.notificationId) {
          return HealthNotification(
            id: notification.id,
            title: notification.title,
            message: notification.message,
            timestamp: notification.timestamp,
            type: notification.type,
            priority: notification.priority,
            isRead: true,
            isResolved: notification.isResolved,
            actionText: notification.actionText,
          );
        }
        return notification;
      }).toList();
      emit(HealthNotificationsLoaded(currentNotifications));
    }
  }

  Future<void> _onDismissNotification(
    DismissNotification event,
    Emitter<HealthNotificationsState> emit,
  ) async {
    if (state is HealthNotificationsLoaded) {
      final currentNotifications = (state as HealthNotificationsLoaded).notifications
          .where((notification) => notification.id != event.notificationId)
          .toList();
      emit(HealthNotificationsLoaded(currentNotifications));
    }
  }

  Future<void> _onClearAllNotifications(
    ClearAllNotifications event,
    Emitter<HealthNotificationsState> emit,
  ) async {
    emit(const HealthNotificationsLoaded([]));
  }

  List<HealthNotification> _generateSampleNotifications() {
    final now = DateTime.now();
    return [
      HealthNotification(
        id: '1',
        title: '🚨 Critical Health Alert',
        message: 'Unusual BP pattern detected: 165/95 mmHg. Please check your reading and consider contacting your healthcare provider.',
        timestamp: now.subtract(const Duration(minutes: 30)),
        type: NotificationType.anomaly,
        priority: NotificationPriority.critical,
        isRead: false,
        isResolved: false,
        actionText: 'Take Action',
      ),
      HealthNotification(
        id: '2',
        title: '📈 Risk Score Increased',
        message: 'Your health risk score has increased by 18% over the past week. Current score: 72/100. This may be due to recent lifestyle changes.',
        timestamp: now.subtract(const Duration(hours: 2)),
        type: NotificationType.riskChange,
        priority: NotificationPriority.high,
        isRead: false,
        isResolved: false,
        actionText: 'View Details',
      ),
      HealthNotification(
        id: '3',
        title: '💊 Medication Reminder',
        message: 'You haven\'t taken your blood pressure medication today. Consistent medication adherence is crucial for effective BP management.',
        timestamp: now.subtract(const Duration(hours: 4)),
        type: NotificationType.medication,
        priority: NotificationPriority.medium,
        isRead: true,
        isResolved: false,
        actionText: 'Mark as Taken',
      ),
      HealthNotification(
        id: '4',
        title: '📊 BP Trend Analysis',
        message: 'Your blood pressure has been trending upward for 5 days. Average increase of 8 mmHg systolic. Consider reviewing your diet and stress levels.',
        timestamp: now.subtract(const Duration(hours: 6)),
        type: NotificationType.trend,
        priority: NotificationPriority.medium,
        isRead: true,
        isResolved: false,
        actionText: 'View Trends',
      ),
      HealthNotification(
        id: '5',
        title: '📋 Daily Health Summary',
        message: 'Your daily health summary is ready. Risk score: 72/100, Average BP: 142/88 mmHg, Steps: 6,234, Sleep: 7.2 hours.',
        timestamp: now.subtract(const Duration(days: 1)),
        type: NotificationType.summary,
        priority: NotificationPriority.low,
        isRead: true,
        isResolved: true,
        actionText: 'View Report',
      ),
      HealthNotification(
        id: '6',
        title: '🎉 Health Improvement',
        message: 'Great progress! Your risk score decreased by 12% this week. Keep up the good work with your medication adherence and exercise routine.',
        timestamp: now.subtract(const Duration(days: 2)),
        type: NotificationType.riskChange,
        priority: NotificationPriority.low,
        isRead: true,
        isResolved: true,
        actionText: 'Celebrate',
      ),
      HealthNotification(
        id: '7',
        title: '⚠️ Medication Adherence',
        message: 'You missed 3 doses of your medication in the past week. This may affect your blood pressure control. Please set up reminders.',
        timestamp: now.subtract(const Duration(days: 3)),
        type: NotificationType.medication,
        priority: NotificationPriority.high,
        isRead: true,
        isResolved: false,
        actionText: 'Set Reminders',
      ),
      HealthNotification(
        id: '8',
        title: '🔍 Anomaly Resolved',
        message: 'The unusual BP pattern detected on Monday has resolved. Your readings have returned to normal range. Continue monitoring.',
        timestamp: now.subtract(const Duration(days: 4)),
        type: NotificationType.anomaly,
        priority: NotificationPriority.low,
        isRead: true,
        isResolved: true,
        actionText: null,
      ),
    ];
  }
}
