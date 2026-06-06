import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeManager {
  static final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(ThemeMode.system);

  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mode = prefs.getString('settings_theme_mode') ?? 'system';
      themeModeNotifier.value = _parseThemeMode(mode);
    } catch (e) {
      debugPrint('[ThemeManager] Error initializing: $e');
    }
  }

  static Future<void> setThemeMode(ThemeMode mode) async {
    try {
      themeModeNotifier.value = mode;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('settings_theme_mode', mode.name);
    } catch (e) {
      debugPrint('[ThemeManager] Error setting theme mode: $e');
    }
  }

  static ThemeMode _parseThemeMode(String mode) {
    switch (mode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static String getLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      default:
        return 'System Default';
    }
  }
}
