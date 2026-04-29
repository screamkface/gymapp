import 'package:flutter/material.dart';

class AppPreferences {
  static const themeModeKey = 'themeMode';
  static const defaultRestSecondsKey = 'defaultRestSeconds';

  static const defaultThemeMode = ThemeMode.system;
  static const defaultRestSeconds = 90;
  static const minRestSeconds = 30;
  static const maxRestSeconds = 300;

  static ThemeMode themeModeFromString(String? value) {
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  static String themeModeToString(ThemeMode themeMode) {
    return switch (themeMode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
  }
}
