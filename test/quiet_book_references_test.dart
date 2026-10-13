import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/models/parsed_reading.dart';
import 'package:mybrev_flutter/ordo/reading_references.dart';
import 'support/ordo_fixture.dart';

void main() {
  test(
    'bundled Sunday Gospel agrees with its text and ORDO in all dioceses',
    () {
      final raw = bundledCollection('readings');
      final source = raw['ordinary-w28-d1--A']!;
      // The published data carries the corrected book (web migration); the app
      // applies no local correction.
      expect((source['gospel'] as Map)['bible'], 'Мц 22, 1–10');
      final index = ReadingReferenceIndex([
        for (final entry in raw.entries)
          ParsedReading.fromMap(entry.key, entry.value),
      ]);
      final reading = index.entries.singleWhere(
        (r) => r.id == 'ordinary-w28-d1--A',
      );
      expect(reading.gospel!.bible, 'Мц 22, 1–10');
      expect(reading.gospel!.text, (source['gospel'] as Map)['text']);
      final engine = bundledOrdoEngine();
      for (final diocese in ['minsk-mohilev', 'grodno', 'vitebsk', 'pinsk']) {
        final day = engine.resolve('2026-10-11', diocese: diocese);
        final refs = readingReferencesForDay(day, index).first;
        expect(refs.documents.single.rows.map((r) => r.key), [
          'reading1',
          'psalm',
          'reading2',
          'gospel',
        ]);
        expect(refs.documents.single.rows.last.citation, reading.gospel!.bible);
      }
    },
  );

  test('no local book correction: the text is shown as published', () {
    final data = {
      'gospel': {
        'bible': 'Мк 22, 1–10',
        'title': '+ Чытанне святога Евангелля паводле Мацвея.',
        'text': 'Тэкст',
      },
    };
    expect(ParsedReading.fromMap('variant', data).gospel!.bible, 'Мк 22, 1–10');
  });
}
