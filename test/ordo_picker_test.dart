// The picker on the canonical engine: years in numeric order, «Святы» of
// full definitions with Ordo permissions (transfers, dioceses, colours), periods
// found by the engine, never from the legacy `days`.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mybrev_flutter/ordo/definitions.dart';
import 'package:mybrev_flutter/ordo/engine.dart';
import 'package:mybrev_flutter/ordo/ordo_picker.dart';
import 'package:mybrev_flutter/widgets/ordo/vestment_marker.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/screens/liturgical_picker_screen.dart';

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

    testWidgets('the year grid is numeric, shows the selected year, and '
        '2027 is one tap away', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            selectedDateProvider.overrideWith((ref) => DateTime(2026, 10, 7)),
            pickerFeastsProvider.overrideWith((ref, key) => const []),
          ],
          child: const MaterialApp(
            home: Scaffold(body: LiturgicalPickerScreen()),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('2026'), findsOneWidget);
      await tester.tap(find.byKey(const Key('picker-year')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('picker-year-grid')), findsOneWidget);
      expect(find.byKey(const Key('picker-year-2026')), findsOneWidget);
      final y2026 = tester.getTopLeft(
        find.byKey(const Key('picker-year-2026')),
      );
      final y2027 = tester.getTopLeft(
        find.byKey(const Key('picker-year-2027')),
      );
      expect(
        y2027.dy > y2026.dy || (y2027.dy == y2026.dy && y2027.dx > y2026.dx),
        isTrue,
      );
      await tester.tap(find.byKey(const Key('picker-year-2027')));
      await tester.pumpAndSettle();
      expect(find.text('2027'), findsOneWidget);
      await tester.tap(find.byKey(const Key('picker-year-next')));
      await tester.pump();
      expect(find.text('2028'), findsOneWidget);
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
      final dates = feasts.map((f) => f.nominalDate ?? f.date).toList();
      expect(dates, [...dates]..sort());
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
      expect(annunciation.nominalDate, '2027-03-25');
      expect(annunciation.transferred, isTrue);
      expect(annunciation.option.transferredFrom, '2027-03-25');
      // Diocesan: with its badge when only one selected diocese keeps it.
      final diocesan = feasts.where((f) => f.kind == 'diocesan').toList();
      expect(diocesan, isNotEmpty);
      expect(diocesan.any((f) => f.badges.length == 1), isTrue);
      // No duplicate copies of one celebration on one date.
      final keys = [
        for (final f in feasts)
          for (final diocese in f.dioceses) '${f.id}|$diocese',
      ];
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

    test(
      'Nicholas stays white and visible when impeded; permission is local',
      () {
        final omitted = pickerFeastsOfYear(
          engine,
          2026,
          kDioceses,
        ).where((f) => f.id == 'sv-nicholas').single;
        expect(omitted.nominalDate, '2026-12-06');
        expect(omitted.colors, ['albus']);
        expect(omitted.status, 'Не адзначаецца ў гэтым годзе');
        expect(omitted.canOpen(readingsMode: false), isFalse);
        expect(omitted.canOpen(readingsMode: true), isFalse);
        expect(engine.resolve('2026-12-06').legalColors, ['violaceus']);
        final next = pickerFeastsOfYear(
          engine,
          2027,
          kDioceses,
        ).where((f) => f.id == 'sv-nicholas').toList();
        final minsk = next.singleWhere(
          (f) => f.dioceses.contains('minsk-mohilev'),
        );
        final grodno = next.singleWhere((f) => f.dioceses.contains('grodno'));
        expect(minsk.hoursAllowed, isTrue);
        expect(minsk.readingsAllowed, isTrue);
        expect(grodno.hoursAllowed, isFalse);
        expect(grodno.readingsAllowed, isFalse);
        expect(grodno.badges, ['Гродна']);
        // Search never adds legal alternatives or colours to the engine.
        expect(
          engine
              .resolve('2027-12-06', diocese: 'grodno')
              .options
              .any((o) => o.id == 'sv-nicholas'),
          isFalse,
        );
      },
    );

    test(
      'all active layered definitions survive, without merging variants',
      () {
        final base = <String, dynamic>{
          'id': 'variant',
          'title': 'Варыянт',
          'scope': 'universal',
          'rank': 'memoria-ad-libitum',
          'color': 'albus',
          'source': {'dioceseId': 'source-a'},
          'dateRule': {'type': 'fixed', 'month': 1, 'day': 20},
        };
        final local = OrdoEngine(
          OrdoDefinitions.fromDocuments(
            celebrations: [
              base,
              {...base, 'id': 'no-color'}..remove('color'),
              {
                ...base,
                'id': 'leap',
                'dateRule': {'type': 'fixed', 'month': 2, 'day': 29},
              },
              {...base, 'id': 'disabled', 'enabled': false},
              {
                ...base,
                'id': 'movable',
                'dateRule': {
                  'type': 'movable',
                  'anchor': 'christmas',
                  'offsetDays': -1,
                },
              },
              {
                ...base,
                'id': 'named',
                'dateRule': {'type': 'named', 'rule': 'holyFamily'},
              },
              {
                ...base,
                'id': 'last-weekday',
                'dateRule': {
                  'type': 'last-weekday-of-month',
                  'month': 10,
                  'isoWeekday': 7,
                },
              },
            ],
            dioceseOverrides: [
              {
                ...base,
                'dioceseId': 'grodno',
                'celebrationId': 'variant',
                'action': 'add',
                'title': 'Мясцовы',
                'rank': 'festum',
                'color': 'ruber',
                'dateRule': {'type': 'fixed', 'month': 1, 'day': 21},
              },
              {
                ...base,
                'dioceseId': 'vitebsk',
                'celebrationId': 'variant',
                'action': 'add',
                'source': {'dioceseId': 'source-b'},
              },
              {
                'dioceseId': 'pinsk',
                'celebrationId': 'variant',
                'action': 'suppress',
              },
              {
                ...base,
                'dioceseId': 'pinsk',
                'celebrationId': 'pinsk-only',
                'action': 'add',
              },
            ],
            yearOverrides: [
              {
                'year': 2026,
                'scope': 'universal',
                'action': 'suppress',
                'targetCelebrationId': 'named',
              },
            ],
          ),
        );
        final rows = pickerFeastsOfYear(local, 2026, [...kDioceses, 'pinsk']);
        final variants = rows.where((f) => f.id == 'variant').toList();
        expect(variants, hasLength(4));
        final grodno = variants.singleWhere(
          (f) => f.dioceses.contains('grodno'),
        );
        expect(grodno.title, 'Мясцовы');
        expect(grodno.option.rank, 'festum');
        expect(grodno.colors, ['ruber']);
        expect(grodno.nominalDate, '2026-01-21');
        expect(
          variants
              .singleWhere((f) => f.dioceses.contains('vitebsk'))
              .option
              .data['source'],
          {'dioceseId': 'source-b'},
        );
        expect(
          variants
              .singleWhere((f) => f.dioceses.contains('pinsk'))
              .hoursAllowed,
          isFalse,
        );
        expect(rows.singleWhere((f) => f.id == 'pinsk-only').badges, ['Пінск']);
        expect(
          rows.where((f) => f.id == 'no-color').every((f) => f.colors.isEmpty),
          isTrue,
        );
        expect(rows.any((f) => f.id == 'disabled'), isFalse);
        final leap = rows.singleWhere((f) => f.id == 'leap');
        expect(leap.date, isNull);
        expect(leap.nominalDate, '2026-02-29');
        expect(leap.hoursAllowed, isFalse);
        final movable = rows.singleWhere((f) => f.id == 'movable');
        expect(movable.kind, 'movable');
        expect(movable.date, '2026-12-24');
        expect(movable.status, 'Толькі памінанне');
        expect(movable.hoursAllowed, isFalse);
        final named = rows.singleWhere((f) => f.id == 'named');
        expect(
          named.date,
          local.plan(2026, 'minsk-mohilev').removedByDate.keys.single,
        );
        expect(named.hoursAllowed, isFalse);
        expect(
          rows.singleWhere((f) => f.id == 'last-weekday').date,
          '2026-10-25',
        );
        for (final row in rows) {
          expect(row.dioceses.toSet().length, row.dioceses.length);
        }
      },
    );

    for (final width in [320.0, 390.0]) {
      for (final brightness in Brightness.values) {
        testWidgets('impeded search at $width, $brightness, large text', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, 850);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                selectedDateProvider.overrideWith(
                  (ref) => DateTime(2026, 12, 6),
                ),
                pickerFeastsProvider.overrideWith(
                  (ref, year) => pickerFeastsOfYear(engine, year, kDioceses),
                ),
              ],
              child: MaterialApp(
                theme: ThemeData(brightness: brightness),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(2)),
                  child: child!,
                ),
                home: const Scaffold(body: LiturgicalPickerScreen()),
              ),
            ),
          );
          await tester.tap(find.text('Святы'));
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byKey(const Key('picker-feast-search')),
            '06.12',
          );
          await tester.pumpAndSettle();
          final row = find.byKey(
            const Key('picker-feast-sv-nicholas-2026-12-06'),
          );
          expect(row, findsOneWidget);
          expect(tester.widget<InkWell>(row).onTap, isNull);
          expect(find.text('Не адзначаецца ў гэтым годзе'), findsOneWidget);
          expect(
            tester
                .widget<VestmentMarker>(
                  find.descendant(
                    of: row,
                    matching: find.byType(VestmentMarker),
                  ),
                )
                .colors,
            ['albus'],
          );
          expect(tester.takeException(), isNull);
        });
      }
    }

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
