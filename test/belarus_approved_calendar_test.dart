import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/ordo/definitions.dart';
import 'support/ordo_fixture.dart';

void main() {
  final definitions = OrdoDefinitions.fromDocuments(
    celebrations: bundledCollection('liturgicalCelebrations').values,
    dioceseOverrides: bundledCollection('liturgicalDioceseOverrides').values,
    yearOverrides: bundledCollection('liturgicalYearOverrides').values,
  );
  final rows =
      (jsonDecode(
                File(
                  'test/fixtures/belarus-approved/reference.json',
                ).readAsStringSync(),
              )
              as List)
          .cast<Map>();
  final local =
      (jsonDecode(
                File(
                  'test/fixtures/belarus-approved/local-assignments.json',
                ).readAsStringSync(),
              )
              as List)
          .cast<Map>();
  final engine = bundledOrdoEngine();

  test(
    'PDF exact inventory: 262 rows, 959 effective IDs/dates/ranks, no fixed extras',
    () {
      expect(rows, hasLength(262));
      expect(rows.map((r) => r['sourceSha256']).toSet(), {
        'a55dc34c89317bd0a4b683ea84b46941213aa2b981d0a9de1fe3ebeb71dc9696',
      });
      var count = 0;
      final matrix = <String, Object>{};
      for (final diocese in kDioceses) {
        final expected = <String, Map>{};
        for (final row in rows) {
          if (row['dioceses'] == '' ||
              '${row['dioceses']}'.split(';').contains(diocese)) {
            expected['${row['celebration_id']}'] = row;
          }
        }
        if (diocese == 'vitebsk') {
          expected.remove('nativity-blessed-virgin-mary');
        }
        final actual = buildCalendarLayers(
          definitions,
          diocese: diocese,
        ).celebrations;
        for (final entry in expected.entries) {
          final item = actual[entry.key];
          expect(item, isNotNull, reason: '$diocese/${entry.key}');
          expect(item!['suppressedBy'], isNull);
          expect(
            item['rank'],
            entry.value['rank'],
            reason: '$diocese/${entry.key}',
          );
          final date = '${entry.value['date']}';
          if (RegExp(r'^\d\d-\d\d$').hasMatch(date)) {
            expect(item['date'], {
              'type': 'fixed',
              'month': int.parse(date.substring(0, 2)),
              'day': int.parse(date.substring(3)),
            }, reason: '$diocese/${entry.key}');
          }
          count++;
        }
        final fixed = actual.values.where(
          (c) =>
              (c['date'] as Map?)?['type'] == 'fixed' &&
              c['suppressedBy'] == null,
        );
        expect(
          fixed.map((c) => c['id']).toSet(),
          expected.entries
              .where(
                (e) => RegExp(r'^\d\d-\d\d$').hasMatch('${e.value['date']}'),
              )
              .map((e) => e.key)
              .toSet(),
        );
        matrix[diocese] = {
          'assignments': expected.length,
          'fixed': fixed.length,
        };
      }
      expect(count, 959);
      File('reports/belarus-approved/inventory.json').writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert({'sourceRows': rows.length, 'effectiveAssignments': count, 'mismatches': 0, 'dioceses': matrix})}\n',
      );
    },
  );

  test(
    '23 local assignments hidden; four manual moves stay disabled; texts retained',
    () {
      expect(local, hasLength(23));
      for (final row in local) {
        final item = buildCalendarLayers(
          definitions,
          diocese: '${row['dioceseId']}',
        ).celebrations[row['id']];
        expect(
          item == null || item['suppressedBy'] != null,
          isTrue,
          reason: '$row',
        );
      }
      final manual = definitions.yearOverrides.where(
        (r) => r['source'] != 'auto-transfer',
      );
      expect(manual, hasLength(4));
      expect(manual.every((r) => r['enabled'] == false), isTrue);
      for (final name in ['liturgicalProperTexts']) {
        final ids = bundledCollection(name).keys;
        expect(ids.any((id) => id.contains('juan-diego')), isTrue);
        expect(ids.any((id) => id.contains('guadalupe')), isTrue);
      }
    },
  );

  test(
    'December extras never appear in any calendar role, 2025–2035 × four dioceses',
    () {
      for (final diocese in kDioceses) {
        for (var year = 2025; year <= 2035; year++) {
          for (final date in ['$year-12-09', '$year-12-12']) {
            final day = engine.resolve(date, diocese: diocese);
            expect(
              [
                day.primary,
                ...day.alternatives,
                ...day.commemorations,
                ...day.suppressed,
              ].map((x) => x.id),
              isNot(anyElement(isIn(['sv-juan-diego', 'our-lady-guadalupe']))),
              reason: '$date/$diocese',
            );
          }
        }
      }
    },
  );

  test('approved diocesan spot checks, transfers and general collisions', () {
    for (final diocese in kDioceses) {
      final layers = buildCalendarLayers(
        definitions,
        diocese: diocese,
      ).celebrations;
      expect(
        layers['our-lady-budslav']!['rank'],
        {
          'minsk-mohilev': 'solemnitas',
          'vitebsk': 'festum',
          'pinsk': 'memoria-ad-libitum',
          'grodno': 'memoria-ad-libitum',
        }[diocese],
      );
      final braslau = engine.resolve('2026-09-08', diocese: diocese);
      expect(
        braslau.primary.id,
        diocese == 'vitebsk'
            ? 'our-lady-braslau'
            : 'nativity-blessed-virgin-mary',
      );
      expect(braslau.primary.rank, 'festum');
      expect(braslau.alternatives, isEmpty);
      final ostra = engine.resolve('2026-11-16', diocese: diocese);
      expect(ostra.primary.id, 'our-lady-mother-mercy');
      expect(
        ostra.primary.rank,
        diocese == 'grodno' ? 'solemnitas' : 'memoria',
      );
      final heart = engine.resolve('2026-06-13', diocese: diocese);
      expect(heart.primary.kind, 'temporal');
      expect(
        heart.alternatives.map((o) => o.id),
        containsAll(['immaculate-heart', 'sv-anthony-padua']),
      );
      expect(
        heart.alternatives.every((o) => o.rank == 'memoria-ad-libitum'),
        isTrue,
      );
      final mother = engine.resolve('2028-06-05', diocese: diocese);
      expect(mother.primary.id, 'mary-mother-church');
      expect(mother.alternatives, isEmpty);
      expect(mother.suppressed.map((o) => o.id), contains('sv-boniface'));
    }
    final grodno = buildCalendarLayers(
      definitions,
      diocese: 'grodno',
    ).celebrations;
    expect(grodno['our-lady-trakai']!['date'], {
      'type': 'fixed',
      'month': 7,
      'day': 5,
    });
    expect(grodno['our-lady-trakai']!['rank'], 'memoria');
    for (final year in [2027, 2032]) {
      expect(
        engine.resolve('$year-05-17', diocese: 'pinsk').primary.id,
        'sv-andrei-bobola',
      );
    }
    // General computation; not a claimed special universal decree for 2033.
    expect(engine.resolve('2033-06-25').primary.id, 'nativity-john-baptist');
  });
  test(
    'Newman validity and Christmas I Vespers follow Web for the full range',
    () {
      for (final diocese in kDioceses) {
        expect(
          engine
              .resolve('2025-10-09', diocese: diocese)
              .options
              .map((o) => o.id),
          isNot(contains('sv-john-henry-newman')),
        );
        expect(
          engine
              .resolve('2026-10-09', diocese: diocese)
              .options
              .map((o) => o.id),
          contains('sv-john-henry-newman'),
        );
        for (final year in [2028, 2034]) {
          final day = engine.resolve('$year-12-24', diocese: diocese);
          expect(day.evening.vespersType, 'first');
          expect(day.evening.celebrationId, 'nativity-lord');
          expect(day.evening.compline, 'sunday-after-first-vespers');
        }
      }
    },
  );
}
