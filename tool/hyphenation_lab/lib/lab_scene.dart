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
  });

  final Mode mode;
  final Scenario scenario;
  final String family;
  final double scale;
  final LabPalette palette;
  final BelarusianHyphenator hyphenator;

  TextAlign get _align => mode == Mode.c ? TextAlign.left : TextAlign.justify;

  @override
  Widget build(BuildContext context) {
    final base = bodyStyle(family, scale, palette);
    final title = Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        fixtureTitle,
        style: base.copyWith(
          color: palette.rubric,
          fontWeight: FontWeight.w600,
          fontSize: base.fontSize! * 0.9,
        ),
      ),
    );
    final Widget body = scenario == Scenario.html ? _html(base) : _plain(base);
    return Container(
      color: palette.bg,
      padding: const EdgeInsets.symmetric(horizontal: gutter, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [title, body],
      ),
    );
  }

  Widget _plain(TextStyle base) {
    var span = buildPlainSpan(
      base,
      palette,
      highlight: scenario == Scenario.highlight,
    );
    switch (mode) {
      case Mode.a:
      case Mode.c:
        return Text.rich(span, textAlign: _align);
      case Mode.b1:
        span =
            mapSpanText(span, (t) => insertSoftHyphens(t, hyphenator))
                as TextSpan;
        return Text.rich(span, textAlign: _align);
      case Mode.b2:
        return HyphenatedJustifiedText(text: span, hyphenator: hyphenator);
    }
  }

  Widget _html(TextStyle base) {
    if (mode == Mode.b2) {
      final paras = htmlToParagraphSpans(htmlFixture, base, palette);
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
              ),
            ),
        ],
      );
    }
    final data = mode == Mode.b1
        ? insertSoftHyphensInHtml(htmlFixture, hyphenator)
        : htmlFixture;
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
          textAlign: _align,
        ),
        'p': Style(margin: Margins.only(bottom: 8), textAlign: _align),
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
