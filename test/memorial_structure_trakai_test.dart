// Owner decisions (Nov 2026), mirror of mybrev tests/memorial-structure-and-trakai.test.mjs:
//  1. Te Deum and the festive structure belong to real feasts/solemnities only
//     (GILH 68, 234-239); a Common chosen for a memorial never makes it a feast.
//  2. Our Lady of Trakai (Grodno): 5 July, `memoria`; 10 July is no longer a
//     celebration of the diocese.
// The real offline bundle (assets/content) is the input; the expected values
// come from the rubrics, not from a recorded Web output.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/content/content_store.dart';
import 'package:mybrev_flutter/models/day.dart';
import 'package:mybrev_flutter/ordo/runtime.dart';
import 'package:mybrev_flutter/ordo/season.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/utils/liturgical_office.dart';
import 'package:mybrev_flutter/utils/office_assembly.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('memorial-trakai-');
    await HiveService.init(path: directory.path, loadBundle: true);
    await ContentStore.instance.ensureLoaded(kContentCollections);
  });
  tearDownAll(() async {
    await ContentStore.instance.idle();
    await Hive.close();
    await directory.delete(recursive: true);
  });

  Map<String, dynamic> doc(String collection, String id) =>
      Map<String, dynamic>.from(
        HiveService.content.collection(collection).get(id) as Map,
      );
  String plain(Object? html) => '$html'
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ');
  const mainHours = {'lauds', 'vespers', 'officeOfReadings'};

  OfficeAssembly assemble(
    String properId,
    String date,
    String choice, {
    String diocese = 'minsk-mohilev',
    String weekdayId = 'ordinary-w29-d2',
  }) {
    final proper = doc('liturgicalProperTexts', properId);
    final office = OrdoRuntime.engine
        .resolve(date, diocese: diocese)
        .office(proper['_celebrationId'] as String)!;
    return assembleOffice(
      proper: proper,
      currentDay: doc('days', weekdayId),
      templates: HiveService.templates(),
      isSunday: computeSeason(date).isSunday,
      choice: choice,
      office: office,
      season: computeSeason(date),
    );
  }

  group('memorials with a Common (GILH 235-238)', () {
    test(
      'A1 Paul of the Cross 19.10.2026: weekday structure, own 2nd reading and prayer',
      () {
        final weekday = doc('days', 'ordinary-w29-d2');
        final proper = doc('liturgicalProperTexts', '19-10-sv-paul-of-cross');
        expect(plain(weekday['officeOfReadingsR1']), contains('Эстэры 3'));
        for (final choice in [kCurrentDayChoice, 'pastors', 'religious']) {
          final result = assemble(
            '19-10-sv-paul-of-cross',
            '2026-10-19',
            choice,
          );
          final data = result.data;
          final reason = choice;
          expect(
            plain(data['officeOfReadingsR1']),
            contains('Эстэры 3'),
            reason: reason,
          );
          expect(
            data['officeOfReadingsR1'],
            weekday['officeOfReadingsR1'],
            reason: reason,
          );
          expect(
            data['officeOfReadingsR2'],
            proper['officeOfReadingsR2'],
            reason: reason,
          );
          for (final field in [
            'laudesPs1',
            'laudesPs2',
            'laudesPs3',
            'officeOfReadingsPs1',
            'vesperPs1',
            'vesperPs2',
            'vesperPs3',
            'laudesAnt1',
            'vesperAnt1',
          ]) {
            expect(data[field], weekday[field], reason: '$reason $field');
            expect(
              result.provenance[field],
              kCurrentDayChoice,
              reason: '$reason $field',
            );
          }
          expect(
            plain(data['laudesPr']),
            startsWith(' Міласэрны Божа, Ты даў святому Паўлу'),
            reason: reason,
          );
          expect(data['vesperPr'], data['laudesPr'], reason: reason);
          expect(data['officeOfReadingsPr'], data['laudesPr'], reason: reason);
          expect(
            kFirstVesperFields.where(data.containsKey),
            isEmpty,
            reason: '$reason: no I Vespers',
          );
          final teDeum = data['officeOfReadingsTeDeum'];
          expect(teDeum == true, isFalse, reason: '$reason: Te Deum flag');
          expect(
            shouldShowTeDeum(LiturgicalDay.fromMap(data)),
            isFalse,
            reason: reason,
          );
          expect(
            plain(data.values.whereType<String>().join(' ')),
            isNot(contains(' N. ')),
            reason: reason,
          );
          expect(result.missing, isEmpty, reason: reason);
          expect(result.integrity, isEmpty, reason: reason);
          if (choice != kCurrentDayChoice) {
            // The Common supplies only the elements the rubric allows it to.
            expect(
              result.provenance['laudesHymn'],
              'common:$choice',
              reason: reason,
            );
            expect(
              result.provenance['vesperAntMag'],
              'common:$choice',
              reason: reason,
            );
          }
        }
      },
    );

    test(
      'A2 St Thérèse 01.10.2026 (obligatory memorial) never gets the festive structure',
      () {
        final office = OrdoRuntime.engine
            .resolve('2026-10-01')
            .office('sv-teresa-lisieux')!;
        expect(office.officeKind, 'memorial');
        expect(office.teDeum, isFalse);
        final proper = doc('liturgicalProperTexts', '01-10-sv-teresa-lisieux');
        for (final choice in assemblyChoices(
          proper,
          'memorial',
          office: office,
        )) {
          final result = assemble(
            '01-10-sv-teresa-lisieux',
            '2026-10-01',
            choice,
            weekdayId: 'ordinary-w26-d5',
          );
          final weekday = doc('days', 'ordinary-w26-d5');
          expect(
            result.data['officeOfReadingsR1'],
            weekday['officeOfReadingsR1'],
            reason: choice,
          );
          expect(
            result.data['laudesPs1'],
            weekday['laudesPs1'],
            reason: choice,
          );
          expect(
            result.data['officeOfReadingsTeDeum'] == true,
            isFalse,
            reason: choice,
          );
          expect(
            kFirstVesperFields.where(result.data.containsKey),
            isEmpty,
            reason: choice,
          );
        }
      },
    );

    test('A3 Lateran Basilica 09.11.2026 (feast) keeps Te Deum', () {
      final office = OrdoRuntime.engine
          .resolve('2026-11-09')
          .office('dedication-lateran-basilica')!;
      expect(office.officeKind, 'feast');
      expect(office.teDeum, isTrue);
      final result = assemble(
        '09-11-dedication-lateran-basilica',
        '2026-11-09',
        'church-dedication',
        weekdayId: 'ordinary-w32-d2',
      );
      expect(result.data['officeOfReadingsTeDeum'], isTrue);
      expect(shouldShowTeDeum(LiturgicalDay.fromMap(result.data)), isTrue);
    });

    test(
      'every memorial of 2026-2027 keeps the weekday structure for each Common',
      () {
        var checked = 0;
        for (final diocese in ['minsk-mohilev', 'grodno', 'pinsk', 'vitebsk']) {
          for (
            var day = DateTime.utc(2026);
            day.isBefore(DateTime.utc(2028));
            day = day.add(const Duration(days: 1))
          ) {
            final date = day.toIso8601String().substring(0, 10);
            final resolved = OrdoRuntime.engine.resolve(date, diocese: diocese);
            for (final option in resolved.options) {
              final office = resolved.office(option.id);
              if (office == null ||
                  !const {
                    'memorial',
                    'optional-memorial',
                  }.contains(office.officeKind)) {
                continue;
              }
              final dayIds = (option.daysRef?['dayIds'] as List?) ?? const [];
              final properId = dayIds
                  .map((id) => '$id')
                  .firstWhere(
                    (id) =>
                        HiveService.content
                            .collection('liturgicalProperTexts')
                            .get(id) !=
                        null,
                    orElse: () => '',
                  );
              if (properId.isEmpty) continue;
              final proper = doc('liturgicalProperTexts', properId);
              if (proper['_obsolete'] == true ||
                  (proper['_templates'] as List?)?.isNotEmpty != true) {
                continue;
              }
              final weekday = {
                for (final field in kOfficeFieldSlots.keys) field: 'day:$field',
              };
              for (final choice in assemblyChoices(
                proper,
                office.officeKind,
                office: office,
              ).where((c) => c != kCurrentDayChoice)) {
                final result = assembleOffice(
                  proper: proper,
                  currentDay: weekday,
                  templates: HiveService.templates(),
                  isSunday: computeSeason(date).isSunday,
                  choice: choice,
                  office: office,
                  season: computeSeason(date),
                );
                final label = '$date $diocese ${option.id} $choice';
                expect(
                  result.data['officeOfReadingsTeDeum'] == true,
                  isFalse,
                  reason: label,
                );
                expect(
                  kFirstVesperFields.where(result.data.containsKey),
                  isEmpty,
                  reason: label,
                );
                expect(
                  result.data['officeOfReadingsR1'] ?? 'day:officeOfReadingsR1',
                  proper['officeOfReadingsR1'] ?? 'day:officeOfReadingsR1',
                  reason: label,
                );
                for (final field in kOfficeFieldSlots.keys) {
                  final (hour, component) = kOfficeFieldSlots[field]!;
                  if (!mainHours.contains(hour) ||
                      !const {
                        'psalmody',
                        'antiphons',
                        'reading1',
                      }.contains(component)) {
                    continue;
                  }
                  if (proper[field] != null && '${proper[field]}'.isNotEmpty) {
                    continue;
                  }
                  if (proper['_fieldRules'] is Map &&
                      (proper['_fieldRules'] as Map).containsKey(field)) {
                    continue;
                  }
                  expect(
                    result.data[field],
                    weekday[field],
                    reason: '$label $field',
                  );
                }
                checked++;
              }
            }
          }
        }
        expect(checked, greaterThan(300));
      },
    );
  });

  group('Our Lady of Trakai: 05.07, memoria (Grodno)', () {
    List<String> ids(String date, String diocese) => OrdoRuntime.engine
        .resolve(date, diocese: diocese)
        .options
        .map((o) => o.id)
        .toList();

    test(
      'one active Proper, retired variant marked obsolete, text untouched',
      () {
        final active = doc(
          'liturgicalProperTexts',
          '05-07-our-lady-trakai-grodno',
        );
        final retired = doc(
          'liturgicalProperTexts',
          '05-07-our-lady-trakai-grodno-memoria-ad-libitum',
        );
        expect(
          [
            active['_date'],
            active['_rank'],
            active['_place'],
            active['_celebrationId'],
          ],
          ['05.07', 'memoria', 'grodno', 'our-lady-trakai'],
        );
        expect(active['_obsolete'], isNot(true));
        expect(retired['_obsolete'], isTrue);
        expect(retired['_supersededBy'], ['05-07-our-lady-trakai-grodno']);
        for (final key in [
          'officeOfReadingsPr',
          '_fieldRules',
          'feastComment',
          '_feastName',
        ]) {
          expect(retired[key], active[key], reason: key);
        }
      },
    );

    test(
      '2025-2035: one memoria card on 05.07 (Sunday keeps priority), nothing on 10.07, only Grodno',
      () {
        for (var year = 2025; year <= 2035; year++) {
          final grodno = OrdoRuntime.engine.resolve(
            '$year-07-05',
            diocese: 'grodno',
          );
          final cards = grodno.options
              .where((o) => o.id == 'our-lady-trakai')
              .toList();
          if (DateTime(year, 7, 5).weekday == DateTime.sunday) {
            expect(cards, isEmpty, reason: '$year Sunday is not displaced');
            expect(grodno.primary.officeKind, 'sunday', reason: '$year');
          } else {
            expect(cards, hasLength(1), reason: '$year');
            expect(cards.single.rank, 'memoria', reason: '$year');
            expect(cards.single.officeKind, 'memorial', reason: '$year');
          }
          expect(
            ids('$year-07-10', 'grodno'),
            isNot(contains('our-lady-trakai')),
            reason: '$year-07-10',
          );
          for (final diocese in ['minsk-mohilev', 'pinsk', 'vitebsk']) {
            expect(
              ids('$year-07-05', diocese),
              isNot(contains('our-lady-trakai')),
              reason: '$year $diocese',
            );
            expect(
              ids('$year-07-10', diocese),
              isNot(contains('our-lady-trakai')),
              reason: '$year $diocese 10.07',
            );
          }
        }
        final monday = ids('2027-07-05', 'grodno');
        expect(monday.first, 'our-lady-trakai');
        expect(monday, isNot(contains('sv-anthony-mary-zaccaria')));
      },
    );

    test(
      'Trakai memorial: Marian Common without festive structure, own prayer kept',
      () {
        final proper = doc(
          'liturgicalProperTexts',
          '05-07-our-lady-trakai-grodno',
        );
        final result = assemble(
          '05-07-our-lady-trakai-grodno',
          '2027-07-05',
          'blessed-virgin-mary',
          diocese: 'grodno',
          weekdayId: 'ordinary-w14-d2',
        );
        expect(result.data['officeOfReadingsTeDeum'] == true, isFalse);
        expect(kFirstVesperFields.where(result.data.containsKey), isEmpty);
        expect(result.data['laudesPr'], proper['officeOfReadingsPr']);
        expect(result.data['vesperPr'], proper['officeOfReadingsPr']);
      },
    );
  });
}
