/// Semantic adapter for the Holy Mass language variants.
///
/// A port of MyBrev's `src/utils/massContent.js` (rules in its
/// `docs/holy-mass.md`): the rendered prayer HTML of a variant becomes a list
/// of semantic blocks with a type, a role and a section, and one shared markup
/// is produced for every language. It understands both the current and the
/// migrated (V4) texts.
///
/// It never edits wording. It only regroups existing text into blocks and
/// drops markup that merely encoded structure: a heading's wrapping bold, a
/// speaker prefix that became role metadata, the English "bold = people"
/// convention. A major section always shows its canonical Belarusian title.
library;

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' show parseFragment;

import 'package:mybrev_flutter/models/mass_ritual.dart';

/// Block types, as listed in the ritual's `blockTypes`.
abstract final class MassBlockType {
  static const majorSection = 'majorSection';
  static const subsection = 'subsection';
  static const heading = 'heading';
  static const rubric = 'rubric';
  static const comment = 'comment';
  static const posture = 'posture';
  static const alternative = 'alternative';
  static const spoken = 'spoken';
  static const response = 'response';
  static const separator = 'separator';
}

/// CSS classes shared by the adapter and the renderer.
abstract final class MassBlockClass {
  static const major = 'mass-major';
  static const subsection = 'mass-subsection';
  static const minorHeading = 'mass-minor-heading';
  static const rubric = 'mass-rubric';
  static const comment = 'mass-comment';
  static const cited = 'mass-cited';
  static const spoken = 'mass-spoken';
  static const response = 'mass-response';

  /// Compact speaker label of a dialogue line (`С.`, `V.`, `P.`…).
  static const roleLabel = 'mass-role';
  static const alternative = 'mass-alternative';
  static const inlineAlternative = 'mass-alternative-inline';
  static const posture = 'mass-posture';
}

/// One semantic block of a Mass text.
class MassBlock {
  const MassBlock({
    required this.type,
    required this.text,
    this.role,
    this.speakerLabel,
    this.sourceLabel,
    this.sectionId,
  });

  /// One of [MassBlockType].
  final String type;

  /// Visible text, without the speaker label.
  final String text;

  /// Speaker role (`priest`, `people`, `all`…), when known.
  final String? role;

  /// Compact label shown by the reader; only set inside a dialogue.
  final String? speakerLabel;

  /// Speaker prefix found in the source text (metadata only).
  final String? sourceLabel;
  final String? sectionId;
}

class MassDocumentChunk {
  const MassDocumentChunk({required this.html, this.section});

  final String html;
  final LocatedMassSection? section;
}

class MassSemanticDocument {
  const MassSemanticDocument({
    required this.chunks,
    required this.sections,
    this.blocks = const [],
  });

  /// Consecutive document parts; a new chunk starts at every located section.
  final List<MassDocumentChunk> chunks;
  final List<LocatedMassSection> sections;
  final List<MassBlock> blocks;
}

const _classifyOrder = [
  MassBlockType.heading,
  MassBlockType.rubric,
  MassBlockType.comment,
  MassBlockType.posture,
  MassBlockType.alternative,
];

final _breakPattern = RegExp(r'<br\s*/?>', caseSensitive: false);
final _space = RegExp(r'\s+');
final _wholeStrong = RegExp(
  r'^<(strong|b)>((?:(?!</?(?:strong|b)>)[\s\S])+)</\1>$',
  caseSensitive: false,
);
final _startsWithPunctuation = RegExp(r'^\p{P}', unicode: true);
final _startsLowerOrPunctuation = RegExp(r'^[\p{Ll}\p{P}]', unicode: true);
final _endsSentence = RegExp(r'[.:!?;]$');

class _Block {
  _Block(this.type, this.html, {String? source}) : source = source ?? html;

  String type;

  /// Inner HTML shown for the block.
  String html;

  /// HTML the block came from, before prefixes and bold were removed.
  String source;
  String? role;
  String? label;
  String? speakerLabel;
  String? sectionId;

  /// The role is written in the source (a prefix or the bold convention).
  bool explicit = false;

  /// A plain run answered by a bold one in the same paragraph.
  bool call = false;

  /// A rubric sentence split around cited words.
  List<({String html, bool cited})>? parts;

  /// Markup passed through unchanged (lists and other unknown elements).
  String? raw;

  String get text => _visible(html);
  String get sourceText => _visible(source);
}

String _visible(String html) =>
    (parseFragment(html).text ?? '').replaceAll(_space, ' ').trim();

String _escape(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

String _stripWrappingStrong(String html) {
  final trimmed = html.trim();
  return _wholeStrong.firstMatch(trimmed)?.group(2)?.trim() ?? trimmed;
}

MassSemanticDocument buildMassDocument(
  String html,
  MassVariant variant, {
  MassRitual ritual = kMassRitual,
}) {
  var blocks = <_Block>[];
  for (final node in parseFragment(html).nodes) {
    blocks.addAll(_sourceBlocks(node, variant));
  }

  for (final block in blocks) {
    _classify(block, variant);
  }
  blocks = _foldLabelOnlyBlocks(blocks);
  blocks = _mergeQuotedRubrics(blocks);
  _applyRoleCues(blocks, variant);
  _applyRoleMarkers(blocks, variant);
  final responseRoles = ritual.rolePolicy.responseRoles;
  for (final block in blocks) {
    if (block.type == MassBlockType.spoken &&
        responseRoles.contains(block.role)) {
      block.type = MassBlockType.response;
    }
  }
  _applySpeakerLabels(blocks, variant, ritual.rolePolicy);

  final located = ritual.locateSections(variant, [
    for (final block in blocks) block.raw == null ? block.sourceText : '',
  ]);
  final byIndex = {for (final s in located) s.blockIndex: s};
  for (final section in located) {
    final block = blocks[section.blockIndex]
      ..sectionId = section.sectionId
      ..type = section.isMajor
          ? MassBlockType.majorSection
          : MassBlockType.subsection
      ..role = null
      ..parts = null
      ..speakerLabel = null;
    // A major section always shows its canonical Belarusian name, whatever
    // heading the source still carries.
    block.html = section.isMajor
        ? _escape(ritual.section(section.sectionId)!.title)
        : _stripWrappingStrong(block.html);
  }

  final alternatives = variant.classify[MassBlockType.alternative] ?? const [];
  final chunks = <MassDocumentChunk>[];
  var buffer = StringBuffer();
  LocatedMassSection? current;
  for (var i = 0; i < blocks.length; i++) {
    if (byIndex[i] case final section?) {
      if (buffer.isNotEmpty || current != null) {
        chunks.add(
          MassDocumentChunk(html: buffer.toString(), section: current),
        );
      }
      buffer = StringBuffer();
      current = section;
    }
    buffer.write(_render(blocks[i], alternatives));
  }
  if (buffer.isNotEmpty || current != null) {
    chunks.add(MassDocumentChunk(html: buffer.toString(), section: current));
  }
  return MassSemanticDocument(
    chunks: chunks,
    sections: located,
    blocks: [
      for (final block in blocks)
        if (block.raw == null)
          MassBlock(
            type: block.type,
            text: block.parts == null
                ? block.text
                : _visible(_joinParts(block)),
            role: block.role,
            speakerLabel: block.speakerLabel,
            sourceLabel: block.label,
            sectionId: block.sectionId,
          ),
    ],
  );
}

/// Heading, paragraph, rubric and separator blocks of one top-level node.
List<_Block> _sourceBlocks(dom.Node node, MassVariant variant) {
  if (node is dom.Text) {
    final text = node.data.trim();
    return text.isEmpty ? const [] : _splitParagraph(_escape(text), variant);
  }
  if (node is! dom.Element) return const [];
  final name = node.localName;
  if (name == 'hr') return [_Block(MassBlockType.separator, '')];
  if (name != null && RegExp(r'^h[1-6]$').hasMatch(name)) {
    final inner = node.innerHtml.trim();
    if (inner.isEmpty) return const [];
    return [
      _Block(MassBlockType.heading, _stripWrappingStrong(inner), source: inner),
    ];
  }
  if (node.classes.contains('prayer-rubric')) {
    final paragraphs = node.children.where((e) => e.localName == 'p').toList();
    final inners =
        paragraphs.length == node.nodes.whereType<dom.Element>().length &&
            paragraphs.isNotEmpty
        ? [for (final p in paragraphs) p.innerHtml.trim()]
        : [node.innerHtml.trim()];
    return [
      for (final inner in inners)
        if (_visible(inner).isNotEmpty) _Block(MassBlockType.rubric, inner),
    ];
  }
  if (name == 'p') {
    final inner = node.innerHtml.trim();
    return _visible(inner).isEmpty ? const [] : _splitParagraph(inner, variant);
  }
  return [_Block(MassBlockType.spoken, '')..raw = node.outerHtml];
}

({String label, String rest})? _speakerLabelOf(
  String line,
  List<String> labels,
) {
  for (final label in labels) {
    if (!line.startsWith(label)) continue;
    final rest = line.substring(label.length);
    if (label.endsWith(':') || rest.isEmpty || rest.startsWith(_space)) {
      return (label: label, rest: rest.trim());
    }
  }
  return null;
}

/// Splits a paragraph into spoken blocks by speaker prefix or by bold lines.
List<_Block> _splitParagraph(String inner, MassVariant variant) {
  final lines = inner.split(_breakPattern);

  if (variant.strongMarksResponses) {
    final runs = <({bool response, List<String> lines, List<String> source})>[];
    for (final line in lines) {
      final trimmed = line.trim();
      final strong = _wholeStrong.firstMatch(trimmed);
      final response = strong != null;
      final content = response ? strong.group(2)!.trim() : trimmed;
      if (runs.isNotEmpty && runs.last.response == response) {
        runs.last.lines.add(content);
        runs.last.source.add(trimmed);
      } else {
        runs.add((response: response, lines: [content], source: [trimmed]));
      }
    }
    // A plain run answered by a bold one in the same paragraph is the call of
    // a call-and-response pair; its role comes from cues or `callRole`.
    return [
      for (var i = 0; i < runs.length; i++)
        _Block(
            runs[i].response ? MassBlockType.response : MassBlockType.spoken,
            runs[i].lines.join('<br>'),
            source: runs[i].source.join('<br>'),
          )
          ..role = runs[i].response ? 'people' : null
          ..explicit =
              runs[i].response || (i + 1 < runs.length && runs[i + 1].response)
          ..call =
              !runs[i].response && i + 1 < runs.length && runs[i + 1].response,
    ];
  }

  final labels = variant.speakerLabels.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  if (labels.isEmpty) return [_Block(MassBlockType.spoken, inner)];

  final blocks = <_Block>[];
  for (final line in lines) {
    final trimmed = line.trim();
    final speaker = _speakerLabelOf(trimmed, labels);
    if (speaker != null) {
      blocks.add(
        _Block(MassBlockType.spoken, speaker.rest, source: trimmed)
          ..role = variant.speakerLabels[speaker.label]
          ..label = speaker.label
          ..explicit = true,
      );
    } else if (blocks.isNotEmpty) {
      final current = blocks.last;
      current.html = current.html.isEmpty
          ? trimmed
          : '${current.html}<br>$trimmed';
      current.source = '${current.source}<br>$trimmed';
    } else {
      blocks.add(_Block(MassBlockType.spoken, trimmed));
    }
  }
  return blocks;
}

void _classify(_Block block, MassVariant variant) {
  if (block.label != null ||
      block.raw != null ||
      block.type == MassBlockType.separator) {
    return;
  }
  final source = block.sourceText;
  for (final type in _classifyOrder) {
    final markers = variant.classify[type] ?? const [];
    if (!markers.any((marker) => massMarkerMatches(marker, source))) continue;
    block
      ..type = type
      ..role = null;
    if (type == MassBlockType.heading) {
      block.html = _stripWrappingStrong(block.html);
    }
    return;
  }
}

/// A speaker prefix with no text of its own gives its role to the next line.
List<_Block> _foldLabelOnlyBlocks(List<_Block> blocks) {
  final result = <_Block>[];
  ({String? role, String label})? pending;
  for (final block in blocks) {
    final spoken = block.type == MassBlockType.spoken && block.raw == null;
    if (spoken && block.label != null && block.text.isEmpty) {
      pending = (role: block.role, label: block.label!);
      continue;
    }
    if (spoken &&
        pending != null &&
        block.label == null &&
        block.role == null) {
      block
        ..role = pending.role
        ..label = pending.label
        ..explicit = true;
      pending = null;
    } else if (block.label != null) {
      pending = null;
    }
    result.add(block);
  }
  return result;
}

String _joinParts(_Block block) {
  final out = StringBuffer();
  final parts = block.parts!;
  for (var i = 0; i < parts.length; i++) {
    final part = parts[i];
    if (i > 0 && !_startsWithPunctuation.hasMatch(_visible(part.html))) {
      out.write(' ');
    }
    out.write(
      part.cited
          ? '<span class="${MassBlockClass.cited}">${part.html}</span>'
          : part.html,
    );
  }
  return out.toString();
}

/// Some rubrics quote a word the people or the cantor say («Потым спяваецца /
/// Аллелюя / альбо іншы спеў…»). The source splits that sentence into three
/// blocks; keep it one rubric sentence with the quoted words marked.
List<_Block> _mergeQuotedRubrics(List<_Block> blocks) {
  final result = <_Block>[];
  for (var i = 0; i < blocks.length; i++) {
    final before = blocks[i];
    final quoted = i + 1 < blocks.length ? blocks[i + 1] : null;
    final after = i + 2 < blocks.length ? blocks[i + 2] : null;
    final isQuote =
        quoted != null &&
        after != null &&
        before.type == MassBlockType.rubric &&
        before.parts == null &&
        !_endsSentence.hasMatch(before.text) &&
        quoted.type == MassBlockType.spoken &&
        quoted.raw == null &&
        quoted.label == null &&
        !quoted.html.contains(_breakPattern) &&
        quoted.text.split(_space).length <= 4 &&
        after.type == MassBlockType.rubric &&
        _startsLowerOrPunctuation.hasMatch(after.text);
    if (!isQuote) {
      result.add(before);
      continue;
    }
    final merged = _Block(MassBlockType.rubric, '')
      ..parts = [
        (html: before.html, cited: false),
        (html: quoted.html.trim(), cited: true),
        (html: after.html, cited: false),
      ];
    merged
      ..html = _joinParts(merged)
      ..source = merged.html;
    result.add(merged);
    i += 2;
  }
  return result;
}

String? _cueRole(String rubricText, Map<String, List<String>> cues) {
  final text = normalizeMassMarker(rubricText);
  String? role;
  var best = -1;
  cues.forEach((candidate, phrases) {
    for (final phrase in phrases) {
      final position = text.lastIndexOf(normalizeMassMarker(phrase));
      if (position > best) {
        best = position;
        role = candidate;
      }
    }
  });
  return role;
}

/// Explicit rubrics such as «Народ адказвае:» give the following lines a role.
void _applyRoleCues(List<_Block> blocks, MassVariant variant) {
  final cues = variant.roleCues;
  if (cues.isEmpty) return;
  String? role;
  for (final block in blocks) {
    if (block.type == MassBlockType.rubric) {
      role = _cueRole(block.text, cues);
    } else if (block.type != MassBlockType.spoken ||
        block.raw != null ||
        block.label != null) {
      role = null;
    } else if (role != null && block.role == null) {
      block.role = role;
    }
  }
}

/// Roles the source expresses neither by a prefix nor by a rubric cue: texts
/// listed in `roleMarkers` (Gloria, Credo…), then `callRole` for the call of a
/// call-and-response paragraph.
void _applyRoleMarkers(List<_Block> blocks, MassVariant variant) {
  for (final block in blocks) {
    if (block.type != MassBlockType.spoken ||
        block.raw != null ||
        block.role != null) {
      continue;
    }
    final source = block.sourceText;
    String? found;
    for (final entry in variant.roleMarkers.entries) {
      if (entry.value.any((marker) => massMarkerMatches(marker, source))) {
        found = entry.key;
        break;
      }
    }
    if (found != null) {
      block.role = found;
    } else if (block.call && variant.callRole != null) {
      block.role = variant.callRole;
    }
  }
}

/// Label policy `dialogue`: a compact speaker label is shown only inside a
/// real exchange — a call whose answer follows immediately, and that answer.
/// Both roles must be explicit in the source (a prefix, or the bold
/// convention); roles inferred from rubrics or markers never get a label, so
/// long prayers, hymns and rubric-led lines stay clean.
void _applySpeakerLabels(
  List<_Block> blocks,
  MassVariant variant,
  MassRolePolicy policy,
) {
  if (!policy.showSpeakerLabels) return;
  final labels = variant.roleLabels;
  bool voiced(_Block? block) =>
      block != null &&
      block.raw == null &&
      block.explicit &&
      block.role != null &&
      (block.type == MassBlockType.spoken ||
          block.type == MassBlockType.response);
  final dialogueOnly = policy.labelPolicy == 'dialogue';
  final labelled = <int>[];
  for (var i = 0; i < blocks.length; i++) {
    final block = blocks[i];
    if (!voiced(block) || labels[block.role] == null) continue;
    final previous = i > 0 ? blocks[i - 1] : null;
    final next = i + 1 < blocks.length ? blocks[i + 1] : null;
    final inDialogue =
        !dialogueOnly ||
        (block.type == MassBlockType.response
            ? voiced(previous) && previous!.type == MassBlockType.spoken
            : voiced(next) && next!.type == MassBlockType.response);
    if (inDialogue) labelled.add(i);
  }
  for (final i in labelled) {
    blocks[i].speakerLabel = labels[blocks[i].role];
  }
}

/// Marks inline alternatives (`… Or: Kyrie, eleison.`) outside of HTML tags.
String _markInlineAlternatives(String html, List<String> labels) {
  if (labels.isEmpty) return html;
  final pattern = RegExp(
    '(^|\\s)(${labels.map((l) => RegExp.escape(_escape(l))).join('|')})'
    r'(?=\s|$)',
  );
  final out = StringBuffer();
  var cursor = 0;
  String mark(String text) => text.replaceAllMapped(
    pattern,
    (m) =>
        '${m[1]}<span class="${MassBlockClass.inlineAlternative}">${m[2]}</span>',
  );
  for (final tag in RegExp(r'<[^>]+>').allMatches(html)) {
    out
      ..write(mark(html.substring(cursor, tag.start)))
      ..write(tag[0]);
    cursor = tag.end;
  }
  out.write(mark(html.substring(cursor)));
  return out.toString();
}

/// Sources sometimes glue sentences (`моляцца.Потым`); add the missing space.
/// Whitespace only, and only in rubrics.
String _spaceAfterSentences(String html) {
  final fragment = parseFragment(html);
  void visit(dom.Node node, {required bool first}) {
    var isFirst = first;
    for (final child in node.nodes) {
      if (child is dom.Text) {
        var data = child.data.replaceAllMapped(
          RegExp(r'([a-zа-яёіў])\.([A-ZА-ЯЁІЎ])'),
          (m) => '${m[1]}. ${m[2]}',
        );
        // `…словамі <span>адары нас супакоем</span>.Затым`
        if (!isFirst) {
          data = data.replaceFirst(RegExp(r'^\.(?=[A-ZА-ЯЁІЎ])'), '. ');
        }
        child.data = data;
      } else {
        visit(child, first: isFirst);
      }
      isFirst = false;
    }
  }

  visit(fragment, first: true);
  return fragment.outerHtml;
}

String _render(_Block block, List<String> alternatives) {
  if (block.raw case final raw?) return raw;
  final role = block.role == null ? '' : ' data-role="${_escape(block.role!)}"';
  String tag(String name, String className, String inner) =>
      '<$name class="$className"$role>$inner</$name>';
  switch (block.type) {
    case MassBlockType.separator:
      return '<hr>';
    case MassBlockType.majorSection:
      return tag('h2', MassBlockClass.major, block.html);
    case MassBlockType.subsection:
      return tag('h3', MassBlockClass.subsection, block.html);
    case MassBlockType.heading:
      return tag('h4', MassBlockClass.minorHeading, block.html);
    case MassBlockType.rubric:
      return '<div class="prayer-rubric ${MassBlockClass.rubric}">'
          '<p>${_spaceAfterSentences(block.html)}</p></div>';
    case MassBlockType.comment:
      return tag('p', MassBlockClass.comment, block.html);
    case MassBlockType.posture:
      return tag('p', MassBlockClass.posture, block.html);
    case MassBlockType.alternative:
      return tag('p', MassBlockClass.alternative, block.html);
  }
  var inner = _markInlineAlternatives(block.html, alternatives);
  if (block.speakerLabel case final label?) {
    inner =
        '<span class="${MassBlockClass.roleLabel}">${_escape(label)}</span> $inner';
  }
  return tag(
    'p',
    block.type == MassBlockType.response
        ? MassBlockClass.response
        : MassBlockClass.spoken,
    inner,
  );
}
