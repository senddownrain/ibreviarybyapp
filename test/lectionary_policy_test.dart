// Closed product policies of the Lectionary, asserted on what the Flutter
// Readings screen actually resolves (independent of the web fixture).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/content/content_store.dart';
import 'package:mybrev_flutter/ordo/runtime.dart';
import 'package:mybrev_flutter/services/hive_service.dart';

import 'support/lectionary_fixture.dart';
import 'support/lectionary_run.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  setUpAll(() async {
    await initializeDateFormatting('be');
    directory = await Directory.systemTemp.createTemp('lectionary-policy-');
    await HiveService.init(path: directory.path, loadBundle: true);
    await ContentStore.instance.ensureLoaded(kContentCollections);
    await applyPublishedReadings();
  });
  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  FlutterScreen screen(
    String iso, {
    String diocese = 'minsk-mohilev',
    String? option,
  }) {
    final date = DateTime.parse(iso);
    final id =
        option ?? OrdoRuntime.engine.resolve(date, diocese: diocese).primary.id;
    return flutterScreenFor(date, diocese, id)!;
  }

  List<String> ids(FlutterScreen s) => [for (final set in s.sets) '${set[0]}'];
  String label(FlutterScreen s, String id) =>
      '${s.sets.firstWhere((set) => set[0] == id)[1]}';

  test('15.08 and 29.06: vigil + day, DAY by default, vigil is labelled', () {
    for (final iso in ['2026-08-15', '2026-06-29', '2027-08-15']) {
      final s = screen(iso);
      expect(ids(s), ['vigil', 'day'], reason: iso);
      expect(s.activeSet, 'day', reason: iso);
      expect(label(s, 'vigil'), 'Св. Імша ў вігілію');
      expect(label(s, 'day'), 'Св. Імша ўдзень');
    }
  });

  test('25.12: three sets, day by default', () {
    final s = screen('2026-12-25');
    expect(ids(s), ['night', 'dawn', 'day']);
    expect(s.activeSet, 'day');
  });

  test('24.12 on a weekday: morning + vigil, EVENING (vigil) default', () {
    final s = screen('2026-12-24');
    expect(ids(s), ['morning', 'vigil']);
    expect(s.activeSet, 'vigil');
  });

  test('24.12 on a Sunday: the Sunday of Advent AND the Christmas Vigil Mass, '
      'the vigil (evening) group is the default', () {
    for (final iso in ['2028-12-24', '2034-12-24']) {
      final sunday = screen(iso);
      expect(
        sunday.groups
            .expand((g) => g.$2)
            .any((d) => d.startsWith('advent-w4-d1--')),
        isTrue,
        reason: '$iso Sunday IV of Advent offered',
      );
      final vigil = flutterScreenFor(
        DateTime.parse(iso),
        'minsk-mohilev',
        null,
      )!;
      expect(
        vigil.groups[vigil.active].$2.any(
              (d) => d.contains('christmas-vigil'),
            ) ||
            vigil.setDoc == 'advent-24-12',
        isTrue,
        reason: '$iso default is the vigil Mass',
      );
    }
  });

  test('Sundays in date-keyed windows read the period documents', () {
    // IV Sunday of Advent 2025, II Sunday after Christmas 2026.
    final advent = screen('2025-12-21');
    expect(advent.view!.docId, startsWith('advent-w4-d1--'));
    expect(advent.view!.cycle, 'A');
    final christmas = screen('2026-01-04');
    expect(christmas.view!.docId, 'christmas-w2-d1');
  });

  test('Holy Thursday: chrism + evening, evening default; Good Friday passion; '
      'Palm Sunday procession + Mass, Mass default, Passion by roles', () {
    final thursday = screen('2026-04-02');
    expect(ids(thursday), ['chrism', 'evening']);
    expect(thursday.activeSet, 'evening');
    expect(ids(screen('2026-04-03')), ['passion']);
    final palm = screen('2026-03-29');
    expect(ids(palm), ['procession', 'mass']);
    expect(palm.activeSet, 'mass');
    expect(palm.cycles, 'ABC');
    expect(palm.view!.sections.where((s) => s.kind == 'gospel'), isNotEmpty);
  });

  test('Easter Vigil keeps all its readings in order; Easter Sunday has the '
      'day Mass with the sequence', () {
    final vigil = screen('2026-04-04');
    expect(ids(vigil), ['vigil']);
    final roles = [for (final s in vigil.view!.sections) s.role];
    expect(
      roles,
      containsAllInOrder([
        'reading1',
        'psalm1',
        'reading2',
        'psalm2',
        'reading3',
        'psalm3',
        'reading4',
        'psalm4',
        'reading5',
        'psalm5',
        'reading6',
        'psalm6',
        'reading7',
        'psalm7',
        'epistle',
        'psalm',
        'gospel',
      ]),
    );
    expect(
      roles.where((r) => r.startsWith('reading')).length,
      greaterThanOrEqualTo(7),
    );
    expect(roles, contains('epistle'));
    expect(roles.last, 'gospel');
    final easter = screen('2026-04-05');
    expect(ids(easter), ['day']);
    expect(easter.view!.sections.map((s) => s.kind), contains('sequence'));
    final pentecost = screen('2026-05-24');
    expect(pentecost.view!.sections.map((s) => s.kind), contains('sequence'));
  });

  test('Pentecost Saturday: vigil by default; Ascension has A/B/C Gospels', () {
    final saturday = screen('2026-05-23');
    expect(ids(saturday), ['morning', 'vigil']);
    expect(saturday.activeSet, 'vigil');
    final ascension = screen('2026-05-14');
    expect(ascension.cycles, 'ABC');
    expect(ascension.cycle, 'A');
  });

  test('All Souls on a Sunday: the Mass is All Souls with three sets', () {
    for (final iso in ['2025-11-02', '2031-11-02']) {
      final s = screen(iso);
      expect(ids(s), ['first', 'second', 'third'], reason: iso);
      expect(s.activeSet, 'first');
    }
  });

  test('reference-only celebrations never invent a text', () {
    final pinsk = screen('2026-05-01', diocese: 'pinsk');
    final other = screen('2026-05-01');
    expect(
      other.groups.expand((g) => g.$2),
      isNot(contains('01-05-pinsk-cathedral-dedication')),
      reason: 'another diocese\'s cathedral dedication never leaks',
    );
    final hasRef = pinsk.groups
        .expand((g) => g.$2)
        .contains('01-05-pinsk-cathedral-dedication');
    if (hasRef) {
      final own = flutterScreenFor(
        DateTime(2026, 5, 1),
        'pinsk',
        OrdoRuntime.engine
            .resolve(DateTime(2026, 5, 1), diocese: 'pinsk')
            .options
            .firstWhere((o) => o.id.contains('dedication'))
            .id,
      )!;
      if (own.setDoc == '01-05-pinsk-cathedral-dedication') {
        expect(own.view!.referenceOnly, isTrue);
      }
    }
  });

  group('decisions of the web audit (2026-10-13)', () {
    List<String> optionIds(String iso, String diocese) {
      final day = OrdoRuntime.engine.resolve(
        DateTime.parse(iso),
        diocese: diocese,
      );
      return [for (final o in day.options) o.id];
    }

    test('24.06: vigil + day sets, DAY by default', () {
      final s = screen('2026-06-24');
      expect(ids(s), ['vigil', 'day']);
      expect(s.activeSet, 'day');
    });

    test('06.08: one Mass set with the Gospels of the years A, B and C', () {
      final s = screen('2026-08-06');
      expect(s.cycles, 'ABC');
      expect(s.setDoc, '06-08-transfiguration-lord');
    });

    test(
      'Pentecost Saturday 2031-05-31 (Visitation): the feast Mass and the '
      'Vigil Mass of Pentecost are both offered, the vigil is the default',
      () {
        for (final diocese in ['minsk-mohilev', 'grodno', 'pinsk', 'vitebsk']) {
          final date = DateTime.parse('2031-05-31');
          final root = flutterScreenFor(
            date,
            diocese,
            null,
            useRouteDayId: false,
          )!;
          final docs = root.groups.expand((g) => g.$2).toList();
          expect(
            docs.any((d) => d.contains('visitation')),
            isTrue,
            reason: diocese,
          );
          expect(
            docs.any((d) => d.startsWith('easter-w7-d7')),
            isTrue,
            reason: diocese,
          );
          final active = root.groups[root.active].$2;
          expect(
            active.any((d) => d.contains('visitation')),
            isFalse,
            reason: '$diocese: the evening vigil is the default',
          );
          final feast = optionIds('2031-05-31', diocese).first;
          final viaOption = screen(
            '2031-05-31',
            diocese: diocese,
            option: feast,
          );
          expect(viaOption.groups, isNotEmpty);
        }
      },
    );

    test('22.10 John Paul II: the weekday readings open, his own readings '
        'are a selectable alternative', () {
      for (final diocese in ['minsk-mohilev', 'grodno', 'pinsk', 'vitebsk']) {
        final s = screen(
          '2026-10-22',
          diocese: diocese,
          option: 'sv-john-paul-ii',
        );
        final docs = s.groups.expand((g) => g.$2).toList();
        final active = s.groups[s.active].$2;
        expect(
          active.any((d) => d.startsWith('ordinary-w29')),
          isTrue,
          reason: diocese,
        );
        expect(
          docs.any((d) => d.contains('john-paul')),
          isTrue,
          reason: diocese,
        );
        expect(active.any((d) => d.contains('john-paul')), isFalse);
      }
    });

    test('Budslav 02.07: the plan prescribes the proper readings only in '
        'Pinsk (the document link is pending web authorization)', () {
      for (final year in [2026, 2027]) {
        final date = DateTime.parse('$year-07-02');
        for (final diocese in ['minsk-mohilev', 'grodno', 'pinsk', 'vitebsk']) {
          final plan = OrdoRuntime.engine
              .resolve(date, diocese: diocese)
              .readingsPlan
              .where((o) => o.optionId == 'our-lady-budslav')
              .toList();
          if (plan.isEmpty || !plan.single.isMemorial) continue;
          final expected = diocese == 'pinsk' ? 'proper' : 'weekday';
          expect(plan.single.defaultPurpose, expected, reason: '$diocese');
          expect(plan.single.lookup.first.purpose, expected);
          // Without `_dayIds` on the readings document nothing wrong opens.
          final s = screen(
            '$year-07-02',
            diocese: diocese,
            option: 'our-lady-budslav',
          );
          expect(s.groups, isNotEmpty);
        }
      }
    });
  });
}
