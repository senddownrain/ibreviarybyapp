import 'package:flutter/gestures.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' show parseFragment;

import 'be_hyphenator.dart';
import 'fixtures.dart';

/// A: stock Flutter justify, no hyphenation (control = today's app).
/// AD: the safe app change — stock renderer, justify only while the line holds
///     at least [kJustifyMinCharsPerLine] characters, otherwise left.
/// B1: stock Flutter + U+00AD soft hyphens inserted from be patterns.
/// B2: alternative single-paragraph renderer (own line breaking + painted
///     hyphens), source text untouched.
/// C: stock Flutter, left-aligned (readability control only).
enum Mode {
  a('A', 'justify · без пераносаў (кантроль)'),
  b1('B1', 'justify + U+00AD (стандартны рэндэрар)'),
  b2('B2', 'justify + пераносы (свой рэндэрар)'),
  c('C', 'left · без пераносаў (кантроль)'),
  d('D', 'left + пераносы (свой рэндэрар)'),
  ad('AD', 'адаптыўнае: justify, а на вузкім — left (стандартны)');

  const Mode(this.tag, this.label);
  final String tag;
  final String label;
}

enum Scenario { plain, highlight, html }

/// Same constant/rule as lib/utils/reading_alignment.dart in the app.
const kJustifyMinCharsPerLine = 36.0;

TextAlign adaptiveAlignment(double innerWidth, TextStyle style) =>
    innerWidth / averageAdvance(style) >= kJustifyMinCharsPerLine
    ? TextAlign.justify
    : TextAlign.left;

const readerFonts = ['Literata', 'SourceSerif4', 'OldStandardTT', 'Kurale'];

/// Reader palette copied from lib/theme/ib_colors.dart (light/dark).
class LabPalette {
  const LabPalette({
    required this.bg,
    required this.ink,
    required this.rubric,
    required this.muted,
    required this.dark,
  });
  final Color bg, ink, rubric, muted;
  final bool dark;

  static const light = LabPalette(
    bg: Color(0xFFFDFCF9),
    ink: Color(0xFF20211F),
    rubric: Color(0xFF9B302A),
    muted: Color(0xFF62645F),
    dark: false,
  );
  static const darkTheme = LabPalette(
    bg: Color(0xFF171917),
    ink: Color(0xFFE9ECE7),
    rubric: Color(0xFFEF9188),
    muted: Color(0xFFAEB3AB),
    dark: true,
  );
}

/// App values: base reader size 16 dp, scale 0.7–1.8 (settings_provider.dart),
/// ReaderTheme.bodyHeight = 1.68, content gutter 16 dp on each side.
const baseReaderSize = 16.0;
const bodyHeight = 1.68;
const gutter = 16.0;

TextStyle bodyStyle(String family, double scale, LabPalette p) => TextStyle(
  fontFamily: family,
  fontSize: baseReaderSize * scale,
  height: bodyHeight,
  color: p.ink,
);

// ---------------------------------------------------------------------------
// Span builders (shared by A, B1, B2, C so that the text is byte-identical).
// ---------------------------------------------------------------------------

class SentencePart {
  const SentencePart(this.text, this.index);
  final String text;
  final int index;
}

/// Same idea as `_splitReadingSentences` in readings_screen.dart.
List<SentencePart> splitSentences(String text) {
  final out = <SentencePart>[];
  final boundary = RegExp(r'[.!?…]+[»”’\)\]]*\s+');
  var start = 0;
  var i = 0;
  for (final m in boundary.allMatches(text)) {
    final before = text.substring(start, m.end).trimRight();
    final last = RegExp(r'([А-ЯЁІЎа-яёіўA-Za-z]+)\.$').firstMatch(before);
    final abbr = last?.group(1)?.toLowerCase();
    if (abbr != null &&
        const {'гл', 'напр', 'пар', 'мц', 'мк', 'лк'}.contains(abbr)) {
      continue;
    }
    out.add(SentencePart(text.substring(start, m.end), i++));
    start = m.end;
  }
  if (start < text.length) out.add(SentencePart(text.substring(start), i));
  return out;
}

/// The plain-text reading as one rich span (what `_ReadingText` builds).
/// With [highlight] sentence 1 gets a marker background and sentence 3 the
/// "selected" underline, as in the app.
TextSpan buildPlainSpan(
  TextStyle base,
  LabPalette p, {
  bool highlight = false,
  List<GestureRecognizer>? recognizers,
  String? text,
}) {
  text ??= plainParagraphs.join('\n');
  final sentences = splitSentences(text);
  return TextSpan(
    style: base,
    children: [
      for (final s in sentences)
        TextSpan(
          style: highlight && s.index == 1
              ? TextStyle(
                  backgroundColor: const Color(
                    0xFFE2AE34,
                  ).withValues(alpha: p.dark ? 0.32 : 0.30),
                )
              : highlight && s.index == 3
              ? TextStyle(
                  decoration: TextDecoration.underline,
                  decorationColor: const Color(0xFF3F6E8C),
                  decorationThickness: 1.5,
                  backgroundColor: const Color(
                    0xFF3F6E8C,
                  ).withValues(alpha: 0.18),
                )
              : null,
          children: [
            for (final piece in s.text.split(RegExp(r'(?=[*†])|(?<=[*†])')))
              TextSpan(
                text: piece,
                recognizer: highlight
                    ? (TapGestureRecognizer()..onTap = () {})
                    : null,
                style: piece == '*' || piece == '†'
                    ? TextStyle(color: p.rubric, fontWeight: FontWeight.w600)
                    : null,
              ),
          ],
        ),
    ],
  );
}

// ---------------------------------------------------------------------------
// B1: soft hyphens from the Belarusian patterns, applied to a span tree.
// ---------------------------------------------------------------------------

const softHyphen = '­';

String insertSoftHyphens(String text, BelarusianHyphenator h) =>
    text.replaceAllMapped(RegExp(r"[А-Яа-яЁёІіЎўЬьЫыЭэ'’ʼ\-]{6,}"), (m) {
      final word = m.group(0)!;
      final pts = h.hyphenationPoints(word);
      if (pts.isEmpty) return word;
      final b = StringBuffer();
      for (var i = 0; i < word.length; i++) {
        if (pts.contains(i) && word[i - 1] != '-') b.write(softHyphen);
        b.write(word[i]);
      }
      return b.toString();
    });

InlineSpan mapSpanText(InlineSpan span, String Function(String) f) {
  if (span is! TextSpan) return span;
  return TextSpan(
    text: span.text == null ? null : f(span.text!),
    style: span.style,
    recognizer: span.recognizer,
    children: span.children?.map((c) => mapSpanText(c, f)).toList(),
  );
}

String insertSoftHyphensInHtml(String html, BelarusianHyphenator h) {
  final fragment = parseFragment(html);
  void walk(dom.Node n) {
    if (n is dom.Text) n.data = insertSoftHyphens(n.data, h);
    for (final c in n.nodes) {
      walk(c);
    }
  }

  walk(fragment);
  return fragment.outerHtml;
}

// ---------------------------------------------------------------------------
// HTML → one TextSpan per <p> (for the B2 renderer). The paragraph stays ONE
// span tree: nothing is cut between tags.
// ---------------------------------------------------------------------------

List<TextSpan> htmlToParagraphSpans(
  String html,
  TextStyle base,
  LabPalette p, {
  List<GestureRecognizer>? recognizers,
}) {
  final fragment = parseFragment(html);
  final out = <TextSpan>[];

  InlineSpan inline(dom.Node n) {
    if (n is dom.Text) {
      return TextSpan(text: n.data.replaceAll(RegExp(r'[ \t\r\n]+'), ' '));
    }
    if (n is dom.Element) {
      final kids = n.nodes.map(inline).toList();
      switch (n.localName) {
        case 'em' || 'i':
          return TextSpan(
            style: const TextStyle(fontStyle: FontStyle.italic),
            children: kids,
          );
        case 'strong' || 'b':
          return TextSpan(
            style: const TextStyle(fontWeight: FontWeight.w700),
            children: kids,
          );
        case 'a':
          final rec = TapGestureRecognizer()..onTap = () {};
          recognizers?.add(rec);
          return TextSpan(
            style: TextStyle(
              color: p.dark ? const Color(0xFF8FB8D4) : const Color(0xFF2F5F7E),
              decoration: TextDecoration.underline,
            ),
            recognizer: rec,
            children: kids,
          );
        case 'br':
          return const TextSpan(text: '\n');
        case 'span' when n.classes.contains('liturgical-rubric-inline'):
          return TextSpan(
            style: TextStyle(color: p.rubric),
            children: kids,
          );
        default:
          return TextSpan(children: kids);
      }
    }
    return const TextSpan();
  }

  for (final n in fragment.nodes) {
    if (n is dom.Element && n.localName == 'p') {
      final spans = n.nodes.map(inline).toList();
      // Trim HTML-collapsed leading/trailing space of the paragraph.
      out.add(TextSpan(style: base, children: spans));
    }
  }
  return out;
}

// ---------------------------------------------------------------------------
// Metrics for the stock renderer (A, B1, C): justify never changes line
// breaking, so a left-aligned TextPainter yields the same lines.
// ---------------------------------------------------------------------------

class LineStat {
  LineStat(this.text, this.natural, this.spaces, this.isLast, this.hyphen);
  final String text;
  final double natural;
  final int spaces;
  final bool isLast;
  final bool hyphen;
}

class LabMetrics {
  LabMetrics({
    required this.width,
    required this.spaceWidth,
    required this.lines,
    required this.justified,
  });
  final double width;
  final double spaceWidth;
  final List<LineStat> lines;
  final bool justified;

  Iterable<LineStat> get body => lines.where((l) => !l.isLast);

  /// Stretch of a justified line in multiples of a normal space.
  double stretch(LineStat l) => l.spaces == 0
      ? double.infinity
      : (width - l.natural) / (l.spaces * spaceWidth);

  int get lineCount => lines.length;
  int get loose => justified
      ? body.where((l) => l.spaces > 0 && stretch(l) > 1.0).length
      : 0;
  int get veryLoose => justified
      ? body.where((l) => l.spaces > 0 && stretch(l) > 2.0).length
      : 0;
  int get singleWord =>
      body.where((l) => l.spaces == 0 && l.natural < width * 0.8).length;
  int get hyphenLines => lines.where((l) => l.hyphen).length;
  int get consecutiveHyphen {
    var n = 0;
    for (var i = 1; i < lines.length; i++) {
      if (lines[i].hyphen && lines[i - 1].hyphen) n++;
    }
    return n;
  }

  double get maxStretch {
    final s = body.where((l) => l.spaces > 0).map(stretch);
    return s.isEmpty ? 0 : s.reduce((a, b) => a > b ? a : b);
  }

  double get meanStretch {
    final s = body.where((l) => l.spaces > 0).map(stretch).toList();
    return s.isEmpty ? 0 : s.reduce((a, b) => a + b) / s.length;
  }

  /// Ragged-right slack of non-final lines as a fraction of the width.
  double get meanSlack {
    final s = body.map((l) => (width - l.natural) / width).toList();
    return s.isEmpty ? 0 : s.reduce((a, b) => a + b) / s.length;
  }

  int get shortRagged =>
      body.where((l) => (width - l.natural) / width > 0.25).length;

  /// ONE bad-line flag per line (never summed from overlapping categories):
  /// justified → the gap is more than 2× a normal space (stretch > 1) or the
  /// line is a lone word that does not fill the measure; left → the line is
  /// short by more than 25 % of the measure. Counts are only comparable
  /// *within* the same alignment family (justify: A vs B2; left: C vs D).
  /// Stretch (in normal spaces) above which a justified gap counts as bad:
  /// 2.0 = the gap is 3× a normal space (≈ 0.6 em in these fonts). `loose`
  /// (> 1.0, gap 2×) is reported separately as a softer signal.
  static const badStretch = 2.0;

  bool isBad(LineStat l) => justified
      ? (l.spaces == 0 ? l.natural < width * 0.8 : stretch(l) > badStretch)
      : (width - l.natural) / width > 0.25;

  int get bad => body.where(isBad).length;

  double get looseShare => !justified || body.isEmpty ? 0 : loose / body.length;

  /// Fraction of non-final lines that are bad (0 when there are none).
  double get badShare => body.isEmpty ? 0 : bad / body.length;
}

/// Average advance of one Belarusian letter (incl. spaces) in [style], used to
/// express a column width as "characters per line" independently of font/scale.
double averageAdvance(TextStyle style) {
  const sample =
      'Умілаваныя, цяпер мы дзеці Божыя, але яшчэ не выявілася, чым будзем. '
      'Ведаем, што калі адкрыецца, мы будзем падобныя да Яго.';
  final tp = TextPainter(
    text: TextSpan(text: sample, style: style),
    textDirection: TextDirection.ltr,
  )..layout();
  return tp.width / sample.length;
}

LabMetrics measureStock(
  InlineSpan span,
  double width, {
  required bool justified,
  required TextStyle base,
}) {
  final tp = TextPainter(
    text: span,
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.left,
  )..layout(maxWidth: width);
  return measureLines(
    plain: span.toPlainText(includeSemanticsLabels: false),
    width: width,
    lineCount: tp.computeLineMetrics().length,
    lineBoundary: (o) => tp.getLineBoundary(TextPosition(offset: o)).end,
    boxes: (a, b) =>
        tp.getBoxesForSelection(TextSelection(baseOffset: a, extentOffset: b)),
    justified: justified,
    base: base,
  );
}

/// Same, but straight from a live [RenderParagraph] (needed for flutter_html,
/// whose spans contain WidgetSpans that a fresh TextPainter cannot lay out).
LabMetrics measureRender(
  RenderParagraph rp, {
  required bool justified,
  required TextStyle base,
}) {
  final plain = rp.text.toPlainText();
  final all = rp.getBoxesForSelection(
    TextSelection(baseOffset: 0, extentOffset: plain.length),
  );
  // Group boxes into visual lines by their top edge.
  final tops = <double>[];
  for (final b in all) {
    if (!tops.any((t) => (t - b.top).abs() < 1)) tops.add(b.top);
  }
  tops.sort();
  final starts = <int>[
    for (final t in tops) rp.getPositionForOffset(Offset(-1, t + 2)).offset,
  ];
  return measureLines(
    plain: plain,
    width: rp.size.width,
    lineCount: tops.length,
    lineBoundary: (o) {
      final k = starts.indexWhere((s) => s > o);
      return k < 0 ? plain.length : starts[k];
    },
    boxes: (a, b) =>
        rp.getBoxesForSelection(TextSelection(baseOffset: a, extentOffset: b)),
    justified: justified,
    base: base,
  );
}

LabMetrics measureLines({
  required String plain,
  required double width,
  required int lineCount,
  required int Function(int) lineBoundary,
  required List<TextBox> Function(int, int) boxes,
  required bool justified,
  required TextStyle base,
}) {
  final space = TextPainter(
    text: TextSpan(text: ' ', style: base),
    textDirection: TextDirection.ltr,
  )..layout();
  final lines = <LineStat>[];
  var start = 0;
  for (var guard = 0; start < plain.length && guard < 100000; guard++) {
    // A hard '\n' is not part of any line: skip it (empty lines add nothing).
    if (plain[start] == '\n') {
      start++;
      continue;
    }
    final end = lineBoundary(start);
    if (end <= start) break;
    var trimmed = end;
    while (trimmed > start &&
        (plain[trimmed - 1] == ' ' || plain[trimmed - 1] == '\n')) {
      trimmed--;
    }
    final raw = plain.substring(start, trimmed);
    // Natural (unstretched) width = sum of word widths + normal spaces, so a
    // live *justified* RenderParagraph is measured as if it were left-aligned.
    var nat = 0.0;
    var spaces = 0;
    var firstWord = true;
    for (final w in RegExp(r'[^ \n]+').allMatches(raw)) {
      final b = boxes(start + w.start, start + w.end);
      if (b.isEmpty) continue;
      nat +=
          b.map((x) => x.right).reduce((a, c) => a > c ? a : c) -
          b.map((x) => x.left).reduce((a, c) => a < c ? a : c);
      if (!firstWord) {
        spaces++;
        nat += space.width;
      }
      firstWord = false;
    }
    final isLast =
        end >= plain.length || plain[end] == '\n' || plain[end - 1] == '\n';
    lines.add(LineStat(raw, nat, spaces, isLast, raw.endsWith(softHyphen)));
    start = end;
  }
  return LabMetrics(
    width: width,
    spaceWidth: space.width,
    lines: lines,
    justified: justified,
  );
}
