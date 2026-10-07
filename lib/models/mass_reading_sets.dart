/// Mass reading sets: several structured sets of Mass readings inside one
/// `readings` document (`massReadings`), e.g. «Св. Імша ў вігілію» and
/// «Св. Імша ўдзень» of the Assumption, the three Masses of Christmas, the
/// procession and the Mass of Palm Sunday, the ordered Easter Vigil.
///
/// Port of mybrev `src/utils/massReadingSets.js` (schema 1). The flat fields
/// of a document (`reading1`, `psalm`, …) stay the projection of one set for
/// older clients; a document that has sets is read from its sets. A legacy
/// document covered by a canonical one carries `_massReadingsRef` and is
/// hidden when the canonical document is also present.
library;

/// Set contexts celebrated in the evening: preferred when the date also has
/// a morning/day set.
const kEveningSetContexts = {'vigil', 'evening'};
const _daytimeSetContexts = {'morning', 'day', 'chrism', 'mass'};

const kSetCycles = ['A', 'B', 'C'];

/// Labels of the Readings screen (source language, as the web).
const kMassSectionLabels = <String, String>{
  'reading1': 'Першае чытанне',
  'reading2': 'Другое чытанне',
  'reading3': 'Трэцяе чытанне',
  'reading4': 'Чацвёртае чытанне',
  'reading5': 'Пятае чытанне',
  'reading6': 'Шостае чытанне',
  'reading7': 'Сёмае чытанне',
  'epistle': 'Эпістала',
  'psalm': 'Рэспансарыйны псальм',
  'alleluia': 'Спеў перад Евангеллем',
  'acclamation': 'Спеў перад Евангеллем',
  'sequence': 'Секвенцыя',
  'gospel': 'Евангелле',
};

/// Passion read by roles (Catholic.by markers → semantic roles).
enum PassionRole {
  narrator('Ев.', 'словы евангеліста'),
  christ('Е.', 'словы Хрыста'),
  speaker('І.', 'словы адной асобы'),
  crowd('Л.', 'словы некалькіх асобаў');

  const PassionRole(this.marker, this.label);
  final String marker;
  final String label;

  static PassionRole? parse(Object? value) {
    for (final role in values) {
      if (role.name == value) return role;
    }
    return null;
  }
}

String _text(Object? value) => value == null ? '' : '$value'.trim();
String? _opt(Object? value) {
  final text = _text(value);
  return text.isEmpty ? null : text;
}

Map<String, dynamic>? _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : null;

List<Map<String, dynamic>> _maps(Object? value) => value is List
    ? [for (final item in value) ?_map(item)]
    : const <Map<String, dynamic>>[];

class PassionRun {
  const PassionRun(this.role, this.text);

  /// Null for a role this version does not know (rendered as narration).
  final PassionRole? role;
  final String text;
}

class PassionBlock {
  const PassionBlock.heading(this.text) : type = 'heading', runs = const [];
  const PassionBlock.rubric(this.text) : type = 'rubric', runs = const [];
  const PassionBlock.paragraph(this.runs) : type = 'paragraph', text = '';

  /// `heading` | `rubric` | `paragraph`.
  final String type;
  final String text;
  final List<PassionRun> runs;

  bool get isParagraph => type == 'paragraph';
}

class PassionText {
  const PassionText({this.legend = const [], this.blocks = const []});

  final List<String> legend;
  final List<PassionBlock> blocks;

  static PassionText? fromMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    final blocks = <PassionBlock>[];
    for (final block in _maps(map['blocks'])) {
      switch (block['type']) {
        case 'heading':
          blocks.add(PassionBlock.heading(_text(block['text'])));
        case 'rubric':
          blocks.add(PassionBlock.rubric(_text(block['text'])));
        default:
          blocks.add(
            PassionBlock.paragraph([
              for (final run in _maps(block['runs']))
                PassionRun(PassionRole.parse(run['role']), _text(run['text'])),
            ]),
          );
      }
    }
    final legend = map['legend'];
    return PassionText(
      legend: legend is List ? [for (final item in legend) _text(item)] : [],
      blocks: blocks,
    );
  }

  /// Roles that occur in the Passion.
  Set<PassionRole> get roles => {
    for (final block in blocks)
      for (final run in block.runs) ?run.role,
  };

  /// Plain text with the source markers (the legacy flat field).
  String toPlainText() => blocks
      .map((block) {
        if (!block.isParagraph) return block.text;
        return block.runs
            .map((run) {
              final marker = run.role?.marker;
              return marker == null ? run.text : '$marker ${run.text}';
            })
            .where((item) => item.isNotEmpty)
            .join(' ');
      })
      .where((item) => item.isNotEmpty)
      .join('\n\n');
}

/// One section of a set, in source order.
class MassReadingSection {
  const MassReadingSection({
    required this.kind,
    this.role,
    this.cycle,
    this.label,
    this.bible,
    this.comment,
    this.title,
    this.text,
    this.conclusion,
    this.alternatives = const [],
    this.rubrics = const [],
    this.chorus,
    this.altChorus,
    this.verses = const [],
    this.acclamation,
    this.verse,
    this.passion,
    this.legend = false,
  });

  /// `reading` | `psalm` | `acclamation` | `sequence` | `gospel` | `rubric`.
  final String kind;

  /// `reading1`…`reading7`, `epistle`, `psalm`, `psalmN`, `alleluia`,
  /// `sequence`, `gospel`; null for a rubric.
  final String? role;

  /// A/B/C: part of one cycle only (shared base + cycle-specific Gospel).
  final String? cycle;
  final String? label;
  final String? bible;
  final String? comment;
  final String? title;
  final String? text;

  /// Closing acclamation: null = the default one, '' = none is said (the
  /// third reading of the Easter Vigil).
  final String? conclusion;
  final List<MassReadingSection> alternatives;
  final List<String> rubrics;
  final String? chorus;
  final String? altChorus;
  final List<String> verses;
  final String? acclamation;
  final String? verse;
  final PassionText? passion;

  /// The rubric is the legend of the Passion roles.
  final bool legend;

  bool get isRubric => kind == 'rubric';

  factory MassReadingSection.fromMap(Map<String, dynamic> map) {
    final verses = map['verses'];
    final conclusion = map['conclusion'];
    final rubrics = map['rubrics'];
    return MassReadingSection(
      kind: _text(map['kind']),
      role: _opt(map['role']),
      cycle: _opt(map['cycle'])?.toUpperCase(),
      label: _opt(map['label']),
      bible: _opt(map['bible']),
      comment: _opt(map['comment']),
      title: _opt(map['title']),
      text: _opt(map['text']),
      conclusion: conclusion is String ? conclusion.trim() : null,
      alternatives: [
        for (final item in _maps(map['alternatives']))
          MassReadingSection.fromMap({'kind': map['kind'], ...item}),
      ],
      rubrics: rubrics is List
          ? [
              for (final item in rubrics)
                if (_text(item).isNotEmpty) _text(item),
            ]
          : const [],
      chorus: _opt(map['chorus']),
      altChorus: _opt(map['altChorus']),
      verses: verses is List
          ? [
              for (final item in verses)
                if (item is Map)
                  _text(item['text'])
                else if (_text(item).isNotEmpty)
                  _text(item),
            ]
          : const [],
      acclamation: _opt(map['acclamation']),
      verse: _opt(map['verse']),
      passion: PassionText.fromMap(_map(map['passion'])),
      legend: map['legend'] == true,
    );
  }

  /// Label of the section on the Readings screen.
  String get displayLabel =>
      label ??
      kMassSectionLabels[role] ??
      kMassSectionLabels[kind] ??
      (RegExp(r'^psalm\d+$').hasMatch(role ?? '')
          ? kMassSectionLabels['psalm']!
          : '');
}

class MassReadingSet {
  const MassReadingSet({
    required this.id,
    required this.label,
    this.sourceLabel,
    this.context,
    this.isDefault = false,
    this.cycle,
    this.referenceOnly = false,
    this.note,
    this.sourceUrl,
    this.sections = const [],
  });

  final String id;
  final String label;
  final String? sourceLabel;
  final String? context;
  final bool isDefault;
  final String? cycle;
  final bool referenceOnly;
  final String? note;
  final String? sourceUrl;
  final List<MassReadingSection> sections;

  factory MassReadingSet.fromMap(Map<String, dynamic> map) => MassReadingSet(
    id: _text(map['id']),
    label: _text(map['label']).isEmpty ? _text(map['id']) : _text(map['label']),
    sourceLabel: _opt(map['sourceLabel']),
    context: _opt(map['context']),
    isDefault: map['default'] == true,
    cycle: _opt(map['cycle'])?.toUpperCase(),
    referenceOnly: map['referenceOnly'] == true,
    note: _opt(map['note']),
    sourceUrl: _opt(_map(map['source'])?['url']),
    sections: [
      for (final section in _maps(map['sections']))
        MassReadingSection.fromMap(section),
    ],
  );

  /// Cycles A/B/C the set distinguishes (from its cycle-specific sections).
  List<String> get cycles {
    final found = {?cycle, for (final section in sections) ?section.cycle};
    return kSetCycles.where(found.contains).toList();
  }

  /// The cycle to show: the wanted one when the set has it, else the first.
  String resolveCycle(String? wanted) {
    final available = cycles;
    if (available.isEmpty) return '';
    final desired = _text(wanted).toUpperCase();
    return available.contains(desired) ? desired : available.first;
  }

  /// Ordered sections for one cycle: the shared base + that cycle's parts.
  List<MassReadingSection> sectionsForCycle(String? wanted) {
    final active = resolveCycle(wanted);
    return [
      for (final section in sections)
        if (section.cycle == null || section.cycle == active) section,
    ];
  }

  /// Citations of a reference-only set (no text is pretended).
  List<MassReadingCitation> citations(String? wanted) => [
    for (final section in sectionsForCycle(wanted))
      if (!section.isRubric && (section.bible ?? '').isNotEmpty)
        MassReadingCitation(
          label: section.displayLabel,
          bible: section.bible!,
          alternatives: [
            for (final item in section.alternatives)
              if ((item.bible ?? '').isNotEmpty) item.bible!,
          ],
        ),
  ];
}

class MassReadingCitation {
  const MassReadingCitation({
    required this.label,
    required this.bible,
    this.alternatives = const [],
  });

  final String label;
  final String bible;
  final List<String> alternatives;
}

class MassReadings {
  const MassReadings({required this.sets, this.flatSet, this.sourceUrl});

  final List<MassReadingSet> sets;
  final String? flatSet;
  final String? sourceUrl;

  static MassReadings? fromMap(Object? raw) {
    final map = _map(raw);
    if (map == null) return null;
    final sets = [
      for (final set in _maps(map['sets'])) MassReadingSet.fromMap(set),
    ].where((set) => set.id.isNotEmpty).toList();
    if (sets.isEmpty) return null;
    return MassReadings(
      sets: sets,
      flatSet: _opt(map['flatSet']),
      sourceUrl: _opt(map['sourceUrl']),
    );
  }

  /// Default set: an explicit `default`; else the evening/vigil set when the
  /// date also has a morning/day set; else the first.
  String get defaultSetId => defaultMassSetId(sets);

  /// The requested set, else the default one.
  MassReadingSet select(String? requestedId) =>
      selectMassSet(sets, requestedId);
}

String defaultMassSetId(List<MassReadingSet> sets) {
  if (sets.isEmpty) return '';
  for (final set in sets) {
    if (set.isDefault) return set.id;
  }
  final evening = sets
      .where((set) => kEveningSetContexts.contains(set.context))
      .firstOrNull;
  final daytime = sets.any((set) => _daytimeSetContexts.contains(set.context));
  if (evening != null && daytime) return evening.id;
  return sets.first.id;
}

MassReadingSet selectMassSet(List<MassReadingSet> sets, String? requestedId) {
  final requested = _text(requestedId);
  return sets.where((set) => set.id == requested).firstOrNull ??
      sets.firstWhere((set) => set.id == defaultMassSetId(sets));
}

/// `_massReadingsRef` of a legacy document covered by a canonical one.
class MassReadingsRef {
  const MassReadingsRef({
    required this.doc,
    this.set,
    this.cycle,
    this.projected = false,
  });

  final String doc;
  final String? set;
  final String? cycle;
  final bool projected;

  static MassReadingsRef? fromMap(Object? raw) {
    final map = _map(raw);
    final doc = _opt(map?['doc']);
    if (map == null || doc == null) return null;
    return MassReadingsRef(
      doc: doc,
      set: _opt(map['set']),
      cycle: _opt(map['cycle']),
      projected: map['projected'] == true,
    );
  }
}
