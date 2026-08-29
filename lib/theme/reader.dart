import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Reader typography and surfaces (mirrors web `--reader-*` tokens).
class ReaderTheme {
  const ReaderTheme._(this.isDark);

  factory ReaderTheme.of(BuildContext context) =>
      ReaderTheme._(Theme.of(context).brightness == Brightness.dark);

  final bool isDark;

  Color get ink => isDark ? const Color(0xFFEEEAE2) : const Color(0xFF211F1B);
  Color get muted => isDark ? const Color(0xFFAAA49B) : const Color(0xFF756E64);
  Color get rubric => isDark ? const Color(0xFFEF9188) : const Color(0xFF9B302A);
  Color get rubricSoft =>
      isDark ? const Color(0x17EF9188) : const Color(0x139B302A);
  Color get surface =>
      isDark ? const Color(0xE81D1D1F) : const Color(0xE8FFFEFA);
  Color get border =>
      isDark ? const Color(0x21F4EDE1) : const Color(0x1F504232);

  TextStyle displayTitle(double size) => GoogleFonts.cormorantGaramond(
        fontSize: size,
        fontWeight: FontWeight.w700,
        height: 1.05,
        letterSpacing: -0.02,
        color: ink,
      );

  TextStyle body(double size, {String? family}) {
    final base = TextStyle(fontSize: size, height: 1.65, color: ink);
    if (family == null || family == 'Сістэмны') {
      return GoogleFonts.literata(textStyle: base);
    }
    return GoogleFonts.getFont(family, textStyle: base);
  }

  TextStyle rubricStyle(double size, {String? family}) => body(size, family: family).copyWith(
        color: rubric,
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w500,
      );

  TextStyle referenceStyle(double size, {String? family}) =>
      body(size, family: family).copyWith(
        color: muted,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.02,
      );
}
