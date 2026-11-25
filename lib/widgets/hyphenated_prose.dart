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
  Widget build(BuildContext context) =>
      ValueListenableBuilder<BelarusianHyphenator?>(
        valueListenable: BelarusianHyphenation.notifier,
        builder: (context, hyphenator, _) => LayoutBuilder(
          builder: (context, constraints) {
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
    final blocks = splitProseBlocks(data);
    // Nothing to hyphenate → identical to the old widget.
    if (!blocks.any((b) => b.prose != null)) {
      return _stock(data, selected);
    }
    final body = style['body']?.generateTextStyle() ?? const TextStyle();
    final children = <Widget>[];
    for (var i = 0; i < blocks.length; i++) {
      final b = blocks[i];
      final last = i == blocks.length - 1;
      if (b.prose != null) {
        final spans = proseSpan(b.prose!, style, body);
        final margin = b.prose!.classes.contains('semantic-last')
            ? 0.0
            : (style['p']?.margin?.bottom?.value ?? 8.0);
        children.add(
          Padding(
            padding: EdgeInsets.only(bottom: last ? 0 : margin),
            child: HyphenatedProse(
              span: spans,
              selected: selected,
              style: body,
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
      styles['body'] = (styles['body'] ?? Style())..textAlign = shown;
      styles['p'] = (styles['p'] ?? Style())..textAlign = shown;
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

/// Splits an HTML fragment into prose paragraphs and "everything else".
/// Consecutive non-prose nodes are merged into one chunk.
List<ProseBlock> splitProseBlocks(String html) {
  final fragment = parseFragment(html);
  final out = <ProseBlock>[];
  final other = StringBuffer();
  void flush() {
    if (other.toString().trim().isNotEmpty)
      out.add(ProseBlock.other(other.toString()));
    other.clear();
  }

  for (final node in fragment.nodes) {
    if (node is dom.Element && isProseParagraph(node)) {
      flush();
      out.add(ProseBlock.prose(node));
    } else {
      other.write(node is dom.Element ? node.outerHtml : node.text ?? '');
    }
  }
  flush();
  return out;
}

const _proseTags = {'em', 'i', 'strong', 'b', 'span', 'a', 'sup', 'sub'};
const _allowedPClasses = {'semantic-last'};

/// Conservative: only a plain `<p>` of running text qualifies. Verses (line
/// breaks, `*`/`†` cadence marks), rubric-only text, paragraphs with a class
/// (liturgical-*, psalm-*, ora-*, prayer-*…), centered/pre-formatted/indented
/// paragraphs and markup we do not model stay with the stock renderer.
bool isProseParagraph(dom.Element p) {
  if (p.localName != 'p') {
    return false;
  }
  if (p.classes.any((c) => !_allowedPClasses.contains(c))) {
    return false;
  }
  final inline = p.attributes['style']?.toLowerCase() ?? '';
  if (RegExp(
    r'text-align\s*:\s*(center|right)|white-space|text-indent',
  ).hasMatch(inline)) {
    return false;
  }
  final html = p.innerHtml;
  if (html.contains('<br') || html.contains('*') || html.contains('†'))
    return false;
  var letters = 0;
  var allRubric = true;
  var ok = true;
  void visit(dom.Node n, bool inRubric) {
    if (n is dom.Text) {
      final t = n.data.trim();
      if (t.isNotEmpty) {
        letters += t.length;
        if (!inRubric) allRubric = false;
      }
      return;
    }
    if (n is! dom.Element) {
      return;
    }
    if (!_proseTags.contains(n.localName)) {
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

/// Inline conversion of one prose paragraph, using the app's own `Style`
/// map for classes/tags (only colour, weight, slant, decoration and size are
/// taken, never the line height, so the paragraph keeps the body metrics).
TextSpan proseSpan(dom.Element p, Map<String, Style> styles, TextStyle base) {
  TextStyle? override(Style? s) => s == null
      ? null
      : TextStyle(
          color: s.color,
          fontWeight: s.fontWeight,
          fontStyle: s.fontStyle,
          decoration: s.textDecoration,
          fontSize: s.fontSize?.value,
        );
  InlineSpan inline(dom.Node n) {
    if (n is dom.Text) {
      return TextSpan(text: n.data.replaceAll(RegExp(r'[ \t\r\n]+'), ' '));
    }
    if (n is! dom.Element) {
      return const TextSpan();
    }
    final kids = n.nodes.map(inline).toList();
    var s = const TextStyle();
    switch (n.localName) {
      case 'em' || 'i':
        s = s.merge(const TextStyle(fontStyle: FontStyle.italic));
      case 'strong' || 'b':
        s = s.merge(const TextStyle(fontWeight: FontWeight.w700));
      case 'sup' || 'sub':
        break;
    }
    final tagStyle = override(styles[n.localName]);
    if (tagStyle != null) s = s.merge(tagStyle);
    for (final c in n.classes) {
      final cs = override(styles['.$c']);
      if (cs != null) s = s.merge(cs);
    }
    return TextSpan(style: s, children: kids);
  }

  final children = p.nodes.map(inline).toList();
  // Trim the collapsed whitespace at the paragraph edges.
  if (children.isNotEmpty && children.first is TextSpan) {
    final f = children.first as TextSpan;
    if (f.text != null) children[0] = TextSpan(text: f.text!.trimLeft());
  }
  if (children.isNotEmpty && children.last is TextSpan) {
    final l = children.last as TextSpan;
    if (l.text != null)
      children[children.length - 1] = TextSpan(text: l.text!.trimRight());
  }
  return TextSpan(style: base, children: children);
}
