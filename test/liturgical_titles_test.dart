import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/models/day.dart';
import 'package:mybrev_flutter/models/parsed_reading.dart';
import 'package:mybrev_flutter/utils/liturgical_titles.dart';

void main() {
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
      'XII звычайны тыдзень, аўторак',
    );
  });
}
