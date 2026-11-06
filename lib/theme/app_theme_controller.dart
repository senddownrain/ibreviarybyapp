import 'package:flutter/material.dart';
import 'package:mybrev_flutter/theme/app_theme_preference.dart';

/// Immediate, app-wide theme signal.
///
/// Hive remains the persisted source of truth. This notifier exists so a
/// running MaterialApp does not have to rely on a provider notification
/// travelling back up from a routed settings screen.
final ValueNotifier<AppThemePreference> appThemePreferenceController =
    ValueNotifier<AppThemePreference>(AppThemePreference.system);

void setActiveThemePreference(AppThemePreference preference) {
  if (appThemePreferenceController.value != preference) {
    appThemePreferenceController.value = preference;
  }
}
