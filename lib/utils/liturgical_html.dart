import 'dart:convert';

import 'package:mybrev_flutter/models/psalmody_preferences.dart';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' show parseFragment;

/// Semantic preparation for legacy liturgical HTML.
///
/// The web application styles psalm metadata, strophes and cadence signs
/// separately. Flutter HTML needs explicit classes for the same result.
final _paragraphPattern = RegExp(
  r'<p\b([^>]*)>([\s\S]*?)</p>',
  caseSensitive: false,
);
final _breakPattern = RegExp(r'<br\s*/?>', caseSensitive: false);
final _cadencePattern = RegExp(
  r'(?:\*|&#0*42;|&#x0*2a;|&ast;|†|&#0*8224;|&#x0*2020;|&dagger;)',
  caseSensitive: false,
);
final _asteriskPattern = RegExp(
  r'(?:\*|&#0*42;|&#x0*2a;|&ast;)',
  caseSensitive: false,
);

String removeBreakAfterCadenceMarker(String html) => html.replaceAllMapped(
  RegExp(
    r'((?:\*|&#0*42;|&#x0*2a;|&ast;|†|&#0*8224;|&#x0*2020;|&dagger;)(?:\s|&nbsp;)*(?:</(?:span|font|strong|b|em|i)>\s*)*)(?:<br\s*/?>\s*)+',
    caseSensitive: false,
  ),
  (match) => '${match.group(1)} ',
);

@Deprecated('Use removeBreakAfterCadenceMarker')
String removeBreakAfterAsterisk(String html) =>
    removeBreakAfterCadenceMarker(html);

String markLiturgicalCadenceSigns(String html) {
  final out = StringBuffer();
  final tagPattern = RegExp(r'<[^>]*>');
  var cursor = 0;
  for (final tag in tagPattern.allMatches(html)) {
    out.write(_markCadenceInText(html.substring(cursor, tag.start)));
    out.write(tag.group(0));
    cursor = tag.end;
  }
  out.write(_markCadenceInText(html.substring(cursor)));
  return out.toString();
}

String _markCadenceInText(String text) => text.replaceAllMapped(
  _cadencePattern,
  (match) => '<span class="psalm-marker">${match.group(0)}</span>',
);

String formatLiturgicalHtml(String html) => _uppercaseDocumentHeadings(
  markLiturgicalCadenceSigns(
    _normalizeLegacyPresentation(
      _normalizeRubricColors(
        _markInlineReadingReference(
          _normalizeRubricBlocks(_markLeadingMetadata(html)),
        ),
      ),
    ),
  ),
);

/// Uppercase only displayed section titles, not Scripture, references or rubrics.
/// Keep inline markup and the normalized source headings unchanged.
String _uppercaseDocumentHeadings(String html) {
  if (!html.contains('liturgical-heading')) return html;
  final fragment = parseFragment(html);
  void uppercaseText(dom.Node node) {
    if (node is dom.Text) {
      node.data = node.data.toUpperCase();
      return;
    }
    if (node is dom.Element &&
        (node.classes.contains('liturgical-reading-reference') ||
            node.classes.contains('liturgical-reference'))) {
      return;
    }
    for (final child in node.nodes) {
      uppercaseText(child);
    }
  }

  for (final heading in fragment.querySelectorAll('.liturgical-heading')) {
    uppercaseText(heading);
  }
  return fragment.outerHtml;
}

String _normalizeRubricBlocks(String html) {
  final fragment = parseFragment(html);
  for (final rubric in fragment.querySelectorAll('.liturgical-rubric')) {
    for (final emphasis in rubric.querySelectorAll('em, i')) {
      emphasis.replaceWith(dom.Text(emphasis.text));
    }
  }
  return fragment.outerHtml;
}

/// Derives office roles from legacy paragraphs without changing the corpus.
/// A heading is split only when the whole first source line matches a known
/// liturgical label followed by an optional reference.
String normalizeOfficeHtml(String source, {bool officeReading = false}) {
  final fragment = parseFragment(
    source.contains('<')
        ? source
        : source
              .split(RegExp(r'\r?\n'))
              .where((line) => line.trim().isNotEmpty)
              .map((line) => '<p>${const HtmlEscape().convert(line)}</p>')
              .join(),
  );
  for (final rubric in fragment.querySelectorAll('.liturgical-rubric')) {
    for (final emphasis in rubric.querySelectorAll('em, i')) {
      emphasis.replaceWith(dom.Text(emphasis.text));
    }
  }

  final heading = RegExp(
    r'^(КАРОТКАЕ\s+ЧЫТАННЕ|КАРОТКІ\s+РЭСПАНСОРЫЙ|РЭСПАНСОРЫЙ)(?:\s+(.+))?$',
    caseSensitive: false,
  );
  for (final paragraph in fragment.querySelectorAll('p').toList()) {
    final parts = paragraph.innerHtml.split(
      RegExp(r'<br\s*/?>', caseSensitive: false),
    );
    final firstLine =
        parseFragment(
          parts.first,
        ).text?.replaceAll(RegExp(r'\s+'), ' ').trim() ??
        '';
    final match = heading.firstMatch(
      firstLine.replaceAllMapped(RegExp(r'\s+([,.;:])'), (m) => m.group(1)!),
    );
    if (match == null) continue;
    final title = switch (match
        .group(1)!
        .toUpperCase()
        .replaceAll(RegExp(r'\s+'), ' ')) {
      'КАРОТКАЕ ЧЫТАННЕ' => 'Кароткае чытанне',
      'КАРОТКІ РЭСПАНСОРЫЙ' => 'Кароткі рэспансорый',
      _ => 'Рэспансорый',
    };
    final titleNode = dom.Element.tag('p')
      ..classes.add('liturgical-heading')
      ..text = title;
    paragraph.parentNode!.insertBefore(titleNode, paragraph);
    final reference = match.group(2)?.trim();
    if (reference != null && reference.isNotEmpty) {
      final referenceNode = dom.Element.tag('p')
        ..classes.add('liturgical-reference')
        ..text = reference;
      paragraph.parentNode!.insertBefore(referenceNode, paragraph);
    }
    if (parts.length == 1) {
      paragraph.remove();
    } else {
      paragraph.innerHtml = parts.skip(1).join('<br>');
    }
  }

  // Responsory source often places several turns in one paragraph, including
  // inline spans. Rebuild only those paragraphs as turns; other text survives.
  final speaker = RegExp(r'(?<![\p{L}\p{N}])[КН]\.\s*', unicode: true);
  for (final paragraph in fragment.querySelectorAll('p').toList()) {
    if (paragraph.classes.contains('liturgical-heading') ||
        paragraph.classes.contains('liturgical-reference')) {
      continue;
    }
    final plain = _textWithBreaks(paragraph).replaceAll('\u00a0', ' ');
    final matches = speaker.allMatches(plain).toList();
    if (matches.isEmpty) continue;
    if (matches.first.start > 0 &&
        plain.substring(0, matches.first.start).trim().isNotEmpty) {
      final prefix = dom.Element.tag('p');
      prefix.nodes.addAll(_copyTextRange(paragraph, 0, matches.first.start));
      paragraph.parentNode!.insertBefore(prefix, paragraph);
    }
    for (var i = 0; i < matches.length; i++) {
      // A <br> before the next speaker separates turns in legacy HTML. Once
      // each turn becomes its own paragraph it must not add an empty line.
      var end = i + 1 < matches.length ? matches[i + 1].start : plain.length;
      while (end > matches[i].start + 2 &&
          RegExp(r'\s').hasMatch(plain[end - 1])) {
        end--;
      }
      final node = dom.Element.tag('p')..classes.add('responsory-turn');
      final marker = dom.Element.tag('span')
        ..classes.add('liturgical-rubric-inline')
        ..text = plain.substring(matches[i].start, matches[i].start + 2);
      node.nodes.add(marker);
      node.nodes.addAll(_copyTextRange(paragraph, matches[i].start + 2, end));
      paragraph.parentNode!.insertBefore(node, paragraph);
    }
    paragraph.remove();
  }

  if (officeReading) {
    final paragraphs = fragment.querySelectorAll('p');
    for (var i = 1; i < paragraphs.length && i < 5; i++) {
      final paragraph = paragraphs[i];
      final previous = paragraphs[i - 1].text.trim();
      final emphasis = paragraph.querySelector('em, i');
      if (RegExp(r'\d+\s*,\s*\d').hasMatch(previous) &&
          emphasis != null &&
          emphasis.text.trim() == paragraph.text.trim() &&
          paragraph.text.trim().isNotEmpty) {
        paragraph.classes.add('office-reading-pericope-title');
        for (final emphasis in paragraph.querySelectorAll('em, i')) {
          emphasis.replaceWith(dom.Text(emphasis.text));
        }
        break;
      }
    }
  }
  return fragment.outerHtml;
}

/// Pulls the already-normalized short-reading header out as semantic pieces.
/// The body retains its original inline HTML for the common document renderer.
({String title, String? reference, String bodyHtml})? extractShortReadingHeader(
  String normalizedHtml,
) {
  final root = parseFragment(normalizedHtml);
  final heading = root.querySelector('.liturgical-heading');
  if (heading?.text.trim() != 'Кароткае чытанне') return null;
  final reference = heading!.nextElementSibling;
  final referenceText =
      reference?.classes.contains('liturgical-reference') == true
      ? reference!.text.trim()
      : null;
  heading.remove();
  if (referenceText != null) reference!.remove();
  return (
    title: 'Кароткае чытанне',
    reference: referenceText,
    bodyHtml: root.outerHtml,
  );
}

String _textWithBreaks(dom.Node node) {
  if (node is dom.Text) return node.data;
  if (node is dom.Element && node.localName == 'br') return '\n';
  return node.nodes.map(_textWithBreaks).join();
}

/// Copies a character range while retaining every inline ancestor and style.
List<dom.Node> _copyTextRange(dom.Node root, int start, int end) {
  var position = 0;
  List<dom.Node> copyChildren(dom.Node parent) {
    final result = <dom.Node>[];
    for (final child in parent.nodes) {
      final length = _textWithBreaks(child).length;
      final from = (start - position).clamp(0, length);
      final to = (end - position).clamp(0, length);
      if (child is dom.Text) {
        if (to > from) result.add(dom.Text(child.data.substring(from, to)));
        position += length;
      } else if (child is dom.Element && child.localName == 'br') {
        if (to > from) result.add(dom.Element.tag('br'));
        position += length;
      } else if (child is dom.Element) {
        final clone = dom.Element.tag(child.localName!)
          ..attributes.addAll(child.attributes);
        clone.nodes.addAll(copyChildren(child));
        if (clone.nodes.isNotEmpty) result.add(clone);
      }
    }
    return result;
  }

  return copyChildren(root);
}

String formatPsalmHtml(String html) {
  var value = removeBreakAfterCadenceMarker(html);

  var stropheIndex = 0;
  value = value.replaceAllMapped(_paragraphPattern, (match) {
    final attributes = match.group(1) ?? '';
    final content = match.group(2) ?? '';
    if (!_asteriskPattern.hasMatch(content)) return match.group(0)!;

    final strophes = <String>[];
    var cursor = 0;
    var current = '';
    final breaks = _breakPattern.allMatches(content).toList();
    for (var i = 0; i < breaks.length; i++) {
      final br = breaks[i];
      current += content.substring(cursor, br.start);
      final nextLineEnd = i + 1 < breaks.length
          ? breaks[i + 1].start
          : content.length;
      final nextLine = content.substring(br.end, nextLineEnd);

      // A source <br> can be a soft wrap inside one verse. Split only when
      // the following line introduces another cadence-bearing strophe.
      // Otherwise a trailing half-verse becomes a false choir/indent.
      if (_asteriskPattern.hasMatch(current) &&
          _cadencePattern.hasMatch(nextLine)) {
        if (current.trim().isNotEmpty) strophes.add(current);
        current = '';
      } else {
        current += br.group(0)!;
      }
      cursor = br.end;
    }
    current += content.substring(cursor);
    if (current.trim().isNotEmpty) strophes.add(current);

    return strophes.map((strophe) {
      stropheIndex += 1;
      final parity = stropheIndex.isEven ? ' psalm-strophe-even' : '';
      final choir = stropheIndex.isEven ? 2 : 1;
      return '<p data-psalm-choir="$choir"${_withClass(attributes, 'psalm-strophe$parity')}>$strophe</p>';
    }).join();
  });

  return markLiturgicalCadenceSigns(
    _normalizeLegacyPresentation(
      _normalizeRubricColors(
        ownsStructuredPsalmPackage(value)
            ? _markStructuredPsalmMetadata(value)
            : _markLeadingMetadata(value, limit: null, psalmMetadata: true),
      ),
    ),
  );
}

String _markStructuredPsalmMetadata(String html) {
  final root = parseFragment(html);
  for (final psalm in root.querySelectorAll('.ora-psalm')) {
    psalm.innerHtml = _markLeadingMetadata(
      psalm.innerHtml,
      limit: null,
      psalmMetadata: true,
    );
  }
  return root.outerHtml;
}

/// Singing layout for responsorial psalm verses on the readings page.
String formatReadingPsalmText(String text) => text
    .replaceAll(RegExp(r'\*[\s\u00a0]*'), '*\n')
    .replaceAll(RegExp(r'[\s\u00a0]+(?=\d+\.[\s\u00a0])'), '\n')
    .trim();

String formatReadingPsalmHtml(String html) {
  // Decode source entities before cadence normalization so encoded spaces
  // do not make an existing half-verse break look like a new strophe.
  final fragment = parseFragment(
    formatPsalmHtml(parseFragment(html).outerHtml.replaceAll('&nbsp;', ' ')),
  );
  for (final paragraph in fragment.querySelectorAll('p')) {
    var needsBreak = false;
    var lineStart = true;
    void visit(dom.Node node) {
      if (node is dom.Element && node.localName == 'br') {
        needsBreak = false;
        lineStart = true;
        return;
      }
      if (node is dom.Text) {
        var text = node.data;
        if (needsBreak || lineStart) {
          text = text.replaceFirst(RegExp(r'^[\s\u00a0]+'), '');
        }
        if (text.isEmpty) {
          node.data = '';
          return;
        }
        text = text.replaceAll(RegExp(r'[\s\u00a0]+(?=\d+\.[\s\u00a0])'), '\n');
        final parts = text.split('\n');
        final replacement = <dom.Node>[];
        if (needsBreak) replacement.add(dom.Element.tag('br'));
        for (var i = 0; i < parts.length; i++) {
          if (i > 0) replacement.add(dom.Element.tag('br'));
          replacement.add(dom.Text(parts[i]));
        }
        final parent = node.parentNode!;
        final index = parent.nodes.indexOf(node);
        node.remove();
        parent.nodes.insertAll(index, replacement);
        needsBreak = text.trimRight().endsWith('*');
        lineStart = text.endsWith('\n');
        return;
      }
      for (final child in node.nodes.toList()) {
        visit(child);
      }
    }

    visit(paragraph);
  }
  return fragment.outerHtml;
}

/// The spoken text of a psalm body, one strophe per line.
///
/// The visible strophes are links (see [preparePsalmChoirHtml]); a link is its
/// own accessibility node, and the reader drops such nodes while they are off
/// screen, so TalkBack skipped the psalms inside the long hour. The same text
/// as a plain label is part of the hour's text node instead.
String psalmPlainText(String html) {
  final fragment = parseFragment(html);
  final strophes = fragment.querySelectorAll('p');
  final blocks = strophes.isEmpty
      ? [fragment.text ?? '']
      : [for (final strophe in strophes) strophe.text];
  return [
    for (final block in blocks)
      if (block.replaceAll(RegExp(r'\s+'), ' ').trim() case final line
          when line.isNotEmpty)
        line,
  ].join('\n');
}

/// Adds tap targets to the already formatted strophes of a psalm.
///
/// Odd and even strophes represent the two choirs. When [selectedChoir] is
/// set, strophes belonging to that choir receive a muted style hook.
String preparePsalmChoirHtml(
  String html, {
  int? selectedChoir,
  PsalmodyMode mode = PsalmodyMode.leftBreak,
}) {
  final breakAfterMarker = mode != PsalmodyMode.alternatingStanzas;
  return html.replaceAllMapped(_paragraphPattern, (match) {
    final attributes = match.group(1) ?? '';
    final content = match.group(2) ?? '';
    if (!RegExp(
      r'''\bclass\s*=\s*["'][^"']*\bpsalm-strophe\b''',
      caseSensitive: false,
    ).hasMatch(attributes)) {
      return match.group(0)!;
    }

    final semanticChoir = int.tryParse(
      RegExp(r'data-psalm-choir="([12])"').firstMatch(attributes)?.group(1) ??
          '',
    );
    final choir =
        semanticChoir ??
        (RegExp(
              r'\bpsalm-strophe-even\b',
              caseSensitive: false,
            ).hasMatch(attributes)
            ? 2
            : 1);
    final mutedClass = selectedChoir == choir ? ' psalm-choir-muted' : '';

    final fragment = parseFragment(content);
    if (mode == PsalmodyMode.alternatingStanzas) {
      // Preserve strophes, words and inline ancestors, but remove every source
      // line break inside this strophe (including nested formatting).
      for (final br in fragment.querySelectorAll('br')) {
        br.replaceWith(dom.Text(' '));
      }
    }
    final pieces = fragment.nodes.expand(_choirPieces);
    final rendered = StringBuffer();
    final segments = <String>[];
    final linked = StringBuffer();
    void flushLink() {
      if (linked.isEmpty) return;
      rendered.write(
        '<a href="psalm-choir:$choir" '
        'class="psalm-choir-strophe$mutedClass">$linked</a>',
      );
      linked.clear();
    }

    for (final piece in pieces) {
      if (piece.isMarker) {
        flushLink();
        rendered.write(piece.html);
        if (breakAfterMarker &&
            parseFragment(piece.html).querySelector('.psalm-marker') != null) {
          segments.add(rendered.toString());
          rendered.clear();
        }
      } else {
        linked.write(piece.html);
      }
    }
    flushLink();
    if (breakAfterMarker && segments.isNotEmpty) {
      if (parseFragment(rendered.toString()).text!.trim().isNotEmpty) {
        segments.add(rendered.toString());
      }
      final lines = StringBuffer();
      for (var i = 0; i < segments.length; i++) {
        // Source breaks inside a segment remain intact. Cadence signs stay
        // with the preceding line; only continuations get an em-based inset.
        final segment = segments[i].replaceFirst(RegExp(r'^(\s|&nbsp;)+'), '');
        lines.write(
          '<span class="psalm-line${i == 0 ? '' : ' psalm-continuation'}">$segment</span>',
        );
      }
      return '<p$attributes>$lines</p>';
    }
    return '<p$attributes>$rendered</p>';
  });
}

/// Lift cadence marks out of the choir link while preserving their inline
/// ancestors. flutter_html applies a link's color after descendant classes.
Iterable<({String html, bool isMarker})> _choirPieces(dom.Node node) sync* {
  if (node is dom.Element &&
      (node.classes.contains('psalm-marker') ||
          node.classes.contains('liturgical-rubric-inline') ||
          node.classes.contains('liturgical-rubric'))) {
    yield (html: node.outerHtml, isMarker: true);
    return;
  }
  if (node is! dom.Element) {
    yield (html: htmlEscape.convert(node.text ?? ''), isMarker: false);
    return;
  }
  if (node.nodes.isEmpty) {
    yield (html: node.outerHtml, isMarker: false);
    return;
  }
  final outer = node.outerHtml;
  final openEnd = outer.indexOf('>') + 1;
  final closeStart = outer.lastIndexOf('</');
  if (closeStart < openEnd) {
    yield (html: outer, isMarker: false);
    return;
  }
  final opening = outer.substring(0, openEnd);
  final closing = outer.substring(closeStart);
  for (final child in node.nodes) {
    for (final piece in _choirPieces(child)) {
      yield (html: '$opening${piece.html}$closing', isMarker: piece.isMarker);
    }
  }
}

String _markInlineReadingReference(String html) => html.replaceAllMapped(
  _paragraphPattern,
  (paragraph) {
    final content = paragraph.group(2) ?? '';
    final visible = _visibleText(content);
    if (!RegExp(
      r'^(?:ПЕРШАЕ|ДРУГОЕ|КАРОТКАЕ)?\s*ЧЫТАННЕ(?:\s|$)',
      caseSensitive: false,
    ).hasMatch(visible)) {
      return paragraph.group(0)!;
    }
    final marked = content.replaceFirstMapped(
      RegExp(r'\(([^<>]{1,80})\)'),
      (match) =>
          '<span class="liturgical-reading-reference">${match.group(0)}</span>',
    );
    return '<p${paragraph.group(1) ?? ''}>$marked</p>';
  },
);

String _normalizeLegacyPresentation(String html) => html.replaceAllMapped(
  RegExp(r'''\sstyle\s*=\s*(["'])(.*?)\1''', caseSensitive: false),
  (match) {
    var style = match.group(2) ?? '';
    style = style
        .replaceAll(
          RegExp(
            r'''(?:text-align|margin-left|font-size)\s*:[^;"']*;?''',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
    return style.isEmpty
        ? ''
        : ' style=${match.group(1)}$style${match.group(1)}';
  },
);

String _normalizeRubricColors(String html) {
  return html.replaceAllMapped(
    RegExp(r'<(span|font)\b([^>]*)>', caseSensitive: false),
    (match) {
      final attributes = match.group(2) ?? '';
      final hasRubricColor = RegExp(
        r'''(?:color\s*:\s*(?:red|#ff0000)|color\s*=\s*["']?(?:red|#ff0000))''',
        caseSensitive: false,
      ).hasMatch(attributes);
      if (!hasRubricColor) return match.group(0)!;

      var cleaned = attributes
          .replaceAll(
            RegExp(r'color\s*:\s*(?:red|#ff0000)\s*;?', caseSensitive: false),
            '',
          )
          .replaceAll(
            RegExp(
              r'''\s+color\s*=\s*(?:["'](?:red|#ff0000)["']|(?:red|#ff0000))''',
              caseSensitive: false,
            ),
            '',
          );
      cleaned = _withClass(cleaned, 'liturgical-rubric-inline');
      return '<${match.group(1)}$cleaned>';
    },
  );
}

String _markLeadingMetadata(
  String html, {
  int? limit = 2,
  bool psalmMetadata = false,
}) {
  var remaining = limit;
  var canMark = true;
  return html.replaceAllMapped(_paragraphPattern, (match) {
    final attributes = match.group(1) ?? '';
    final content = match.group(2) ?? '';
    final visible = _visibleText(content);

    // Explicit document roles own their typography. In particular, opening
    // rubrics must not be reclassified as smaller leading metadata merely
    // because all of their source text is red or emphasized.
    if (_hasClass(attributes, 'liturgical-rubric') ||
        _hasClass(attributes, 'office-reading-pericope-title')) {
      return match.group(0)!;
    }

    if (RegExp(
      r'^(?:ПЕРШАЕ|ДРУГОЕ)\s+ЧЫТАННЕ\s*$',
      caseSensitive: false,
    ).hasMatch(visible)) {
      return '<p${_withClass(attributes, 'liturgical-heading')}>$content</p>';
    }

    final centered = RegExp(
      r'text-align\s*:\s*center',
      caseSensitive: false,
    ).hasMatch(attributes);
    final outerItalic = RegExp(
      r'font-style\s*:\s*italic',
      caseSensitive: false,
    ).hasMatch(attributes);
    final italic =
        outerItalic || _allVisibleTextStyled(content, italicOnly: true);
    final emphasized = italic || _allVisibleTextStyled(content);
    final red = _allVisibleTextIsRubric(content, visible);
    final psalmTitle =
        psalmMetadata &&
        RegExp(r'^Псальм\s+\d+', caseSensitive: false).hasMatch(visible);

    // Legacy instructions sometimes have only a red inline span. Their
    // semantic role is the entire paragraph, unlike K./N. dialogue markers.
    if (!psalmMetadata &&
        (red ||
            RegExp(
              r'color\s*:\s*(?:red|#ff0000)',
              caseSensitive: false,
            ).hasMatch(content)) &&
        RegExp(
          r'^(?:Потым|Калі|Пасля|Перад|Паводле)(?:\s|$|[.,])',
          caseSensitive: false,
        ).hasMatch(visible)) {
      return '<p${_withClass(attributes, 'liturgical-rubric')}>$content</p>';
    }

    final hasRoom = remaining == null || remaining! > 0;
    if (canMark && hasRoom && (centered || emphasized || red || psalmTitle)) {
      if (remaining != null && remaining! > 0) {
        remaining = remaining! - 1;
      }
      final className = psalmMetadata
          ? 'liturgical-subheading psalm-metadata${italic && !red && !psalmTitle ? ' psalm-subtitle' : ''}'
          : 'liturgical-subheading';
      return '<p${_withClass(attributes, className)}>$content</p>';
    }

    if (!RegExp(
      r'^(?:ПЕРШАЕ|ДРУГОЕ|КАРОТКАЕ)\s+ЧЫТАННЕ',
      caseSensitive: false,
    ).hasMatch(visible)) {
      canMark = false;
    }
    return match.group(0)!;
  });
}

bool _allVisibleTextStyled(String html, {bool italicOnly = false}) {
  final root = parseFragment(html);
  var sawText = false;
  var unstyled = false;
  void visit(dom.Node node, bool styled) {
    if (node is dom.Text) {
      if (node.data.trim().isNotEmpty) {
        sawText = true;
        if (!styled) unstyled = true;
      }
      return;
    }
    if (node is dom.Element) {
      final tag = node.localName;
      final style = node.attributes['style'] ?? '';
      styled =
          styled ||
          tag == 'em' ||
          tag == 'i' ||
          (!italicOnly && (tag == 'strong' || tag == 'b')) ||
          RegExp(
            r'font-style\s*:\s*italic',
            caseSensitive: false,
          ).hasMatch(style);
    }
    for (final child in node.nodes) {
      visit(child, styled);
    }
  }

  visit(root, false);
  return sawText && !unstyled;
}

bool _hasClass(String attributes, String className) {
  final match = RegExp(
    r'''\bclass\s*=\s*(["'])(.*?)\1''',
    caseSensitive: false,
  ).firstMatch(attributes);
  if (match == null) return false;
  return match
      .group(2)!
      .split(RegExp(r'\s+'))
      .any((value) => value.toLowerCase() == className.toLowerCase());
}

bool _allVisibleTextIsRubric(String content, String visible) {
  if (visible.isEmpty) return false;
  final styled = RegExp(
    r'''<(span|font)\b(?=[^>]*(?:color\s*:\s*(?:#ff0000|red)|color\s*=\s*["']?(?:#ff0000|red)))[^>]*>([\s\S]*?)</\1>''',
    caseSensitive: false,
  ).allMatches(content);
  if (styled.isEmpty) return false;
  final styledText = styled
      .map((match) => _visibleText(match.group(2)!))
      .join(' ');
  return _normalizeVisible(styledText) == _normalizeVisible(visible);
}

String _normalizeVisible(String value) =>
    value.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();

/// Removes a trailing antiphon only when composition already owns the exact
/// external antiphon. Generic psalm HTML is otherwise left untouched.
String stripEmbeddedAntiphon(String html, {String? externalAntiphon}) {
  final expected = _normalizeVisible(_visibleText(externalAntiphon ?? ''));
  if (expected.isEmpty) return html;
  final matches = _paragraphPattern.allMatches(html).toList();
  if (matches.isEmpty) return html;
  final last = matches.last;
  var actual = _normalizeVisible(_visibleText(last.group(2) ?? ''));
  actual = actual.replaceFirst(RegExp(r'^ант\.?\s*', caseSensitive: false), '');
  final normalizedExpected = expected.replaceFirst(
    RegExp(r'^ант\.?\s*', caseSensitive: false),
    '',
  );
  if (actual != normalizedExpected) return html;
  return html.replaceRange(last.start, last.end, '');
}

bool ownsStructuredPsalmPackage(String html) =>
    RegExp(
      r'''class\s*=\s*["'][^"']*\bora-ant\b''',
      caseSensitive: false,
    ).hasMatch(html) &&
    RegExp(
      r'''class\s*=\s*["'][^"']*\bora-psalm\b''',
      caseSensitive: false,
    ).hasMatch(html);

bool structuredPsalmEndsWithAntiphon(String html) {
  final blocks = parseFragment(html).querySelectorAll('.ora-ant, .ora-psalm');
  return blocks.isNotEmpty && blocks.last.classes.contains('ora-ant');
}

/// Removes only the legacy structural label already supplied by composition.
/// Source/reference/body content following a break remains intact.
String stripLeadingReadingHeading(String html, String structuralLabel) {
  final expected = _normalizeVisible(structuralLabel);
  final fragment = parseFragment(html);

  // The legacy heading is sometimes its own paragraph and sometimes the
  // first line of a styled paragraph. Parsing first makes encoded spaces
  // (&#x20;, &#32; and &nbsp;) ordinary whitespace and keeps nested spans valid.
  final standalone = fragment
      .querySelectorAll('p, h1, h2, h3, h4, h5, h6')
      .where((element) => _normalizeVisible(element.text) == expected)
      .firstOrNull;
  if (standalone != null && _hasNoVisibleTextBefore(fragment, standalone)) {
    standalone.remove();
    return fragment.outerHtml;
  }

  final firstBreak = fragment.querySelector('br');
  if (firstBreak == null) return html;
  dom.Node lineRoot = fragment;
  var ancestor = firstBreak.parentNode;
  while (ancestor != null && ancestor != fragment) {
    if (ancestor is dom.Element &&
        const {'p', 'div', 'li'}.contains(ancestor.localName)) {
      lineRoot = ancestor;
      break;
    }
    ancestor = ancestor.parentNode;
  }

  final beforeBreak = <dom.Text>[];
  var reachedBreak = false;
  void collect(dom.Node node) {
    if (reachedBreak) return;
    if (identical(node, firstBreak)) {
      reachedBreak = true;
      return;
    }
    if (node is dom.Text) beforeBreak.add(node);
    for (final child in node.nodes.toList()) {
      collect(child);
      if (reachedBreak) return;
    }
  }

  collect(lineRoot);
  final firstLine = _normalizeVisible(
    beforeBreak.map((node) => node.data).join(' '),
  );
  if (firstLine != expected || !_hasNoVisibleTextBefore(fragment, lineRoot)) {
    return html;
  }

  for (final node in beforeBreak) {
    node.remove();
  }
  firstBreak.remove();
  return fragment.outerHtml;
}

bool _hasNoVisibleTextBefore(dom.Node root, dom.Node target) {
  var reachedTarget = false;
  final text = StringBuffer();

  void visit(dom.Node node) {
    if (reachedTarget) return;
    if (identical(node, target)) {
      reachedTarget = true;
      return;
    }
    if (node is dom.Text) text.write(node.data);
    for (final child in node.nodes) {
      visit(child);
      if (reachedTarget) return;
    }
  }

  visit(root);
  return reachedTarget && _normalizeVisible(text.toString()).isEmpty;
}

String _visibleText(String html) => html
    .replaceAll(RegExp(r'<[^>]*>'), ' ')
    .replaceAll(RegExp(r'&nbsp;|&#x0*20;', caseSensitive: false), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

String _withClass(String attributes, String className) {
  final classPattern = RegExp(
    r'''\bclass\s*=\s*(["'])(.*?)\1''',
    caseSensitive: false,
  );
  final match = classPattern.firstMatch(attributes);
  if (match == null) return '$attributes class="$className"';
  final quote = match.group(1)!;
  final classes = match.group(2)!;
  final replacement = 'class=$quote$classes $className$quote';
  return attributes.replaceRange(match.start, match.end, replacement);
}
