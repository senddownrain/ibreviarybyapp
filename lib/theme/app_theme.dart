import 'package:flutter/material.dart';

/// Application chrome palette shared with the MyBrev PWA.
///
/// Liturgical colours remain contextual accents and must not replace these
/// achromatic surfaces. Rubrics keep their traditional red.
abstract final class AppPalette {
  static const lightPrimary = Color(0xFF242522);
  static const lightOnPrimary = Color(0xFFFFFFFF);
  static const lightSecondary = Color(0xFF656760);
  static const lightBackground = Color(0xFFF2F1EE);
  static const lightSurface = Color(0xFFF8F8F5);
  static const lightSurfaceBright = Color(0xFFFEFDFB);
  static const lightSurfaceVariant = Color(0xFFE6E5E0);
  static const lightOnSurface = Color(0xFF20211F);
  static const lightOnSurfaceVariant = Color(0xFF5F625C);
  static const lightDevotional = Color(0xFF4E504B);
  static const lightRubric = Color(0xFF9B302A);
  static const lightAmbient = Color(0xFFC8CAC3);

  static const darkPrimary = Color(0xFFE8EBE6);
  static const darkOnPrimary = Color(0xFF191B18);
  static const darkSecondary = Color(0xFFB7BCB4);
  static const darkBackground = Color(0xFF0F110F);
  static const darkSurface = Color(0xFF171917);
  static const darkSurfaceBright = Color(0xFF20231F);
  static const darkSurfaceVariant = Color(0xFF292C28);
  static const darkOnSurface = Color(0xFFE9ECE7);
  static const darkOnSurfaceVariant = Color(0xFFAEB3AB);
  static const darkDevotional = Color(0xFFD0D5CD);
  static const darkRubric = Color(0xFFEF9188);
  static const darkAmbient = Color(0xFF343A34);

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
