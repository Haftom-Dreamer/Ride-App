import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'theme_mode';

  ThemeMode _themeMode = ThemeMode.system;
  bool _isDarkMode = false;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _isDarkMode;

  ThemeProvider() {
    _loadThemeFromPrefs();
  }

  Future<void> _loadThemeFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt(_themeKey) ?? 0;
    _themeMode = ThemeMode.values[themeIndex];
    _isDarkMode = _themeMode == ThemeMode.dark;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    _isDarkMode = mode == ThemeMode.dark;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, mode.index);

    notifyListeners();
  }

  void toggleTheme() {
    if (_themeMode == ThemeMode.light) {
      setThemeMode(ThemeMode.dark);
    } else if (_themeMode == ThemeMode.dark) {
      setThemeMode(ThemeMode.system);
    } else {
      setThemeMode(ThemeMode.light);
    }
  }

  ThemeData get currentTheme {
    if (_themeMode == ThemeMode.dark) {
      return AppTheme.darkTheme;
    } else if (_themeMode == ThemeMode.light) {
      return AppTheme.lightTheme;
    } else {
      // System mode - return light theme as default
      return AppTheme.lightTheme;
    }
  }

  String get themeModeName {
    switch (_themeMode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }
}

// Riverpod provider to expose ThemeProvider to the app
final themeProviderNotifier = ChangeNotifierProvider<ThemeProvider>((ref) {
  return ThemeProvider();
});
