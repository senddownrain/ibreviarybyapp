import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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

  factory ReaderTheme.of(BuildContext context) => ReaderTheme._(
    Theme.of(context).brightness == Brightness.dark,
    ReaderTypographyScope.useSystemFontsOf(context),
  );

  final bool isDark;
  final bool useSystemFonts;

  Color get ink => isDark ? const Color(0xFFF1F1F1) : const Color(0xFF1C1C1C);
  Color get muted => isDark ? const Color(0xFFB0B0B0) : const Color(0xFF686868);
  Color get rubric =>
      isDark ? const Color(0xFFEF9188) : const Color(0xFF9B302A);
  Color get rubricSoft =>
      isDark ? const Color(0x17EF9188) : const Color(0x139B302A);
  Color get surface =>
      isDark ? const Color(0xFF171A18) : const Color(0xFFFCFBF8);
  Color get border =>
      isDark ? const Color(0x21FFFFFF) : const Color(0x1F000000);

  TextStyle displayTitle(double size) {
    final base = TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w700,
      height: 1.05,
      letterSpacing: -0.02,
      color: ink,
    );
    return useSystemFonts
        ? base
        : GoogleFonts.cormorantGaramond(textStyle: base);
  }

  TextStyle body(double size, {String? family}) {
    final base = TextStyle(fontSize: size, height: 1.65, color: ink);
    if (useSystemFonts) return base;
    if (family == null || family == 'Сістэмны') {
      try {
        return GoogleFonts.literata(textStyle: base);
      } catch (_) {
        return base;
      }
    }
    try {
      return GoogleFonts.getFont(family, textStyle: base);
    } catch (_) {
      return base;
    }
  }

  TextStyle rubricStyle(double size, {String? family}) =>
      body(size, family: family).copyWith(
        color: rubric,
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w500,
      );

  TextStyle referenceStyle(double size, {String? family}) => body(
    size,
    family: family,
  ).copyWith(color: muted, fontWeight: FontWeight.w600, letterSpacing: 0.02);

  TextStyle majorHeading(double bodySize) => body(
    (bodySize * .98).clamp(15, double.infinity),
  ).copyWith(height: 1.3, fontWeight: FontWeight.w600);

  TextStyle blockHeading(double bodySize) => body(
    (bodySize * 1.10).clamp(18, double.infinity),
  ).copyWith(height: 1.3, color: rubric, fontWeight: FontWeight.w600);

  TextStyle metadata(double bodySize, {bool italic = false}) =>
      body((bodySize * .88).clamp(14, double.infinity)).copyWith(
        height: 1.45,
        color: muted,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      );

  TextStyle rubricBlock(double bodySize, {bool italic = false}) =>
      body((bodySize * .90).clamp(14, double.infinity)).copyWith(
        height: 1.45,
        color: rubric,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      );
}
