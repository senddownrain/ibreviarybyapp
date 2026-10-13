// Structured Mass reading model: every field of the web contract is parsed,
// hashed and rendered (altChorusRef, form, prayers, preface, alternatives of
// flat sections, Passion roles, unknown roles), at a narrow width and large
// text; plus the lookup and cycle fixes found by the parity audit.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mybrev_flutter/models/mass_reading_sets.dart';
import 'package:mybrev_flutter/models/parsed_reading.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/providers/readings_loader_provider.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/screens/readings_screen.dart';
import 'package:mybrev_flutter/utils/liturgical_cycle.dart';
import 'package:mybrev_flutter/utils/reading_view.dart';

import 'support/ordo_fixture.dart';

class _Settings extends SettingsNotifier {
  @override
  SettingsState build() => const SettingsState();
}

final _body = List.filled(8, 'Тэкст чытання для праверкі шырыні.').join(' ');

Map<String, dynamic> _document() => {
  'id': 'synthetic',
  'title': 'Праверка',
  '_date': '01.01',
  'massReadings': {
    'schema': 1,
    'sets': [
      {
        'id': 'mass',
        'label': 'Св. Імша',
        'preface': ['Успамін. Агульная Імша.'],
        'prayers': [
          {'kind': 'collect', 'label': 'Калекта', 'text': 'Малітва дня.'},
        ],
        'sections': [
          {
            'kind': 'reading',
            'role': 'reading1',
            'form': 'long',
            'bible': 'Быц 1, 1–5',
            'text': _body,
            'rubrics': ['Не гаворыцца.'],
            'conclusion': '',
            'alternatives': [
              {'bible': 'Быц 1, 1–2', 'form': 'short', 'text': _body},
            ],
          },
          {
            'kind': 'psalm',
            'role': 'psalm',
            'bible': 'Пс 23',
            'chorus': 'Рэфрэн адзін',
            'altChorus': 'Рэфрэн два',
            'altChorusRef': '(Р.: 9а)',
            'verses': ['Страфа адна', 'Страфа дзве'],
          },
          {
            'kind': 'gospel',
            'role': 'gospel',
            'bible': 'Мк 15',
            'passion': {
              'legend': ['Ев. — евангеліст'],
              'blocks': [
                {
                  'type': 'paragraph',
                  'runs': [
                    {'role': 'narrator', 'text': 'Расказвае.'},
                    {'role': 'christ', 'text': 'Кажа.'},
                    {'role': 'future-role', 'text': 'Невядомы.'},
                  ],
                },
              ],
            },
          },
        ],
      },
    ],
  },
};

void main() {
  setUpAll(() => initializeDateFormatting('be'));

  group('model', () {
    final doc = ParsedReading.fromMap('synthetic', _document());
    final set = doc.massReadings!.sets.single;

    test('every contract field is parsed', () {
      final reading = set.sections[0];
      expect(reading.form, 'long');
      expect(reading.alternatives.single.form, 'short');
      expect(reading.conclusion, '');
      expect(reading.rubrics, ['Не гаворыцца.']);
      expect(set.sections[1].altChorusRef, '(Р.: 9а)');
      expect(set.preface, ['Успамін. Агульная Імша.']);
      expect(set.prayers.single.kind, 'collect');
      final runs = set.sections[2].passion!.blocks.single.runs;
      expect(runs.map((r) => r.rawRole), ['narrator', 'christ', 'future-role']);
      expect(runs.last.role, isNull, reason: 'unknown roles read as narration');
    });

    test('the content hash sees every field (nothing is dropped silently)', () {
      final base = set.sections[0].contentHash;
      for (final key in ['form', 'rubrics', 'conclusion', 'alternatives']) {
        final map = Map<String, dynamic>.from(
          ((_document()['massReadings'] as Map)['sets'] as List)
                  .first['sections'][0]
              as Map,
        );
        map.remove(key);
        expect(
          MassReadingSection.fromMap(map).contentHash,
          isNot(base),
          reason: key,
        );
      }
      expect(
        set.sections[1].contentHash,
        isNot(
          MassReadingSection.fromMap({
            ...((_document()['massReadings'] as Map)['sets'] as List)
                    .first['sections'][1]
                as Map<String, dynamic>,
            'altChorusRef': null,
          }).contentHash,
        ),
      );
    });

    test('a flat (legacy) section keeps its «Або» alternative', () {
      final flat = ParsedReading.fromMap('flat', {
        'reading1': {
          'bible': 'Эф 1, 3',
          'text': _body,
          'alternatives': [
            {'bible': 'Гал 4, 4', 'text': _body},
          ],
        },
        'gospel': {'bible': 'Лк 1', 'text': _body},
      });
      expect(flat.reading1!.alternatives.single.bible, 'Гал 4, 4');
      expect(
        legacyReadingSections(flat).first.alternatives.single.bible,
        'Гал 4, 4',
      );
    });
  });

  group('engine lookups and cycles', () {
    final engine = bundledOrdoEngine();

    test('a Sunday in a date-keyed window uses the period documents', () {
      final day = engine.resolve('2025-12-21');
      final where = day.readingsPlan.first.lookup.single.where;
      expect(where['_periodType'], 'advent');
      expect(where['_dayOfWeek'], 1);
      expect(where.containsKey('_date'), isFalse);
      // …while the weekday of the same window stays date-keyed.
      expect(
        engine.resolve('2025-12-22').readingsPlan.first.lookup.single.where,
        containsPair('_date', '22.12'),
      );
    });

    test('a Sunday 24 December also looks up the Christmas Vigil Mass', () {
      final lookups = engine.resolve('2028-12-24').readingsPlan.first.lookup;
      expect(lookups.length, 2);
      expect(lookups.last.where['_variant'], 'christmas-vigil');
      expect(
        engine.resolve('2026-12-24').readingsPlan.first.lookup.length,
        1,
        reason: 'only on a Sunday',
      );
    });

    test('Advent I on a Sunday Christmas starts the new year (2033)', () {
      expect(getCycleForDate(DateTime(2033, 11, 27), dayOfWeek: 1), 'C');
      expect(getCycleForDate(DateTime(2033, 11, 26), dayOfWeek: 1), 'B');
      expect(engine.resolve('2033-11-27').readingCycle.sunday, 'C');
    });
  });

  group('rendering', () {
    Future<void> pump(WidgetTester tester, {double scale = 1}) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final result = ReadingsLoadResult(
        readings: [ParsedReading.fromMap('synthetic', _document())],
        sundayCycle: 'A',
        weekdayCycle: '1',
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            liturgicalContentReadyProvider.overrideWith((ref) async {}),
            dayOptionsProvider.overrideWithValue(const []),
            settingsProvider.overrideWith(_Settings.new),
            liturgicalSeasonColorProvider.overrideWithValue(Colors.green),
            readingsLocalLoaderProvider.overrideWithValue(
              ({required dateStr, required liturgicalKey, required dayId}) =>
                  result,
            ),
            readingsLoaderProvider.overrideWithValue(
              ({
                required dateStr,
                required liturgicalKey,
                required dayId,
              }) async => result,
            ),
          ],
          child: const MaterialApp(home: ReadingsScreen(dateStr: '2026-01-01')),
        ),
      );
      await tester.pumpAndSettle();
    }

    for (final scale in [1.0, 2.0]) {
      testWidgets('new fields render without overflow at 320 px, x$scale', (
        tester,
      ) async {
        await pump(tester, scale: scale);
        Future<void> see(Finder finder) async {
          await tester.scrollUntilVisible(
            finder,
            300,
            scrollable: find.byType(Scrollable).first,
          );
          expect(finder, findsWidgets);
        }

        await see(find.textContaining('Успамін. Агульная Імша.'));
        await see(find.byKey(const ValueKey('reading-form')));
        await see(find.textContaining('карацейшая форма', findRichText: true));
        await see(find.textContaining('(Р.: 9а)'));
        await see(find.textContaining('Малітва дня.'));
        expect(tester.takeException(), isNull);
      });
    }
  });
}
