import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:mybrev_flutter/theme/reader.dart';

/// The same unspoken direction in HTML documents of different domains.
Style readerRubricHtmlStyle({
  required ReaderTheme reader,
  required TextStyle body,
  Margins? margin,
  TextAlign? textAlign,
}) {
  final rubric = reader.rubricBlock(body.fontSize ?? 16);
  return Style(
    color: rubric.color,
    fontFamily: body.fontFamily,
    fontSize: FontSize(rubric.fontSize!),
    lineHeight: LineHeight(rubric.height!),
    fontStyle: rubric.fontStyle,
    fontWeight: rubric.fontWeight,
    margin: margin,
    textAlign: textAlign,
  );
}

/// Keeps the visible block gap equal when the preceding source ends in an
/// antiphon (4 px paragraph tail) or directly in a psalm (8 px tail).
double psalmBlockSpacerAfter({required bool antiphon}) =>
    LiturgicalSpacing.psalmBlockToNext +
    LiturgicalSpacing.antiphonToPsalm -
    (antiphon
        ? LiturgicalSpacing.antiphonToPsalm
        : LiturgicalSpacing.paragraphAfter);

/// Shared HTML role styling for document surfaces. Screen renderers may add
/// structure-specific rules (choirs, intercessions), but roles live here.
Map<String, Style> liturgicalDocumentStyles({
  required ReaderTheme reader,
  required TextStyle body,
  double paragraphAfter = LiturgicalSpacing.paragraphAfter,
}) {
  final size = body.fontSize ?? 16;
  final heading = reader.blockHeading(size);
  final reference = reader.referenceStyle(size);
  final metadataSize = (size * .88).clamp(14, double.infinity).toDouble();
  return {
    'body': Style(
      fontSize: FontSize(size),
      fontFamily: body.fontFamily,
      fontWeight: body.fontWeight,
      color: body.color ?? reader.ink,
      lineHeight: LineHeight(body.height ?? ReaderTheme.bodyHeight),
      margin: Margins.zero,
      padding: HtmlPaddings.zero,
      textAlign: TextAlign.left,
    ),
    'p': Style(margin: Margins.only(bottom: paragraphAfter)),
    '.liturgical-heading': Style(
      fontFamily: heading.fontFamily,
      fontSize: FontSize(heading.fontSize!),
      lineHeight: LineHeight(heading.height!),
      color: reader.rubric,
      fontWeight: heading.fontWeight,
      fontStyle: FontStyle.normal,
      margin: Margins.only(bottom: LiturgicalSpacing.sectionTitleToBody),
    ),
    '.liturgical-service-heading': Style(
      fontSize: FontSize(metadataSize),
      lineHeight: LineHeight(ReaderTheme.metadataHeight),
      color: reader.rubric,
      fontWeight: FontWeight.normal,
      fontStyle: FontStyle.normal,
      margin: Margins.only(bottom: LiturgicalSpacing.metadataToBody),
    ),
    '.liturgical-reference': Style(
      fontSize: FontSize(metadataSize),
      lineHeight: LineHeight(ReaderTheme.referenceHeight),
      color: reader.rubric,
      fontWeight: FontWeight.w500,
      fontStyle: FontStyle.normal,
      margin: Margins.only(bottom: LiturgicalSpacing.metadataToBody),
    ),
    '.liturgical-subheading': Style(
      fontSize: FontSize(metadataSize),
      lineHeight: LineHeight(ReaderTheme.metadataHeight),
      color: reader.muted,
      margin: Margins.only(bottom: LiturgicalSpacing.metadataToBody),
    ),
    '.psalm-metadata': Style(textAlign: TextAlign.center),
    '.psalm-subtitle': Style(
      fontSize: FontSize(metadataSize),
      lineHeight: LineHeight(ReaderTheme.metadataHeight),
      color: reader.muted,
      fontStyle: FontStyle.italic,
      textAlign: TextAlign.center,
    ),
    '.office-reading-pericope-title': Style(
      fontSize: FontSize(metadataSize),
      lineHeight: LineHeight(ReaderTheme.metadataHeight),
      color: reader.rubric,
      fontStyle: FontStyle.normal,
    ),
    '.liturgical-rubric': readerRubricHtmlStyle(reader: reader, body: body),
    '.liturgical-rubric-inline': Style(color: reader.rubric),
    '.liturgical-reading-reference': Style(
      color: reference.color,
      fontFamily: body.fontFamily,
      fontSize: FontSize(reference.fontSize!),
      lineHeight: LineHeight(reference.height!),
      fontWeight: reference.fontWeight,
    ),
    '.psalm-marker': Style(color: reader.rubric, fontWeight: FontWeight.w600),
    '.responsory-turn': Style(margin: Margins.only(bottom: 3)),
  };
}

class LiturgicalSectionDivider extends StatelessWidget {
  const LiturgicalSectionDivider({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(
      top: LiturgicalSpacing.dividerBefore,
      bottom: LiturgicalSpacing.dividerAfter,
    ),
    child: Divider(
      height: 1,
      thickness: 0.5,
      color: ReaderTheme.of(context).border,
    ),
  );
}

/// A content heading owns the section gap only when no divider owns that
/// transition. The same title-to-body rhythm applies to both cases.
class LiturgicalSectionHeading extends StatelessWidget {
  const LiturgicalSectionHeading({
    super.key,
    required this.title,
    required this.bodySize,
    this.startsSection = false,
  });

  final String title;
  final double bodySize;
  final bool startsSection;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      top: startsSection ? LiturgicalSpacing.sectionBefore : 0,
      bottom: LiturgicalSpacing.sectionTitleToBody,
    ),
    child: Text(title, style: ReaderTheme.of(context).blockHeading(bodySize)),
  );
}

/// One header contract for short readings, including a narrow-width fallback.
class LiturgicalHeadingReferenceRow extends StatelessWidget {
  const LiturgicalHeadingReferenceRow({
    super.key,
    required this.title,
    required this.reference,
    required this.bodySize,
  });

  final String title;
  final String? reference;
  final double bodySize;

  @override
  Widget build(BuildContext context) {
    final reader = ReaderTheme.of(context);
    final titleStyle = reader.blockHeading(bodySize);
    final referenceStyle = reader.rubricReference(bodySize);
    final ref = reference;
    if (ref == null || ref.isEmpty) {
      return LiturgicalSectionHeading(title: title, bodySize: bodySize);
    }
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    double widthOf(String value, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: value, style: style),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    return Padding(
      padding: const EdgeInsets.only(
        bottom: LiturgicalSpacing.sectionTitleToBody,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fits =
              widthOf(title, titleStyle) + widthOf(ref, referenceStyle) + 12 <=
              constraints.maxWidth;
          final titleWidget = Text(title, style: titleStyle);
          final referenceWidget = Text(
            ref,
            style: referenceStyle,
            textAlign: TextAlign.right,
          );
          return fits
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(child: titleWidget),
                    const SizedBox(width: 12),
                    referenceWidget,
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    titleWidget,
                    Align(
                      alignment: Alignment.centerRight,
                      child: referenceWidget,
                    ),
                  ],
                );
        },
      ),
    );
  }
}
