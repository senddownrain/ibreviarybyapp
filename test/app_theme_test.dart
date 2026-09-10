import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/theme/app_theme.dart';

void main() {
  test('explicit theme mode is authoritative for both MaterialApp slots', () {
    final light = AppPalette.schemesFor(ThemeMode.light);
    expect(light.theme.brightness, Brightness.light);
    expect(light.darkTheme.brightness, Brightness.light);

    final dark = AppPalette.schemesFor(ThemeMode.dark);
    expect(dark.theme.brightness, Brightness.dark);
    expect(dark.darkTheme.brightness, Brightness.dark);
  });

  test('system theme keeps separate light and dark MaterialApp slots', () {
    final system = AppPalette.schemesFor(ThemeMode.system);
    expect(system.theme.brightness, Brightness.light);
    expect(system.darkTheme.brightness, Brightness.dark);
  });
}
