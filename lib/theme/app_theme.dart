import 'package:flutter/material.dart';

/// Application chrome palette shared with the MyBrev PWA.
///
/// Liturgical colours remain contextual accents and must not replace these
/// achromatic surfaces. Rubrics keep their traditional red.
abstract final class AppPalette {
  static const lightPrimary = Color(0xFF202020);
  static const lightOnPrimary = Color(0xFFFFFFFF);
  static const lightSecondary = Color(0xFF626262);
  static const lightBackground = Color(0xFFF3F3F3);
  static const lightSurface = Color(0xFFFAFAFA);
  static const lightSurfaceBright = Color(0xFFFFFFFF);
  static const lightSurfaceVariant = Color(0xFFE7E7E7);
  static const lightOnSurface = Color(0xFF1C1C1C);
  static const lightOnSurfaceVariant = Color(0xFF626262);
  static const lightDevotional = Color(0xFF484848);
  static const lightRubric = Color(0xFF9B302A);
  static const lightAmbient = Color(0xFFBEBEBE);

  static const darkPrimary = Color(0xFFF0F0F0);
  static const darkOnPrimary = Color(0xFF171717);
  static const darkSecondary = Color(0xFFBEBEBE);
  static const darkBackground = Color(0xFF0D0D0D);
  static const darkSurface = Color(0xFF151515);
  static const darkSurfaceBright = Color(0xFF1D1D1D);
  static const darkSurfaceVariant = Color(0xFF292929);
  static const darkOnSurface = Color(0xFFF1F1F1);
  static const darkOnSurfaceVariant = Color(0xFFB5B5B5);
  static const darkDevotional = Color(0xFFD0D0D0);
  static const darkRubric = Color(0xFFEF9188);
  static const darkAmbient = Color(0xFF3A3A3A);

  /// Returns the schemes placed into MaterialApp's light and dark slots.
  ///
  /// For an explicit user choice both slots intentionally use the same
  /// brightness. This makes the in-app preference authoritative even when an
  /// Android device reports a stale platform brightness during an activity.
  static ({ColorScheme theme, ColorScheme darkTheme}) schemesFor(
    ThemeMode mode,
  ) {
    final light = scheme(Brightness.light);
    final dark = scheme(Brightness.dark);
    return switch (mode) {
      ThemeMode.light => (theme: light, darkTheme: light),
      ThemeMode.dark => (theme: dark, darkTheme: dark),
      ThemeMode.system => (theme: light, darkTheme: dark),
    };
  }

  static ColorScheme scheme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final primary = dark ? darkPrimary : lightPrimary;
    final onPrimary = dark ? darkOnPrimary : lightOnPrimary;
    final secondary = dark ? darkSecondary : lightSecondary;
    final background = dark ? darkBackground : lightBackground;
    final surface = dark ? darkSurface : lightSurface;
    final surfaceBright = dark ? darkSurfaceBright : lightSurfaceBright;
    final surfaceVariant = dark ? darkSurfaceVariant : lightSurfaceVariant;
    final onSurface = dark ? darkOnSurface : lightOnSurface;
    final onSurfaceVariant = dark
        ? darkOnSurfaceVariant
        : lightOnSurfaceVariant;
    final devotional = dark ? darkDevotional : lightDevotional;

    return ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: primary.withValues(alpha: dark ? 0.22 : 0.13),
      onPrimaryContainer: primary,
      secondary: secondary,
      onSecondary: onPrimary,
      secondaryContainer: surfaceVariant,
      onSecondaryContainer: onSurface,
      tertiary: devotional,
      onTertiary: onPrimary,
      tertiaryContainer: devotional.withValues(alpha: dark ? 0.22 : 0.10),
      onTertiaryContainer: devotional,
      error: dark ? const Color(0xFFFFB4AB) : const Color(0xFFBA1A1A),
      onError: dark ? const Color(0xFF690005) : Colors.white,
      errorContainer: dark ? const Color(0xFF93000A) : const Color(0xFFFFDAD6),
      onErrorContainer: dark
          ? const Color(0xFFFFDAD6)
          : const Color(0xFF410002),
      surface: surface,
      onSurface: onSurface,
      surfaceDim: background,
      surfaceBright: surfaceBright,
      surfaceContainerLowest: background,
      surfaceContainerLow: surface,
      surfaceContainer: surfaceBright,
      surfaceContainerHigh: surfaceVariant,
      surfaceContainerHighest: surfaceVariant,
      onSurfaceVariant: onSurfaceVariant,
      outline: onSurfaceVariant.withValues(alpha: 0.55),
      outlineVariant: onSurfaceVariant.withValues(alpha: 0.22),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: onSurface,
      onInverseSurface: surface,
      inversePrimary: dark ? lightPrimary : darkPrimary,
    );
  }
}
