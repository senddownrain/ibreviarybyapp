import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/models/day.dart';
import 'package:mybrev_flutter/models/parsed_reading.dart';
import 'package:mybrev_flutter/utils/liturgical_titles.dart';

void main() {
  test('office for the dead uses the agreed full period label', () {
    final day = LiturgicalDay.fromMap({'id': 'office-for-dead'});
    expect(liturgicalDayPeriodLabel(day), 'Афіцый за памерлых');
    expect(
      liturgicalDayDisplayTitle(day, DateTime(2026, 11, 2)),
      'Афіцый за памерлых',
    );
  });

  test('formats period Sundays and weekdays like mybrev', () {
    final sunday = LiturgicalDay.fromMap({
      'id': 'ordinary-w12-d1',
      '_periodType': 'ordinary',
      '_periodWeekNumber': 12,
      '_dayOfWeek': 1,
    });
    final tuesday = LiturgicalDay.fromMap({
      'id': 'ordinary-w12-d3',
      '_periodType': 'ordinary',
      '_periodWeekNumber': 12,
      '_dayOfWeek': 3,
    });

    expect(
      liturgicalDayDisplayTitle(sunday, DateTime(2026, 6, 21)),
      'XII нядзеля звычайная',
    );
    expect(
      liturgicalDayDisplayTitle(tuesday, DateTime(2026, 6, 23)),
      'XII звычайны тыдзень, аўторак',
    );
  });

  test('III ordinary Sunday is Sunday of the Word of God', () {
    final sunday = LiturgicalDay.fromMap({
      'id': 'ordinary-w3-d1',
      '_periodType': 'ordinary',
      '_periodWeekNumber': 3,
      '_dayOfWeek': 1,
    });
    expect(
      liturgicalDayDisplayTitle(sunday, DateTime(2027, 1, 24)),
      'III нядзеля звычайная · Нядзеля Божага Слова',
    );
  });

  test('uses Christmas octave and celebration titles', () {
    final octave = LiturgicalDay.fromMap({
      'id': 'christmas-26-12',
      '_periodType': 'christmas',
      '_periodWeekNumber': 1,
      '_dayOfWeek': 7,
    });
    final celebration = LiturgicalDay.fromMap({
      'id': 'saint',
      '_periodType': 'ordinary',
      '_periodWeekNumber': 8,
      '_dayOfWeek': 2,
      '_feast': 'saint',
      '_rank': 'memoria',
      '_feastName': 'Святы Казімір',
    });

    expect(
      liturgicalDayDisplayTitle(octave, DateTime(2026, 12, 26)),
      'Субота у Актаве Нараджэння Пана',
    );
    expect(
      liturgicalDayDisplayTitle(celebration, DateTime(2026, 3, 4)),
      'Святы Казімір',
    );
    expect(liturgicalDayRankLabel(celebration), 'Успамін');
  });

  test('formats a readings title like the Liturgy of the Hours', () {
    const reading = ParsedReading(
      id: 'ordinary-w12-d3-cycle2',
      periodType: 'ordinary',
      periodWeekNumber: 12,
      dayOfWeek: 3,
      title: 'Сырая назва з базы',
    );

    expect(
      liturgicalReadingPeriodTitle(reading, DateTime(2026, 6, 23)),
      '12 звычайны тыдзень, аўторак',
    );
  });

  test('formats one or several liturgical places without duplicates', () {
    final day = LiturgicalDay.fromMap({
      'id': 'local-celebration',
      '_place': ['grodno', 'vitebsk', ' GRODNO '],
    });

    expect(liturgicalDayPlaces(day), [
      'Гродзенская дыяцэзія',
      'Віцебская дыяцэзія',
    ]);
    expect(
      liturgicalDayPlaceLabel(day),
      'Гродзенская дыяцэзія, Віцебская дыяцэзія',
    );
  });

  test('formats a scalar liturgical place', () {
    final day = LiturgicalDay.fromMap({
      'id': 'local-celebration',
      '_place': 'pinsk',
    });

    expect(liturgicalDayPlaceLabel(day), 'Пінская дыяцэзія');
  });

  test('combines places from grouped celebrations of the same rank', () {
    final variants = [
      LiturgicalDay.fromMap({'id': 'one', '_place': 'Мінск'}),
      LiturgicalDay.fromMap({
        'id': 'two',
        '_place': ['grodno', 'МІНСК'],
      }),
    ];

    expect(mergedLiturgicalDayPlaces(variants), [
      'Мінск',
      'Гродзенская дыяцэзія',
    ]);
  });

  test('uses Belarusian names for every place code stored in days', () {
    const expected = {
      'grodno': 'Гродзенская дыяцэзія',
      'pinsk': 'Пінская дыяцэзія',
      'vitebsk': 'Віцебская дыяцэзія',
      'minsk-mohilev': 'Мінска-Магілёўская архідыяцэзія',
    };

    for (final entry in expected.entries) {
      final day = LiturgicalDay.fromMap({'id': entry.key, '_place': entry.key});
      expect(liturgicalDayPlaceLabel(day), entry.value);
    }
  });
}
