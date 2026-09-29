/// Semantic normalization of Holy Mass language variants.
///
/// The Belarusian and Latin variants are synced prayer documents and the
/// English one is a bundled asset; each marks the same liturgical elements in
/// its own way (headings vs. bold paragraphs vs. rubric blocks, `V./R.` vs.
/// `С./Н.` vs. bold responses, ...). This adapter assigns one set of semantic
/// classes to the rendered HTML so a single renderer style applies to every
/// language. It never rewrites wording: it only changes element types and
/// classes, joins fragments of one rubric sentence, wraps role abbreviations
/// that the source already contains, and normalizes whitespace.
library;

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' show parseFragment;

import 'package:mybrev_flutter/models/mass_ritual.dart';

/// CSS classes shared by the adapter and the renderer.
abstract final class MassBlockClass {
  static const major = 'mass-major';
  static const subsection = 'mass-subsection';
  static const minorHeading = 'mass-minor-heading';
  static const rubric = 'mass-rubric';
  static const cited = 'mass-cited';
  static const inlineRubric = 'mass-rubric-inline';
  static const spoken = 'mass-spoken';
  static const response = 'mass-response';
  static const roleLabel = 'mass-role';
  static const alternative = 'mass-alternative';
  static const posture = 'mass-posture';
}

/// Speaker metadata. Visible labels are shown only where the source text
/// itself contains the abbreviation; the role is kept as `data-role`.
enum MassRole { celebrant, people, all }

class MassDocumentChunk {
  const MassDocumentChunk({required this.html, this.section});

  final String html;
  final LocatedMassSection? section;
}

class MassSemanticDocument {
  const MassSemanticDocument({required this.chunks, required this.sections});

  /// Consecutive document parts; a new chunk starts at every located section.
  final List<MassDocumentChunk> chunks;
  final List<LocatedMassSection> sections;
}

/// Role abbreviations that appear in the sources, per variant language.
final Map<String, List<(RegExp, MassRole)>> _roleLabels = {
  'la': [
    (RegExp(r'^V\.(?=\s|$)'), MassRole.celebrant),
    (RegExp(r'^R\.(?=\s|$)'), MassRole.people),
  ],
  'be': [
    (RegExp(r'^[СC]\.:'), MassRole.celebrant),
    (RegExp(r'^Н\.:'), MassRole.people),
    (RegExp(r'^Цэлебрант:'), MassRole.celebrant),
    (RegExp(r'^Усе:'), MassRole.all),
  ],
};

/// Rubrics that introduce the congregation's part in variants without role
/// abbreviations for it (Belarusian): the following spoken block is a response.
final Map<String, RegExp> _peopleCues = {
  'be': RegExp(
    'адказва|адказаць|разам з народам|разам з вернікамі|усе разам|'
    'народ спявае|гавораць|працягваюць|спяваецца ці прамаўляецца',
    caseSensitive: false,
  ),
};

/// Variants whose spoken text is Latin-script while directions are Cyrillic
/// plain paragraphs (the Latin prayer uses Russian rubrics).
const _cyrillicDirections = {'la'};

final _alternativePattern = RegExp(
  r'^(?:or|vel|альбо|або|или)\s*:?$',
  caseSensitive: false,
);
final _posturePattern = RegExp(
  r'^all\s+(?:sit|stand|kneel)\.?$',
  caseSensitive: false,
);
final _breakPattern = RegExp(r'<br\s*/?>', caseSensitive: false);
final _space = RegExp(r'\s+');

MassSemanticDocument buildMassDocument(
  String html,
  MassVariant variant, {
  MassRitual ritual = kMassRitual,
}) {
  final fragment = parseFragment(html);
  // Whitespace-only text nodes between blocks carry no content.
  for (final node in fragment.nodes.toList()) {
    if (node is dom.Text && node.data.trim().isEmpty) node.remove();
  }
  final blocks = fragment.nodes.toList();

  _mergeCitedRubricPhrases(blocks);
  _mergeRoleLabelFragments(blocks, variant.language);

  final texts = [
    for (final node in blocks)
      node is dom.Element &&
              const {
                'h2',
                'h3',
                'h4',
                'h5',
                'h6',
                'p',
                'div',
                'aside',
              }.contains(node.localName)
          ? node.text
          : '',
  ];
  final located = ritual.locateSections(variant, texts);
  final byIndex = {for (final s in located) s.blockIndex: s};
  final firstSection = located.isEmpty ? 0 : located.first.blockIndex;

  // The congregation's part runs from a people cue until a rubric introduces
  // another speaker (ends with a colon) or a heading starts a new part.
  // Plain directions in between (bows, gestures) do not interrupt it.
  final peopleCue = _peopleCues[variant.language];
  var peoplePart = false;
  for (var i = 0; i < blocks.length; i++) {
    final node = blocks[i];
    if (node is! dom.Element) continue;

    if (byIndex[i] case final section?) {
      blocks[i] = _heading(node, section.isMajor);
      peoplePart = false;
      continue;
    }
    if (_isRubric(node)) {
      final text = _visible(node.text);
      final replaced = _classifyRubric(node, text);
      blocks[i] = replaced;
      if (replaced.classes.contains(MassBlockClass.rubric)) {
        if (peopleCue != null && peopleCue.hasMatch(text)) {
          peoplePart = true;
        } else if (text.endsWith(':')) {
          peoplePart = false;
        }
      }
      continue;
    }
    switch (node.localName) {
      case 'h2' || 'h3':
        peoplePart = false;
        node.classes.add(MassBlockClass.subsection);
      case 'h4' || 'h5' || 'h6':
        node.classes.add(MassBlockClass.minorHeading);
      case 'p':
        final text = _visible(node.text);
        if (_alternativePattern.hasMatch(text)) {
          blocks[i] = _replace(node, 'p', MassBlockClass.alternative);
        } else if (i > firstSection &&
            _cyrillicDirections.contains(variant.language) &&
            _isCyrillicOnly(text)) {
          final rubric = _rubricFrom(node.innerHtml)
            ..classes.add(MassBlockClass.rubric);
          node.replaceWith(rubric);
          blocks[i] = rubric;
        } else {
          final split = _classifySpoken(node, variant, response: peoplePart);
          if (split.length > 1 || !identical(split.single, node)) {
            final parent = node.parentNode!;
            final at = parent.nodes.indexOf(node);
            node.remove();
            parent.nodes.insertAll(at, split);
          }
        }
    }
  }

  final anchors = Map<dom.Node, LocatedMassSection>.identity();
  for (final section in located) {
    anchors[blocks[section.blockIndex]] = section;
  }
  final chunks = <MassDocumentChunk>[];
  var buffer = StringBuffer();
  LocatedMassSection? current;
  for (final node in fragment.nodes.toList()) {
    if (anchors[node] case final section?) {
      if (buffer.isNotEmpty || current != null) {
        chunks.add(
          MassDocumentChunk(html: buffer.toString(), section: current),
        );
      }
      buffer = StringBuffer();
      current = section;
    }
    buffer.write(_serialize(node));
  }
  if (buffer.isNotEmpty || current != null) {
    chunks.add(MassDocumentChunk(html: buffer.toString(), section: current));
  }
  return MassSemanticDocument(chunks: chunks, sections: located);
}

bool _isRubric(dom.Element node) => node.classes.contains('prayer-rubric');

String _visible(String text) => text.replaceAll(_space, ' ').trim();

/// Content of a rubric block: its single paragraph when present.
String _rubricInner(dom.Element rubric) {
  final children = rubric.children;
  if (children.length == 1 && children.single.localName == 'p') {
    return children.single.innerHtml.trim();
  }
  return rubric.innerHtml.trim();
}

dom.Element _rubricFrom(String inner) {
  final rubric = dom.Element.tag('div')..classes.add('prayer-rubric');
  rubric.append(dom.Element.tag('p')..innerHtml = inner);
  return rubric;
}

dom.Element _replace(dom.Element node, String tag, String className) {
  final inner = node.localName == 'div' ? _rubricInner(node) : node.innerHtml;
  final element = dom.Element.tag(tag)
    ..classes.add(className)
    ..innerHtml = inner.trim();
  node.replaceWith(element);
  return element;
}

/// Section markers become headings of the right level, whatever element the
/// source used (Markdown heading, bold paragraph, plain line or rubric).
dom.Element _heading(dom.Element node, bool major) {
  var inner = _isRubric(node) ? _rubricInner(node) : node.innerHtml.trim();
  // A paragraph that is only a bold run: the heading already carries weight.
  final bold = RegExp(
    r'^<(strong|b)>([^<]*)</\1>$',
    caseSensitive: false,
  ).firstMatch(inner);
  if (bold != null) inner = bold.group(2)!;
  final heading = dom.Element.tag(major ? 'h2' : 'h3')
    ..classes.add(major ? MassBlockClass.major : MassBlockClass.subsection)
    ..innerHtml = inner;
  node.replaceWith(heading);
  return heading;
}

dom.Element _classifyRubric(dom.Element node, String text) {
  if (_alternativePattern.hasMatch(text)) {
    return _replace(node, 'p', MassBlockClass.alternative);
  }
  if (_posturePattern.hasMatch(text)) {
    return _replace(node, 'p', MassBlockClass.posture);
  }
  node.classes.add(MassBlockClass.rubric);
  _spaceAfterSentences(node);
  return node;
}

/// Sources sometimes glue sentences (`моляцца.Потым`); add the missing space.
void _spaceAfterSentences(dom.Node node) {
  for (final child in node.nodes) {
    if (child is dom.Text) {
      var data = child.data.replaceAllMapped(
        RegExp(r'([a-zа-яёіў])\.([A-ZА-ЯЁІЎ])'),
        (m) => '${m[1]}. ${m[2]}',
      );
      // `…словамі <span>адары нас супакоем</span>.Затым`
      if (!identical(node.nodes.first, child)) {
        data = data.replaceFirst(RegExp(r'^\.(?=[A-ZА-ЯЁІЎ])'), '. ');
      }
      child.data = data;
    } else {
      _spaceAfterSentences(child);
    }
  }
}

bool _isCyrillicOnly(String text) =>
    RegExp('[А-Яа-яЁёІіЎў]').hasMatch(text) &&
    !RegExp('[A-Za-z]').hasMatch(text);

/// `Потым спяваецца` · `Аллелюя` · `альбо іншы спеў…`: one rubric sentence
/// split around a quoted phrase becomes a single rubric with the phrase
/// marked as cited text.
void _mergeCitedRubricPhrases(List<dom.Node> blocks) {
  for (var i = 0; i + 2 < blocks.length; i++) {
    final first = blocks[i], phrase = blocks[i + 1], rest = blocks[i + 2];
    if (first is! dom.Element ||
        phrase is! dom.Element ||
        rest is! dom.Element) {
      continue;
    }
    if (!_isRubric(first) || !_isRubric(rest) || phrase.localName != 'p') {
      continue;
    }
    final lead = _visible(first.text);
    final cited = _visible(phrase.text);
    final tail = _visible(rest.text);
    if (lead.isEmpty || lead.endsWith(':')) continue;
    if (cited.isEmpty ||
        cited.split(' ').length > 5 ||
        phrase.innerHtml.contains(_breakPattern)) {
      continue;
    }
    if (!RegExp(r'^(?:[,.;:)]|[a-zа-яёіў])').hasMatch(tail)) continue;

    final tailHtml = _rubricInner(rest);
    final joiner = RegExp(r'^[,.;:)]').hasMatch(tail) ? '' : ' ';
    final merged = _rubricFrom(
      '${_rubricInner(first)} '
      '<span class="${MassBlockClass.cited}">${phrase.innerHtml.trim()}</span>'
      '$joiner$tailHtml',
    );
    first.replaceWith(merged);
    phrase.remove();
    rest.remove();
    blocks
      ..removeRange(i, i + 3)
      ..insert(i, merged);
    i--; // The merged rubric may continue with another quoted phrase.
  }
}

/// `V.` · `(После чтения)` · `Verbum Domini.`: a bare role label, an inline
/// direction and the spoken words form one spoken line.
void _mergeRoleLabelFragments(List<dom.Node> blocks, String language) {
  final labels = _roleLabels[language];
  if (labels == null) return;
  for (var i = 0; i + 2 < blocks.length; i++) {
    final label = blocks[i], direction = blocks[i + 1], words = blocks[i + 2];
    if (label is! dom.Element ||
        direction is! dom.Element ||
        words is! dom.Element) {
      continue;
    }
    if (label.localName != 'p' ||
        !_isRubric(direction) ||
        words.localName != 'p') {
      continue;
    }
    final labelText = _visible(label.text);
    final isBareLabel = labels.any(
      (entry) =>
          entry.$1.hasMatch(labelText) &&
          labelText.replaceFirst(entry.$1, '').trim().isEmpty,
    );
    if (!isBareLabel) continue;
    final merged = dom.Element.tag('p')
      ..innerHtml =
          '$labelText <span class="${MassBlockClass.inlineRubric}">'
          '${_rubricInner(direction)}</span> ${words.innerHtml.trim()}';
    label.replaceWith(merged);
    direction.remove();
    words.remove();
    blocks
      ..removeRange(i, i + 3)
      ..insert(i, merged);
  }
}

/// Classifies a spoken paragraph: role labels already present in the source
/// are wrapped as labels; responses get the response class. English marks the
/// people's part in bold, so a mixed dialogue paragraph is split into the
/// leader's lines and the response.
List<dom.Element> _classifySpoken(
  dom.Element node,
  MassVariant variant, {
  required bool response,
}) {
  final lines = node.innerHtml.split(_breakPattern);
  final labels = _roleLabels[variant.language];

  if (labels != null) {
    var labelled = false;
    var allResponses = true;
    final out = <String>[];
    for (final line in lines) {
      final trimmed = line.trimLeft();
      (RegExp, MassRole)? hit;
      for (final entry in labels) {
        if (entry.$1.hasMatch(trimmed)) {
          hit = entry;
          break;
        }
      }
      if (hit == null) {
        allResponses = false;
        out.add(line);
        continue;
      }
      labelled = true;
      final label = hit.$1.firstMatch(trimmed)![0]!;
      final rest = trimmed.substring(label.length).trimLeft();
      final role = hit.$2;
      final isResponse = role != MassRole.celebrant;
      if (!isResponse) allResponses = false;
      final body = isResponse && lines.length > 1
          ? '<span class="${MassBlockClass.response}">$rest</span>'
          : rest;
      out.add(
        '<span class="${MassBlockClass.roleLabel}" data-role="${role.name}">'
        '$label</span> $body',
      );
    }
    if (labelled) {
      node
        ..innerHtml = out.join('<br>')
        ..classes.add(
          allResponses ? MassBlockClass.response : MassBlockClass.spoken,
        );
      return [node];
    }
  }

  if (variant.strongMarksResponses) {
    bool strong(String line) =>
        RegExp(r'^\s*<strong>[\s\S]*</strong>\s*$').hasMatch(line);
    final groups = <(bool, List<String>)>[];
    for (final line in lines) {
      final isStrong = strong(line);
      if (groups.isNotEmpty && groups.last.$1 == isStrong) {
        groups.last.$2.add(line);
      } else {
        groups.add((isStrong, [line]));
      }
    }
    if (groups.length == 1) {
      node.classes.add(
        groups.single.$1 ? MassBlockClass.response : MassBlockClass.spoken,
      );
      return [node];
    }
    return [
      for (final (isStrong, group) in groups)
        dom.Element.tag('p')
          ..classes.add(
            isStrong ? MassBlockClass.response : MassBlockClass.spoken,
          )
          ..innerHtml = group.join('<br>'),
    ];
  }

  node.classes.add(response ? MassBlockClass.response : MassBlockClass.spoken);
  return [node];
}

String _serialize(dom.Node node) => node is dom.Element
    ? node.outerHtml
    : (node.text ?? '')
          .replaceAll('&', '&amp;')
          .replaceAll('<', '&lt;')
          .replaceAll('>', '&gt;');
