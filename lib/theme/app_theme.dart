import 'package:flutter/material.dart';
import 'package:mybrev_flutter/theme/ib_colors.dart';

/// Application chrome palette shared with the MyBrev PWA.
///
/// Liturgical colours remain contextual accents and must not replace these
/// achromatic surfaces. Rubrics keep their traditional red.
abstract final class AppPalette {
  static final lightPrimary = IbColors.light.accent;
  static final lightOnPrimary = IbColors.light.onAccent;
  static const lightSecondary = Color(0xFF656760);
  static final lightBackground = IbColors.light.page;
  static final lightSurface = IbColors.light.surface;
  static final lightSurfaceBright = IbColors.light.surfaceRaised;
  static final lightSurfaceVariant = IbColors.light.floating;
  static final lightOnSurface = IbColors.light.ink;
  static final lightOnSurfaceVariant = IbColors.light.inkMuted;
  static const lightDevotional = Color(0xFF4E504B);
  static final lightRubric = IbColors.light.rubric;
  static final lightAmbient = IbColors.light.neutralAmbient;

  static final darkPrimary = IbColors.dark.accent;
  static final darkOnPrimary = IbColors.dark.onAccent;
  static const darkSecondary = Color(0xFFB7BCB4);
  static final darkBackground = IbColors.dark.page;
  static final darkSurface = IbColors.dark.surface;
  static final darkSurfaceBright = IbColors.dark.surfaceRaised;
  static final darkSurfaceVariant = IbColors.dark.floating;
  static final darkOnSurface = IbColors.dark.ink;
  static final darkOnSurfaceVariant = IbColors.dark.inkMuted;
  static const darkDevotional = Color(0xFFD0D5CD);
  static final darkRubric = IbColors.dark.rubric;
  static final darkAmbient = IbColors.dark.neutralAmbient;

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
    final colors = IbColors.forBrightness(brightness);
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
      error: colors.error,
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
      outline: colors.outline.withValues(alpha: 0.55),
      outlineVariant: colors.outline.withValues(alpha: 0.22),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: onSurface,
      onInverseSurface: surface,
      inversePrimary: dark ? lightPrimary : darkPrimary,
    );
  }
}
