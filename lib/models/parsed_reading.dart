/// Parse psalm verses — supports both List<String> and List<{number, text}> formats.
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
  final List<String> verses;

  // Alleluia
  final String? verse;

  const ParsedSection({
    this.bible,
    this.comment,
    this.title,
    this.text,
    this.chorus,
    this.altChorus,
    this.verses = const [],
    this.verse,
  });

  factory ParsedSection.fromMap(Map<String, dynamic> map) {
    return ParsedSection(
      bible: map['bible'] as String?,
      comment: map['comment'] as String?,
      title: map['title'] as String?,
      text: map['text'] as String?,
      chorus: map['chorus'] as String?,
      altChorus: map['altChorus'] as String?,
      verses: _parseVerses(map['verses']),
      verse: map['verse'] as String?,
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

  // Metadata
  final String? periodType;
  final int? periodWeekNumber;
  final int? dayOfWeek;
  final String? date; // DD.MM
  final String? feast;
  final String? sourceId;
  final bool hasReadings; // false = commune stub (feast exists but no own readings)

  const ParsedReading({
    required this.id,
    this.year,
    this.reading,
    this.reading1,
    this.reading2,
    this.psalm,
    this.alleluia,
    this.gospel,
    this.periodType,
    this.periodWeekNumber,
    this.dayOfWeek,
    this.date,
    this.feast,
    this.sourceId,
    this.hasReadings = true,
  });

  /// First reading regardless of field name (reading or reading1).
  ParsedSection? get firstReading => reading ?? reading1;

  /// Whether this has a second reading (Sunday/solemnity).
  bool get hasTwoReadings => reading2 != null;

  factory ParsedReading.fromMap(String docId, Map<String, dynamic> map) {
    ParsedSection? section(String key) {
      final v = map[key];
      if (v == null) return null;
      return ParsedSection.fromMap(Map<String, dynamic>.from(v as Map));
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
      periodType: map['_periodType'] as String?,
      periodWeekNumber: _toInt(map['_periodWeekNumber']),
      dayOfWeek: _toInt(map['_dayOfWeek']),
      date: map['_date'] as String?,
      feast: map['_feast'] as String?,
      sourceId: map['_sourceId'] as String?,
      hasReadings: (map['_hasReadings'] as bool?) ?? true,
    );
  }

  static int? _toInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    return null;
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
      if (periodType != null) '_periodType': periodType,
      if (periodWeekNumber != null) '_periodWeekNumber': periodWeekNumber,
      if (dayOfWeek != null) '_dayOfWeek': dayOfWeek,
      if (date != null) '_date': date,
      if (feast != null) '_feast': feast,
      if (sourceId != null) '_sourceId': sourceId,
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
      };
}
