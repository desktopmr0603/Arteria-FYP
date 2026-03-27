part of 'health_notifications_bloc.dart';

abstract class HealthNotificationsState extends Equatable {
  const HealthNotificationsState();

  @override
  List<Object> get props => [];
}

class HealthNotificationsInitial extends HealthNotificationsState {
  const HealthNotificationsInitial();
}

class HealthNotificationsLoading extends HealthNotificationsState {
  const HealthNotificationsLoading();
}

class HealthNotificationsLoaded extends HealthNotificationsState {
  final List<HealthNotification> notifications;

  const HealthNotificationsLoaded(this.notifications);

  @override
  List<Object> get props => [notifications];
}

class HealthNotificationsError extends HealthNotificationsState {
  final String message;

  const HealthNotificationsError(this.message);

  @override
  List<Object> get props => [message];
}
