import 'package:flutter/material.dart';

/// User choice, distinct from the three brightness modes understood by Flutter.
/// Names also remain compatible with the existing Hive `themeMode` strings.
enum AppThemePreference {
  system('Сістэма'),
  light('Светлая'),
  dark('Цёмная'),
  marian('Марыйная');

  const AppThemePreference(this.label);
  final String label;

  ThemeMode get themeMode => switch (this) {
    system => ThemeMode.system,
    dark => ThemeMode.dark,
    light || marian => ThemeMode.light,
  };

  static AppThemePreference fromThemeMode(ThemeMode mode) => switch (mode) {
    ThemeMode.system => system,
    ThemeMode.light => light,
    ThemeMode.dark => dark,
  };

  static AppThemePreference fromStorage(Object? value) =>
      values.firstWhere((option) => option.name == value, orElse: () => system);
}
