/// Biblical citations of the readings of every legal option of a day, for the
/// Ordo — without opening the readings texts (port of mybrev
/// `readingReferences.js` + `readingsPlan.js`).
///
/// The same plan and the same selection as the Readings run on a lightweight
/// in-memory projection of the offline `readings` corpus (no new
/// collection). A celebration whose own readings are not in `readings` shows
/// the citation printed in the calendars (`reference-only`) or the weekday
/// readings when that is the rubrical default; otherwise `missing`.
library;

import 'package:mybrev_flutter/content/content_store.dart';
import 'package:mybrev_flutter/models/parsed_reading.dart';
import 'package:mybrev_flutter/ordo/definitions.dart';
import 'package:mybrev_flutter/ordo/engine.dart';
import 'package:mybrev_flutter/ordo/readings_plan.dart';
import 'package:mybrev_flutter/services/liturgical_content_service.dart'
    show readingTitleSimilarity;
import 'package:mybrev_flutter/utils/reading_content.dart';
import 'package:mybrev_flutter/utils/reading_groups.dart';

abstract final class ReadingReferenceStatus {
  static const proper = 'proper';
  static const weekday = 'weekday';
  static const referenceOnly = 'reference-only';
  static const missing = 'missing';
}

/// «1 чыт.», «Пс», «2 чыт.», «Ев.».
const kReadingCitationLabels = {
  'reading1': '1 чыт.',
  'psalm': 'Пс',
  'reading2': '2 чыт.',
  'gospel': 'Ев.',
};

class ReadingCitation {
  const ReadingCitation(this.key, this.citation);
  final String key;
  final String citation;
  String get label => kReadingCitationLabels[key] ?? key;
}

class ReadingReferenceDocument {
  const ReadingReferenceDocument(this.id, this.title, this.year, this.rows);
  final String id;
  final String title;
  final String? year;
  final List<ReadingCitation> rows;
}

class OptionReadingReferences {
  const OptionReadingReferences({
    required this.optionId,
    required this.title,
    required this.officeKind,
    required this.status,
    required this.documents,
    required this.alternatives,
    this.reference,
  });

  final String optionId;
  final String title;
  final String officeKind;
  final String status;

  /// What the Readings open for this option.
  final List<ReadingReferenceDocument> documents;

  /// A memorial keeps the weekday readings; its own ones are an option.
  final List<ReadingReferenceDocument> alternatives;

  /// Citation printed in the calendars (`reference-only`).
  final String? reference;
}

const _sections = ['reading1', 'reading2', 'psalm', 'alleluia', 'gospel'];

/// In-memory projection of `readings` (documents with content only).
class ReadingReferenceIndex {
  ReadingReferenceIndex(this.entries);

  final List<ParsedReading> entries;

  static ReadingReferenceIndex? _cached;
  static int _builtAt = -1;

  /// The projection of the effective `readings` (rebuilt after a change).
  static ReadingReferenceIndex current() {
    final collection = ContentStore.instance.collection('readings');
    final cached = _cached;
    if (cached != null && _builtAt == collection.changeCount) return cached;
    final entries = <ParsedReading>[];
    for (final key in collection.keys) {
      final raw = collection.get(key);
      if (raw is! Map || raw['_obsolete'] == true) continue;
      final data = Map<String, dynamic>.from(raw);
      final reading = ParsedReading.fromMap(key, data);
      // Structured Mass reading sets (also reference-only ones) count as
      // content even without flat fields (mybrev
      // `hasReadingDocumentContent`).
      final hasContent =
          _hasMassReadingSets(data) ||
          _sections.any(
            (name) => hasReadingSectionContent(switch (name) {
              'reading1' => reading.reading1,
              'reading2' => reading.reading2,
              'psalm' => reading.psalm,
              'alleluia' => reading.alleluia,
              _ => reading.gospel,
            }),
          );
      if (hasContent) entries.add(reading);
    }
    entries.sort((a, b) => a.id.compareTo(b.id));
    _builtAt = collection.changeCount;
    return _cached = ReadingReferenceIndex(entries);
  }
}

/// mybrev `hasMassReadingSets`: `massReadings.sets` holds a set with an id.
bool _hasMassReadingSets(Map<String, dynamic> doc) {
  final massReadings = doc['massReadings'];
  final sets = massReadings is Map ? massReadings['sets'] : null;
  return sets is List &&
      sets.any((set) => set is Map && '${set['id'] ?? ''}'.trim().isNotEmpty);
}

String _clean(String? value) => (value ?? '')
    .replaceAll(RegExp(r'<[^>]*>'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

List<ReadingCitation> _citations(ParsedReading doc) {
  final result = <String, String>{};
  void add(String key, ParsedSection? section) {
    final bible = _clean(section?.bible);
    if (bible.isNotEmpty &&
        hasReadingSectionContent(section) &&
        !result.containsKey(key)) {
      result[key] = bible;
    }
  }

  add('reading1', doc.reading1);
  add('reading1', doc.reading);
  add('psalm', doc.psalm);
  add('reading2', doc.reading2);
  add('gospel', doc.gospel);
  return [
    for (final key in const ['reading1', 'psalm', 'reading2', 'gospel'])
      if (result[key] case final citation?) ReadingCitation(key, citation),
  ];
}

String _normalizeCycle(String? value) {
  final cycle = (value ?? '').trim().toUpperCase();
  return const {'A', 'B', 'C', '1', '2'}.contains(cycle) ? cycle : '';
}

List<ParsedReading> selectLectionaryVariants(
  List<ParsedReading> documents, {
  required String cycle,
  required String sundayCycle,
}) {
  final groups = <String, List<ParsedReading>>{};
  for (final document in documents) {
    groups.putIfAbsent(readingCelebrationKey(document), () => []).add(document);
  }
  return [
    for (final group in groups.values)
      ...() {
        final available = {
          for (final doc in group)
            if (_normalizeCycle(doc.year).isNotEmpty) _normalizeCycle(doc.year),
        };
        final hasSunday = const ['A', 'B', 'C'].any(available.contains);
        final desired = _normalizeCycle(hasSunday ? sundayCycle : cycle);
        if (desired.isNotEmpty) {
          final exact = group
              .where((doc) => _normalizeCycle(doc.year) == desired)
              .toList();
          if (exact.isNotEmpty) return exact;
        }
        final shared = group
            .where((doc) => _normalizeCycle(doc.year).isEmpty)
            .toList();
        return shared.isNotEmpty ? shared : group;
      }(),
  ];
}

/// Weekday documents of a date-keyed season keep the variant of the
/// calendar weekday (mybrev `selectCalendarDayVariants`).
List<ParsedReading> calendarDayVariants(List<ParsedReading> docs, int dow) {
  final exact = docs.where((doc) => doc.calendarDayOfWeek == dow).toList();
  if (exact.isNotEmpty) return exact;
  return docs.where((doc) => doc.calendarDayOfWeek == null).toList();
}

String _bareFeast(String? code) =>
    (code ?? '').replaceFirst(RegExp(r'^feast-'), '');

bool _sameWeek(int? value, Object? wanted) => wanted == null
    ? value == null
    : value != null && value == (wanted as num).toInt();

/// Readings of one lookup among the documents of the date (mybrev
/// `selectReadingDocuments`).
List<ParsedReading> selectReadingDocuments(
  ReadingLookup entry,
  Json option,
  List<ParsedReading> docs,
) {
  final where = entry.where;
  if (where['_feast'] != null) {
    final code = _bareFeast('${where['_feast']}');
    return docs.where((doc) => _bareFeast(doc.feast) == code).toList();
  }
  if (where['_periodType'] != null) {
    final rawWeeks = where['_periodWeekNumber'];
    final weeks = rawWeeks is List ? rawWeeks : [rawWeeks];
    final variant = '${where['_variant'] ?? ''}'.toLowerCase();
    return docs
        .where(
          (doc) =>
              (doc.date ?? '').isEmpty &&
              (doc.feast ?? '').isEmpty &&
              (variant.isEmpty ||
                  (doc.variant ?? '').toLowerCase() == variant) &&
              doc.periodType == where['_periodType'] &&
              weeks.any((week) => _sameWeek(doc.periodWeekNumber, week)) &&
              doc.dayOfWeek == (where['_dayOfWeek'] as num?)?.toInt(),
        )
        .toList();
  }
  if (where['_date'] != null) {
    final variant = '${where['_variant'] ?? ''}'.toLowerCase();
    final sameDate = docs
        .where(
          (doc) =>
              doc.date == where['_date'] &&
              (variant.isEmpty || (doc.variant ?? '').toLowerCase() == variant),
        )
        .toList();
    if (entry.purpose == 'weekday' || where['dateOnly'] == true) {
      return sameDate;
    }
    final ids = <String>{
      for (final ref in [
        option['daysRef'],
        ...?(option['fallbackDaysRefs'] as List?),
      ])
        if (ref is Map) ...?(ref['dayIds'] as List?)?.map((e) => '$e'),
    };
    final linked = sameDate
        .where((doc) => [?doc.dayId, ...doc.dayIds].any(ids.contains))
        .toList();
    if (linked.isNotEmpty) return linked;
    final scored = [
      for (final doc in sameDate)
        (doc, readingTitleSimilarity(doc.title ?? '', '${option['title']}')),
    ];
    final indexed = [for (var i = 0; i < scored.length; i++) (i, scored[i])]
      ..sort((a, b) {
        final byScore = b.$2.$2.compareTo(a.$2.$2);
        return byScore != 0 ? byScore : a.$1.compareTo(b.$1);
      });
    if (indexed.isNotEmpty && indexed.first.$2.$2 >= 0.4) {
      final best = indexed.first.$2.$2;
      return [
        for (final item in indexed)
          if (item.$2.$2 >= best - 0.001) item.$2.$1,
      ];
    }
    return sameDate.every((doc) => (doc.title ?? '').isEmpty)
        ? sameDate
        : const [];
  }
  return const [];
}

/// Ids of the readings the Readings open for [optionId] of [day], in the
/// engine's lookup order (mybrev `orderReadingsByPlan` without alternatives):
/// the option's first lookup that has documents; from the other options only
/// weekday readings may stand in.
List<String> orderedReadingIdsForOption(
  OrdoDay day,
  String optionId,
  List<ParsedReading> pool,
) {
  final plan = day.readingsPlan;
  final selected =
      plan.where((option) => option.optionId == optionId).firstOrNull ??
      plan.first;
  final isSunday = day.dayOfWeek == 1;
  final cycle = isSunday ? day.readingCycle.sunday : day.readingCycle.weekday;
  for (final option in [selected, ...plan.where((o) => o != selected)]) {
    for (final entry in option.lookup) {
      if (option != selected && entry.purpose != 'weekday') continue;
      var found = selectReadingDocuments(entry, option.option, pool);
      if (entry.where['_date'] != null) {
        found = calendarDayVariants(found, day.dayOfWeek);
      }
      final picked = selectLectionaryVariants(
        found,
        cycle: cycle,
        sundayCycle: day.readingCycle.sunday,
      );
      if (picked.isNotEmpty) return [for (final doc in picked) doc.id];
    }
  }
  return const [];
}

/// Reading references of every legal option of [day].
List<OptionReadingReferences> readingReferencesForDay(
  OrdoDay day,
  ReadingReferenceIndex index,
) {
  final plan = day.readingsPlan;
  final isSunday = day.dayOfWeek == 1;
  final cycle = isSunday ? day.readingCycle.sunday : day.readingCycle.weekday;
  final sundayCycle = day.readingCycle.sunday;

  // Documents a Firestore query of the plan would return.
  final docs = <String, ParsedReading>{};
  for (final option in plan) {
    for (final entry in option.lookup) {
      final where = entry.where;
      Iterable<ParsedReading> found = const [];
      if (where['_feast'] != null) {
        final bare = _bareFeast('${where['_feast']}');
        found = [
          ...index.entries.where((doc) => doc.feast == 'feast-$bare'),
          ...index.entries.where((doc) => doc.feast == bare),
        ];
      } else if (where['_date'] != null) {
        found = index.entries.where((doc) => doc.date == where['_date']);
      } else if (where['_periodType'] != null) {
        final rawWeeks = where['_periodWeekNumber'];
        final weeks = rawWeeks is List ? rawWeeks : [rawWeeks];
        found = index.entries.where(
          (doc) =>
              doc.periodType == where['_periodType'] &&
              weeks.any((week) => _sameWeek(doc.periodWeekNumber, week)) &&
              doc.dayOfWeek == (where['_dayOfWeek'] as num?)?.toInt(),
        );
      }
      for (final doc in found) {
        docs[doc.id] = doc;
      }
    }
  }
  final pool = docs.values.toList();

  List<ParsedReading> variants(List<ParsedReading> list) =>
      selectLectionaryVariants(list, cycle: cycle, sundayCycle: sundayCycle);
  List<List<ParsedReading>> optionReadings(OptionReadingsPlan option) => [
    for (final entry in option.lookup)
      () {
        final found = selectReadingDocuments(entry, option.option, pool);
        return entry.where['_date'] != null
            ? calendarDayVariants(found, day.dayOfWeek)
            : found;
      }(),
  ];
  List<ParsedReading> ordered(OptionReadingsPlan selected) {
    for (final option in [selected, ...plan.where((o) => o != selected)]) {
      final lists = optionReadings(option);
      for (var i = 0; i < lists.length; i++) {
        if (option != selected && option.lookup[i].purpose != 'weekday') {
          continue;
        }
        final picked = variants(lists[i]);
        if (picked.isNotEmpty) return picked;
      }
    }
    return const [];
  }

  List<ReadingReferenceDocument> describe(Iterable<ParsedReading> list) => [
    for (final doc in list)
      ReadingReferenceDocument(
        doc.id,
        doc.title ?? '',
        doc.year,
        _citations(doc),
      ),
  ];

  return [
    for (final option in plan)
      () {
        final chosen = ordered(option);
        final ownMap = <String, ParsedReading>{
          for (final entry in option.lookup)
            if (entry.purpose == 'proper')
              for (final doc in selectReadingDocuments(
                entry,
                option.option,
                pool,
              ))
                doc.id: doc,
        };
        final own = variants(ownMap.values.toList());
        final memorial = option.isMemorial;
        String status;
        if (option.kind == 'temporal' || memorial) {
          status = chosen.isNotEmpty
              ? ReadingReferenceStatus.weekday
              : ReadingReferenceStatus.missing;
        } else if (own.isNotEmpty) {
          status = ReadingReferenceStatus.proper;
        } else if ((option.readingsReference ?? '').isNotEmpty) {
          status = ReadingReferenceStatus.referenceOnly;
        } else {
          status = chosen.isNotEmpty
              ? ReadingReferenceStatus.weekday
              : ReadingReferenceStatus.missing;
        }
        final chosenIds = {for (final doc in chosen) doc.id};
        return OptionReadingReferences(
          optionId: option.optionId,
          title: option.title,
          officeKind: option.officeKind,
          status: status,
          documents: status == ReadingReferenceStatus.referenceOnly
              ? const []
              : describe(chosen),
          alternatives: memorial
              ? describe(own.where((doc) => !chosenIds.contains(doc.id)))
              : const [],
          reference: (option.readingsReference ?? '').isNotEmpty && own.isEmpty
              ? option.readingsReference
              : null,
        );
      }(),
  ];
}
