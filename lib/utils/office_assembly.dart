import 'package:mybrev_flutter/models/day.dart';
import 'package:mybrev_flutter/ordo/office.dart';

export 'package:mybrev_flutter/ordo/office.dart' show OfficeSlot;

/// Sparse feast documents (`_schema: 2`) and their assembly — the Flutter
/// port of `mybrev/src/utils/ordo/officeAssembly.js`.
///
/// A sparse document holds only the celebration's own texts plus structured
/// `_fieldRules`; the rest comes from the source the Office prescribes for
/// each component (Proper → Common → current day, Sunday of week I, …).
/// The Commons and the Sunday week I psalter are `liturgicalTemplates`.

const kSparseDaySchema = 2;
const kSundayWeek1Template = 'sunday-week-1';
const kCurrentDayChoice = 'current-day';

bool isSparseDayData(Map<dynamic, dynamic>? data) =>
    data != null && (data['_schema'] is num) && (data['_schema'] as num) == 2;

bool isSparseDay(LiturgicalDay? day) => isSparseDayData(day?.data);

String _hour(String prefix, String part) => '$prefix$part';

Map<String, (String, String)> _hourSlots(
  String prefix,
  String hour, {
  String? canticle,
}) => {
  _hour(prefix, 'Hymn'): (hour, 'hymn'),
  for (final i in [1, 2, 3]) _hour(prefix, 'Ant$i'): (hour, 'antiphons'),
  for (final i in [1, 2, 3]) _hour(prefix, 'Ps$i'): (hour, 'psalmody'),
  _hour(prefix, 'R'): (hour, 'reading'),
  if (canticle != null) _hour(prefix, canticle): (hour, 'canticleAntiphon'),
  if (canticle != null) _hour(prefix, 'Inter'): (hour, 'intercessions'),
  _hour(prefix, 'Pr'): (hour, 'prayer'),
};

/// field → (hour, component) of the Office.
final Map<String, (String, String)> kOfficeFieldSlots = {
  'invitatoriumAnt': ('invitatory', 'antiphon'),
  'officeOfReadingsHymn': ('officeOfReadings', 'hymn'),
  for (final i in [1, 2, 3])
    'officeOfReadingsAnt$i': ('officeOfReadings', 'antiphons'),
  for (final i in [1, 2, 3])
    'officeOfReadingsPs$i': ('officeOfReadings', 'psalmody'),
  'officeOfReadingsVers': ('officeOfReadings', 'versicle'),
  'officeOfReadingsR1': ('officeOfReadings', 'reading1'),
  'officeOfReadingsR2': ('officeOfReadings', 'reading2'),
  'officeOfReadingsPr': ('officeOfReadings', 'prayer'),
  ..._hourSlots('laudes', 'lauds', canticle: 'AntBen'),
  ..._hourSlots('sext1', 'daytime'),
  ..._hourSlots('sext2', 'daytime'),
  ..._hourSlots('sext3', 'daytime'),
  ..._hourSlots('vesper', 'vespers', canticle: 'AntMag'),
};

const kFirstVesperFields = [
  'vesper1Hymn',
  'vesper1Ant1',
  'vesper1Ant2',
  'vesper1Ant3',
  'vesper1Ps1',
  'vesper1Ps2',
  'vesper1Ps3',
  'vesper1R',
  'vesper1AntMag',
  'vesper1Inter',
  'vesper1Pr',
];

const _teDeum = 'officeOfReadingsTeDeum';

const kComplementaryPsalmodyTemplate = 'complementary-psalmody';

/// Office kind of a sparse celebration from its rank.
String officeKindOfRank(String? rank) => switch ((rank ?? '').toLowerCase()) {
  'solemnitas' || 'solemnity' => 'solemnity',
  'festum' || 'feast' => 'feast',
  _ => 'memorial',
};

/// Slots of an Office (port of `hoursFor` in `office.js`).
Map<String, OfficeSlot> officeSlots(
  String officeKind, {
  required bool isSunday,
}) {
  const properCommon = OfficeSlot(['proper', 'common']);
  const currentDay = OfficeSlot(['current-day']);
  final slots = <String, OfficeSlot>{};
  void hour(String name, Map<String, OfficeSlot> components) =>
      components.forEach((component, slot) => slots['$name.$component'] = slot);

  if (officeKind == 'memorial') {
    const properOrChoice = OfficeSlot(
      ['proper'],
      choice: [kCurrentDayChoice, 'common'],
    );
    const properDay = OfficeSlot(['proper', 'current-day']);
    Map<String, OfficeSlot> main() => {
      'hymn': properOrChoice,
      'psalmody': properDay,
      'antiphons': properDay,
      'reading': properOrChoice,
      'canticleAntiphon': properOrChoice,
      'intercessions': properOrChoice,
      'prayer': properCommon,
    };
    hour('invitatory', {'antiphon': properOrChoice});
    hour('officeOfReadings', {
      'hymn': properOrChoice,
      'psalmody': properDay,
      'antiphons': properDay,
      'versicle': properDay,
      'reading1': currentDay,
      'reading2': properOrChoice,
      'prayer': properCommon,
    });
    hour('lauds', main());
    hour('daytime', {
      for (final c in ['hymn', 'psalmody', 'antiphons', 'reading', 'prayer'])
        c: currentDay,
    });
    hour('vespers', main());
    return slots;
  }

  final solemnity = officeKind == 'solemnity';
  final daytimePsalms = solemnity
      ? OfficeSlot([isSunday ? kSundayWeek1Template : 'complementary'])
      : currentDay;
  final daytimeAntiphons = solemnity
      ? const OfficeSlot(['proper', 'common', 'current-day'])
      : const OfficeSlot(['proper', 'current-day']);
  Map<String, OfficeSlot> main() => {
    for (final c in [
      'hymn',
      'psalmody',
      'antiphons',
      'reading',
      'canticleAntiphon',
      'intercessions',
      'prayer',
    ])
      c: properCommon,
  };
  hour('invitatory', {'antiphon': properCommon});
  hour('officeOfReadings', {
    for (final c in [
      'hymn',
      'psalmody',
      'antiphons',
      'versicle',
      'reading1',
      'reading2',
      'prayer',
    ])
      c: properCommon,
  });
  hour('lauds', {
    ...main(),
    'psalmody': const OfficeSlot([kSundayWeek1Template]),
  });
  hour('daytime', {
    'hymn': currentDay,
    'psalmody': daytimePsalms,
    'antiphons': daytimeAntiphons,
    'reading': properCommon,
    'prayer': properCommon,
  });
  hour('vespers', main());
  return slots;
}

bool _blank(Object? value) {
  if (value == null) return true;
  if (value is String) {
    final text = value.trim();
    return text.isEmpty || text == 'from-day' || text == '[from-day]';
  }
  if (value is List) return value.isEmpty || value.every(_blank);
  return false;
}

List<String> _templatesOf(Map<String, dynamic> proper) {
  final raw = proper['_templates'];
  return raw is List
      ? raw.map((item) => item.toString()).where((t) => t.isNotEmpty).toList()
      : const [];
}

String defaultTemplateOf(Map<String, dynamic> proper) {
  final templates = _templatesOf(proper);
  final preferred = proper['_defaultTemplate']?.toString();
  if (preferred != null && templates.contains(preferred)) return preferred;
  return templates.isEmpty ? '' : templates.first;
}

/// Legal assemblies, default first: memorial `[day, …Commons]`,
/// solemnity/feast `[default Common, …other Commons]`.
List<String> assemblyChoices(
  Map<String, dynamic> proper,
  String officeKind, {
  OfficeDescriptor? office,
}) {
  final templates = _templatesOf(proper);
  final preferred = defaultTemplateOf(proper);
  final ordered = [
    if (preferred.isNotEmpty) preferred,
    ...templates.where((t) => t != preferred),
  ];
  final dayChoice = office?.hasDayChoice ?? officeKind == 'memorial';
  if (dayChoice) return [kCurrentDayChoice, ...ordered];
  return ordered.isEmpty ? [kCurrentDayChoice] : ordered;
}

/// A reusable source the rubric requires and the content lacks: an
/// integrity error, never a silent current-day text.
class AssemblyIntegrityError {
  const AssemblyIntegrityError(this.field, this.source, this.reason);
  final String field;
  final String source;

  /// `template-missing` | `field-missing`.
  final String reason;

  Map<String, String> toJson() => {
    'field': field,
    'source': source,
    'reason': reason,
  };
}

class OfficeAssembly {
  const OfficeAssembly(
    this.data,
    this.choice,
    this.provenance, {
    this.missing = const [],
    this.integrity = const [],
  });
  final Map<String, dynamic> data;
  final String choice;
  final Map<String, String> provenance;

  /// Office fields left empty (nothing in the prescribed sources).
  final List<String> missing;
  final List<AssemblyIntegrityError> integrity;
}

/// Slots of an engine descriptor keyed `hour.component`.
Map<String, OfficeSlot> _descriptorSlots(OfficeDescriptor office) => {
  for (final hour in office.hours.entries)
    for (final component in hour.value.entries)
      '${hour.key}.${component.key}': component.value,
};

const _identity = {
  'id',
  '_id',
  '_schema',
  '_date',
  '_feast',
  '_feastName',
  '_rank',
  '_place',
  '_templates',
  '_defaultTemplate',
  '_currentVersion',
  '_celebrationId',
  '_fieldRules',
  '_contentStatus',
  '_legacyIds',
  '_periodType',
  '_periodWeekNumber',
  '_dayOfWeek',
  '_fromDayFields',
  '_omitFirstVespers',
  '_omitTeDeum',
  '_obsolete',
  '_scaffold',
};

/// Assemble one legal Office of a sparse document. [office] is the engine's
/// descriptor of the option (office kind, slots, Te Deum); without it the
/// office kind follows the document's rank (legacy callers, fixtures).
OfficeAssembly assembleOffice({
  required Map<String, dynamic> proper,
  required Map<String, dynamic> currentDay,
  required Map<String, Map<String, dynamic>> templates,
  required bool isSunday,
  String? choice,
  OfficeDescriptor? office,
}) {
  final officeKind =
      office?.officeKind ?? officeKindOfRank(proper['_rank']?.toString());
  final slots = office == null
      ? officeSlots(officeKind, isSunday: isSunday)
      : _descriptorSlots(office);
  final choices = assemblyChoices(proper, officeKind, office: office);
  final selected = choices.contains(choice) ? choice! : choices.first;
  final templateId = selected == kCurrentDayChoice
      ? defaultTemplateOf(proper)
      : selected;
  final common = templates[templateId];
  final sunday = templates[kSundayWeek1Template];
  final rules = proper['_fieldRules'] is Map
      ? Map<String, dynamic>.from(proper['_fieldRules'] as Map)
      : const <String, dynamic>{};
  final day = <String, dynamic>{};
  final provenance = <String, String>{};
  final refs = <(String, List<String>)>[];
  final integrity = <AssemblyIntegrityError>[];
  const missingRequired = (null, 'missing-required');

  currentDay.forEach((key, value) {
    if (!_identity.contains(key) &&
        !kOfficeFieldSlots.containsKey(key) &&
        !kFirstVesperFields.contains(key)) {
      day[key] = value;
    }
  });
  proper.forEach((key, value) {
    if (key != '_fieldRules' &&
        !kOfficeFieldSlots.containsKey(key) &&
        !kFirstVesperFields.contains(key) &&
        !_blank(value)) {
      day[key] = value;
    }
  });

  List<String> refNames(Object? ref) =>
      ref is List ? ref.map((e) => e.toString()).toList() : [ref.toString()];

  // `fromSource` and `fromTemplate` call each other.
  late final (Object?, String)? Function(String, String, [String?]) sourceOf;
  (Object?, String)? fromTemplate(
    Map<String, dynamic>? template,
    String field,
    String origin,
  ) {
    if (template == null) return null;
    final templateRules = template['_fieldRules'];
    final rule = templateRules is Map ? templateRules[field] : null;
    if (rule is Map && rule['ref'] != null) {
      refs.add((field, refNames(rule['ref'])));
      return (null, 'pending');
    }
    if (rule is Map && rule['source'] != null) {
      final source = rule['source'].toString();
      return sourceOf(
        source == 'common' ? kCurrentDayChoice : source,
        field,
        rule['template']?.toString(),
      );
    }
    return _blank(template[field]) ? null : (template[field], origin);
  }

  (Object?, String)? fromSource(String source, String field, [String? named]) {
    switch (source) {
      case 'common':
        return fromTemplate(common, field, 'common:$templateId');
      case 'template':
        return fromTemplate(templates[named], field, 'common:$named');
      case kSundayWeek1Template:
        return sunday != null && !_blank(sunday[field])
            ? (sunday[field], kSundayWeek1Template)
            : null;
      case 'office-for-dead':
        return fromTemplate(
          templates['office-for-dead'],
          field,
          'common:office-for-dead',
        );
      case 'complementary':
        final complementary = templates[kComplementaryPsalmodyTemplate];
        if (complementary != null && !_blank(complementary[field])) {
          return (complementary[field], 'complementary');
        }
        integrity.add(
          AssemblyIntegrityError(
            field,
            kComplementaryPsalmodyTemplate,
            complementary == null ? 'template-missing' : 'field-missing',
          ),
        );
        return missingRequired;
      case kCurrentDayChoice:
        return _blank(currentDay[field])
            ? null
            : (currentDay[field], kCurrentDayChoice);
    }
    return null;
  }

  sourceOf = fromSource;

  (Object?, String)? firstOf(Iterable<String> sources, String field) {
    var required = false;
    for (final source in sources) {
      final found = fromSource(source, field);
      if (found?.$2 == 'missing-required') {
        required = true;
        continue;
      }
      if (found != null) return found;
    }
    return required ? missingRequired : null;
  }

  (Object?, String)? resolve(String field) {
    if (!_blank(proper[field])) return (proper[field], 'proper');
    final rule = rules[field];
    if (rule is Map && rule['omit'] == true) return ('', 'omit');
    if (rule is Map && rule['ref'] != null) {
      refs.add((field, refNames(rule['ref'])));
      return (null, 'pending');
    }
    if (rule is Map && rule['source'] != null) {
      if (rule['allowCurrentDay'] == true && selected == kCurrentDayChoice) {
        final fromDay = fromSource(kCurrentDayChoice, field);
        if (fromDay != null) return fromDay;
      }
      final found = fromSource(
        rule['source'].toString(),
        field,
        rule['template']?.toString(),
      );
      if (found != null && found.$2 != 'missing-required') return found;
    }
    final (hour, component) = kOfficeFieldSlots[field]!;
    final slot = slots['$hour.$component'];
    if (slot == null) return firstOf(['common', kCurrentDayChoice], field);
    final fromChain = firstOf(slot.chain.where((s) => s != 'proper'), field);
    // A required source (complementary psalmody) is never replaced by the
    // day: the field stays empty and the integrity error is reported.
    if (fromChain?.$2 == 'missing-required') return null;
    if (fromChain != null) return fromChain;
    if (slot.choice.isNotEmpty) {
      final order = selected == kCurrentDayChoice
          ? [kCurrentDayChoice, 'common']
          : ['common', kCurrentDayChoice];
      return firstOf(order.where(slot.choice.contains), field);
    }
    return fromSource(kCurrentDayChoice, field);
  }

  final missing = <String>[];
  for (final field in kOfficeFieldSlots.keys) {
    final found = resolve(field);
    if (found?.$2 == 'pending') continue;
    if (found == null || found.$2 == 'missing-required') {
      day[field] = '';
      missing.add(field);
      continue;
    }
    day[field] = found.$1;
    provenance[field] = found.$2;
  }

  // One antiphon around the whole psalmody: an empty 2nd/3rd antiphon is
  // the form of the hour, not a gap.
  for (final hour in const [
    'officeOfReadings',
    'laudes',
    'sext1',
    'sext2',
    'sext3',
    'vesper',
  ]) {
    bool has(String name) => !_blank(day['$hour$name']);
    if (!has('Ant1') ||
        !has('Ps1') ||
        !has('Ps2') ||
        !has('Ps3') ||
        has('Ant2') ||
        has('Ant3')) {
      continue;
    }
    missing
      ..remove('${hour}Ant2')
      ..remove('${hour}Ant3');
  }

  if (proper['_omitFirstVespers'] != true) {
    for (final field in kFirstVesperFields) {
      if (!_blank(proper[field])) {
        day[field] = proper[field];
        provenance[field] = 'proper';
        continue;
      }
      final rule = rules[field];
      if (rule is Map && rule['omit'] == true) continue;
      if (rule is Map && rule['ref'] != null) {
        refs.add((field, refNames(rule['ref'])));
        continue;
      }
      final found =
          (rule is Map && rule['source'] != null
              ? fromSource(
                  rule['source'].toString(),
                  field,
                  rule['template']?.toString(),
                )
              : null) ??
          fromTemplate(common, field, 'common:$templateId');
      if (found != null && found.$2 != 'pending') {
        day[field] = found.$1;
        provenance[field] = found.$2;
      }
    }
  }

  // References to another field of the same Office («Гімн з Ютрані»).
  for (final (field, names) in refs) {
    final target = names.where((name) => !_blank(day[name])).firstOrNull;
    if (target != null) {
      day[field] = day[target];
      provenance[field] = 'ref:$target';
    } else {
      final fallback = fromSource(kCurrentDayChoice, field);
      day[field] = fallback?.$1 ?? '';
      if (fallback != null) {
        provenance[field] = fallback.$2;
      } else if (kOfficeFieldSlots.containsKey(field)) {
        missing.add(field);
      }
    }
  }

  if (proper['_omitTeDeum'] == true) {
    day[_teDeum] = false;
  } else if (proper[_teDeum] != null && proper[_teDeum] != '') {
    day[_teDeum] = proper[_teDeum] == true;
  } else if (office != null) {
    day[_teDeum] = office.teDeum ? true : '';
  } else {
    day[_teDeum] = officeKind == 'solemnity' || officeKind == 'feast'
        ? true
        : '';
  }

  for (final key in const [
    '_date',
    '_rank',
    '_place',
    '_feastName',
    '_feast',
    '_celebrationId',
    '_contentStatus',
  ]) {
    if (proper.containsKey(key)) day[key] = proper[key];
  }
  day['_templates'] = _templatesOf(proper);
  if (templateId.isNotEmpty && selected != kCurrentDayChoice) {
    day['_currentVersion'] = templateId;
  }
  day['_assembly'] = {
    'choice': selected,
    'template': selected == kCurrentDayChoice ? '' : templateId,
    'sparse': true,
  };
  if (integrity.isNotEmpty) {
    day['_integrityErrors'] = [for (final error in integrity) error.toJson()];
  }
  return OfficeAssembly(
    day,
    selected,
    provenance,
    missing: missing,
    integrity: integrity,
  );
}

/// Route id of a choice: the default is the document id; the others are
/// `<id>--<template>` (the ids of the former copies) or `<id>--day`.
String assemblyDayId(
  String documentId,
  String choice, {
  required bool isDefault,
}) => isDefault
    ? documentId
    : '$documentId--${choice == kCurrentDayChoice ? 'day' : choice}';

/// `<id>--<choice>` → (documentId, choice); null when not a choice id.
(String, String)? parseAssemblyDayId(String dayId) {
  final index = dayId.lastIndexOf('--');
  if (index <= 0) return null;
  final suffix = dayId.substring(index + 2);
  return (
    dayId.substring(0, index),
    suffix == 'day' ? kCurrentDayChoice : suffix,
  );
}
