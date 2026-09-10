import 'package:flutter/material.dart';

/// Immediate, app-wide theme signal.
///
/// Hive remains the persisted source of truth. This notifier exists so a
/// running MaterialApp does not have to rely on a provider notification
/// travelling back up from a routed settings screen.
final ValueNotifier<ThemeMode> appThemeModeController =
    ValueNotifier<ThemeMode>(ThemeMode.system);

void setActiveThemeMode(ThemeMode mode) {
  if (appThemeModeController.value != mode) {
    appThemeModeController.value = mode;
  }
}
