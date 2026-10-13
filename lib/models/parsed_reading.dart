import 'package:mybrev_flutter/models/mass_reading_sets.dart';

/// Parse psalm verses — supports both `List<String>` and
/// `List<{number, text}>` formats.
List<String> _parseVerses(dynamic raw) {
  if (raw == null) return [];
  final list = raw as List<dynamic>;
  return list.map((e) {
    if (e is String) return e;
    if (e is Map) {
      // {number: N, text: "..."} format from parser
      return (e['text'] as String?) ?? e.toString();
    }
    return e.toString();
  }).toList();
}

/// A single section within a parsed reading (reading, psalm, alleluia, gospel).
class ParsedSection {
  // Common
  final String? bible;

  // Reading / Gospel
  final String? comment;
  final String? title;
  final String? text;

  // Psalm
  final String? chorus;
  final String? altChorus;

  /// Citation printed with the alternative refrain («Р.: 9а»).
  final String? altChorusRef;
  final List<String> verses;

  // Alleluia
  final String? verse;
  final String? acclamation;

  /// Closing acclamation: null = the default one, '' = none is said.
  final String? conclusion;

  /// Rubrics after the text.
  final List<String> rubrics;

  /// «Або …» second reading of the same slot (a shorter form, another text).
  final List<ParsedSection> alternatives;

  /// `long` | `short` (an alternative offered in two lengths).
  final String? form;

  /// Weekday year `1`/`2` the page gave the section to (never filtered:
  /// weekday years are separate documents).
  final String? year;

  /// Passion by roles instead of the plain text.
  final PassionText? passion;

  const ParsedSection({
    this.bible,
    this.comment,
    this.title,
    this.text,
    this.chorus,
    this.altChorus,
    this.altChorusRef,
    this.verses = const [],
    this.verse,
    this.acclamation,
    this.conclusion,
    this.rubrics = const [],
    this.alternatives = const [],
    this.form,
    this.year,
    this.passion,
  });

  static String? _keep(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  /// This flat (legacy) section as the structured section the Readings
  /// screen renders it as: [kind] `reading` | `psalm` | `acclamation` |
  /// `sequence` | `gospel`, [role] the flat field name.
  MassReadingSection toSection(String kind, String role) => MassReadingSection(
    kind: kind,
    role: role,
    year: _keep(year),
    form: _keep(form),
    bible: _keep(bible),
    comment: _keep(comment),
    title: _keep(title),
    text: _keep(text),
    conclusion: conclusion?.trim(),
    alternatives: [for (final item in alternatives) item.toSection(kind, role)],
    rubrics: rubrics,
    chorus: _keep(chorus),
    altChorus: _keep(altChorus),
    altChorusRef: _keep(altChorusRef),
    verses: verses,
    acclamation: _keep(acclamation),
    verse: _keep(verse),
    passion: passion,
  );

  factory ParsedSection.fromMap(Map<String, dynamic> map) {
    final conclusion = map['conclusion'];
    final rubrics = map['rubrics'];
    final alternatives = map['alternatives'];
    return ParsedSection(
      bible: map['bible'] as String?,
      comment: map['comment'] as String?,
      title: map['title'] as String?,
      text: map['text'] as String?,
      chorus: map['chorus'] as String?,
      altChorus: map['altChorus'] as String?,
      altChorusRef: map['altChorusRef'] as String?,
      verses: _parseVerses(map['verses']),
      verse: map['verse'] as String?,
      acclamation: map['acclamation'] as String?,
      conclusion: conclusion is String ? conclusion : null,
      rubrics: rubrics is List
          ? [
              for (final item in rubrics)
                if ('$item'.trim().isNotEmpty) '$item'.trim(),
            ]
          : const [],
      alternatives: alternatives is List
          ? [
              for (final item in alternatives)
                if (item is Map)
                  ParsedSection.fromMap(Map<String, dynamic>.from(item)),
            ]
          : const [],
      form: map['form']?.toString(),
      year: map['year']?.toString(),
      passion: map['passion'] is Map
          ? PassionText.fromMap(
              Map<String, dynamic>.from(map['passion'] as Map),
            )
          : null,
    );
  }
}

/// A document from the `readings` Firestore collection.
class ParsedReading {
  final String id;

  // Year indicator: '1'/'2' for weekdays, 'A'/'B'/'C' for Sundays, null if none
  final String? year;

  // Sections
  final ParsedSection? reading; // weekday single reading
  final ParsedSection? reading1; // Sunday / solemnity first reading
  final ParsedSection? reading2; // Sunday / solemnity second reading
  final ParsedSection? psalm;
  final ParsedSection? alleluia;
  final ParsedSection? gospel;
  final ParsedSection? sequence;

  /// Structured Mass reading sets (vigil/day, A/B/C, Passion by roles).
  final MassReadings? massReadings;

  /// A legacy document covered by a canonical document with sets.
  final MassReadingsRef? massReadingsRef;

  // Metadata
  final String? title;
  final String? periodType;
  final int? periodWeekNumber;
  final int? dayOfWeek;
  final String? date; // DD.MM
  final String? feast;
  final String? sourceId;
  final String? dayId;
  final List<String> dayIds;
  final String? rank;
  final List<String> places;
  final String? variant;
  final int? calendarDayOfWeek;
  final bool hasReadings; // false = commune stub without own readings

  /// The legal Ordo option whose readings lookup named this document (set
  /// when the readings of a date are ordered by the engine's plan; never
  /// stored).
  final String? ordoOptionId;

  const ParsedReading({
    required this.id,
    this.year,
    this.reading,
    this.reading1,
    this.reading2,
    this.psalm,
    this.alleluia,
    this.gospel,
    this.sequence,
    this.massReadings,
    this.massReadingsRef,
    this.title,
    this.periodType,
    this.periodWeekNumber,
    this.dayOfWeek,
    this.date,
    this.feast,
    this.sourceId,
    this.dayId,
    this.dayIds = const [],
    this.rank,
    this.places = const [],
    this.variant,
    this.calendarDayOfWeek,
    this.hasReadings = true,
    this.ordoOptionId,
  });

  /// This document, remembered as belonging to the legal option [optionId].
  ParsedReading withOrdoOption(String optionId) => ParsedReading(
    id: id,
    year: year,
    reading: reading,
    reading1: reading1,
    reading2: reading2,
    psalm: psalm,
    alleluia: alleluia,
    gospel: gospel,
    sequence: sequence,
    massReadings: massReadings,
    massReadingsRef: massReadingsRef,
    title: title,
    periodType: periodType,
    periodWeekNumber: periodWeekNumber,
    dayOfWeek: dayOfWeek,
    date: date,
    feast: feast,
    sourceId: sourceId,
    dayId: dayId,
    dayIds: dayIds,
    rank: rank,
    places: places,
    variant: variant,
    calendarDayOfWeek: calendarDayOfWeek,
    hasReadings: hasReadings,
    ordoOptionId: optionId,
  );

  /// First reading regardless of field name (reading or reading1).
  ParsedSection? get firstReading => reading ?? reading1;

  /// Whether this has a second reading (Sunday/solemnity).
  bool get hasTwoReadings => reading2 != null;

  /// The document carries structured Mass reading sets.
  bool get hasMassReadingSets => massReadings != null;

  factory ParsedReading.fromMap(String docId, Map<String, dynamic> map) {
    ParsedSection? section(String key) {
      final v = map[key];
      if (v == null) return null;
      final data = Map<String, dynamic>.from(v as Map);
      // The bundled ordinary-w28-d1 year A source prints «Мк 22» above
      // a Gospel explicitly titled «паводле Мацвея». Correct only this
      // confirmed book mismatch, preserving the complete/short verse ranges
      // and source JSON. Both the reader and ORDO consume this projection.
      if (key == 'gospel' &&
          (data['title'] as String? ?? '').contains('паводле Мацвея') &&
          RegExp(r'^Мк\s+22\s*,').hasMatch(data['bible'] as String? ?? '')) {
        data['bible'] = (data['bible'] as String).replaceFirst('Мк', 'Мц');
      }
      return ParsedSection.fromMap(data);
    }

    return ParsedReading(
      id: docId,
      year: map['year']?.toString(),
      reading: section('reading'),
      reading1: section('reading1'),
      reading2: section('reading2'),
      psalm: section('psalm'),
      alleluia: section('alleluia'),
      gospel: section('gospel'),
      sequence: section('sequence'),
      massReadings: MassReadings.fromMap(map['massReadings']),
      massReadingsRef: MassReadingsRef.fromMap(map['_massReadingsRef']),
      title: _asString(map['title']),
      periodType: map['_periodType'] as String?,
      periodWeekNumber: _toInt(map['_periodWeekNumber']),
      dayOfWeek: _toInt(map['_dayOfWeek']),
      date: map['_date'] as String?,
      feast: map['_feast'] as String?,
      sourceId: map['_sourceId'] as String?,
      dayId: _asString(map['_dayId']),
      dayIds: _asStringList(map['_dayIds']),
      rank: _asString(map['_rank']),
      places: _asStringList(map['_place']),
      variant: _asString(map['_variant']),
      calendarDayOfWeek: _toInt(map['_calendarDayOfWeek']),
      hasReadings: (map['_hasReadings'] as bool?) ?? true,
    );
  }

  static int? _toInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    return null;
  }

  static String? _asString(dynamic value) {
    final result = value?.toString().trim() ?? '';
    return result.isEmpty ? null : result;
  }

  static List<String> _asStringList(dynamic value) {
    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    final single = value?.toString().trim() ?? '';
    return single.isEmpty ? const [] : [single];
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      if (year != null) 'year': year,
      if (reading != null) 'reading': _sectionToMap(reading!),
      if (reading1 != null) 'reading1': _sectionToMap(reading1!),
      if (reading2 != null) 'reading2': _sectionToMap(reading2!),
      if (psalm != null) 'psalm': _sectionToMap(psalm!),
      if (alleluia != null) 'alleluia': _sectionToMap(alleluia!),
      if (gospel != null) 'gospel': _sectionToMap(gospel!),
      if (sequence != null) 'sequence': _sectionToMap(sequence!),
      if (title != null) 'title': title,
      if (periodType != null) '_periodType': periodType,
      if (periodWeekNumber != null) '_periodWeekNumber': periodWeekNumber,
      if (dayOfWeek != null) '_dayOfWeek': dayOfWeek,
      if (date != null) '_date': date,
      if (feast != null) '_feast': feast,
      if (sourceId != null) '_sourceId': sourceId,
      if (dayId != null) '_dayId': dayId,
      if (dayIds.isNotEmpty) '_dayIds': dayIds,
      if (rank != null) '_rank': rank,
      if (places.isNotEmpty) '_place': places,
      if (variant != null) '_variant': variant,
      if (calendarDayOfWeek != null) '_calendarDayOfWeek': calendarDayOfWeek,
      '_hasReadings': hasReadings,
    };
  }

  static Map<String, dynamic> _sectionToMap(ParsedSection s) => {
    if (s.bible != null) 'bible': s.bible,
    if (s.comment != null) 'comment': s.comment,
    if (s.title != null) 'title': s.title,
    if (s.text != null) 'text': s.text,
    if (s.chorus != null) 'chorus': s.chorus,
    if (s.altChorus != null) 'altChorus': s.altChorus,
    if (s.verses.isNotEmpty) 'verses': s.verses,
    if (s.verse != null) 'verse': s.verse,
    if (s.altChorusRef != null) 'altChorusRef': s.altChorusRef,
    if (s.acclamation != null) 'acclamation': s.acclamation,
    if (s.conclusion != null) 'conclusion': s.conclusion,
    if (s.rubrics.isNotEmpty) 'rubrics': s.rubrics,
    if (s.alternatives.isNotEmpty)
      'alternatives': [for (final item in s.alternatives) _sectionToMap(item)],
    if (s.form != null) 'form': s.form,
    if (s.year != null) 'year': s.year,
  };
}
