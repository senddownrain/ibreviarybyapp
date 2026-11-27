import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:mybrev_flutter/models/prayer.dart';
import 'package:mybrev_flutter/theme/reader.dart';
import 'package:mybrev_flutter/theme/liturgical_document.dart';
import 'package:mybrev_flutter/utils/prayer_legacy_html.dart';
import 'package:mybrev_flutter/utils/prayer_markdown.dart';
import 'package:mybrev_flutter/widgets/hyphenated_prose.dart';

/// One document surface for ordinary prayer reading and local editor preview.
/// Access checks belong to the containing screen, before constructing this.
class PrayerContent extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final alignment = ref.watch(
      settingsProvider.select((s) => s.textAlignment),
    );
    final html = prayer.isMarkdown
        ? prayerMarkdownToHtml(prayer.displayText)
        : prayerMarkdownToHtml(prayerLegacyHtmlToMarkdown(prayer.displayText));
    // Running-text paragraphs get Belarusian hyphenation (B2/D, adaptive);
    // headings, lists, quotes, rubrics and verse stay with the stock renderer.
    final body = HyphenatedHtml(
      data: html,
      style: prayerDocumentStyles(context, textStyle, textAlignment: alignment),
      selected: alignment,
      onLinkTap: onLinkTap,
    );
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        body,
        PrayerSourceNote(source: prayer.source, textStyle: textStyle),
        PrayerPagesNote(
          pages: prayer.pages,
          textStyle: textStyle,
          topSpacing: prayer.source?.trim().isNotEmpty == true ? 6 : 16,
        ),
      ],
    );
    return wrapInSelectionArea ? SelectionArea(child: content) : content;
  }
}

Map<String, Style> prayerDocumentStyles(
  BuildContext context,
  TextStyle body, {
  TextAlign textAlignment = TextAlign.justify,
}) {
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
      textAlign: textAlignment,
      margin: Margins.zero,
      padding: HtmlPaddings.zero,
    ),
    'p': Style(
      margin: Margins.only(bottom: LiturgicalSpacing.paragraphAfter),
      textAlign: textAlignment,
    ),
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
      textAlign: TextAlign.left,
    )..padding = HtmlPaddings.zero,
    '.prayer-rubric p': readerRubricHtmlStyle(
      reader: reader,
      body: body,
      margin: Margins.only(bottom: LiturgicalSpacing.paragraphAfter),
      textAlign: TextAlign.left,
    ),
    '.prayer-rubric em': Style(color: reader.rubric),
    '.psalm-marker': Style(color: reader.rubric, fontWeight: FontWeight.w600),
    '.liturgical-rubric-inline': Style(color: reader.rubric),
  };
}

/// Optional, unobtrusive printed page reference at the end of the prayer.
class PrayerPagesNote extends StatelessWidget {
  const PrayerPagesNote({
    super.key,
    this.pages,
    required this.textStyle,
    this.topSpacing = 16,
  });

  final String? pages;
  final TextStyle textStyle;
  final double topSpacing;

  @override
  Widget build(BuildContext context) {
    final value = pages?.trim() ?? '';
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: topSpacing),
      child: Text(
        value,
        key: const Key('prayer-pages'),
        style: textStyle.copyWith(
          fontSize: ((textStyle.fontSize ?? 16) * 0.75)
              .clamp(11.0, 16.0)
              .toDouble(),
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          height: 1.35,
        ),
      ),
    );
  }
}

/// Displays the server's canonical value; the shared registry lives in MyBrev /sources.
class PrayerSourceNote extends StatelessWidget {
  const PrayerSourceNote({super.key, this.source, required this.textStyle});
  final String? source;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    if (source == null || source!.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Text(
        'Крыніца: ${source!.trim()}',
        key: const Key('prayer-source'),
        style: textStyle.copyWith(
          fontSize: (textStyle.fontSize ?? 16) * 0.8,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
