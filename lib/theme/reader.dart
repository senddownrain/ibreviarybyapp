import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mybrev_flutter/theme/ib_colors.dart';

/// Persisted reader-family identifiers. User-facing labels live in Settings;
/// storage keys stay language-neutral and must not be passed to Google Fonts.
abstract final class ReaderFontFamily {
  static const literata = 'literata';
  static const system = 'system';
  static const sourceSerif4 = 'sourceSerif4';
  static const oldStandardTt = 'oldStandardTt';
  static const kurale = 'kurale';
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
  const ReaderTheme._(this.isDark, this.useSystemFonts, this.colors);

  static const double bodyHeight = 1.68;
  static const double hymnHeight = 1.72;
  static const double responsoryHeight = 1.48;
  static const double referenceHeight = 1.40;
  static const double rubricHeight = 1.48;
  static const double metadataHeight = 1.42;
  static const double headingHeight = 1.28;
  static const double documentTitleSize = 33;

  factory ReaderTheme.of(BuildContext context) => ReaderTheme._(
    Theme.of(context).brightness == Brightness.dark,
    ReaderTypographyScope.useSystemFontsOf(context),
    IbColors.of(context),
  );

  final bool isDark;
  final bool useSystemFonts;
  final IbColors colors;

  Color get ink => colors.ink;
  Color get muted => colors.readerMuted;
  Color get rubric => colors.rubric;
  Color get rubricSoft =>
      colors.rubric.withValues(alpha: isDark ? 0x17 / 255 : 0x13 / 255);
  Color get surface => colors.reader;
  Color get border => colors.separator;

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

  /// A document title is fixed to the page scale, independent of reader Aa.
  TextStyle documentTitle() =>
      displayTitle(documentTitleSize).copyWith(height: 1.12);

  TextStyle body(double size, {String? family}) {
    final base = TextStyle(fontSize: size, height: bodyHeight, color: ink);
    if (useSystemFonts) return base;
    try {
      return switch (family) {
        ReaderFontFamily.system => base,
        ReaderFontFamily.sourceSerif4 => GoogleFonts.sourceSerif4(
          textStyle: base,
        ),
        ReaderFontFamily.oldStandardTt => GoogleFonts.oldStandardTt(
          textStyle: base,
        ),
        ReaderFontFamily.kurale => GoogleFonts.kurale(textStyle: base),
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
        fontStyle: FontStyle.normal,
        fontWeight: FontWeight.w400,
        height: rubricHeight,
      );

  TextStyle referenceStyle(double size, {String? family}) =>
      body(size, family: family).copyWith(
        color: muted,
        fontWeight: FontWeight.w600,
        height: referenceHeight,
        letterSpacing: 0.02,
      );

  TextStyle majorHeading(double bodySize) {
    final heading = blockHeading(bodySize);
    return heading.copyWith(fontSize: heading.fontSize! * 1.12);
  }

  /// Content heading, shared by Hours, Mass, Readings and document readers.
  /// The title face has a smaller x-height than the reader body, so its scale
  /// and line height are chosen together rather than copied from Literata.
  TextStyle blockHeading(double bodySize) {
    final base = TextStyle(
      fontSize: (bodySize * 1.42).clamp(22, double.infinity),
      height: 1.12,
      color: rubric,
      fontWeight: FontWeight.w700,
    );
    return useSystemFonts
        ? base
        : GoogleFonts.cormorantGaramond(textStyle: base);
  }

  /// Compact uppercase heading in the Liturgy of the Hours (112% of the body).
  /// The shared document headings elsewhere retain their established scale.
  TextStyle hourSectionHeading(double bodySize) =>
      blockHeading(bodySize).copyWith(
        fontSize: bodySize * 1.12,
        letterSpacing: bodySize * 0.04,
      );

  /// Section label on the Mass readings page (108% of the body).
  TextStyle readingsSectionHeading(double bodySize) =>
      blockHeading(bodySize).copyWith(
        fontSize: bodySize * 1.08,
        letterSpacing: bodySize * 0.065,
      );

  /// The Scripture/Gospel introduction is prose, not an uppercase section.
  TextStyle readingIntroduction(TextStyle bodyStyle) => bodyStyle.copyWith(
    fontSize: (bodyStyle.fontSize ?? 16) * 1.04,
    fontWeight: FontWeight.w700,
  );

  TextStyle serviceHeading(double bodySize, {String? family}) => body(
    bodySize * .88,
    family: family,
  ).copyWith(color: rubric, height: metadataHeight);

  TextStyle rubricReference(double bodySize, {String? family}) =>
      serviceHeading(
        bodySize,
        family: family,
      ).copyWith(fontWeight: FontWeight.w500);

  TextStyle metadata(double bodySize, {bool italic = false, String? family}) =>
      body(bodySize * .88, family: family).copyWith(
        height: metadataHeight,
        color: muted,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      );

  TextStyle sourceStyle(double bodySize, {String? family}) =>
      metadata(bodySize, family: family);

  /// Psalm explanations share the Hours scale and follow the full Aa range.
  TextStyle psalmSubtitle(double bodySize, {String? family}) => metadata(
    bodySize,
    italic: true,
    family: family,
  ).copyWith(fontSize: bodySize * .76);

  TextStyle rubricBlock(double bodySize, {String? family}) =>
      rubricStyle((bodySize * .90).clamp(14, double.infinity), family: family);
}

/// Vertical relationships belong to semantic roles, not individual hours.
abstract final class LiturgicalSpacing {
  static const sectionBefore = 24.0;
  static const sectionTitleToBody = 8.0;
  static const paragraphAfter = 8.0;
  static const hymnStropheAfter = 15.0;
  static const responsoryTurnAfter = 2.0;
  static const intercessionIntroAfter = 13.0;
  static const intercessionRefrainAfter = 22.0;
  static const intercessionPetitionBefore = 18.0;
  static const intercessionPetitionAfter = 5.0;
  static const intercessionResponseInset = 12.0;
  static const intercessionResponseAfter = 15.0;
  static const intercessionConclusionBefore = 22.0;
  static const antiphonToPsalm = 4.0;
  static const psalmBlockToNext = 12.0;
  static const metadataToBody = 7.0;
  static const dividerBefore = 22.0;
  static const dividerAfter = 21.0;
  static const plainTextAfter = 12.0;
}
