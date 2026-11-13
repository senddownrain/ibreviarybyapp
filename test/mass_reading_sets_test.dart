// Structured Mass reading sets on the real bundled `readings` (mybrev
// final phase §4, §5, §17, §21): the same date → document → set choice as
// the web Readings screen (`massReadingSets.js`, `readingSetChoice.js`).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/content/content_store.dart';
import 'package:mybrev_flutter/models/mass_reading_sets.dart';
import 'package:mybrev_flutter/models/parsed_reading.dart';
import 'package:mybrev_flutter/ordo/definitions.dart';
import 'package:mybrev_flutter/providers/calendar_provider.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/services/liturgical_content_service.dart';
import 'package:mybrev_flutter/services/parsed_readings_service.dart';
import 'package:mybrev_flutter/utils/liturgical_cycle.dart';
import 'package:mybrev_flutter/utils/reading_content.dart';
import 'package:mybrev_flutter/utils/readings_selection.dart';

final _calendar = CalendarService();

/// The readings of a date as the Readings screen resolves them (the
/// production loader: service + Ordo order + day-id link rules).
DefaultReadingsSelection readingsOn(
  String iso, {
  String diocese = kDefaultDiocese,
  String? dayId,
  String? set,
  String? cycle,
}) {
  final date = DateTime.parse(iso);
  final service = ParsedReadingsService();
  final readings = service.cachedForDate(
    date,
    _calendar.getYearOptionsCached(date.year),
    _calendar.getYearOptionsCached(date.year + 1),
    _calendar.getDynamicDatesCached(date.year),
    includeAlternatives: true,
    dayId: dayId,
    diocese: diocese,
  );
  expect(readings, isNotNull, reason: iso);
  final selection = service.ordoSelection(date, dayId: dayId, diocese: diocese);
  final link =
      selection == null || !(selection.memorial || selection.officeOnly);
  return resolveDefaultReadings(
    readings: readings!,
    sundayCycle: getCycleForDate(date, dayOfWeek: 1),
    weekdayCycle: getWeekdayCycleForDate(date),
    dayId: link ? dayId : null,
    requestedSetId: set,
    manualCycle: cycle,
  );
}

List<String> ids(Iterable<MassReadingSet> sets) => [
  for (final set in sets) set.id,
];

List<String> roles(MassSetSelection selection) => [
  for (final section in selection.sections) section.role ?? section.kind,
];

MassReadingSection only(MassSetSelection selection, String role) =>
    selection.sections.singleWhere((section) => section.role == role);

/// No legacy document covered by a shown canonical document, no group
/// twice: one celebration, one entry.
void expectNoDuplicates(DefaultReadingsSelection selection) {
  final shown = {
    for (final group in selection.groups)
      for (final document in group.documents) document.id,
  };
  for (final group in selection.groups) {
    for (final document in group.documents) {
      final covered = document.massReadingsRef?.doc;
      expect(
        covered == null || !shown.contains(covered),
        isTrue,
        reason: '${document.id} is covered by $covered',
      );
    }
  }
  final keys = [for (final group in selection.groups) group.key];
  expect(keys.toSet(), hasLength(keys.length));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('mass-reading-sets-');
    await HiveService.init(path: directory.path, loadBundle: true);
    await ContentStore.instance.ensureLoaded(kLiturgicalCollections);
  });

  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  group('vigil and day', () {
    for (final (iso, docId) in [
      ('2026-08-15', '15-08-assumption-blessed-virgin-mary'),
      ('2026-06-29', '29-06-sv-peter-paul-apostles'),
    ]) {
      test('$iso: exactly vigil + day, default day', () {
        final result = readingsOn(iso);
        expectNoDuplicates(result);
        final massSet = result.massSet!;
        expect(massSet.document.id, docId);
        expect(ids(massSet.sets), ['vigil', 'day']);
        expect(massSet.sets.first.label, 'Св. Імша ў вігілію');
        expect(massSet.sets.last.label, 'Св. Імша ўдзень');
        expect(massSet.set.id, 'day');
        expect(massSet.automaticSetId, 'day');
        // The vigil is a full set of its own, not mixed with the day.
        final vigil = readingsOn(iso, set: 'vigil').massSet!;
        expect(vigil.set.id, 'vigil');
        expect(
          only(vigil, 'gospel').bible,
          isNot(only(massSet, 'gospel').bible),
        );
        expect(roles(vigil), [
          'reading1',
          'psalm',
          'reading2',
          'alleluia',
          'gospel',
        ]);
      });
    }

    test('an unknown set id falls back to the default', () {
      expect(readingsOn('2026-08-15', set: 'nope').massSet!.set.id, 'day');
    });
  });

  test('25.12 has the three Masses of the source, default day', () {
    final result = readingsOn('2026-12-25');
    expectNoDuplicates(result);
    final massSet = result.massSet!;
    expect(ids(massSet.sets), ['night', 'dawn', 'day']);
    expect(
      [for (final set in massSet.sets) set.label],
      ['Св. Імша ўначы', 'Св. Імша на світанні', 'Св. Імша ўдзень'],
    );
    expect(massSet.set.id, 'day');
    final gospels = {
      for (final set in massSet.sets)
        set.sectionsForCycle('').singleWhere((s) => s.kind == 'gospel').bible,
    };
    expect(gospels, hasLength(3));
  });

  test('24.12: morning + Christmas vigil Mass, default evening', () {
    final result = readingsOn('2026-12-24');
    expectNoDuplicates(result);
    // The legacy vigil document is covered by the sets of advent-24-12.
    expect(result.groups, hasLength(1));
    final massSet = result.massSet!;
    expect(ids(massSet.sets), ['morning', 'vigil']);
    expect(massSet.set.id, 'vigil');
    expect(massSet.set.label, 'Св. Імша ў вігілію');
    // The route can open the morning Mass explicitly.
    final morning = readingsOn('2026-12-24', set: 'morning').massSet!;
    expect(morning.set.label, 'Ранішняя Св. Імша');
    expect(roles(morning), ['reading1', 'psalm', 'alleluia', 'gospel']);
    // Opened from the Hours (day id of the date): the same choice.
    expect(
      readingsOn('2026-12-24', dayId: 'advent-24-12').massSet!.set.id,
      'vigil',
    );
  });

  group('Palm Sunday', () {
    test('shared readings once, cycle procession Gospel and Passion', () {
      for (final (iso, cycle, procession, passion) in [
        ('2026-03-29', 'A', 'Мц 21, 1–11', 'Мц 27, 11–54'),
        ('2027-03-21', 'B', 'Мк 11, 1–10', 'Мк 15, 1–39'),
        ('2028-04-09', 'C', 'Лк 19, 28–40', 'Лк 23, 1–49'),
      ]) {
        final result = readingsOn(iso);
        expectNoDuplicates(result);
        expect(result.groups, hasLength(1), reason: iso);
        final massSet = result.massSet!;
        expect(ids(massSet.sets), ['procession', 'mass']);
        expect(massSet.set.id, 'mass', reason: 'default: the Mass');
        expect(massSet.cycle, cycle, reason: iso);
        expect(massSet.cycles, ['A', 'B', 'C']);

        final mass = massSet.sections;
        for (final role in ['reading1', 'psalm', 'reading2', 'alleluia']) {
          expect(
            mass.where((s) => s.role == role),
            hasLength(1),
            reason: '$iso $role shared, once',
          );
        }
        final gospel = only(massSet, 'gospel');
        expect(gospel.cycle, cycle);
        expect(gospel.bible, passion);
        expect(gospel.passion!.roles, containsAll(PassionRole.values));
        expect(mass.where((s) => s.isRubric), isNotEmpty);
        expect(mass.where((s) => s.legend), hasLength(1));
        expect(only(massSet, 'alleluia').acclamation, isNotEmpty);

        final processionSet = readingsOn(iso, set: 'procession').massSet!;
        expect(processionSet.set.label, 'Працэсія з пальмамі');
        expect(processionSet.sections, hasLength(1));
        expect(processionSet.sections.single.bible, procession);
      }
    });

    test('another cycle changes only the Gospel', () {
      final a = readingsOn('2026-03-29').massSet!;
      final c = readingsOn('2026-03-29', cycle: 'C').massSet!;
      expect(c.cycle, 'C');
      expect(only(c, 'gospel').bible, 'Лк 23, 1–49');
      expect(only(c, 'reading1').bible, only(a, 'reading1').bible);
      expect(c.sections.length, a.sections.length);
    });
  });

  test('Holy Thursday: Chrism Mass and the evening Mass, default evening', () {
    final result = readingsOn('2026-04-02');
    expectNoDuplicates(result);
    expect(result.groups, hasLength(1));
    final massSet = result.massSet!;
    expect(ids(massSet.sets), ['chrism', 'evening']);
    expect(
      [for (final set in massSet.sets) set.context],
      ['chrism', 'evening'],
    );
    expect(massSet.set.id, 'evening');
    expect(massSet.set.label, 'Св. Імша Вячэры Пана');
    expect(
      readingsOn('2026-04-02', set: 'chrism').massSet!.set.label,
      'Св. Імша Хрызма',
    );
  });

  test('Good Friday: one set, the Passion by roles preserved', () {
    final massSet = readingsOn('2026-04-03').massSet!;
    expect(massSet.sets, hasLength(1));
    final gospel = only(massSet, 'gospel');
    final passion = gospel.passion!;
    expect(passion.roles, containsAll(PassionRole.values));
    expect(passion.blocks.where((b) => b.type == 'heading'), isNotEmpty);
    expect(passion.blocks.where((b) => b.type == 'rubric'), isNotEmpty);
    final christ = passion.blocks
        .expand((block) => block.runs)
        .firstWhere((run) => run.role == PassionRole.christ);
    expect(christ.text, isNotEmpty);
    // The flat text of the old apps keeps the source markers.
    final plain = passion.toPlainText();
    expect(plain, contains('Е. '));
    expect(plain, contains('Ев. '));
    expect(plain, contains('Л. '));
  });

  test('Easter Vigil: ordered multi-reading structure', () {
    final result = readingsOn('2026-04-04');
    expectNoDuplicates(result);
    expect(result.groups, hasLength(1));
    final massSet = result.massSet!;
    expect(massSet.document.id, 'holyweek-w1-d7--vigil');
    expect(massSet.cycle, 'A');
    expect(roles(massSet), [
      'rubric',
      for (var i = 1; i <= 7; i++) ...['reading$i', 'psalm$i'],
      'rubric',
      'epistle',
      'psalm',
      'gospel',
    ]);
    expect(only(massSet, 'reading3').conclusion, '');
    expect(only(massSet, 'reading3').rubrics, isNotEmpty);
    expect(only(massSet, 'epistle').displayLabel, 'Эпістала');
    expect(only(massSet, 'psalm3').displayLabel, 'Рэспансарыйны псальм');
    expect(only(massSet, 'gospel').bible, 'Мц 28, 1–10');
    expect(
      only(readingsOn('2026-04-04', cycle: 'B').massSet!, 'gospel').bible,
      'Мк 16, 1–7',
    );
  });

  test('Pentecost: Saturday morning / vigil, Sunday separate', () {
    final saturday = readingsOn('2026-05-23');
    expectNoDuplicates(saturday);
    expect(saturday.groups, hasLength(1));
    final sets = saturday.massSet!;
    expect(ids(sets.sets), ['morning', 'vigil']);
    expect(sets.set.id, 'vigil');
    expect(sets.set.label, 'Св. Імша ў вігілію');
    expect(
      readingsOn('2026-05-23', set: 'morning').massSet!.set.label,
      'Ранішняя імша',
    );
    // From the Hours (the legacy vigil document is linked to the day).
    expect(
      readingsOn('2026-05-23', dayId: 'easter-w7-d7').massSet!.set.id,
      'vigil',
    );

    final sunday = readingsOn('2026-05-24').massSet!;
    expect(sunday.document.id, 'feast-pentecost');
    expect(ids(sunday.sets), ['day']);
    expect(only(sunday, 'gospel').bible, isNot(only(sets, 'gospel').bible));
  });

  test('Ascension: shared readings + A/B/C Gospel', () {
    final result = readingsOn('2026-05-14');
    expectNoDuplicates(result);
    final massSet = result.massSet!;
    expect(massSet.document.id, 'feast-ascension');
    expect(massSet.cycles, ['A', 'B', 'C']);
    expect(massSet.cycle, 'A');
    expect(roles(massSet), [
      'reading1',
      'psalm',
      'reading2',
      'alleluia',
      'gospel',
    ]);
    // The cycle documents of the old apps are covered: one celebration.
    expect(
      result.groups.where(
        (g) => g.documents.any((d) => d.id == 'feast-ascension'),
      ),
      hasLength(1),
    );
    final gospels = {
      for (final cycle in ['A', 'B', 'C'])
        only(readingsOn('2026-05-14', cycle: cycle).massSet!, 'gospel').bible,
    };
    expect(gospels, hasLength(3));
    expect(
      only(readingsOn('2026-05-14', cycle: 'C').massSet!, 'reading1').bible,
      only(massSet, 'reading1').bible,
    );
  });

  test('sequence is its own section (Easter Sunday, Pentecost)', () {
    for (final iso in ['2026-04-05', '2026-05-24']) {
      final massSet = readingsOn(iso).massSet!;
      expect(roles(massSet), [
        'reading1',
        'psalm',
        'reading2',
        'sequence',
        'alleluia',
        'gospel',
      ], reason: iso);
      expect(only(massSet, 'sequence').displayLabel, 'Секвенцыя');
      expect(only(massSet, 'sequence').text, isNotEmpty);
    }
  });

  group('reference-only', () {
    test('cathedral dedication: citations, no text, still shown', () {
      final result = readingsOn(
        '2026-12-04',
        diocese: 'grodno',
        dayId: '04-12-grodno-cathedral-dedication',
      );
      final massSet = result.massSet!;
      expect(massSet.document.id, '04-12-grodno-cathedral-dedication');
      expect(massSet.referenceOnly, isTrue);
      expect(hasReadingDocumentContent(massSet.document), isTrue);
      expect(massSet.sections.where((s) => (s.text ?? '').isNotEmpty), isEmpty);
      final citations = massSet.set.citations(massSet.cycle);
      expect(
        [for (final c in citations) c.label],
        [
          'Першае чытанне',
          'Рэспансарыйны псальм',
          'Другое чытанне',
          'Евангелле',
        ],
      );
      expect(citations.first.bible, 'Нм 8, 2–4а. 5–6. 8–10');
      expect(citations.last.bible, 'Мц 16, 13–19');
    });

    test(
      'Our Lady of Lahishyn: retained source citations without a general calendar assignment',
      () {
        final raw = HiveService.readingsBox.values.cast<Map>().firstWhere(
          (doc) =>
              '${doc['id']}'.contains('lahishyn') &&
              doc['massReadings'] != null,
        );
        final source = ParsedReading.fromMap(
          '${raw['id']}',
          raw.cast<String, dynamic>(),
        );
        final citations = source.massReadings!.sets.first.citations('');
        expect(citations.first.bible, 'Саф 3, 14–18');
        expect(citations.first.alternatives, ['Рым 12, 9–16аb']);
        expect(citations.last.bible, 'Лк 1, 39–59');
        expect(
          LiturgicalContentService()
              .contentForDate(DateTime(2026, 8, 22), diocese: 'pinsk')
              .ordo
              .options
              .map((o) => o.id),
          isNot(contains('our-lady-lahishyn')),
        );
      },
    );
  });

  group('All Souls', () {
    test('2 November: three Masses, the first by default', () {
      final massSet = readingsOn('2026-11-02').massSet!;
      expect(ids(massSet.sets), ['first', 'second', 'third']);
      expect(massSet.set.id, 'first');
    });

    test('on a Sunday the readings are of All Souls (Mass source)', () {
      final result = readingsOn('2025-11-02');
      expect(result.massSet?.document.id, '02-11-all-faithful-departed');
      expect(result.massSet!.set.id, 'first');
    });

    test('an Office that is not a Mass option does not choose them', () {
      final day = LiturgicalContentService()
          .contentForDate(DateTime(2025, 11, 2))
          .ordo;
      expect(
        ParsedReadingsService.isOfficeOnlySource(
          day,
          'temporal:ordinary-w31-d1',
        ),
        isTrue,
      );
      expect(
        ParsedReadingsService.isOfficeOnlySource(day, day.primary.id),
        isFalse,
      );
    });
  });

  test('documents without sets keep the flat fields', () {
    final result = readingsOn('2026-05-17');
    expect(result.massSet, isNull);
    expect(result.reading?.hasMassReadingSets, isFalse);
    expect(result.reading?.gospel?.text, isNotEmpty);
    expect(result.cycles, ['A', 'B', 'C']);
  });

  test('every bundled set parses and resolves', () {
    final docs = bundledReadings();
    var sets = 0;
    for (final MapEntry(key: id, value: data) in docs.entries) {
      final reading = ParsedReading.fromMap(id, data);
      final ref = reading.massReadingsRef;
      if (ref != null) {
        final canonical = docs[ref.doc];
        expect(canonical?['massReadings'], isNotNull, reason: id);
        final target = ParsedReading.fromMap(ref.doc, canonical!);
        expect(
          target.massReadings!.sets.map((s) => s.id),
          contains(ref.set),
          reason: id,
        );
      }
      final massReadings = reading.massReadings;
      if (massReadings == null) continue;
      expect(
        massReadings.sets.where((set) => set.id == massReadings.defaultSetId),
        hasLength(1),
        reason: id,
      );
      for (final set in massReadings.sets) {
        sets++;
        expect(set.label, isNotEmpty, reason: '$id ${set.id}');
        expect(set.sections, isNotEmpty, reason: '$id ${set.id}');
        expect(
          set.sections.every(
            (section) => const {
              'reading',
              'psalm',
              'acclamation',
              'sequence',
              'gospel',
              'rubric',
            }.contains(section.kind),
          ),
          isTrue,
          reason: '$id ${set.id}',
        );
        for (final cycle in ['', ...set.cycles]) {
          final gospels = set
              .sectionsForCycle(cycle)
              .where((s) => s.kind == 'gospel');
          expect(gospels.length, lessThanOrEqualTo(1), reason: '$id $cycle');
        }
      }
    }
    expect(sets, greaterThan(20));
  });
}

Map<String, Map<String, dynamic>> bundledReadings() => decodeContentCollection(
  File('$kContentAssetDir/readings.json.gz').readAsBytesSync(),
).docs;
