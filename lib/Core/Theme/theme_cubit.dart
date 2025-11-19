import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeCubit with ChangeNotifier {
  static const String _themeKey = 'darkMode';
  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

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

  Future<void> _saveThemePreference(bool isDark) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_themeKey, isDark);
    } catch (_) {}
  }
}
