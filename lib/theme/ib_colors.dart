import 'package:flutter/material.dart';

/// Semantic application colors. Platform chrome may express [floating] as
/// translucent glass or an opaque tonal surface.
@immutable
class IbColors extends ThemeExtension<IbColors> {
  const IbColors({
    required this.page,
    required this.reader,
    required this.surface,
    required this.surfaceRaised,
    required this.floating,
    required this.ink,
    required this.inkMuted,
    required this.readerMuted,
    required this.accent,
    required this.onAccent,
    required this.rubric,
    required this.error,
    required this.separator,
    required this.outline,
    required this.neutralAmbient,
  });

  final Color page;
  final Color reader;
  final Color surface;
  final Color surfaceRaised;
  final Color floating;
  final Color ink;
  final Color inkMuted;
  final Color readerMuted;
  final Color accent;
  final Color onAccent;
  final Color rubric;
  final Color error;
  final Color separator;
  final Color outline;
  final Color neutralAmbient;

  static const light = IbColors(
    page: Color(0xFFF2F1EE),
    reader: Color(0xFFFDFCF9),
    surface: Color(0xFFF8F8F5),
    surfaceRaised: Color(0xFFFEFDFB),
    floating: Color(0xFFE6E5E0),
    ink: Color(0xFF20211F),
    inkMuted: Color(0xFF5F625C),
    readerMuted: Color(0xFF62645F),
    accent: Color(0xFF242522),
    onAccent: Color(0xFFFFFFFF),
    rubric: Color(0xFF9B302A),
    error: Color(0xFFBA1A1A),
    separator: Color(0x1F000000),
    outline: Color(0xFF5F625C),
    neutralAmbient: Color(0xFFC8CAC3),
  );

  static const dark = IbColors(
    page: Color(0xFF0F110F),
    reader: Color(0xFF171917),
    surface: Color(0xFF171917),
    surfaceRaised: Color(0xFF20231F),
    floating: Color(0xFF292C28),
    ink: Color(0xFFE9ECE7),
    inkMuted: Color(0xFFAEB3AB),
    readerMuted: Color(0xFFAEB3AB),
    accent: Color(0xFFE8EBE6),
    onAccent: Color(0xFF191B18),
    rubric: Color(0xFFEF9188),
    error: Color(0xFFFFB4AB),
    separator: Color(0x21FFFFFF),
    outline: Color(0xFFAEB3AB),
    neutralAmbient: Color(0xFF343A34),
  );

  static const marian = IbColors(
    page: Color(0xFFF4F8FC),
    reader: Color(0xFFFBFDFF),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFFFFFFF),
    floating: Color(0xFFE2EFF9),
    ink: Color(0xFF202D39),
    inkMuted: Color(0xFF52687A),
    readerMuted: Color(0xFF52687A),
    accent: Color(0xFF244D78),
    onAccent: Color(0xFFFFFFFF),
    rubric: Color(0xFF9B302A),
    error: Color(0xFFA62D32),
    separator: Color(0x1F244D78),
    outline: Color(0xFF52687A),
    neutralAmbient: Color(0xFFA8CBE6),
  );

  /// Fallback for themes without the application extension. App assembly must
  /// install the selected palette explicitly: Marian is also light in Flutter.
  static IbColors forBrightness(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  static IbColors of(BuildContext context) =>
      Theme.of(context).extension<IbColors>() ??
      forBrightness(Theme.of(context).brightness);

  @override
  IbColors copyWith({
    Color? page,
    Color? reader,
    Color? surface,
    Color? surfaceRaised,
    Color? floating,
    Color? ink,
    Color? inkMuted,
    Color? readerMuted,
    Color? accent,
    Color? onAccent,
    Color? rubric,
    Color? error,
    Color? separator,
    Color? outline,
    Color? neutralAmbient,
  }) => IbColors(
    page: page ?? this.page,
    reader: reader ?? this.reader,
    surface: surface ?? this.surface,
    surfaceRaised: surfaceRaised ?? this.surfaceRaised,
    floating: floating ?? this.floating,
    ink: ink ?? this.ink,
    inkMuted: inkMuted ?? this.inkMuted,
    readerMuted: readerMuted ?? this.readerMuted,
    accent: accent ?? this.accent,
    onAccent: onAccent ?? this.onAccent,
    rubric: rubric ?? this.rubric,
    error: error ?? this.error,
    separator: separator ?? this.separator,
    outline: outline ?? this.outline,
    neutralAmbient: neutralAmbient ?? this.neutralAmbient,
  );

  @override
  IbColors lerp(ThemeExtension<IbColors>? other, double t) {
    if (other is! IbColors) return this;
    return IbColors(
      page: Color.lerp(page, other.page, t)!,
      reader: Color.lerp(reader, other.reader, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      floating: Color.lerp(floating, other.floating, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      readerMuted: Color.lerp(readerMuted, other.readerMuted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      rubric: Color.lerp(rubric, other.rubric, t)!,
      error: Color.lerp(error, other.error, t)!,
      separator: Color.lerp(separator, other.separator, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      neutralAmbient: Color.lerp(neutralAmbient, other.neutralAmbient, t)!,
    );
  }
}
