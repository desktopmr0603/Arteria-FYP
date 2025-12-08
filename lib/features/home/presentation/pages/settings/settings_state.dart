import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class SettingsState extends Equatable {
  final bool isDarkMode;
  final bool pauseNotifications;
  final Locale locale;

  const SettingsState({
    required this.isDarkMode,
    required this.pauseNotifications,
    this.locale = const Locale('en'),
  });

  SettingsState copyWith({
    bool? isDarkMode,
    bool? pauseNotifications,
    Locale? locale,
  }) {
    return SettingsState(
      isDarkMode: isDarkMode ?? this.isDarkMode,
      pauseNotifications: pauseNotifications ?? this.pauseNotifications,
      locale: locale ?? this.locale,
    );
  }

  @override
  List<Object> get props => [isDarkMode, pauseNotifications, locale];
}
