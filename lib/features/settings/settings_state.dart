import 'package:equatable/equatable.dart';

class SettingsState extends Equatable {
  final bool isDarkMode;
  final bool pauseNotifications;

  const SettingsState({
    required this.isDarkMode,
    required this.pauseNotifications,
  });

  SettingsState copyWith({bool? isDarkMode, bool? pauseNotifications}) {
    return SettingsState(
      isDarkMode: isDarkMode ?? this.isDarkMode,
      pauseNotifications: pauseNotifications ?? this.pauseNotifications,
    );
  }

  @override
  List<Object> get props => [isDarkMode, pauseNotifications];
}
