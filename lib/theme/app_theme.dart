import 'package:flutter/material.dart';
import 'package:mybrev_flutter/theme/ib_colors.dart';
import 'package:mybrev_flutter/theme/app_theme_preference.dart';

/// Application chrome palette shared with the MyBrev PWA.
///
/// Liturgical colours remain contextual accents and must not replace the application
/// surfaces. Rubrics keep their traditional red.
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
    AppThemePreference preference,
  ) {
    final light = scheme(Brightness.light);
    final dark = scheme(Brightness.dark);
    return switch (preference) {
      AppThemePreference.light => (theme: light, darkTheme: light),
      AppThemePreference.dark => (theme: dark, darkTheme: dark),
      AppThemePreference.system => (theme: light, darkTheme: dark),
      AppThemePreference.marian => (
        theme: marianScheme,
        darkTheme: marianScheme,
      ),
    };
  }

  static ColorScheme scheme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final colors = IbColors.forBrightness(brightness);
    return _scheme(
      brightness,
      colors,
      dark ? darkSecondary : lightSecondary,
      dark ? darkDevotional : lightDevotional,
      colors.onAccent,
    );
  }

  static ColorScheme get marianScheme => _scheme(
    Brightness.light,
    IbColors.marian,
    const Color(0xFF477DAA),
    IbColors.marian.accent,
    // White on #477DAA is 4.39:1; black keeps small secondary labels AA.
    Colors.black,
    outlineAlpha: 1,
  );

  static IbColors colorsFor(
    AppThemePreference preference,
    Brightness brightness,
  ) => preference == AppThemePreference.marian
      ? IbColors.marian
      : IbColors.forBrightness(brightness);

  static ColorScheme _scheme(
    Brightness brightness,
    IbColors colors,
    Color secondary,
    Color devotional,
    Color onSecondary, {
    double outlineAlpha = 0.55,
  }) {
    final dark = brightness == Brightness.dark;
    final primary = colors.accent;
    final onPrimary = colors.onAccent;
    final background = colors.page;
    final surface = colors.surface;
    final surfaceBright = colors.surfaceRaised;
    final surfaceVariant = colors.floating;
    final onSurface = colors.ink;
    final onSurfaceVariant = colors.inkMuted;

    return ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: primary.withValues(alpha: dark ? 0.22 : 0.13),
      onPrimaryContainer: primary,
      secondary: secondary,
      onSecondary: onSecondary,
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
      outline: colors.outline.withValues(alpha: outlineAlpha),
      outlineVariant: colors.outline.withValues(alpha: 0.22),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: onSurface,
      onInverseSurface: surface,
      inversePrimary: dark ? lightPrimary : darkPrimary,
    );
  }
}
