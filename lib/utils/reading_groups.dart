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
  if (reading.feast != null && reading.feast!.isNotEmpty) {
    return 'feast:${reading.feast}';
  }
  if (reading.date != null && reading.date!.isNotEmpty) {
    return 'date:${reading.date}';
  }
  if (reading.periodType != null) {
    return 'period:${reading.periodType}:${reading.periodWeekNumber}:${reading.dayOfWeek}';
  }
  return 'id:${reading.id}';
}

String _groupLabel(List<ParsedReading> documents) {
  final withContent =
      documents.where(readingHasVisibleContent).toList();
  final reading = withContent.isNotEmpty ? withContent.first : documents.first;
  final title = reading.firstReading?.title?.trim();
  if (title != null && title.isNotEmpty) return _stripHtml(title);
  if (reading.feast != null && reading.feast!.isNotEmpty) {
    return reading.feast!;
  }
  if (reading.date != null) return 'Чытанні ${reading.date}';
  return 'Чытанні дня';
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

  if (cycle != null && cycle.isNotEmpty) {
    final exact = preferContent(documents.where((d) => d.year == cycle).toList());
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
      .map((d) => d.year)
      .whereType<String>()
      .where((y) => y.isNotEmpty)
      .toSet();
  return order.where(found.contains).toList();
}
