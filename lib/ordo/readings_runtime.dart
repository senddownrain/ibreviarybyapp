/// Execution of a readings plan (port of mybrev `src/utils/ordo/readingsPlan.js`
/// and the `readingsService` query step): the engine's lookups of EVERY legal
/// option are answered from the `readings` on the device and the documents
/// are put in the engine's order. No priority logic of its own: documents
/// that no lookup of a legal option names never reach the Readings screen.
library;

import 'package:mybrev_flutter/models/parsed_reading.dart';
import 'package:mybrev_flutter/ordo/reading_references.dart';
import 'package:mybrev_flutter/ordo/readings_plan.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/utils/reading_content.dart';
import 'package:mybrev_flutter/utils/readings_index.dart';

/// One query a plan needs (a Firestore query of the web service).
class ReadingQuery {
  const ReadingQuery(this.field, this.value);

  /// `_feast`, `_date`, `_dayId` or `period`.
  final String field;

  /// A string, or `(type, week, dayOfWeek)` for `period` (`week` null = the
  /// documents of a week-less period).
  final Object value;

  @override
  bool operator ==(Object other) =>
      other is ReadingQuery && other.field == field && other.value == value;

  @override
  int get hashCode => Object.hash(field, value);
}

List<String> _feastVariants(String code) {
  final bare = code.replaceFirst(RegExp(r'^feast-'), '');
  return bare.isEmpty ? const [] : ['feast-$bare', bare];
}

/// Queries needed by [plan] (deduplicated, in plan order).
List<ReadingQuery> readingQueriesOfPlan(
  List<OptionReadingsPlan> plan, {
  String dayId = '',
}) {
  final specs = <ReadingQuery>{};
  if (dayId.isNotEmpty) specs.add(ReadingQuery('_dayId', dayId));
  for (final option in plan) {
    for (final entry in option.lookup) {
      final where = entry.where;
      if (where['_feast'] != null) {
        for (final value in _feastVariants('${where['_feast']}')) {
          specs.add(ReadingQuery('_feast', value));
        }
      } else if (where['_date'] != null) {
        specs.add(ReadingQuery('_date', '${where['_date']}'));
      } else if (where['_periodType'] != null) {
        final raw = where['_periodWeekNumber'];
        final weeks = raw is List ? raw : [raw];
        for (final week in weeks) {
          specs.add(
            ReadingQuery('period', (
              '${where['_periodType']}',
              week == null ? null : (week as num).toInt(),
              (where['_dayOfWeek'] as num).toInt(),
            )),
          );
        }
      }
    }
  }
  return specs.toList();
}

/// The documents a [ReadingQuery] returns from the readings on the device,
/// by document id (as Firestore orders an equality query).
List<ParsedReading> executeReadingQuery(ReadingQuery query) {
  final ids = switch (query.field) {
    '_feast' => ReadingsIndex.lookupByFeast(query.value as String),
    '_date' => ReadingsIndex.lookupByDate(query.value as String),
    '_dayId' => ReadingsIndex.lookupByDayId(query.value as String),
    'period' => () {
      final (type, week, day) = query.value as (String, int?, int);
      return ReadingsIndex.lookupByPeriod(type, week ?? 0, day);
    }(),
    _ => const <String>[],
  };
  final box = HiveService.readingsBox;
  final docs = <ParsedReading>[];
  for (final id in [...ids]..sort()) {
    final raw = box.get(id);
    if (raw is! Map) continue;
    if (raw['_obsolete'] == true) continue;
    final doc = ParsedReading.fromMap(id, Map<String, dynamic>.from(raw));
    if (hasReadingDocumentContent(doc)) docs.add(doc);
  }
  return docs;
}

/// Every document the plan's queries return (one entry per id).
List<ParsedReading> fetchReadingDocuments(
  List<OptionReadingsPlan> plan, {
  String dayId = '',
}) {
  final byId = <String, ParsedReading>{};
  for (final query in readingQueriesOfPlan(plan, dayId: dayId)) {
    for (final doc in executeReadingQuery(query)) {
      byId.putIfAbsent(doc.id, () => doc);
    }
  }
  return byId.values.toList();
}

bool _linkedTo(ParsedReading doc, String dayId) =>
    doc.dayId == dayId || doc.dayIds.contains(dayId);

/// Documents of each lookup of [option], in lookup order (mybrev
/// `optionReadings`): weekday documents of date-based seasons keep the
/// calendar-weekday variant.
List<List<ParsedReading>> optionReadingLists(
  OptionReadingsPlan option,
  List<ParsedReading> docs,
  int dayOfWeek,
) => [
  for (final entry in option.lookup)
    () {
      final found = selectReadingDocuments(entry, option.option, docs);
      return entry.where['_date'] != null
          ? calendarDayVariants(found, dayOfWeek)
          : found;
    }(),
];

/// Every document of every legal option in the engine's order: a document
/// linked to [dayId] first, then primary, then the alternatives. Each
/// document remembers the legal option it belongs to
/// ([ParsedReading.ordoOptionId]; the first option that names it, an
/// untagged linked document takes the tag of the first option that names
/// it), so the screen can open the readings of the celebration chosen in the
/// calendar (mybrev `orderReadingsByPlan`, `includeAlternatives`).
List<ParsedReading> orderReadingsByPlan(
  List<OptionReadingsPlan> plan,
  List<ParsedReading> docs, {
  required int dayOfWeek,
  String dayId = '',
}) {
  final planned = <ParsedReading>[];
  for (final option in plan) {
    final lists = optionReadingLists(option, docs, dayOfWeek);
    for (var i = 0; i < lists.length; i++) {
      final purpose = option.lookup[i].purpose;
      final role = (
        purpose: purpose,
        isDefault: purpose == option.defaultPurpose,
      );
      planned.addAll(
        lists[i].map(
          (doc) => doc.withOrdoOption(
            option.optionId,
            roles: {option.optionId: role},
          ),
        ),
      );
    }
  }
  // A document linked to the Hours day id comes first, but only when the
  // plan itself offers it.
  final plannedIds = {for (final doc in planned) doc.id};
  final ordered = <ParsedReading>[
    if (dayId.isNotEmpty)
      ...docs.where(
        (doc) => _linkedTo(doc, dayId) && plannedIds.contains(doc.id),
      ),
    ...planned,
  ];
  final unique = <String, ParsedReading>{};
  for (final doc in ordered) {
    final known = unique[doc.id];
    if (known == null) {
      unique[doc.id] = doc;
    } else {
      unique[doc.id] =
          (known.ordoOptionId == null && doc.ordoOptionId != null
                  ? known.withOrdoOption(
                      doc.ordoOptionId!,
                      roles: known.ordoOptionRoles,
                    )
                  : known)
              .withOrdoOption(
                (known.ordoOptionId ?? doc.ordoOptionId)!,
                roles: {...known.ordoOptionRoles, ...doc.ordoOptionRoles},
              );
    }
  }
  return unique.values.toList();
}

/// What to tell the reader when the selected celebration has no texts of its
/// own readings (mybrev `readingsNotice`): the known citation
/// (`reference-only`) or nothing known (`missing`). Null: nothing to say
/// (the weekday readings of a memorial are normal).
({String status, String optionId, String title, String? reference})?
readingsNotice(
  List<OptionReadingsPlan> plan,
  String selectedOptionId,
  List<ParsedReading> docs,
) {
  final option =
      plan.where((item) => item.optionId == selectedOptionId).firstOrNull ??
      plan.firstOrNull;
  if (option == null || option.kind == 'temporal') return null;
  if (option.isMemorial) return null;
  final proper = [
    for (final entry in option.lookup)
      if (entry.purpose == 'proper')
        ...selectReadingDocuments(entry, option.option, docs),
  ];
  if (proper.isNotEmpty) return null;
  final reference = option.readingsReference;
  final has = (reference ?? '').isNotEmpty;
  return (
    status: has ? 'reference-only' : 'missing',
    optionId: option.optionId,
    title: option.title,
    reference: has ? reference : null,
  );
}
