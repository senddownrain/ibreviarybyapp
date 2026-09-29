import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Persisted reader-family identifiers. User-facing labels live in Settings;
/// storage keys stay language-neutral and must not be passed to Google Fonts.
abstract final class ReaderFontFamily {
  static const literata = 'literata';
  static const system = 'system';
  static const sourceSerif4 = 'sourceSerif4';
}

/// Allows deterministic widget harnesses to use Flutter's bundled test font.
/// Production does not install this scope, so its typography is unchanged.
class ReaderTypographyScope extends InheritedWidget {
  const ReaderTypographyScope({
    super.key,
    required this.useSystemFonts,
    required super.child,
  });

  final bool useSystemFonts;

  static bool useSystemFontsOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<ReaderTypographyScope>()
          ?.useSystemFonts ??
      false;

  @override
  bool updateShouldNotify(ReaderTypographyScope oldWidget) =>
      useSystemFonts != oldWidget.useSystemFonts;
}

/// Reader typography and surfaces (mirrors web `--reader-*` tokens).
class ReaderTheme {
  const ReaderTheme._(this.isDark, this.useSystemFonts);

  static const double bodyHeight = 1.68;
  static const double hymnHeight = 1.72;
  static const double referenceHeight = 1.40;
  static const double rubricHeight = 1.48;
  static const double metadataHeight = 1.42;
  static const double headingHeight = 1.28;

  factory ReaderTheme.of(BuildContext context) => ReaderTheme._(
    Theme.of(context).brightness == Brightness.dark,
    ReaderTypographyScope.useSystemFontsOf(context),
  );

  final bool isDark;
  final bool useSystemFonts;

  Color get ink => isDark ? const Color(0xFFE9ECE7) : const Color(0xFF20211F);
  Color get muted => isDark ? const Color(0xFFAEB3AB) : const Color(0xFF62645F);
  Color get rubric =>
      isDark ? const Color(0xFFEF9188) : const Color(0xFF9B302A);
  Color get rubricSoft =>
      isDark ? const Color(0x17EF9188) : const Color(0x139B302A);
  Color get surface =>
      isDark ? const Color(0xFF171917) : const Color(0xFFFDFCF9);
  Color get border =>
      isDark ? const Color(0x21FFFFFF) : const Color(0x1F000000);

  TextStyle displayTitle(double size) {
    final base = TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w700,
      height: 1.06,
      letterSpacing: -0.02,
      color: ink,
    );
    return useSystemFonts
        ? base
        : GoogleFonts.cormorantGaramond(textStyle: base);
  }

  TextStyle body(double size, {String? family}) {
    final base = TextStyle(fontSize: size, height: bodyHeight, color: ink);
    if (useSystemFonts) return base;
    try {
      return switch (family) {
        ReaderFontFamily.system => base,
        ReaderFontFamily.sourceSerif4 => GoogleFonts.sourceSerif4(
          textStyle: base,
        ),
        _ => GoogleFonts.literata(textStyle: base),
      };
    } catch (_) {
      return base;
    }
  }

  TextStyle psalm(double size, {String? family}) => body(size, family: family);

  TextStyle hymn(double size, {String? family}) =>
      body(size, family: family).copyWith(height: hymnHeight);

  TextStyle rubricStyle(double size, {String? family}) =>
      body(size, family: family).copyWith(
        color: rubric,
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w500,
        height: rubricHeight,
      );

  TextStyle referenceStyle(double size, {String? family}) =>
      body(size, family: family).copyWith(
        color: muted,
        fontWeight: FontWeight.w600,
        height: referenceHeight,
        letterSpacing: 0.02,
      );

  TextStyle majorHeading(double bodySize) => body(
    (bodySize * .98).clamp(15, double.infinity),
  ).copyWith(height: headingHeight, fontWeight: FontWeight.w600);

  TextStyle blockHeading(double bodySize) => body(
    (bodySize * 1.10).clamp(18, double.infinity),
  ).copyWith(height: headingHeight, color: rubric, fontWeight: FontWeight.w600);

  TextStyle metadata(double bodySize, {bool italic = false}) =>
      body((bodySize * .88).clamp(14, double.infinity)).copyWith(
        height: metadataHeight,
        color: muted,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      );

  TextStyle rubricBlock(double bodySize, {bool italic = false}) =>
      body((bodySize * .90).clamp(14, double.infinity)).copyWith(
        height: rubricHeight,
        color: rubric,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      );
}
