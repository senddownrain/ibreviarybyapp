import 'package:flutter/material.dart';

/// Application chrome palette shared with the MyBrev PWA.
///
/// Liturgical colours remain contextual accents and must not replace these
/// warm neutral surfaces.
abstract final class AppPalette {
  static const lightPrimary = Color(0xFF6B4A32);
  static const lightOnPrimary = Color(0xFFFFF8EE);
  static const lightSecondary = Color(0xFF79583D);
  static const lightBackground = Color(0xFFF5F1E8);
  static const lightSurface = Color(0xFFFFFBF3);
  static const lightSurfaceBright = Color(0xFFFFFDF9);
  static const lightSurfaceVariant = Color(0xFFECE3D6);
  static const lightOnSurface = Color(0xFF2A221B);
  static const lightOnSurfaceVariant = Color(0xFF675A4D);
  static const lightDevotional = Color(0xFF8B493B);
  static const lightRubric = Color(0xFF9B302A);
  static const lightAmbient = Color(0xFFB49B71);

  static const darkPrimary = Color(0xFFC9A67B);
  static const darkOnPrimary = Color(0xFF281B12);
  static const darkSecondary = Color(0xFFB89570);
  static const darkBackground = Color(0xFF0F0E0C);
  static const darkSurface = Color(0xFF171512);
  static const darkSurfaceBright = Color(0xFF211E1A);
  static const darkSurfaceVariant = Color(0xFF2A2621);
  static const darkOnSurface = Color(0xFFF2EBDD);
  static const darkOnSurfaceVariant = Color(0xFFC5B8A7);
  static const darkDevotional = Color(0xFFD39A83);
  static const darkRubric = Color(0xFFEF9188);
  static const darkAmbient = Color(0xFF4A3A2D);

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
