import 'package:flutter/widgets.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' show parseFragment;

import 'be_hyphenator.dart';
import 'justified_hyphen_text.dart';
import 'lab_core.dart';

/// Which hyphenating renderer the merged logic picks for a prose block.
enum Hyph { b2, d }

/// The merged rule (stage 4): the saved alignment and the width/size decide
/// between B2 (justify + hyphenation) and D (left + hyphenation). The
/// adaptive switch is exactly the one shipped in #149 (≥ 36 characters per
/// line keeps justify); nothing else about the choice is new.
///
/// * saved "Па левым краі"                      → D
/// * saved "Па шырыні", enough characters/line  → B2
/// * saved "Па шырыні", narrow line / large type → D
Hyph finalChoice({
  required TextAlign saved,
  required double innerWidth,
  required TextStyle style,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  if (saved != TextAlign.justify) return Hyph.d;
  final scaled = style.copyWith(
    fontSize: textScaler.scale(style.fontSize ?? 16),
  );
  return innerWidth / averageAdvance(scaled) >= kJustifyMinCharsPerLine
      ? Hyph.b2
      : Hyph.d;
}

enum FinalKind { plain, markdown, html, psalmHtml }

/// Block type decides applicability (hyphenation only for prose).
enum BlockKind { prose, verse, rubric }

/// Legacy liturgical HTML paints rubrics with `color:#ff0000`; the app turns
/// those into the themed rubric class (see lib/utils/liturgical_html.dart).
String normalizeLegacyHtml(String html) => html.replaceAllMapped(
  RegExp(
    r'<span\s+style="[^"]*color\s*:\s*#ff0000;?[^"]*"\s*>',
    caseSensitive: false,
  ),
  (_) => '<span class="liturgical-rubric-inline">',
);

/// Verse/psalmody paragraphs (explicit line breaks, `*` / `†` cadence marks)
/// and rubric-only paragraphs are never hyphenated or re-wrapped.
BlockKind classifyBlock(dom.Element p) {
  final html = p.innerHtml;
  if (html.contains('<br') || html.contains('*') || html.contains('†')) {
    return BlockKind.verse;
  }
  var hasText = false;
  var allRubric = true;
  void visit(dom.Node n, bool inRubric) {
    if (n is dom.Text) {
      if (n.data.trim().isNotEmpty) {
        hasText = true;
        if (!inRubric) allRubric = false;
      }
      return;
    }
    final rubric =
        inRubric ||
        (n is dom.Element && n.classes.contains('liturgical-rubric-inline'));
    for (final c in n.nodes) {
      visit(c, rubric);
    }
  }

  visit(p, false);
  return hasText && allRubric ? BlockKind.rubric : BlockKind.prose;
}

/// Minimal "mybrev-markdown" → spans: `**bold**`, `_italic_`, `# heading`
/// (bold), blank line = paragraph break. The visible text never contains the
/// markers; no hyphens are ever added to it.
TextSpan markdownToSpan(String md, TextStyle base) {
  final paragraphs = md
      .replaceAll('\r', '')
      .split(RegExp(r'\n[ \t]*\n+'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();
  final marker = RegExp(r'\*\*(.+?)\*\*|(?<![\w])_(.+?)_(?![\w])');
  final children = <InlineSpan>[];
  for (var i = 0; i < paragraphs.length; i++) {
    var para = paragraphs[i];
    final heading = RegExp(r'^#+\s+').hasMatch(para);
    para = para.replaceFirst(RegExp(r'^#+\s+'), '');
    var pos = 0;
    final parts = <InlineSpan>[];
    for (final m in marker.allMatches(para)) {
      if (m.start > pos)
        parts.add(TextSpan(text: para.substring(pos, m.start)));
      if (m.group(1) != null) {
        parts.add(
          TextSpan(
            text: m.group(1),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        );
      } else {
        parts.add(
          TextSpan(
            text: m.group(2),
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
        );
      }
      pos = m.end;
    }
    if (pos < para.length) parts.add(TextSpan(text: para.substring(pos)));
    children.add(
      TextSpan(
        style: heading ? const TextStyle(fontWeight: FontWeight.w700) : null,
        children: parts,
      ),
    );
    if (i < paragraphs.length - 1) children.add(const TextSpan(text: '\n'));
  }
  return TextSpan(style: base, children: children);
}

/// The merged demo reading: prose → B2/D, everything else (psalmody, verses,
/// rubrics) → the stock renderer, unchanged.
class FinalReading extends StatelessWidget {
  const FinalReading({
    super.key,
    required this.kind,
    required this.text,
    required this.family,
    required this.scale,
    required this.palette,
    required this.hyphenator,
    this.saved = TextAlign.justify,
    this.title,
  });

  final FinalKind kind;
  final String text;
  final String family;
  final double scale;
  final LabPalette palette;
  final BelarusianHyphenator hyphenator;
  final TextAlign saved;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final base = bodyStyle(family, scale, palette);
    final scaler =
        MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling;
    return Container(
      color: palette.bg,
      padding: const EdgeInsets.symmetric(horizontal: gutter, vertical: 12),
      child: LayoutBuilder(
        builder: (context, c) {
          final choice = finalChoice(
            saved: saved,
            innerWidth: c.maxWidth,
            style: base,
            textScaler: scaler,
          );
          Widget prose(TextSpan span) => HyphenatedJustifiedText(
            text: span,
            hyphenator: hyphenator,
            justify: choice == Hyph.b2,
            textScaler: scaler,
          );
          final children = <Widget>[
            if (title != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  title!,
                  style: base.copyWith(
                    color: palette.rubric,
                    fontWeight: FontWeight.w600,
                    fontSize: base.fontSize! * 0.9,
                  ),
                ),
              ),
          ];
          switch (kind) {
            case FinalKind.plain:
              children.add(
                prose(
                  buildPlainSpan(
                    base,
                    palette,
                    text: text.replaceAll(RegExp(r'\r?\n[ \t]*\r?\n+'), '\n'),
                  ),
                ),
              );
            case FinalKind.markdown:
              children.add(prose(markdownToSpan(text, base)));
            case FinalKind.psalmHtml:
              children.add(_stock(normalizeLegacyHtml(text), base));
            case FinalKind.html:
              final fragment = parseFragment(normalizeLegacyHtml(text));
              final blocks = fragment.nodes
                  .whereType<dom.Element>()
                  .where((e) => e.localName == 'p')
                  .toList();
              for (var i = 0; i < blocks.length; i++) {
                final b = blocks[i];
                final isProse = classifyBlock(b) == BlockKind.prose;
                children.add(
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: i == blocks.length - 1 ? 0 : 8,
                    ),
                    child: isProse
                        ? prose(
                            htmlToParagraphSpans(
                              b.outerHtml,
                              base,
                              palette,
                            ).first,
                          )
                        : _stock(b.outerHtml, base),
                  ),
                );
              }
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: children,
          );
        },
      ),
    );
  }

  /// The existing (unchanged) renderer: flutter_html, left-aligned.
  Widget _stock(String html, TextStyle base) => Html(
    data: html,
    style: {
      'body': Style(
        margin: Margins.zero,
        padding: HtmlPaddings.zero,
        fontFamily: base.fontFamily,
        fontSize: FontSize(base.fontSize!),
        lineHeight: LineHeight(bodyHeight),
        color: palette.ink,
        textAlign: TextAlign.left,
      ),
      'p': Style(margin: Margins.only(bottom: 8)),
      '.liturgical-rubric-inline': Style(color: palette.rubric),
    },
  );
}

/// Top-level `<p>` elements of an HTML fragment (helper shared with tests).
List<dom.Element> parseFragmentElements(String html) => parseFragment(
  html,
).nodes.whereType<dom.Element>().where((e) => e.localName == 'p').toList();
