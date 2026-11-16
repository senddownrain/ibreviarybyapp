import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/models/prayer.dart';
import 'package:mybrev_flutter/widgets/prayer_content.dart';

void main() {
  test('old bundle without source still decodes', () {
    final prayer = Prayer.fromMap({'title': 'Малітва', 'text': 'Тэкст'}, 'old');
    expect(prayer.source, isNull);
    expect(prayer.displayText, 'Тэкст');
  });

  test('source survives bundle decode, copy and local serialization', () {
    for (final source in ['Бог добры', 'Літургія гадзін', 'Невядомая кніга']) {
      final prayer = Prayer.fromMap({
        'title': 'Малітва',
        'text': 'Пс 23, 1–6',
        'source': source,
      }, 'p');
      expect(prayer.copyWith(body: 'Тэкст').source, source);
      expect(Prayer.fromMap(prayer.toMap(), 'p').source, source);
      expect(prayer.displayText, 'Пс 23, 1–6');
    }
  });

  testWidgets('reader source note displays the canonical server value', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: PrayerSourceNote(
          source: 'Бог добры',
          textStyle: TextStyle(fontSize: 18),
        ),
      ),
    ));
    expect(find.text('Крыніца: Бог добры'), findsOneWidget);
  });

  testWidgets('legacy record without a source has no empty footer', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: PrayerSourceNote(textStyle: TextStyle(fontSize: 18)),
      ),
    ));
    expect(find.byKey(const Key('prayer-source')), findsNothing);
  });
}
