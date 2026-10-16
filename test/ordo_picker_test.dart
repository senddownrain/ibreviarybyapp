// The picker on the canonical engine: years in numeric order, «Святы» of
// the chosen year from the Ordo (transfers, dioceses, colours), periods
// found by the engine, never from the legacy `days`.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mybrev_flutter/ordo/ordo_picker.dart';

import 'support/ordo_fixture.dart';

void main() {
  setUpAll(() => initializeDateFormatting('be'));
  final engine = bundledOrdoEngine();

  group('years', () {
    test('strictly ascending, 2027 included, the selected year added', () {
      final years = pickerYears(2026, today: 2026);
      expect(years, [...years]..sort());
      expect(years.toSet().length, years.length);
      expect(years, contains(2027));
      expect(years.indexOf(2027), years.indexOf(2026) + 1);
      expect(years.last, greaterThan(2030));
      final far = pickerYears(2061, today: 2026);
      expect(far, contains(2061));
      expect(far, [...far]..sort());
    });
  });

  group('«Святы» from the Ordo of the year', () {
    test('no legacy days source in the picker', () {
      final source = File(
        'lib/screens/liturgical_picker_screen.dart',
      ).readAsStringSync();
      expect(source, isNot(contains('daysBox')));
      expect(source, isNot(contains('_loadFixedFeasts')));
      expect(source, isNot(contains('calculateDateForContext')));
    });

    test('fixed, movable, transferred and diocesan, on final dates, with '
        'their colours', () {
      final feasts = pickerFeastsOfYear(engine, 2027, [
        'minsk-mohilev',
        'grodno',
      ]);
      PickerFeast find(String id) => feasts.firstWhere((f) => f.id == id);
      expect(feasts.map((f) => f.date), [...feasts.map((f) => f.date)]..sort());
      // Fixed.
      expect(find('assumption-blessed-virgin-mary').date, '2027-08-15');
      expect(find('assumption-blessed-virgin-mary').kind, 'fixed');
      // Movable.
      expect(find('easter-sunday').date, '2027-03-28');
      expect(find('pentecost').colors, ['ruber']);
      // Transferred: Annunciation from Holy Thursday to the Monday after the
      // II Sunday of Easter.
      final annunciation = find('annunciation-lord');
      expect(annunciation.date, '2027-04-05');
      expect(annunciation.transferred, isTrue);
      expect(annunciation.option.transferredFrom, '2027-03-25');
      // Diocesan: with its badge when only one selected diocese keeps it.
      final diocesan = feasts.where((f) => f.kind == 'diocesan').toList();
      expect(diocesan, isNotEmpty);
      expect(diocesan.any((f) => f.badges.length == 1), isTrue);
      // No duplicate copies of one celebration on one date.
      final keys = feasts.map((f) => '${f.id}|${f.option.rank}|${f.date}');
      expect(keys.toSet().length, keys.length);
      // Real vestment colours only.
      for (final feast in feasts) {
        expect(
          feast.colors.every(
            (c) => const [
              'albus',
              'ruber',
              'viridis',
              'violaceus',
              'rosaceus',
              'niger',
            ].contains(c),
          ),
          isTrue,
        );
      }
      expect(find('all-faithful-departed').colors, ['violaceus', 'niger']);
    });

    test('a year override moves a diocesan celebration (Grodno 2027)', () {
      final grodno = pickerFeastsOfYear(engine, 2027, ['grodno']);
      final dedication = grodno.firstWhere(
        (f) => f.id == 'grodno-cathedral-dedication',
      );
      expect(dedication.date, '2027-12-06');
      expect(dedication.option.movedFrom, '2027-12-04');
    });
  });

  group('«Перыяды»: exact dates by the engine', () {
    test('Advent, 17–24 December, Christmas, Lent, Holy Week, Easter, '
        'Ordinary Time before and after Lent', () {
      expect(pickerDateForPosition(2026, 'advent', 1, 1), '2026-11-29');
      expect(pickerDateForPosition(2026, 'advent', 4, 1), '2026-12-20');
      // Advent IV has no Saturday after 24 December in 2026.
      expect(pickerDateForPosition(2026, 'advent', 4, 7), isNull);
      expect(pickerExactDates(2026, 'advent'), hasLength(8));
      final christmas = pickerExactDates(2026, 'christmas');
      expect(christmas.first, '2026-12-25');
      expect(christmas.last, '2027-01-10');
      expect(pickerDateForPosition(2027, 'lent', 0, 4), '2027-02-10');
      expect(pickerExactDates(2027, 'lent').first, '2027-02-10');
      expect(pickerDateForPosition(2027, 'lent', 1, 1), '2027-02-14');
      expect(pickerDateForPosition(2027, 'holyweek', 1, 5), '2027-03-25');
      expect(pickerDateForPosition(2027, 'easter', 1, 1), '2027-03-28');
      expect(pickerDateForPosition(2027, 'easter', 8, 1), '2027-05-16');
      // Ordinary Time: week I starts after the Baptism; the I Sunday is the
      // Baptism itself, so it does not exist.
      expect(pickerDateForPosition(2027, 'ordinary', 1, 1), isNull);
      expect(pickerDateForPosition(2027, 'ordinary', 1, 2), '2027-01-11');
      expect(pickerDateForPosition(2027, 'ordinary', 34, 1), '2027-11-21');
      // Ordinary Time split around Lent and Easter: 2027 has weeks I–V
      // before Lent and resumes with week VII after Pentecost (no week VI).
      final ordinary = pickerPositions(2027, 'ordinary');
      expect(ordinary.keys.contains(5), isTrue);
      expect(ordinary.keys.contains(6), isFalse);
      expect(pickerDateForPosition(2027, 'ordinary', 6, 2), isNull);
      // …and a position never lands on a neighbouring period.
      for (final week in ordinary.values) {
        for (final iso in week.values) {
          expect(engine.resolve(iso).period, 'ordinary');
        }
      }
    });
  });
}
