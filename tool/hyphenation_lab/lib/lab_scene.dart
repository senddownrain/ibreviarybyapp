import 'package:flutter/widgets.dart';
import 'package:flutter_html/flutter_html.dart';

import 'be_hyphenator.dart';
import 'fixtures.dart';
import 'justified_hyphen_text.dart';
import 'lab_core.dart';

/// One reading rendered in one mode. Everything the A/B/C comparison needs to
/// hold constant (text, palette, width, font, scale) is a constructor argument.
class LabReading extends StatelessWidget {
  const LabReading({
    super.key,
    required this.mode,
    required this.scenario,
    required this.family,
    required this.scale,
    required this.palette,
    required this.hyphenator,
    this.plainText,
    this.htmlText,
    this.title,
  });

  final Mode mode;
  final Scenario scenario;
  final String family;
  final double scale;
  final LabPalette palette;
  final BelarusianHyphenator hyphenator;

  /// Real reading text (plain/HTML) instead of the built-in fixtures.
  final String? plainText;
  final String? htmlText;

  /// Heading above the text (defaults to the fixture's "Тыт 2, 1–5").
  final String? title;

  @override
  Widget build(BuildContext context) {
    final base = bodyStyle(family, scale, palette);
    final heading = Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title ?? fixtureTitle,
        style: base.copyWith(
          color: palette.rubric,
          fontWeight: FontWeight.w600,
          fontSize: base.fontSize! * 0.9,
        ),
      ),
    );
    return Container(
      color: palette.bg,
      padding: const EdgeInsets.symmetric(horizontal: gutter, vertical: 12),
      child: LayoutBuilder(
        builder: (context, c) {
          final align = switch (mode) {
            Mode.c || Mode.d => TextAlign.left,
            Mode.ad => adaptiveAlignment(c.maxWidth, base),
            _ => TextAlign.justify,
          };
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              heading,
              scenario == Scenario.html
                  ? _html(context, base, align)
                  : _plain(context, base, align),
            ],
          );
        },
      ),
    );
  }

  Widget _plain(BuildContext context, TextStyle base, TextAlign align) {
    var span = buildPlainSpan(
      base,
      palette,
      highlight: scenario == Scenario.highlight,
      text: plainText,
    );
    switch (mode) {
      case Mode.a:
      case Mode.c:
      case Mode.ad:
        return Text.rich(span, textAlign: align);
      case Mode.b1:
        span =
            mapSpanText(span, (t) => insertSoftHyphens(t, hyphenator))
                as TextSpan;
        return Text.rich(span, textAlign: align);
      case Mode.b2:
      case Mode.d:
        return HyphenatedJustifiedText(
          text: span,
          hyphenator: hyphenator,
          justify: mode == Mode.b2,
          textScaler:
              MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling,
        );
    }
  }

  Widget _html(BuildContext context, TextStyle base, TextAlign align) {
    final html = htmlText ?? htmlFixture;
    if (mode == Mode.b2 || mode == Mode.d) {
      final paras = htmlToParagraphSpans(html, base, palette);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < paras.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == paras.length - 1 ? 0 : 8),
              child: HyphenatedJustifiedText(
                text: paras[i],
                hyphenator: hyphenator,
                justify: mode == Mode.b2,
                textScaler:
                    MediaQuery.maybeTextScalerOf(context) ??
                    TextScaler.noScaling,
              ),
            ),
        ],
      );
    }
    final data = mode == Mode.b1
        ? insertSoftHyphensInHtml(html, hyphenator)
        : html;
    return Html(
      data: data,
      style: {
        'body': Style(
          margin: Margins.zero,
          padding: HtmlPaddings.zero,
          fontFamily: base.fontFamily,
          fontSize: FontSize(base.fontSize!),
          lineHeight: LineHeight(bodyHeight),
          color: palette.ink,
          textAlign: align,
        ),
        'p': Style(margin: Margins.only(bottom: 8), textAlign: align),
        'a': Style(
          color: palette.dark
              ? const Color(0xFF8FB8D4)
              : const Color(0xFF2F5F7E),
        ),
        '.liturgical-rubric-inline': Style(color: palette.rubric),
      },
    );
  }
}
