import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// This class handles dark/light mode toggling and persists user preference
/// to local storage using SharedPreferences. It extends ChangeNotifier to
/// enable reactive UI updates when theme changes occur.

class ThemeCubit with ChangeNotifier {
  /// Storage key for persisting theme preference in SharedPreferences
  static const String _themeKey = 'darkMode';
  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  /// Theme is loaded asynchronously on initialization. The UI will reflect
  /// the default (light mode) until the saved preference is loaded.
  ThemeCubit() {
    _loadTheme();
  }

  Future<void> _loadTheme({bool notifyOnLoad = true}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDarkMode = prefs.getBool(_themeKey) ?? false;
      if (notifyOnLoad) notifyListeners();
    } catch (_) {}
  }

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners(); // instant update
    _saveThemePreference(_isDarkMode); // save asynchronously
  }

  void setTheme(bool isDark) {
    _isDarkMode = isDark;
    notifyListeners();
    _saveThemePreference(isDark);
  }

  /// Saves the user's theme choice to the phone's storage.
  /// [isDark] - true means save "dark mode is ON", false means "dark mode is OFF"

  Future<void> _saveThemePreference(bool isDark) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_themeKey, isDark);
    } catch (_) {}
  }
}
