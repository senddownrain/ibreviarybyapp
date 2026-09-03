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
    final places = [...reading.places]..sort();
    return [
      'date:${reading.date}',
      normalizeReadingTitle(reading.title),
      (reading.rank ?? '').trim().toLowerCase(),
      places.join(','),
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

String normalizeReadingTitle(String? value) => (value ?? '')
    .toLowerCase()
    .replaceFirst(RegExp(r'^\d{1,2}\s+[^—–-]+[—–-]\s*'), '')
    .replaceAll(RegExp(r'\bгод\s+[abcавс]\b'), ' ')
    .replaceAll(RegExp(r'\b(урачыстасць|свята|успамін)\b'), ' ')
    .replaceAll(RegExp(r'[^a-zа-яёіў0-9]+', caseSensitive: false), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

String normalizeReadingCycle(String? value) {
  final cycle = (value ?? '').trim().toUpperCase();
  return const {'A', 'B', 'C', '1', '2'}.contains(cycle) ? cycle : '';
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
      .map((e) => ReadingCelebrationGroup(
            key: e.key,
            label: _groupLabel(e.value),
            documents: e.value,
          ))
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
