/// Calendar definitions (port of mybrev `src/utils/ordo/definitions.js` and
/// `layers.js`): the permanent calendar as normalized, declarative
/// documents, read from the content bundle (+ update overlay):
///
/// ```text
/// liturgicalCelebrations/{id}       universal and Belarus celebrations
/// liturgicalDioceseOverrides/{id}   what a diocese adds / modifies / suppresses
/// liturgicalYearOverrides/{id}      manual one-year decisions
/// ```
///
/// A date is a small DSL checked against a white list; nothing stored is
/// executed. Invalid documents are skipped (and reported), never thrown: a
/// broken edit must not take the calendar down.
library;

typedef Json = Map<String, dynamic>;

const kMovableAnchors = [
  'easterSunday',
  'pentecost',
  'firstAdventSunday',
  'christmas',
  'epiphany',
];
const kNamedDateRules = [
  'ascension',
  'corpusChristi',
  'holyFamily',
  'baptismOfLord',
];
const kCelebrationScopes = ['universal', 'belarus'];
const kDioceseOverrideActions = ['add', 'modify', 'suppress'];
const kCelebrationRanks = [
  'solemnitas',
  'festum',
  'memoria',
  'memoria-ad-libitum',
  'commemoratio-defunctorum',
  'dies-liturgicus',
];

/// Canonical vestment colours (Latin rubrical names). There is no `blue`.
const kLiturgicalColors = [
  'albus',
  'ruber',
  'viridis',
  'violaceus',
  'rosaceus',
  'niger',
];

/// The four Belarusian dioceses, in the order Settings lists them.
const kDioceses = ['minsk-mohilev', 'grodno', 'pinsk', 'vitebsk'];
const kDefaultDiocese = 'minsk-mohilev';

const _dioceseAliases = {
  'minsk': 'minsk-mohilev',
  'minsk-mogilev': 'minsk-mohilev',
  'minsk-mohilev': 'minsk-mohilev',
  'grodno': 'grodno',
  'hrodna': 'grodno',
  'vitebsk': 'vitebsk',
  'viciebsk': 'vitebsk',
  'pinsk': 'pinsk',
};

String normalizeDioceseId(String? value) {
  final key = (value ?? '').trim().toLowerCase();
  return key.isEmpty ? '' : (_dioceseAliases[key] ?? key);
}

bool _isInt(Object? value, int min, int max) =>
    value is num && value == value.toInt() && value >= min && value <= max;

const _daysInMonth = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

List<String> validateDateRule(Object? rule) {
  if (rule is! Map) return ['dateRule is required'];
  switch (rule['type']) {
    case 'fixed':
      return _isInt(rule['month'], 1, 12) &&
              _isInt(
                rule['day'],
                1,
                _daysInMonth[(rule['month'] as num).toInt() - 1],
              )
          ? const []
          : ['fixed dateRule needs a valid month and day'];
    case 'movable':
      return [
        if (!kMovableAnchors.contains(rule['anchor']))
          'unknown anchor ${rule['anchor']}',
        if (!_isInt(rule['offsetDays'] ?? 0, -120, 120))
          'offsetDays must be an integer between -120 and 120',
      ];
    case 'named':
      return kNamedDateRules.contains(rule['rule'])
          ? const []
          : ['unknown named rule ${rule['rule']}'];
    case 'last-weekday-of-month':
      return _isInt(rule['month'], 1, 12) && _isInt(rule['isoWeekday'], 1, 7)
          ? const []
          : ['last-weekday-of-month needs month and isoWeekday'];
  }
  return ['unknown dateRule type ${rule['type']}'];
}

/// `dateRule` → the engine's `date` (placed on a year by the year plan).
Json? engineDateOf(Object? rule) {
  if (rule is! Map) return null;
  switch (rule['type']) {
    case 'fixed':
      return {'type': 'fixed', 'month': rule['month'], 'day': rule['day']};
    case 'movable':
      return {
        'type': 'movable',
        'anchor': rule['anchor'],
        'offsetDays': rule['offsetDays'] ?? 0,
      };
    case 'named':
      return {'type': 'movable', 'anchor': rule['rule'], 'offsetDays': 0};
    case 'last-weekday-of-month':
      return {
        'type': 'last-weekday-of-month',
        'month': rule['month'],
        'isoWeekday': rule['isoWeekday'],
      };
  }
  return null;
}

bool _filled(Object? value) =>
    value != null && !(value is String && value.isEmpty);

List<String> validateCelebrationDefinition(Json doc) => [
  if (doc['id'] is! String || (doc['id'] as String).isEmpty) 'id is required',
  if (!_filled(doc['title'])) 'title is required',
  if (!kCelebrationScopes.contains(doc['scope']))
    'scope must be universal or belarus',
  if (!kCelebrationRanks.contains(doc['rank'])) 'unknown rank ${doc['rank']}',
  if (_filled(doc['color']) && !kLiturgicalColors.contains(doc['color']))
    'unknown color ${doc['color']}',
  ...validateDateRule(doc['dateRule']),
  if (doc['templates'] != null && doc['templates'] is! List)
    'templates must be an array',
  if (_filled(doc['defaultTemplate']) &&
      !((doc['templates'] as List?) ?? const []).contains(
        doc['defaultTemplate'],
      ))
    'defaultTemplate must be one of templates',
];

List<String> validateDioceseOverride(Json doc) => [
  if (!_filled(doc['dioceseId'])) 'dioceseId is required',
  if (!_filled(doc['celebrationId'])) 'celebrationId is required',
  if (!kDioceseOverrideActions.contains(doc['action']))
    'unknown action ${doc['action']}',
  if (_filled(doc['rank']) && !kCelebrationRanks.contains(doc['rank']))
    'unknown rank ${doc['rank']}',
  if (_filled(doc['color']) && !kLiturgicalColors.contains(doc['color']))
    'unknown color ${doc['color']}',
  if (doc['action'] == 'add') ...[
    if (!_filled(doc['title'])) 'add needs a title',
    if (!_filled(doc['rank'])) 'add needs a rank',
    ...validateDateRule(doc['dateRule']),
  ] else if (doc['dateRule'] != null)
    ...validateDateRule(doc['dateRule']),
];

/// Fields that describe the document itself, not the celebration.
const _documentFields = {
  'scope',
  'order',
  'enabled',
  'dateRule',
  'dioceseId',
  'celebrationId',
  'action',
  'id',
  'updatedAt',
  'createdAt',
  'importedAt',
};

Json _celebrationFields(Json doc) => {
  for (final entry in doc.entries)
    if (!_documentFields.contains(entry.key)) entry.key: entry.value,
};

Json definitionToCelebration(Json doc) => {
  'id': doc['id'],
  ..._celebrationFields(doc),
  'layer': doc['scope'],
  'date': engineDateOf(doc['dateRule']),
};

int _byOrder(Json a, Json b) {
  final left = (a['order'] as num?) ?? 1e9;
  final right = (b['order'] as num?) ?? 1e9;
  final byOrder = left.compareTo(right);
  return byOrder != 0
      ? byOrder
      : a['id'].toString().compareTo(b['id'].toString());
}

/// Normalized, ordered calendar definitions of one publication.
class OrdoDefinitions {
  OrdoDefinitions._({
    required this.revision,
    required this.celebrations,
    required this.dioceseOverrides,
    required this.yearOverrides,
    required this.warnings,
  });

  /// From raw documents (bundle ⊕ overlay); invalid ones are dropped.
  factory OrdoDefinitions.fromDocuments({
    Iterable<Json> celebrations = const [],
    Iterable<Json> dioceseOverrides = const [],
    Iterable<Json> yearOverrides = const [],
    int revision = 0,
  }) {
    final warnings = <String>[];
    List<Json> keep(
      Iterable<Json> list,
      List<String> Function(Json) validate,
      String label,
    ) {
      final kept = <Json>[];
      for (final doc in list) {
        if (doc['enabled'] == false) continue;
        final errors = validate(doc);
        if (errors.isNotEmpty) {
          warnings.add('$label ${doc['id'] ?? '?'}: ${errors.join('; ')}');
          continue;
        }
        kept.add(doc);
      }
      kept.sort(_byOrder);
      return kept;
    }

    return OrdoDefinitions._(
      revision: revision,
      celebrations: keep(
        celebrations,
        validateCelebrationDefinition,
        'celebration',
      ),
      dioceseOverrides: keep(
        dioceseOverrides,
        validateDioceseOverride,
        'dioceseOverride',
      ),
      yearOverrides: [for (final item in yearOverrides) Json.of(item)],
      warnings: warnings,
    );
  }

  static final empty = OrdoDefinitions.fromDocuments();

  final int revision;
  final List<Json> celebrations;
  final List<Json> dioceseOverrides;
  final List<Json> yearOverrides;
  final List<String> warnings;

  bool get isEmpty => celebrations.isEmpty;
}

/// Result of applying the layers: the effective celebrations (insertion
/// order = definition order) and the notes the layers carry.
class CalendarLayers {
  const CalendarLayers(this.celebrations, this.appliedLayers);
  final Map<String, Json> celebrations;
  final List<Json> appliedLayers;
}

Json _applyChanges(Json target, Json changes) => {...target, ...changes};

/// Universal → Belarus → diocese (one diocese per call).
CalendarLayers buildCalendarLayers(
  OrdoDefinitions definitions, {
  String diocese = '',
}) {
  final dioceseId = normalizeDioceseId(diocese);
  final celebrations = <String, Json>{};
  final summaries = {
    'universal': <String, dynamic>{
      'id': 'universal',
      'level': 'universal',
      'added': <String>[],
      'modified': <String>[],
    },
    'belarus': <String, dynamic>{
      'id': 'belarus',
      'level': 'belarus',
      'added': <String>[],
      'modified': <String>[],
    },
  };
  for (final doc in definitions.celebrations) {
    celebrations[doc['id'] as String] = {
      ...definitionToCelebration(doc),
      'layerTrail': [doc['scope']],
    };
    (summaries[doc['scope']]!['added'] as List).add(doc['id']);
  }
  final applied = <Json>[summaries['universal']!, summaries['belarus']!];
  if (dioceseId.isEmpty) return CalendarLayers(celebrations, applied);

  final summary = <String, dynamic>{
    'id': dioceseId,
    'level': 'diocese',
    'added': <String>[],
    'modified': <String>[],
    'suppressed': <String>[],
    'warnings': <String>[],
  };
  final overrides = definitions.dioceseOverrides
      .where((item) => item['dioceseId'] == dioceseId)
      .toList();
  final adds = <Json>[];
  final modifies = <(String, Json)>[];
  final suppresses = <String>[];
  for (final override in overrides) {
    final fields = _celebrationFields(override);
    final id = override['celebrationId'] as String;
    switch (override['action']) {
      case 'add':
        adds.add({
          'id': id,
          ...fields,
          'layer': 'diocese',
          'dioceseId': dioceseId,
          'date': engineDateOf(override['dateRule']),
        });
      case 'modify':
        final changes = Json.of(fields)..remove('source');
        if (override['dateRule'] != null) {
          changes['date'] = engineDateOf(override['dateRule']);
        }
        modifies.add((id, changes));
      default:
        suppresses.add(id);
    }
  }
  for (final item in adds) {
    celebrations[item['id'] as String] = {
      ...item,
      'layerTrail': [dioceseId],
    };
    (summary['added'] as List).add(item['id']);
  }
  for (final (id, changes) in modifies) {
    final current = celebrations[id];
    if (current == null) {
      (summary['warnings'] as List).add('modify: unknown celebration $id');
      continue;
    }
    final next = _applyChanges({
      ...current,
      'layer': changes['layer'] ?? 'diocese',
    }, changes);
    next['dioceseId'] = dioceseId;
    next['layerTrail'] = [...(current['layerTrail'] as List? ?? []), dioceseId];
    next['inheritedFrom'] =
        current['inheritedFrom'] ??
        {
          'rank': current['rank'],
          'title': current['title'],
          'layer': current['layer'],
        };
    celebrations[id] = next;
    (summary['modified'] as List).add(id);
  }
  for (final id in suppresses) {
    final current = celebrations[id];
    if (current == null) continue;
    celebrations[id] = {...current, 'suppressedBy': dioceseId};
    (summary['suppressed'] as List).add(id);
  }
  return CalendarLayers(celebrations, [...applied, summary]);
}
