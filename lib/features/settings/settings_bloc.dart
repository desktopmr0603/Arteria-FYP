import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'settings_event.dart';
import 'settings_state.dart';

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  static const _themeKey = 'darkMode';
  static const _pauseKey = 'pauseNotifications';
  static const _localeKey = 'locale';

  SettingsBloc()
    : super(const SettingsState(
        isDarkMode: false,
        pauseNotifications: false,
        locale: Locale('en'),
      )) {
    on<LoadSettings>(_onLoadSettings);
    on<ToggleDarkMode>(_onToggleDarkMode);
    on<TogglePauseNotifications>(_onTogglePauseNotifications);
    on<ChangeLocale>(_onChangeLocale);

    // Load saved settings immediately when bloc is created
    add(LoadSettings());
  }

  Future<void> _onLoadSettings(
    LoadSettings event,
    Emitter<SettingsState> emit,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final dark = prefs.getBool(_themeKey) ?? false;
    final paused = prefs.getBool(_pauseKey) ?? false;
    final localeCode = prefs.getString(_localeKey) ?? 'en';
    emit(SettingsState(
      isDarkMode: dark,
      pauseNotifications: paused,
      locale: Locale(localeCode),
    ));
  }

  Future<void> _onToggleDarkMode(
    ToggleDarkMode event,
    Emitter<SettingsState> emit,
  ) async {
    final newMode = !state.isDarkMode;
    emit(state.copyWith(isDarkMode: newMode)); // instant UI update
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool(_themeKey, newMode); // save in background
  }

  Future<void> _onTogglePauseNotifications(
    TogglePauseNotifications event,
    Emitter<SettingsState> emit,
  ) async {
    final newValue = !state.pauseNotifications;
    emit(state.copyWith(pauseNotifications: newValue));
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool(_pauseKey, newValue);
  }

  Future<void> _onChangeLocale(
    ChangeLocale event,
    Emitter<SettingsState> emit,
  ) async {
    debugPrint('🔄 Changing locale to: ${event.locale.languageCode}');
    emit(state.copyWith(locale: event.locale)); // instant UI update
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, event.locale.languageCode); // save in background
    debugPrint('✅ Locale saved to SharedPreferences');
  }
}
