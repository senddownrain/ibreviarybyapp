import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:mybrev_flutter/models/prayer.dart';
import 'package:mybrev_flutter/theme/reader.dart';
import 'package:mybrev_flutter/theme/liturgical_document.dart';
import 'package:mybrev_flutter/utils/prayer_legacy_html.dart';
import 'package:mybrev_flutter/utils/prayer_markdown.dart';

/// One document surface for ordinary prayer reading and local editor preview.
/// Access checks belong to the containing screen, before constructing this.
class PrayerContent extends StatelessWidget {
  const PrayerContent({
    super.key,
    required this.prayer,
    required this.textStyle,
    this.onLinkTap,
    this.wrapInSelectionArea = true,
  });
  final Prayer prayer;
  final TextStyle textStyle;
  final OnTap? onLinkTap;

  /// Composed readers provide one selection region across their whole document.
  final bool wrapInSelectionArea;

  @override
  Widget build(BuildContext context) {
    final html = prayer.isMarkdown
        ? prayerMarkdownToHtml(prayer.displayText)
        : prayerMarkdownToHtml(prayerLegacyHtmlToMarkdown(prayer.displayText));
    final content = Html(
      data: html,
      style: prayerDocumentStyles(context, textStyle),
      onLinkTap: onLinkTap,
    );
    return wrapInSelectionArea ? SelectionArea(child: content) : content;
  }
}

Map<String, Style> prayerDocumentStyles(BuildContext context, TextStyle body) {
  final reader = ReaderTheme.of(context);
  final size = body.fontSize ?? 16;
  final heading = reader.blockHeading(size);
  final major = reader.majorHeading(size);
  return {
    'body': Style(
      fontSize: FontSize(size),
      fontFamily: body.fontFamily,
      fontWeight: body.fontWeight ?? FontWeight.normal,
      fontStyle: body.fontStyle ?? FontStyle.normal,
      color: body.color ?? reader.ink,
      lineHeight: LineHeight(ReaderTheme.bodyHeight),
      margin: Margins.zero,
      padding: HtmlPaddings.zero,
    ),
    'p': Style(margin: Margins.only(bottom: LiturgicalSpacing.paragraphAfter)),
    'a': Style(
      color: Theme.of(context).colorScheme.primary,
      textDecoration: TextDecoration.underline,
    ),
    'ul': Style(
      margin: Margins.symmetric(vertical: 10),
      padding: HtmlPaddings.only(left: 24),
    ),
    'ol': Style(
      margin: Margins.symmetric(vertical: 10),
      padding: HtmlPaddings.only(left: 24),
    ),
    for (var level = 1; level <= 6; level++)
      'h$level': Style(
        fontFamily: level <= 2 ? major.fontFamily : heading.fontFamily,
        fontSize: FontSize(level <= 2 ? major.fontSize! : heading.fontSize!),
        fontWeight: FontWeight.w700,
        color: reader.rubric,
        lineHeight: LineHeight(heading.height!),
        margin: Margins.only(
          top: LiturgicalSpacing.sectionBefore,
          bottom: LiturgicalSpacing.sectionTitleToBody,
        ),
      ),
    'blockquote': Style(
      margin: Margins.only(left: 12, bottom: LiturgicalSpacing.paragraphAfter),
      padding: HtmlPaddings.only(left: 12),
      border: Border(left: BorderSide(color: reader.border, width: 2)),
    ),
    '.prayer-speaker': Style(
      color: reader.rubric,
      fontWeight: FontWeight.w700,
      fontStyle: FontStyle.normal,
    ),
    '.prayer-rubric': readerRubricHtmlStyle(
      reader: reader,
      body: body,
      margin: Margins.symmetric(vertical: 8),
    )..padding = HtmlPaddings.zero,
    '.prayer-rubric p': readerRubricHtmlStyle(
      reader: reader,
      body: body,
      margin: Margins.only(bottom: LiturgicalSpacing.paragraphAfter),
    ),
    '.prayer-rubric em': Style(color: reader.rubric),
    '.psalm-marker': Style(color: reader.rubric, fontWeight: FontWeight.w600),
    '.liturgical-rubric-inline': Style(color: reader.rubric),
  };
}
