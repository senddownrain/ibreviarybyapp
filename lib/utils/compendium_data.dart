// Pure helpers for the canonical Compendium dataset. Dart port of MyBrev
// `src/utils/compendiumData.js`
// (see docs/compendium.md). No Flutter, Hive or Firebase imports.

import 'package:mybrev_flutter/models/compendium.dart';

const kCompendiumSchemaVersion = 1;
const kCompendiumExpectedQuestionCount = 598;

final _cccRef = RegExp(r'^\d+(?:-\d+)?$');
final _introMarkers = [
  RegExp(r'motu\s+proprio', caseSensitive: false),
  RegExp(r'^УВОДЗІНЫ$', unicode: true),
  RegExp(r'Бенедыкт\s+XVI', unicode: true),
];

bool _isText(Object? value) => value is String && value.trim().isNotEmpty;

/// JavaScript `Number.isInteger`.
bool _isInteger(Object? value) =>
    value is int ||
    (value is double && value.isFinite && value == value.truncateToDouble());

Map<String, dynamic>? _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : null;

List<Map<String, dynamic>> _maps(Object? value) => value is List
    ? [for (final item in value) _map(item) ?? const <String, dynamic>{}]
    : const [];

/// Structural validation of a canonical dataset map. Returns human-readable
/// errors; an empty list means the dataset is safe to render and index.
/// Same checks and limits as MyBrev `validateCompendiumDataset`.
List<String> validateCompendiumDataset(
  Object? dataset, {
  int expectedQuestionCount = kCompendiumExpectedQuestionCount,
}) {
  final errors = <String>[];
  void fail(String message) {
    if (errors.length < 50) errors.add(message);
  }

  final root = _map(dataset);
  if (root == null) return ['Dataset is not an object.'];
  final meta = _map(root['meta']);
  final parts = root['parts'];
  final units = root['units'];
  if (meta == null || meta['schemaVersion'] != kCompendiumSchemaVersion) {
    fail('Unsupported schemaVersion: ${meta?['schemaVersion']}');
  }
  final contentVersion = meta?['contentVersion'];
  if (!_isInteger(contentVersion) || (contentVersion as num) < 1) {
    fail('meta.contentVersion must be a positive integer.');
  }
  if (!_isText(meta?['sourceUrl']) || !_isText(meta?['sourceTitle'])) {
    fail('Source attribution is missing.');
  }
  if (parts is! List || parts.length != 4) fail('Expected exactly four parts.');
  if (units is! List || units.isEmpty) {
    return [...errors, 'Units are missing.'];
  }

  final partNumbers = {
    if (parts is List)
      for (final part in _maps(parts)) part['number'],
  };
  final unitIds = <Object?>{};
  final topicIds = <Object?>{};
  var expectedNumber = 1;
  num previousPart = 0;
  final unitMaps = _maps(units);
  for (var unitIndex = 0; unitIndex < unitMaps.length; unitIndex++) {
    final unit = unitMaps[unitIndex];
    final unitId = unit['id'];
    if (!_isText(unitId) || unitIds.contains(unitId)) {
      fail('Invalid or duplicate unit id at $unitIndex.');
    }
    unitIds.add(unitId);
    if (unit['order'] != unitIndex + 1) {
      fail(
        'Unit $unitId has order ${unit['order']}, expected ${unitIndex + 1}.',
      );
    }
    if (!partNumbers.contains(unit['partNumber'])) {
      fail('Unit $unitId references unknown part ${unit['partNumber']}.');
    }
    final partNumber = unit['partNumber'];
    if (partNumber is num && partNumber < previousPart) {
      fail('Unit $unitId breaks part order.');
    }
    if (partNumber is num) previousPart = partNumber;
    final questions = unit['questions'];
    if (questions is! List || questions.isEmpty) {
      fail('Unit $unitId has no questions.');
    }
    final topics = _maps(unit['topics']);
    final unitTopics = {for (final topic in topics) topic['id']: topic};
    for (var topicIndex = 0; topicIndex < topics.length; topicIndex++) {
      final topic = topics[topicIndex];
      if (!_isText(topic['id']) || topicIds.contains(topic['id'])) {
        fail('Invalid or duplicate topic id in $unitId.');
      }
      topicIds.add(topic['id']);
      if (topic['order'] != topicIndex + 1) {
        fail('Topic ${topic['id']} has order ${topic['order']}.');
      }
      if (!_isText(topic['title'])) fail('Topic ${topic['id']} has no title.');
    }
    var previousTopicIndex = -1;
    final questionMaps = _maps(questions);
    for (final question in questionMaps) {
      final number = question['number'];
      final label = 'Question $number';
      if (number != expectedNumber) {
        fail(
          '$label: expected number $expectedNumber (gap, duplicate or order error).',
        );
      }
      expectedNumber =
          (_isInteger(number) ? (number as num).toInt() : expectedNumber) + 1;
      final expectedId = _isInteger(number)
          ? 'q${(number as num).toInt().toString().padLeft(3, '0')}'
          : 'q$number';
      if (question['id'] != expectedId) {
        fail('$label: unexpected id ${question['id']}.');
      }
      if (question['order'] != number) {
        fail('$label: order ${question['order']} differs from number.');
      }
      if (!_isText(question['question'])) fail('$label: empty question.');
      if (!_isText(question['answer'])) fail('$label: empty answer.');
      final refs = question['cccRefs'];
      if (refs is! List ||
          refs.any((ref) => ref is! String || !_cccRef.hasMatch(ref))) {
        fail('$label: invalid cccRefs.');
      }
      final topicId = question['topicId'];
      if (topicId != null) {
        final topic = unitTopics[topicId];
        if (topic == null) {
          fail('$label: unknown topic $topicId.');
        } else {
          if (question['topicTitle'] != topic['title']) {
            fail('$label: topicTitle differs from topic.');
          }
          final topicIndex = topics.indexOf(topic);
          if (topicIndex < previousTopicIndex) {
            fail('$label: topic order is not monotonic.');
          }
          previousTopicIndex = topicIndex;
          final first = topic['firstQuestion'];
          final last = topic['lastQuestion'];
          if (number is! num ||
              first is! num ||
              last is! num ||
              number < first ||
              number > last) {
            fail('$label: outside topic range.');
          }
        }
      } else if (previousTopicIndex >= 0) {
        fail('$label: question without topic after a topic.');
      }
      final answer = question['answer'];
      final answerLength = answer is String ? answer.length : 0;
      for (final range in _maps(question['answerEmphasis'])) {
        final start = range['start'];
        final end = range['end'];
        if (!(start is num &&
            end is num &&
            start >= 0 &&
            end > start &&
            end <= answerLength)) {
          fail('$label: invalid emphasis range.');
        }
      }
      for (final text in [question['question'], answer]) {
        final value = text is String ? text : '';
        if (_introMarkers.any((marker) => marker.hasMatch(value))) {
          fail('$label: contains introductory material.');
        }
      }
    }
    final firstNumber = questionMaps.isEmpty
        ? null
        : questionMaps.first['number'];
    final lastNumber = questionMaps.isEmpty
        ? null
        : questionMaps.last['number'];
    if (unit['firstQuestion'] != firstNumber ||
        unit['lastQuestion'] != lastNumber) {
      fail('Unit $unitId: question range does not match its questions.');
    }
  }
  final total = expectedNumber - 1;
  if (total != expectedQuestionCount) {
    fail('Expected $expectedQuestionCount questions, found $total.');
  }
  if (meta?['questionCount'] != total) {
    fail('meta.questionCount (${meta?['questionCount']}) differs from $total.');
  }
  final metaUnitIds = meta?['unitIds'];
  if (metaUnitIds is List &&
      metaUnitIds.join('|') != unitMaps.map((unit) => unit['id']).join('|')) {
    fail('meta.unitIds differ from unit order.');
  }
  return errors;
}

/// Reassembles a dataset map from Firestore documents
/// (`compendiumMeta/current` + one `compendium/{unitId}` document per unit).
/// `importedAt` is dropped from every document.
Map<String, dynamic> compendiumFromDocuments(
  Map<String, dynamic>? meta,
  List<Map<String, dynamic>> unitDocuments,
) {
  final byId = <Object?, Map<String, dynamic>>{
    for (final unit in unitDocuments) unit['id']: unit,
  };
  final ids = meta?['unitIds'] is List
      ? meta!['unitIds'] as List
      : byId.keys.toList();
  final units = [
    for (final id in ids)
      if (byId[id] case final unit?)
        Map<String, dynamic>.from(unit)..remove('importedAt'),
  ];
  _stableSort(units, compare: (a, b) => _compareOrder(a['order'], b['order']));
  final rest = Map<String, dynamic>.from(meta ?? const {})
    ..remove('importedAt');
  final parts = rest.remove('parts');
  return {'meta': rest, 'parts': parts ?? <Object?>[], 'units': units};
}

int _compareOrder(Object? a, Object? b) =>
    a is num && b is num ? a.compareTo(b) : 0;

/// Stable insertion sort (JavaScript `Array.prototype.sort` is stable).
void _stableSort<T>(List<T> list, {required int Function(T, T) compare}) {
  for (var i = 1; i < list.length; i++) {
    final value = list[i];
    var j = i - 1;
    while (j >= 0 && compare(list[j], value) > 0) {
      list[j + 1] = list[j];
      j--;
    }
    list[j + 1] = value;
  }
}

const _romanNumerals = ['', 'I', 'II', 'III', 'IV', 'V'];

String romanNumeral(int? value) =>
    value != null && value >= 0 && value < _romanNumerals.length
    ? (_romanNumerals[value].isEmpty ? '$value' : _romanNumerals[value])
    : '${value ?? ''}';

enum CompendiumGroupKind { unit, topic }

/// A reading group: a topic, or a unit's questions before its first topic.
///
/// Groups remain an internal compatibility index for legacy deep links.
/// Visible Part content comes from [buildCompendiumPartReadingOutline].
class CompendiumGroup {
  CompendiumGroup._({
    required this.id,
    required this.kind,
    required this.unit,
    required this.title,
    required this.questions,
    this.topic,
    this.parentTitle,
    this.leadCitations = const [],
  });

  final String id;
  final CompendiumGroupKind kind;
  final CompendiumUnit unit;
  final CompendiumTopic? topic;
  final String title;
  final String? parentTitle;
  final List<CompendiumCitation> leadCitations;
  final List<CompendiumQuestion> questions;

  int get firstQuestion => questions.first.number;
  int get lastQuestion => questions.last.number;

  /// Whether this group is a real source heading (a named topic). An
  /// untitled lead-in is only a reading chunk: it is never shown as a
  /// navigation node, and its [title] is the nearest real heading above it.
  bool get hasSourceHeading => kind == CompendiumGroupKind.topic;

  /// «Пытанне 5» or «Пытанні 5–12» (secondary metadata, never a heading).
  String get rangeLabel => compendiumRangeLabel(firstQuestion, lastQuestion);
}

String? _nonEmpty(String? value) =>
    value == null || value.isEmpty ? null : value;

/// Lookup structures built once per dataset (MyBrev `indexCompendium`).
class CompendiumIndex {
  CompendiumIndex._({
    required this.dataset,
    required this.questions,
    required this.groups,
    required this.groupOrder,
    required Map<int, CompendiumQuestion> byNumber,
    required Map<String, CompendiumPart> partsById,
  }) : _byNumber = byNumber,
       _partsById = partsById;

  factory CompendiumIndex(CompendiumDataset dataset) {
    final questions = <CompendiumQuestion>[];
    final byNumber = <int, CompendiumQuestion>{};
    final groups = <String, CompendiumGroup>{};
    final groupOrder = <String>[];
    for (final unit in dataset.units) {
      final unitQuestions = <CompendiumQuestion>[];
      final topicQuestions = {
        for (final topic in unit.topics) topic.id: <CompendiumQuestion>[],
      };
      for (final question in unit.questions) {
        questions.add(question);
        byNumber[question.number] = question;
        (topicQuestions[question.topicId] ?? unitQuestions).add(question);
      }
      final candidates = [
        CompendiumGroup._(
          id: unit.id,
          kind: CompendiumGroupKind.unit,
          unit: unit,
          title:
              _nonEmpty(unit.chapterTitle) ??
              _nonEmpty(unit.sectionTitle) ??
              unit.partTitle,
          leadCitations: unit.leadCitations,
          questions: List.unmodifiable(unitQuestions),
        ),
        for (final topic in unit.topics)
          CompendiumGroup._(
            id: topic.id,
            kind: CompendiumGroupKind.topic,
            unit: unit,
            topic: topic,
            title: topic.title,
            parentTitle: _nonEmpty(topic.parentTitle),
            leadCitations: topic.leadCitations,
            questions: List.unmodifiable(topicQuestions[topic.id]!),
          ),
      ];
      for (final group in candidates) {
        if (group.questions.isEmpty) continue;
        groups[group.id] = group;
        groupOrder.add(group.id);
      }
    }
    _stableSort(
      groupOrder,
      compare: (a, b) =>
          groups[a]!.firstQuestion.compareTo(groups[b]!.firstQuestion),
    );
    return CompendiumIndex._(
      dataset: dataset,
      questions: List.unmodifiable(questions),
      groups: groups,
      groupOrder: List.unmodifiable(groupOrder),
      byNumber: byNumber,
      partsById: {for (final part in dataset.parts) part.id: part},
    );
  }

  final CompendiumDataset dataset;

  /// Reading streams are derived once per dataset, including stable anchors.
  late final Map<String, CompendiumPartOutline> partReadingOutlines = {
    for (final part in parts)
      part.id: buildCompendiumPartReadingOutline(this, part.id)!,
  };

  CompendiumPartOutline? partReadingOutline(String? id) {
    final part = getPart(id);
    return part == null ? null : partReadingOutlines[part.id];
  }

  /// Source heading tree retained for compatibility links, built once.
  late final List<CompendiumNavNode> navigation = buildCompendiumNavigation(
    this,
  );

  late final Map<String, CompendiumNavNode> _nodes = {
    for (final part in navigation)
      for (final node in part.descendants) node.id: node,
  };

  /// A visible navigation node by its id: part (`p1`), section (`p1-s1`),
  /// chapter (`p1-s1-ch1`) or named topic (`p1-s1-ch2-t1`). Untitled reading
  /// groups (`p1-s1-intro`) are not nodes.
  CompendiumNavNode? getNode(String? id) => _nodes[id];

  late final Map<int, CompendiumNavNode> _owners = {
    for (final node in _nodes.values)
      for (final question in node.group?.questions ?? node.directQuestions)
        question.number: node,
  };

  /// The nearest real source heading that owns [question].
  CompendiumNavNode? ownerOf(CompendiumQuestion question) =>
      _owners[question.number];

  /// Source outline of a part, by id (`p2`) or number (`2`).
  CompendiumNavNode? partOutline(String? id) {
    final part = getPart(id);
    return part == null
        ? null
        : navigation.where((node) => node.id == part.id).firstOrNull;
  }

  /// Every question in canonical order.
  final List<CompendiumQuestion> questions;
  final Map<String, CompendiumGroup> groups;

  /// Group ids ordered by their first question.
  final List<String> groupOrder;
  final Map<int, CompendiumQuestion> _byNumber;
  final Map<String, CompendiumPart> _partsById;

  CompendiumMeta get meta => dataset.meta;
  List<CompendiumPart> get parts => dataset.parts;
  List<CompendiumUnit> get units => dataset.units;

  /// Accepts `42`, `"42"` or `"q042"`.
  CompendiumQuestion? getQuestion(Object? value) {
    final text = '${value ?? ''}'.trim().replaceFirst(
      RegExp(r'^q0*', caseSensitive: false),
      '',
    );
    final number = num.tryParse(text);
    if (number == null || number != number.truncate()) return null;
    return _byNumber[number.toInt()];
  }

  CompendiumGroup? getGroup(String? id) => groups[id];

  /// By id (`p2`) or by number (`2`).
  CompendiumPart? getPart(String? id) =>
      _partsById[id] ??
      parts.where((part) => '${part.number}' == id).firstOrNull;

  CompendiumGroup? groupOf(CompendiumQuestion question) =>
      groups[question.groupId] ?? groups[question.unitId];

  /// Previous and next reading group in canonical order.
  (CompendiumGroup?, CompendiumGroup?) neighbours(String groupId) {
    final position = groupOrder.indexOf(groupId);
    if (position < 0) return (null, null);
    return (
      position > 0 ? groups[groupOrder[position - 1]] : null,
      position + 1 < groupOrder.length
          ? groups[groupOrder[position + 1]]
          : null,
    );
  }

  /// First and last question number of a part.
  (int, int)? partRange(String partId) {
    final inPart = questions.where((question) => question.partId == partId);
    if (inPart.isEmpty) return null;
    return (inPart.first.number, inPart.last.number);
  }
}

/// Level of a visible source heading. Model names stay close to the data
/// (`section` is a РАЗДЗЕЛ, `chapter` a source ГЛАВА). The product shows a
/// chapter as a ПАДРАЗДЗЕЛ: see [CompendiumNavNode.displayLabel].
enum CompendiumNodeKind { part, section, chapter, topic }

const _masculineOrdinals = [
  'ПЕРШЫ',
  'ДРУГІ',
  'ТРЭЦІ',
  'ЧАЦВЁРТЫ',
  'ПЯТЫ',
  'ШОСТЫ',
  'СЁМЫ',
  'ВОСЬМЫ',
  'ДЗЯВЯТЫ',
  'ДЗЯСЯТЫ',
];

/// Product name of the chapter level.
const kCompendiumSubsectionTerm = 'ПАДРАЗДЗЕЛ';

/// «ПАДРАЗДЗЕЛ ПЕРШЫ»: the product label of a source chapter, generated from
/// its number with a masculine ordinal (the source «ГЛАВА ПЕРШАЯ» is feminine,
/// so the label is never derived by replacing the noun). Numbers without a
/// known ordinal fall back to «ПАДРАЗДЗЕЛ 11».
String compendiumSubsectionLabel(int? number) {
  if (number == null || number < 1) return kCompendiumSubsectionTerm;
  return number <= _masculineOrdinals.length
      ? '$kCompendiumSubsectionTerm ${_masculineOrdinals[number - 1]}'
      : '$kCompendiumSubsectionTerm $number';
}

/// A visible node of the source hierarchy (ЧАСТКА → РАЗДЗЕЛ → ГЛАВА → named
/// topic), derived from the canonical dataset without copying its content.
///
/// Source hierarchy and reading groups are separate concepts: only headings
/// that exist in the Catholic.by text become nodes. A unit's untitled lead-in
/// ([CompendiumGroupKind.unit], for example `p1-s1-intro`) never becomes a
/// node; its questions are [directQuestions] of the nearest real heading.
/// Within a node the direct questions always precede [children] (the source
/// prints them before the first sub-heading), so rendering `directQuestions`
/// then `children` keeps canonical order.
class CompendiumNavNode {
  CompendiumNavNode._({
    required this.id,
    required this.kind,
    required this.title,
    this.label,
    this.number,
    this.heading,
    this.group,
    this.parent,
  });

  /// Part/section/chapter id from the dataset (`p1`, `p1-s1`, `p1-s1-ch1`)
  /// or the topic id.
  final String id;
  final CompendiumNodeKind kind;

  /// Source label: «ЧАСТКА ПЕРШАЯ», «РАЗДЗЕЛ ПЕРШЫ», «ГЛАВА ПЕРШАЯ»; `null`
  /// for topics. Screens show [displayLabel] instead.
  final String? label;

  /// Part, section or chapter number; `null` for topics.
  final int? number;
  final String title;

  /// The node above this one; `null` for a part.
  final CompendiumNavNode? parent;

  /// Quotation boxes the source prints under this heading.
  final List<CompendiumCitation> leadCitations = [];

  /// Level label shown in the UI: ЧАСТКА and РАЗДЗЕЛ come from the source, a
  /// chapter is a «ПАДРАЗДЗЕЛ …» ([compendiumSubsectionLabel]), and a named
  /// topic has no generic level name.
  String? get displayLabel => switch (kind) {
    CompendiumNodeKind.chapter => compendiumSubsectionLabel(number),
    CompendiumNodeKind.topic => null,
    CompendiumNodeKind.part || CompendiumNodeKind.section => label,
  };

  /// Part, section or chapter: a screen of rows, not a reader.
  bool get isStructural => kind != CompendiumNodeKind.topic;

  /// Headings above this node, outermost first, as shown in a context line:
  /// the part by its label, deeper levels by their titles.
  List<String> get contextTrail => [
    for (CompendiumNavNode? node = parent; node != null; node = node.parent)
      node.kind == CompendiumNodeKind.part
          ? (node.label ?? node.title)
          : node.title,
  ].reversed.where((text) => text.isNotEmpty).toList();

  /// This node and everything below it, in canonical order.
  Iterable<CompendiumNavNode> get descendants sync* {
    yield this;
    for (final child in children) {
      yield* child.descendants;
    }
  }

  /// A source heading printed above this topic that groups it with the next
  /// topics (`CompendiumTopic.parentTitle`).
  final String? heading;

  /// The reading group behind a topic node.
  final CompendiumGroup? group;

  final List<CompendiumQuestion> directQuestions = [];
  final List<CompendiumNavNode> children = [];

  /// Every question below this node, in canonical order.
  Iterable<CompendiumQuestion> get questions sync* {
    if (group case final group?) {
      yield* group.questions;
      return;
    }
    yield* directQuestions;
    for (final child in children) {
      yield* child.questions;
    }
  }

  int get firstQuestion => questions.first.number;
  int get lastQuestion => questions.last.number;

  /// Secondary metadata only («Пытанні 6–10»), never a heading.
  String get rangeLabel => compendiumRangeLabel(firstQuestion, lastQuestion);
}

/// «Пытанне 5» or «Пытанні 5–12».
String compendiumRangeLabel(int first, int last) =>
    first == last ? 'Пытанне $first' : 'Пытанні $first–$last';

/// Source navigation for every part, in canonical order.
List<CompendiumNavNode> buildCompendiumNavigation(CompendiumIndex index) => [
  for (final part in index.parts) ?buildCompendiumPartOutline(index, part.id),
];

/// Source heading tree used by compatibility links and lookups. Untitled
/// lead-in questions attach to the nearest real heading. The Part screen uses
/// [buildCompendiumPartReadingOutline] instead.
CompendiumNavNode? buildCompendiumPartOutline(
  CompendiumIndex index,
  String partId,
) {
  final part = index.getPart(partId);
  if (part == null) return null;
  final root = CompendiumNavNode._(
    id: part.id,
    kind: CompendiumNodeKind.part,
    label: _nonEmpty(part.label),
    number: part.number,
    title: part.title,
  );
  final sections = <int, CompendiumNavNode>{};
  final chapters = <String, CompendiumNavNode>{};
  for (final unit in index.units) {
    if (unit.partId != part.id) continue;
    final sectionInfo = part.sections
        .where((section) => section.number == unit.sectionNumber)
        .firstOrNull;
    final section = sections.putIfAbsent(unit.sectionNumber, () {
      final node = CompendiumNavNode._(
        id: sectionInfo?.id ?? '${part.id}-s${unit.sectionNumber}',
        kind: CompendiumNodeKind.section,
        label: _nonEmpty(unit.sectionLabel) ?? _nonEmpty(sectionInfo?.label),
        number: unit.sectionNumber,
        title: _nonEmpty(unit.sectionTitle) ?? sectionInfo?.title ?? '',
        parent: root,
      );
      root.children.add(node);
      return node;
    });
    var target = section;
    if (unit.chapterNumber case final number?) {
      final chapterInfo = sectionInfo?.chapters
          .where((chapter) => chapter.number == number)
          .firstOrNull;
      final id = chapterInfo?.id ?? '${section.id}-ch$number';
      target = chapters.putIfAbsent(id, () {
        final node = CompendiumNavNode._(
          id: id,
          kind: CompendiumNodeKind.chapter,
          label: _nonEmpty(unit.chapterLabel) ?? _nonEmpty(chapterInfo?.label),
          number: number,
          title: _nonEmpty(unit.chapterTitle) ?? chapterInfo?.title ?? '',
          parent: section,
        );
        section.children.add(node);
        return node;
      });
    }
    target.leadCitations.addAll(unit.leadCitations);
    // The untitled lead-in (validated to precede every topic of the unit).
    if (index.groups[unit.id] case final lead?
        when lead.kind == CompendiumGroupKind.unit) {
      target.directQuestions.addAll(lead.questions);
    }
    for (final topic in unit.topics) {
      final group = index.groups[topic.id];
      if (group == null) continue;
      target.children.add(
        CompendiumNavNode._(
          id: topic.id,
          kind: CompendiumNodeKind.topic,
          title: topic.title,
          heading: _nonEmpty(topic.parentTitle),
          group: group,
          parent: target,
        ),
      );
    }
  }
  return root;
}

/// Question number to open instead of [group]'s reader: an untitled
/// one-question lead-in (for example the legacy `p1-s1-intro`) is not a
/// heading, so its only question opens in the individual question reader.
int? compendiumGroupQuestionRedirect(CompendiumGroup group) =>
    !group.hasSourceHeading && group.questions.length == 1
    ? group.firstQuestion
    : null;

/// Breadcrumb labels for a question: real source headings only (part label,
/// section, chapter, named topic). Question 1 lies directly under its
/// section, so its trail is «ЧАСТКА ПЕРШАЯ · «ВЕРУ» — «ВЕРЫМ»».
List<String> questionContextTrail(CompendiumQuestion question) => [
  question.partLabel,
  question.sectionTitle,
  ?question.chapterTitle,
  ?question.topicTitle,
].where((label) => label.isNotEmpty).toList();

/// Breadcrumb labels for a reading group; for an untitled lead-in it ends at
/// the nearest real heading (chapter or section), never at a range.
List<String> groupContextTrail(CompendiumGroup group) => [
  group.unit.partLabel,
  group.unit.sectionTitle,
  ?group.unit.chapterTitle,
  ?group.topic?.title,
].where((label) => label.isNotEmpty).toList();

enum CompendiumPartItemKind {
  sectionHeading,
  subsectionHeading,
  topicHeading,
  subtopicHeading,
  leadCitations,
  question,
}

/// One immutable entry in a Part's canonical reading stream.
class CompendiumPartItem {
  const CompendiumPartItem({
    required this.kind,
    required this.id,
    this.label,
    this.title,
    this.citations = const [],
    this.question,
  });

  final CompendiumPartItemKind kind;
  final String id;
  final String? label;
  final String? title;
  final List<CompendiumCitation> citations;
  final CompendiumQuestion? question;
}

class CompendiumPartOutline {
  const CompendiumPartOutline(this.part, this.items, this.targetIndices);

  final CompendiumPart part;
  final List<CompendiumPartItem> items;
  final Map<String, int> targetIndices;
}

/// Matches the Web `buildPartReadingOutline`: units are only ordering data;
/// their ids and question ranges never become visible headings.
CompendiumPartOutline? buildCompendiumPartReadingOutline(
  CompendiumIndex index,
  String partId,
) {
  final part = index.getPart(partId);
  if (part == null) return null;
  final items = <CompendiumPartItem>[];
  final targets = <String, int>{};
  void add(CompendiumPartItem item) {
    targets[item.id] = items.length;
    items.add(item);
  }

  String? sectionId;
  String? chapterId;
  String? topicId;
  String? parentTitle;
  String? subtopicTitle;
  for (final unit in index.units.where((unit) => unit.partId == part.id)) {
    final section = part.sections.firstWhere(
      (section) => section.number == unit.sectionNumber,
    );
    if (sectionId != section.id) {
      sectionId = section.id;
      add(
        CompendiumPartItem(
          kind: CompendiumPartItemKind.sectionHeading,
          id: section.id,
          label: section.label,
          title: section.title,
        ),
      );
      chapterId = topicId = parentTitle = subtopicTitle = null;
    }
    final chapter = unit.chapterNumber == null
        ? null
        : section.chapters.firstWhere(
            (chapter) => chapter.number == unit.chapterNumber,
          );
    if (chapterId != chapter?.id) {
      chapterId = chapter?.id;
      if (chapter != null) {
        add(
          CompendiumPartItem(
            kind: CompendiumPartItemKind.subsectionHeading,
            id: chapter.id,
            label: compendiumSubsectionLabel(chapter.number),
            title: chapter.title,
          ),
        );
      }
      topicId = parentTitle = subtopicTitle = null;
    }
    if (unit.leadCitations.isNotEmpty) {
      add(
        CompendiumPartItem(
          kind: CompendiumPartItemKind.leadCitations,
          id: '${unit.id}-lead',
          citations: List.unmodifiable(unit.leadCitations),
        ),
      );
    }
    for (final question in unit.questions) {
      if (topicId != question.topicId) {
        topicId = question.topicId;
        subtopicTitle = null;
        if (topicId != null) {
          final topic = unit.topics.firstWhere((topic) => topic.id == topicId);
          if (topic.parentTitle != null && topic.parentTitle != parentTitle) {
            add(
              CompendiumPartItem(
                kind: CompendiumPartItemKind.topicHeading,
                id: '${topic.id}-parent',
                title: topic.parentTitle,
              ),
            );
          }
          parentTitle = topic.parentTitle;
          add(
            CompendiumPartItem(
              kind: CompendiumPartItemKind.topicHeading,
              id: topic.id,
              title: topic.title,
            ),
          );
          if (topic.leadCitations.isNotEmpty) {
            add(
              CompendiumPartItem(
                kind: CompendiumPartItemKind.leadCitations,
                id: '${topic.id}-lead',
                citations: List.unmodifiable(topic.leadCitations),
              ),
            );
          }
        } else {
          parentTitle = null;
        }
      }
      if (question.subtopicTitle != null &&
          question.subtopicTitle != subtopicTitle) {
        add(
          CompendiumPartItem(
            kind: CompendiumPartItemKind.subtopicHeading,
            id: '${question.id}-subtopic',
            title: question.subtopicTitle,
          ),
        );
      }
      subtopicTitle = question.subtopicTitle;
      add(
        CompendiumPartItem(
          kind: CompendiumPartItemKind.question,
          id: question.id,
          question: question,
        ),
      );
    }
  }
  return CompendiumPartOutline(
    part,
    List.unmodifiable(items),
    Map.unmodifiable(targets),
  );
}

/// A run of answer text with an optional emphasis style.
class CompendiumTextRun {
  const CompendiumTextRun(this.text, [this.style]);

  final String text;
  final CompendiumEmphasisStyle? style;

  @override
  bool operator ==(Object other) =>
      other is CompendiumTextRun && other.text == text && other.style == style;

  @override
  int get hashCode => Object.hash(text, style);

  @override
  String toString() => 'CompendiumTextRun($text, $style)';
}

/// Splits an answer into paragraphs of styled runs using `answerEmphasis`
/// (MyBrev `answerParagraphs`): every `\n` starts a new paragraph and empty
/// paragraphs are dropped.
List<List<CompendiumTextRun>> answerParagraphs(CompendiumQuestion question) {
  final text = question.answer;
  final ranges = [...question.answerEmphasis];
  _stableSort(ranges, compare: (a, b) => a.start.compareTo(b.start));
  final runs = <CompendiumTextRun>[];
  var cursor = 0;
  for (final range in ranges) {
    final start = range.start.clamp(0, text.length);
    final end = range.end.clamp(start, text.length);
    if (start > cursor) {
      runs.add(CompendiumTextRun(text.substring(cursor, start)));
    }
    if (end > start && start >= cursor) {
      runs.add(CompendiumTextRun(text.substring(start, end), range.style));
    }
    cursor = end > cursor ? end : cursor;
  }
  if (cursor < text.length) runs.add(CompendiumTextRun(text.substring(cursor)));

  final paragraphs = <List<CompendiumTextRun>>[[]];
  for (final run in runs) {
    final pieces = run.text.split('\n');
    for (var i = 0; i < pieces.length; i++) {
      if (i > 0) paragraphs.add([]);
      if (pieces[i].isNotEmpty) {
        paragraphs.last.add(CompendiumTextRun(pieces[i], run.style));
      }
    }
  }
  return paragraphs.where((paragraph) => paragraph.isNotEmpty).toList();
}

/// `["50-53", "68"]` → `"50–53, 68"`.
String formatCccRefs(List<String> refs) =>
    refs.map((ref) => ref.replaceFirst('-', '–')).join(', ');
