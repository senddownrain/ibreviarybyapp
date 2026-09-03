import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/models/parsed_reading.dart';
import 'package:mybrev_flutter/utils/reading_groups.dart';

ParsedReading reading(
  String id, {
  String? title,
  String? year,
  String? date,
  String? dayId,
}) => ParsedReading(
  id: id,
  title: title,
  year: year,
  date: date,
  dayId: dayId,
  reading1: const ParsedSection(text: 'Дастаткова доўгі тэкст чытання.'),
);

void main() {
  test('groups cycle variants by linked day and keeps the document title', () {
    final groups = groupReadings([
      reading('day-a', title: 'Святая Сям’я', year: 'A', dayId: 'holy-family'),
      reading('day-b', title: 'Святая Сям’я', year: 'B', dayId: 'holy-family'),
    ]);

    expect(groups, hasLength(1));
    expect(groups.single.label, 'Святая Сям’я');
    expect(availableCyclesForGroup(groups.single.documents), ['A', 'B']);
    expect(pickReadingForCycle(groups.single.documents, 'B')?.id, 'day-b');
  });

  test('does not merge different fixed-date celebrations', () {
    final groups = groupReadings([
      reading('one', title: 'Святы Ян', date: '24.06'),
      reading('two', title: 'Святыя мучанікі', date: '24.06'),
    ]);

    expect(groups, hasLength(2));
  });

  test('preserves reading identity metadata in the model', () {
    final parsed = ParsedReading.fromMap('reading', {
      'title': 'Чытанні дня',
      '_dayId': 'day-id',
      '_dayIds': ['day-id', 'template-id'],
      '_rank': 'festum',
      '_place': ['grodno'],
      '_variant': 'vigil',
      '_calendarDayOfWeek': 7,
      'reading1': {'text': 'Дастаткова доўгі тэкст чытання.'},
    });

    expect(parsed.title, 'Чытанні дня');
    expect(parsed.dayIds, ['day-id', 'template-id']);
    expect(parsed.toMap()['_variant'], 'vigil');
    expect(parsed.calendarDayOfWeek, 7);
  });
}
