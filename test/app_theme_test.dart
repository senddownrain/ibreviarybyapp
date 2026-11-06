import 'package:mybrev_flutter/theme/app_theme_preference.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/theme/app_theme.dart';
import 'package:mybrev_flutter/theme/app_theme_controller.dart';

void main() {
  test('explicit theme mode is authoritative for both MaterialApp slots', () {
    final light = AppPalette.schemesFor(AppThemePreference.light);
    expect(light.theme.brightness, Brightness.light);
    expect(light.darkTheme.brightness, Brightness.light);

    final dark = AppPalette.schemesFor(AppThemePreference.dark);
    expect(dark.theme.brightness, Brightness.dark);
    expect(dark.darkTheme.brightness, Brightness.dark);
  });

  test('system theme keeps separate light and dark MaterialApp slots', () {
    final system = AppPalette.schemesFor(AppThemePreference.system);
    expect(system.theme.brightness, Brightness.light);
    expect(system.darkTheme.brightness, Brightness.dark);
  });

  testWidgets('app theme controller updates the running MaterialApp', (
    tester,
  ) async {
    setActiveThemePreference(AppThemePreference.light);
    addTearDown(() => setActiveThemePreference(AppThemePreference.system));

    await tester.pumpWidget(
      ValueListenableBuilder<AppThemePreference>(
        valueListenable: appThemePreferenceController,
        builder: (context, mode, _) {
          final schemes = AppPalette.schemesFor(mode);
          return MaterialApp(
            key: ValueKey(mode),
            theme: ThemeData(colorScheme: schemes.theme),
            darkTheme: ThemeData(colorScheme: schemes.darkTheme),
            themeMode: mode.themeMode,
            themeAnimationDuration: Duration.zero,
            home: Builder(
              builder: (context) => Scaffold(
                body: Column(
                  children: [
                    Text(
                      Theme.of(context).brightness.name,
                      key: const Key('active-brightness'),
                    ),
                    TextButton(
                      onPressed: () =>
                          setActiveThemePreference(AppThemePreference.dark),
                      child: const Text('dark'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    expect(
      tester.widget<Text>(find.byKey(const Key('active-brightness'))).data,
      'light',
    );
    await tester.tap(find.text('dark'));
    await tester.pump();
    expect(
      tester.widget<Text>(find.byKey(const Key('active-brightness'))).data,
      'dark',
    );
  });
}
