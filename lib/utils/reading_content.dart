import 'package:mybrev_flutter/models/parsed_reading.dart';

bool hasReadingSectionContent(ParsedSection? section) {
  if (section == null) return false;
  final text = section.text?.trim() ?? '';
  if (text.length > 10) return true;
  final verse = section.verse?.trim() ?? '';
  if (verse.length > 5) return true;
  if (section.verses.any((item) => item.trim().isNotEmpty)) return true;
  final chorus = section.chorus?.trim() ?? '';
  return chorus.length > 5;
}

bool hasReadingDocumentContent(ParsedReading reading) {
  return hasReadingSectionContent(reading.reading) ||
      hasReadingSectionContent(reading.reading1) ||
      hasReadingSectionContent(reading.reading2) ||
      hasReadingSectionContent(reading.psalm) ||
      hasReadingSectionContent(reading.alleluia) ||
      hasReadingSectionContent(reading.gospel);
}

bool readingHasVisibleContent(ParsedReading reading) =>
    hasReadingDocumentContent(reading);

bool hasReadingMapContent(Map<String, dynamic> map) {
  ParsedSection? section(String key) {
    final raw = map[key];
    if (raw is! Map) return null;
    return ParsedSection.fromMap(Map<String, dynamic>.from(raw));
  }

  return hasReadingSectionContent(section('reading')) ||
      hasReadingSectionContent(section('reading1')) ||
      hasReadingSectionContent(section('reading2')) ||
      hasReadingSectionContent(section('psalm')) ||
      hasReadingSectionContent(section('alleluia')) ||
      hasReadingSectionContent(section('gospel'));
}
