// Isolated welcome-screen preview: no Firebase, Hive or network access to data.
// flutter run -d chrome -t tool/welcome_smoke.dart --web-port 5243
// Query: ?theme=light|dark|marian&scale=1&fail=1
import 'package:flutter/material.dart';
import 'package:mybrev_flutter/main.dart' show buildAppTheme;
import 'package:mybrev_flutter/screens/welcome_screen.dart';
import 'package:mybrev_flutter/theme/app_theme.dart';
import 'package:mybrev_flutter/theme/app_theme_preference.dart';

void main() {
  final query = Uri.base.queryParameters;
  final preference = AppThemePreference.fromStorage(query['theme']);
  final schemes = AppPalette.schemesFor(preference);
  final scale = double.tryParse(query['scale'] ?? '') ?? 1;
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: preference.themeMode,
      theme: buildAppTheme(schemes.theme, preference: preference),
      darkTheme: buildAppTheme(schemes.darkTheme, preference: preference),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: WelcomeScreen(
        onStart: (section) async {
          if (query['fail'] == '1') throw StateError('preview failure');
          debugPrint('start: $section');
        },
      ),
    ),
  );
}
