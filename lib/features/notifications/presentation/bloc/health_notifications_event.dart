part of 'health_notifications_bloc.dart';

abstract class HealthNotificationsEvent extends Equatable {
  const HealthNotificationsEvent();

  @override
  List<Object> get props => [];
}

class LoadHealthNotifications extends HealthNotificationsEvent {
  const LoadHealthNotifications();
}

class AddHealthNotification extends HealthNotificationsEvent {
  final HealthNotification notification;

  const AddHealthNotification(this.notification);

  @override
  List<Object> get props => [notification];
}

class MarkNotificationAsRead extends HealthNotificationsEvent {
  final String notificationId;

  const MarkNotificationAsRead(this.notificationId);

  @override
  List<Object> get props => [notificationId];
}

class DismissNotification extends HealthNotificationsEvent {
  final String notificationId;

  const DismissNotification(this.notificationId);

  @override
  List<Object> get props => [notificationId];
}

class ClearAllNotifications extends HealthNotificationsEvent {
  const ClearAllNotifications();
}
