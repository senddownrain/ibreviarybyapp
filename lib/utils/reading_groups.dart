import 'package:mybrev_flutter/models/parsed_reading.dart';
import 'package:mybrev_flutter/utils/reading_content.dart';

class ReadingCelebrationGroup {
  final String key;
  final String label;
  final List<ParsedReading> documents;

  const ReadingCelebrationGroup({
    required this.key,
    required this.label,
    required this.documents,
  });
}

/// Returns the Hours day identity when every document in a celebration group
/// points to the same liturgical day.
String? readingCelebrationDayId(ReadingCelebrationGroup group) {
  final directIds = <String>{};
  for (final reading in group.documents) {
    final direct = reading.dayId?.trim();
    if (direct != null && direct.isNotEmpty) directIds.add(direct);
  }
  if (directIds.isNotEmpty) {
    return directIds.length == 1 ? directIds.single : null;
  }

  final linkedIds = <String>{};
  for (final reading in group.documents) {
    linkedIds.addAll(
      reading.dayIds.map((id) => id.trim()).where((id) => id.isNotEmpty),
    );
  }
  return linkedIds.length == 1 ? linkedIds.single : null;
}

String readingCelebrationKey(ParsedReading reading) {
  final variant = (reading.variant ?? '').trim().toLowerCase();
  final variantSuffix = variant.isEmpty ? '' : '|variant:$variant';
  if ((reading.dayId ?? '').isNotEmpty) {
    return 'day:${reading.dayId}$variantSuffix';
  }
  if (reading.dayIds.isNotEmpty) {
    final ids = [...reading.dayIds]..sort();
    return 'days:${ids.join(',')}$variantSuffix';
  }
  if (reading.date != null && reading.date!.isNotEmpty) {
    return [
      'date:${reading.date}',
      normalizeReadingTitle(reading.title),
      normalizeLiturgicalRank(reading.rank),
      normalizeDayPlaces(reading.places),
      variant,
    ].join('|');
  }
  if (reading.feast != null && reading.feast!.isNotEmpty) {
    final feast = reading.feast!.replaceFirst(RegExp(r'^feast-'), '');
    return 'feast:feast-$feast$variantSuffix';
  }
  if (reading.periodType != null) {
    return 'period:${reading.periodType}:w${reading.periodWeekNumber}:d${reading.dayOfWeek}$variantSuffix';
  }
  return 'id:${reading.id}';
}

String _groupLabel(List<ParsedReading> documents) {
  final withContent = documents.where(readingHasVisibleContent).toList();
  final reading = withContent.isNotEmpty ? withContent.first : documents.first;
  final title = reading.title?.trim();
  if (title != null && title.isNotEmpty) return _stripHtml(title);
  if (reading.feast != null && reading.feast!.isNotEmpty) {
    return reading.feast!;
  }
  if (reading.date != null) return 'Чытанні ${reading.date}';
  return 'Чытанні дня';
}

const _rankAliases = {
  'урачыстасць': 'solemnitas',
  'solemnity': 'solemnitas',
  'solemnitas': 'solemnitas',
  'свята': 'festum',
  'feast': 'festum',
  'festum': 'festum',
  'успамін': 'memoria',
  'memorial': 'memoria',
  'memoria': 'memoria',
  'memoria-ad-libitum': 'memoria-ad-libitum',
  'успамін усіх памерлых': 'commemoratio-defunctorum',
  'commemoratio-defunctorum': 'commemoratio-defunctorum',
};

/// mybrev `normalizeRank`: a missing rank is an optional memorial, an unknown
/// one is '' .
String normalizeLiturgicalRank(String? value) {
  final key = (value ?? '').trim().toLowerCase();
  if (key.isEmpty) return 'memoria-ad-libitum';
  return _rankAliases[key] ?? '';
}

const _placeCodes = {
  'гродзенская дыяцэзія': 'grodno',
  'гродзенскай дыяцэзіі': 'grodno',
  'віцебская дыяцэзія': 'vitebsk',
  'віцебскай дыяцэзіі': 'vitebsk',
  'пінская дыяцэзія': 'pinsk',
  'пінскай дыяцэзіі': 'pinsk',
  'мінска-магілёўская архідыяцэзія': 'minsk-mohilev',
  'мінска-магілёўскай архідыяцэзіі': 'minsk-mohilev',
};

/// mybrev `normalizeDayPlaces`: diocese codes, sorted, comma-joined.
String normalizeDayPlaces(Iterable<String> places) {
  final codes = <String>{};
  for (final item in places) {
    final key = item.trim().toLowerCase();
    if (key.isEmpty) continue;
    if (_placeCodes.containsValue(key)) {
      codes.add(key);
      continue;
    }
    for (final entry in _placeCodes.entries) {
      if (key.contains(entry.key)) codes.add(entry.value);
    }
  }
  return (codes.toList()..sort()).join(',');
}

/// mybrev `normalizeReadingTitle` (without NFKC: the texts are NFC).
String normalizeReadingTitle(String? value) =>
    (value ?? '')
        .toLowerCase()
        .replaceFirst(
          RegExp(r'^\d{1,2}\s+[\p{L}.]+\s*[—–-]\s*', unicode: true),
          '',
        )
        .replaceAll(
          RegExp(r'(?:^|[\s,])год\s+[abcавс](?=\s|,|$)', unicode: true),
          ' ',
        )
        .replaceAll(
          RegExp(
            r'(?:^|[\s,])(?:урачыстасць|свята|успамін)(?=[\s,]|$)',
            unicode: true,
          ),
          ' ',
        )
        .replaceAll(
          RegExp(
            r'юзаф\p{L}*\s+(?:работнік|рамеснік)\p{L}*',
            unicode: true,
          ),
          'юзаф рамеснік',
        )
        .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

String normalizeReadingCycle(String? value) {
  final cycle = (value ?? '').trim().toUpperCase();
  return const {'A', 'B', 'C', '1', '2'}.contains(cycle) ? cycle : '';
}

final RegExp _readingYearSuffixPattern = RegExp(
  r'(?:,\s*)?Год\s+(?:[АAВBБCС]|I{1,3}|[12])\s*:?\s*$',
  caseSensitive: false,
);

/// The stored reading titles often end with a hardcoded "Год A" suffix that
/// does not necessarily match the document's actual lectionary year.
String stripReadingYearSuffix(String title) =>
    title.replaceFirst(_readingYearSuffixPattern, '').trim();

/// "Год A" / "Год I" label for a lectionary cycle ('A'|'B'|'C'|'1'|'2').
String readingCycleLabel(String cycle) {
  final normalized = normalizeReadingCycle(cycle);
  return switch (normalized) {
    'A' || 'B' || 'C' => 'Год $normalized',
    '1' => 'Год I',
    '2' => 'Год II',
    _ => '',
  };
}

String _stripHtml(String s) =>
    s.replaceAll(RegExp(r'<[^>]+>'), '').replaceAll(RegExp(r'\s+'), ' ').trim();

List<ReadingCelebrationGroup> groupReadings(List<ParsedReading> readings) {
  final map = <String, List<ParsedReading>>{};
  for (final reading in readings) {
    final key = readingCelebrationKey(reading);
    map.putIfAbsent(key, () => []).add(reading);
  }
  return map.entries
      .map(
        (e) => ReadingCelebrationGroup(
          key: e.key,
          label: _groupLabel(e.value),
          documents: e.value,
        ),
      )
      .toList();
}

ParsedReading? pickReadingForCycle(
  List<ParsedReading> documents,
  String? cycle,
) {
  if (documents.isEmpty) return null;

  List<ParsedReading> preferContent(List<ParsedReading> docs) {
    final withContent = docs.where(readingHasVisibleContent).toList();
    return withContent.isNotEmpty ? withContent : docs;
  }

  final normalizedCycle = normalizeReadingCycle(cycle);
  if (normalizedCycle.isNotEmpty) {
    final exact = preferContent(
      documents
          .where((d) => normalizeReadingCycle(d.year) == normalizedCycle)
          .toList(),
    );
    if (exact.isNotEmpty) return exact.first;
  }
  final shared = preferContent(
    documents.where((d) => d.year == null || d.year!.isEmpty).toList(),
  );
  if (shared.isNotEmpty) return shared.first;
  return preferContent(documents).first;
}

List<String> availableCyclesForGroup(List<ParsedReading> documents) {
  const order = ['A', 'B', 'C', '1', '2'];
  final found = documents
      .map((d) => normalizeReadingCycle(d.year))
      .where((y) => y.isNotEmpty)
      .toSet();
  return order.where(found.contains).toList();
}
