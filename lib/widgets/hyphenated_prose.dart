import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' show parseFragment;

import 'package:mybrev_flutter/hyphenation/be_hyphenator.dart';
import 'package:mybrev_flutter/hyphenation/hyphenation_service.dart';
import 'package:mybrev_flutter/hyphenation/justified_hyphen_text.dart';
import 'package:mybrev_flutter/utils/reading_alignment.dart';

/// Which hyphenating renderer a prose block uses.
enum ProseLayout { b2, d, fallback }

/// The merged rule: the saved alignment plus the adaptive threshold from
/// `reading_alignment.dart` (≥ [kJustifyMinCharsPerLine] characters per line).
///
/// * saved "Па левым краі"                       → D (left + hyphens)
/// * saved "Па шырыні", enough characters/line   → B2 (justified + hyphens)
/// * saved "Па шырыні", narrow line / large type  → D
/// * hyphenation data not available               → fallback (stock renderer,
///   adaptive alignment exactly as before)
ProseLayout proseLayoutFor({
  required TextAlign selected,
  required double maxWidth,
  required TextStyle style,
  required TextScaler textScaler,
  required BelarusianHyphenator? hyphenator,
}) {
  if (hyphenator == null || !maxWidth.isFinite || maxWidth <= 0) {
    return ProseLayout.fallback;
  }
  final shown = effectiveProseAlignment(
    selected: selected,
    maxWidth: maxWidth,
    style: style,
    textScaler: textScaler,
  );
  return shown == TextAlign.justify ? ProseLayout.b2 : ProseLayout.d;
}

/// One prose paragraph (an inline span tree) with Belarusian hyphenation.
/// Falls back to a plain `Text.rich` with the adaptive alignment.
class HyphenatedProse extends StatelessWidget {
  const HyphenatedProse({
    super.key,
    required this.span,
    required this.selected,
    required this.style,
  });

  final TextSpan span;

  /// The saved user choice (never modified here).
  final TextAlign selected;

  /// Base style used to measure characters per line.
  final TextStyle style;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    // The patterns and the reader face both arrive asynchronously.
    listenable: Listenable.merge([
      BelarusianHyphenation.notifier,
      PaintingBinding.instance.systemFonts,
    ]),
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) {
        final hyphenator = BelarusianHyphenation.current;
        final scaler = MediaQuery.textScalerOf(context);
        final layout = proseLayoutFor(
          selected: selected,
          maxWidth: constraints.maxWidth,
          style: style,
          textScaler: scaler,
          hyphenator: hyphenator,
        );
        if (layout == ProseLayout.fallback || _hasWidgetSpan(span)) {
          return Text.rich(
            span,
            textAlign: effectiveProseAlignment(
              selected: selected,
              maxWidth: constraints.maxWidth,
              style: style,
              textScaler: scaler,
            ),
          );
        }
        return HyphenatedJustifiedText(
          text: span,
          hyphenator: hyphenator,
          justify: layout == ProseLayout.b2,
          textScaler: scaler,
        );
      },
    ),
  );
}

bool _hasWidgetSpan(InlineSpan span) {
  if (span is! TextSpan) return true; // WidgetSpan etc. → keep stock
  return (span.children ?? const <InlineSpan>[]).any(_hasWidgetSpan);
}

/// Drop-in for `Html(data:, style:)` for prose documents: ordinary `<p>`
/// paragraphs get hyphenation, everything else (headings, rubrics, verses,
/// lists, quotes, responsories, anything with a class or markup we do not
/// model) is rendered by the existing `Html` exactly as before, grouped so its
/// structure and spacing are unchanged.
class HyphenatedHtml extends StatelessWidget {
  const HyphenatedHtml({
    super.key,
    required this.data,
    required this.style,
    required this.selected,
    this.onLinkTap,
  });

  final String data;
  final Map<String, Style> style;
  final TextAlign selected;
  final OnTap? onLinkTap;

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<BelarusianHyphenator?>(
        valueListenable: BelarusianHyphenation.notifier,
        builder: (context, hyphenator, _) => hyphenator == null
            // Patterns not loaded (yet): exactly the pre-hyphenation widget.
            ? _stock(data, selected)
            : _blocks(context),
      );

  Widget _blocks(BuildContext context) {
    // A paragraph style we cannot reproduce keeps the whole document stock.
    if (!isReproducibleParagraphStyle(style['p'])) {
      return _stock(data, selected);
    }
    final blocks = splitProseBlocks(data, style);
    // Nothing to hyphenate → identical to the old widget.
    if (!blocks.any((b) => b.prose != null)) {
      return _stock(data, selected);
    }
    final base = proseBaseStyle(style);
    final children = <Widget>[];
    for (var i = 0; i < blocks.length; i++) {
      final b = blocks[i];
      final last = i == blocks.length - 1;
      if (b.prose != null) {
        final margin = b.prose!.classes.contains('semantic-last')
            ? 0.0
            : (style['p']?.margin?.bottom?.value ?? 8.0);
        // Adjacent vertical margins collapse in one `Html`; keep that here.
        final nextTop = last ? 0.0 : _topMarginOf(blocks[i + 1], style);
        final gap = last ? 0.0 : math.max(0.0, margin - nextTop);
        children.add(
          Padding(
            padding: EdgeInsets.only(bottom: gap),
            child: HyphenatedProse(
              span: proseSpan(b.prose!, style, base),
              selected: selected,
              style: base,
            ),
          ),
        );
      } else {
        children.add(_stock(b.html!, selected));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  Widget _stock(String html, TextAlign selected) => LayoutBuilder(
    builder: (context, c) {
      // Stock blocks keep the shipped adaptive alignment (#149).
      final body = style['body']?.generateTextStyle() ?? const TextStyle();
      final shown = effectiveProseAlignment(
        selected: selected,
        maxWidth: c.maxWidth,
        style: body,
        textScaler: MediaQuery.textScalerOf(context),
      );
      final styles = {...style};
      // Only replace an alignment the caller already set: otherwise inline
      // `text-align` (centred rubric titles) must keep winning.
      if (styles['body']?.textAlign != null) {
        styles['body']!.textAlign = shown;
      }
      if (styles['p']?.textAlign != null) {
        styles['p']!.textAlign = shown;
      }
      return Html(data: html, style: styles, onLinkTap: onLinkTap);
    },
  );
}

/// A top-level block: either a prose paragraph or a chunk of other HTML.
class ProseBlock {
  const ProseBlock.prose(this.prose) : html = null;
  const ProseBlock.other(this.html) : prose = null;
  final dom.Element? prose;
  final String? html;
}

double _topMarginOf(ProseBlock block, Map<String, Style> styles) {
  if (block.prose != null) {
    return styles['p']?.margin?.top?.value ?? 0;
  }
  final first = parseFragment(block.html!).children.firstOrNull;
  if (first == null) {
    return 0;
  }
  var top = styles[first.localName]?.margin?.top?.value ?? 0;
  for (final c in first.classes) {
    top = styles['.$c']?.margin?.top?.value ?? top;
  }
  return top;
}

/// Sections whose text is sung or recited as verse: never re-wrapped.
final _verseSection = RegExp(
  r'гімн|псальм|псалм|псалом|песн|кантык|антыф|hymn|psalm|cantic',
  caseSensitive: false,
);

/// Antiphons and versicle/response dialogues ("1 ант.", "К.", "Н.:", "℟").
final _antiphonOrDialogue = RegExp(
  r'^\s*((\d+\s*)?(ант\.|ант\s|антыфона)|[КНСЦВVR]\s*[.:]|[℣℟])',
  caseSensitive: false,
);

bool? _opensVerseSection(dom.Element e) {
  final heading =
      RegExp(r'^h[1-6]$').hasMatch(e.localName ?? '') ||
      e.classes.any(
        (c) => const {
          'liturgical-heading',
          'liturgical-subheading',
          'liturgical-service-heading',
        }.contains(c),
      ) ||
      (e.classes.any((c) => c == 'prayer-rubric' || c == 'liturgical-rubric') &&
          e.text.trim().length < 60);
  return heading ? _verseSection.hasMatch(e.text) : null;
}

/// Splits an HTML fragment into prose paragraphs and "everything else".
/// Consecutive non-prose nodes are merged into one chunk. Paragraphs inside a
/// hymn / psalm / canticle / antiphon section stay with the stock renderer.
List<ProseBlock> splitProseBlocks(
  String html, [
  Map<String, Style> styles = const {},
]) {
  final fragment = parseFragment(html);
  final out = <ProseBlock>[];
  final other = StringBuffer();
  var verseSection = false;
  void flush() {
    if (other.toString().trim().isNotEmpty) {
      out.add(ProseBlock.other(other.toString()));
    }
    other.clear();
  }

  for (final node in fragment.nodes) {
    if (node is dom.Element) {
      verseSection = _opensVerseSection(node) ?? verseSection;
      if (!verseSection && isProseParagraph(node, styles)) {
        flush();
        out.add(ProseBlock.prose(node));
        continue;
      }
    }
    other.write(node is dom.Element ? node.outerHtml : node.text ?? '');
  }
  flush();
  return out;
}

const _proseTags = {'em', 'i', 'strong', 'b', 'span'};
const _allowedPClasses = {'semantic-last'};

/// Only properties [proseSpan] can reproduce (colour, weight, slant,
/// decoration line, size). Anything else keeps the stock renderer.
bool isReproducibleInlineStyle(Style? s) =>
    s == null ||
    (s.backgroundColor == null &&
        s.fontFamily == null &&
        s.fontFeatureSettings == null &&
        s.letterSpacing == null &&
        s.wordSpacing == null &&
        s.lineHeight == null &&
        s.margin == null &&
        s.padding == null &&
        s.textShadow == null &&
        (s.textTransform == null || s.textTransform == TextTransform.none) &&
        s.verticalAlign == VerticalAlign.baseline &&
        s.whiteSpace == null &&
        s.border == null &&
        s.width == null &&
        s.height == null &&
        s.before == null &&
        s.after == null &&
        s.textDecorationColor == null &&
        s.textDecorationStyle == null &&
        s.textDecorationThickness == null);

/// The `p` rule may only set text properties and vertical margins.
bool isReproducibleParagraphStyle(Style? s) =>
    s == null ||
    ((s.margin?.left?.value ?? 0) == 0 &&
        (s.margin?.right?.value ?? 0) == 0 &&
        s.padding == null &&
        s.backgroundColor == null &&
        s.border == null &&
        (s.textTransform == null || s.textTransform == TextTransform.none) &&
        s.textShadow == null &&
        s.whiteSpace == null &&
        s.width == null &&
        s.height == null);

/// Conservative: only a plain `<p>` of running text qualifies. Everything
/// whose look or behaviour cannot be reproduced exactly stays with `Html`:
/// links, `sup`/`sub` and any other tag, any attribute besides `class`
/// (inline CSS included), classes without a reproducible style, verses (line
/// breaks, `*`/`†`), antiphons and dialogues, rubric-only and short text,
/// paragraphs with a class, centered / right / indented paragraphs.
bool isProseParagraph(dom.Element p, [Map<String, Style> styles = const {}]) {
  if (p.localName != 'p' ||
      p.classes.any((c) => !_allowedPClasses.contains(c))) {
    return false;
  }
  for (final name in p.attributes.keys) {
    if (name != 'class' && name != 'style') {
      return false;
    }
  }
  final declarations = (p.attributes['style'] ?? '')
      .split(';')
      .map((d) => d.replaceAll(RegExp(r'\s'), '').toLowerCase())
      .where((d) => d.isNotEmpty);
  if (declarations.any(
    (d) => d != 'text-align:justify' && d != 'text-align:left',
  )) {
    return false;
  }
  final html = p.innerHtml;
  if (html.contains('<br') ||
      html.contains('*') ||
      html.contains('†') ||
      _antiphonOrDialogue.hasMatch(p.text)) {
    return false;
  }
  var letters = 0;
  var allRubric = true;
  var ok = true;
  void visit(dom.Node n, bool inRubric) {
    if (n is dom.Text) {
      final t = n.data.trim();
      if (t.isNotEmpty) {
        letters += t.length;
        if (!inRubric) {
          allRubric = false;
        }
      }
      return;
    }
    if (n is! dom.Element) {
      return;
    }
    if (!_proseTags.contains(n.localName) ||
        n.attributes.keys.any((k) => k != 'class') ||
        n.classes.contains('prayer-speaker') ||
        !isReproducibleInlineStyle(styles[n.localName]) ||
        n.classes.any(
          (c) =>
              styles['.$c'] == null ||
              !isReproducibleInlineStyle(styles['.$c']),
        )) {
      ok = false;
      return;
    }
    final rubric = inRubric || n.classes.contains('liturgical-rubric-inline');
    for (final c in n.nodes) {
      visit(c, rubric);
    }
  }

  for (final c in p.nodes) {
    visit(c, false);
  }
  return ok && letters >= 40 && !allRubric;
}

TextStyle? _textOverride(Style? s) => s == null
    ? null
    : TextStyle(
        color: s.color,
        fontWeight: s.fontWeight,
        fontStyle: s.fontStyle,
        decoration: s.textDecoration,
        fontSize: s.fontSize?.value,
      );

/// The paragraph's base style: `body`, then whatever the `p` rule overrides.
TextStyle proseBaseStyle(Map<String, Style> styles) {
  final body = styles['body']?.generateTextStyle() ?? const TextStyle();
  final p = styles['p'];
  if (p == null) {
    return body;
  }
  return body
      .merge(_textOverride(p))
      .copyWith(height: p.lineHeight?.size ?? body.height);
}

/// Inline conversion of one prose paragraph, using the app's own `Style` map
/// for classes/tags (never the line height, so body metrics are kept).
TextSpan proseSpan(dom.Element p, Map<String, Style> styles, TextStyle base) {
  InlineSpan inline(dom.Node n) {
    if (n is dom.Text) {
      return TextSpan(text: n.data.replaceAll(RegExp(r'[ \t\r\n]+'), ' '));
    }
    if (n is! dom.Element) {
      return const TextSpan();
    }
    final kids = n.nodes.map(inline).toList();
    var s = switch (n.localName) {
      'em' || 'i' => const TextStyle(fontStyle: FontStyle.italic),
      'strong' || 'b' => const TextStyle(fontWeight: FontWeight.w700),
      _ => const TextStyle(),
    };
    s = s.merge(_textOverride(styles[n.localName]));
    for (final c in n.classes) {
      s = s.merge(_textOverride(styles['.$c']));
    }
    return TextSpan(style: s, children: kids);
  }

  final children = p.nodes.map(inline).toList();
  // Trim the collapsed whitespace at the paragraph edges.
  if (children.isNotEmpty && children.first is TextSpan) {
    final f = children.first as TextSpan;
    if (f.text != null) {
      children[0] = TextSpan(text: f.text!.trimLeft());
    }
  }
  if (children.isNotEmpty && children.last is TextSpan) {
    final l = children.last as TextSpan;
    if (l.text != null) {
      children[children.length - 1] = TextSpan(text: l.text!.trimRight());
    }
  }
  return TextSpan(style: base, children: children);
}
