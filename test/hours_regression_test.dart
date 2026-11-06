// Hours regressions on the bundled content (what a fresh install shows):
// the engine decides the legal Offices, `liturgicalProperTexts` carries the
// Propers, the assembler fills the rest from the sources the rubrics name.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mybrev_flutter/constants/liturgical.dart';
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/content/content_store.dart';
import 'package:mybrev_flutter/ordo/dates.dart';
import 'package:mybrev_flutter/ordo/engine.dart';
import 'package:mybrev_flutter/ordo/runtime.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/services/liturgical_content_service.dart';
import 'package:mybrev_flutter/utils/office_assembly.dart';
import 'package:mybrev_flutter/utils/liturgical_day_resolution.dart';
import 'package:mybrev_flutter/utils/liturgical_vespers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  final service = LiturgicalContentService();

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('hours-regression-');
    await HiveService.init(path: directory.path, loadBundle: true);
    await ContentStore.instance.ensureLoaded(kContentCollections);
  });
  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  Map<String, Map<String, dynamic>> templates() => HiveService.templates();
  bool rawInstruction(Object? value) =>
      value is String && value.toLowerCase().contains('з нядзелі і тыдня');

  test('Guardian Angels 02.10.2026: Proper antiphons, Lauds psalms of '
      'Sunday I, never the raw instruction', () {
    final content = service.contentForDate(DateTime(2026, 10, 2));
    expect(content.ordo.primary.id, 'holy-guardian-angels');
    final option = content.options.single;
    expect(option.properSource, ProperSource.properTexts);
    final day = option.day!.data;
    final proper =
        HiveService.content
                .collection('liturgicalProperTexts')
                .get('02-10-holy-guardian-angels')
            as Map;
    for (final field in ['laudesPs1', 'laudesPs2', 'laudesPs3']) {
      expect(day[field], templates()['sunday-week-1']![field], reason: field);
    }
    if (proper['laudesAnt1'] != null) {
      expect(day['laudesAnt1'], proper['laudesAnt1']);
    }
    for (final entry in day.entries) {
      expect(rawInstruction(entry.value), isFalse, reason: entry.key);
    }
    // The route opens the assembled Office.
    expect(
      content.dayById('02-10-holy-guardian-angels')!.data['laudesPs1'],
      day['laudesPs1'],
    );
  });

  test('St Bruno 06.10.2026: «З дня» (default) / «Пра пастыраў» / «Пра '
      'законнікаў»; the own Proper survives every Common', () {
    final content = service.contentForDate(DateTime(2026, 10, 6));
    expect(content.ordo.primary.isTemporal, isTrue);
    final bruno = content.options.firstWhere(
      (option) => option.optionId == 'sv-bruno',
    );
    expect(bruno.ordo!.officeKind, 'optional-memorial');
    expect(bruno.templates.map((t) => t.label), [
      'З дня',
      'Пра пастыраў',
      'Пра законнікаў',
    ]);
    final proper =
        HiveService.content
                .collection('liturgicalProperTexts')
                .get('06-10-sv-bruno')
            as Map;
    for (final template in bruno.templates) {
      expect(
        template.day.data['officeOfReadingsR2'],
        proper['officeOfReadingsR2'],
        reason: template.label,
      );
      if (proper['laudesPr'] != null) {
        expect(template.day.data['laudesPr'], proper['laudesPr']);
      }
    }
    // «З дня» keeps the weekday hymn; a Common brings its own.
    final day = content.options.first.day!.data;
    expect(bruno.templates.first.day.data['laudesHymn'], day['laudesHymn']);
    expect(
      bruno.templates[1].day.data['laudesHymn'],
      templates()['pastors']!['laudesHymn'],
    );
  });

  test('All Souls: the Office for the Dead, not the weekday', () {
    // 2025 and 2031: 2 November is a Sunday (separate test below).
    for (final year in [2026, 2027, 2030]) {
      final content = service.contentForDate(DateTime(year, 11, 2));
      expect(content.ordo.primary.id, 'all-faithful-departed', reason: '$year');
      expect(content.ordo.primary.officeKind, 'all-souls');
      expect(
        content.options.any((option) => option.ordo?.officeKind == 'weekday'),
        isFalse,
      );
    }
  });

  test('All Souls on a Sunday: the Hours are of the Sunday, the Mass of All '
      'Souls (§11.1)', () {
    for (final date in [DateTime(2025, 11, 2), DateTime(2031, 11, 2)]) {
      for (final diocese in ['minsk-mohilev', 'grodno', 'pinsk', 'vitebsk']) {
        final content = service.contentForDate(date, diocese: diocese);
        final ordo = content.ordo;
        expect(ordo.primary.id, 'all-faithful-departed', reason: '$date');
        expect(ordo.sources.split, isTrue);
        expect(ordo.sources.mass.optionId, 'all-faithful-departed');
        // One Office card: the Sunday. No All Souls Office, no votive
        // Office for the Dead.
        expect(content.options, hasLength(1), reason: '$date $diocese');
        final sunday = content.options.single;
        expect(sunday.ordo!.optionId, ordo.sources.office.optionId);
        expect(sunday.ordo!.officeKind, 'sunday');
        expect(sunday.source, LiturgicalOptionSource.period);
        expect(
          content.options.any(
            (o) => o.source == LiturgicalOptionSource.officeForDead,
          ),
          isFalse,
        );
        expect(sunday.day!.data['officeOfReadingsTeDeum'], isNot(false));
        expect(content.unavailable, isEmpty);
      }
    }
    // The Monday after is an ordinary weekday again (no split).
    expect(service.contentForDate(DateTime(2025, 11, 3)).ordo.isSplit, false);
  });

  test('13-14.06.2026: memorial assembly and I/II Vespers field routing in four dioceses', () {
    final date = DateTime(2026, 6, 13);
    for (final diocese in ['minsk-mohilev', 'grodno', 'pinsk', 'vitebsk']) {
      final today = service.contentForDate(date, diocese: diocese);
      final tomorrow = service.contentForDate(DateTime(2026, 6, 14), diocese: diocese);
      final heart = today.options.firstWhere(
        (option) => option.ordo?.optionId == 'immaculate-heart',
      );
      final antony = today.options.firstWhere(
        (option) => option.ordo?.optionId == 'sv-anthony-padua',
      );
      expect(antony.day, isNotNull, reason: diocese);
      for (final option in [heart, antony]) {
        for (final variant in option.templates) {
          for (final field in kOfficeFieldSlots.keys) {
            if (field.startsWith('vesper')) continue;
            expect(variant.day.field(field)?.trim(), isNotEmpty,
                reason: '$diocese ${option.optionId} ${variant.choice} $field');
          }
          expect(variant.day.data['officeOfReadingsTeDeum'], isNot(true),
              reason: 'no Te Deum on a memorial');
        }
      }
      expect(heart.day, isNotNull, reason: diocese);
      expect(heart.templates.map((choice) => choice.choice),
          contains('blessed-virgin-mary'), reason: diocese);
      expect(heart.day!.field('laudesHymn')?.trim(), isNotEmpty,
          reason: 'Marian Lauds hymn $diocese');
      expect(heart.day!.field('officeOfReadingsR2')?.trim(), isNotEmpty,
          reason: 'Marian second reading $diocese');

      expect(today.ordo.evening.vespersType, 'first', reason: diocese);
      final saturdayId = periodDayDocumentId(
        today.ordo.period, today.ordo.week, today.ordo.dayOfWeek,
      );
      final saturdayPsalter = today.itemsDays[saturdayId];
      expect(saturdayPsalter, isNotNull, reason: '$diocese $saturdayId');
      expect(saturdayId, 'ordinary-w10-d7', reason: diocese);
      final sunday = tomorrow.options.firstWhere(
        (option) => option.ordo?.optionId == today.ordo.evening.celebrationId,
      );
      expect(sunday.ordo?.officeKind, 'sunday', reason: diocese);
      final first = resolveEveningOffice(
        date: date, selected: heart.day!, today: today, tomorrow: tomorrow,
      );
      expect(first.isFirst, isTrue, reason: diocese);
      expect(first.day.id, sunday.day?.id, reason: diocese);
      expect(first.day.data['_firstVespersSource'], isNot('proper'),
          reason: diocese);
      for (final suffix in firstVespersSuffixes) {
        final own = sunday.day?.field('vesper1$suffix');
        final expected = own != null && own.trim().isNotEmpty
            ? own : saturdayPsalter?.field('vesper$suffix');
        expect(expected?.trim(), isNotEmpty,
            reason: '$diocese I Vespers source: $suffix');
        expect(first.day.field('vesper$suffix'), expected,
            reason: '$diocese I Vespers: $suffix');
      }
      expect(first.day.data['_missingFirstVespersFields'], isEmpty,
          reason: diocese);
      final second = resolveEveningOffice(
        date: DateTime(2026, 6, 14),
        selected: sunday.day!,
        today: tomorrow,
        tomorrow: service.contentForDate(DateTime(2026, 6, 15), diocese: diocese),
      );
      expect(second.isFirst, isFalse, reason: diocese);
      expect(second.isSecond, isTrue, reason: diocese);
      for (final suffix in firstVespersSuffixes) {
        expect(second.day.field('vesper$suffix'), sunday.day!.field('vesper$suffix'),
            reason: '$diocese Sunday II Vespers: $suffix');
      }
      final anthonyVespers = resolveEveningOffice(
        date: date, selected: antony.day!, today: today, tomorrow: tomorrow,
      );
      expect(anthonyVespers.day.field('vesperHymn'),
          first.day.field('vesperHymn'), reason: diocese);
    }
  });

  test('Immaculate Heart + St Anthony (13.06.2026): exactly two memorial '
      'Offices, no weekday card (§11.2)', () {
    for (final diocese in ['minsk-mohilev', 'grodno', 'pinsk', 'vitebsk']) {
      final content = service.contentForDate(
        DateTime(2026, 6, 13),
        diocese: diocese,
      );
      expect(
        [for (final option in content.options) option.ordo?.optionId],
        ['immaculate-heart', 'sv-anthony-padua'],
        reason: diocese,
      );
      expect(content.options.first.ordo!.role, 'primary');
      expect(content.options.last.ordo!.role, 'alternative');
      expect(
        content.options.any((o) => o.ordo?.kind == 'temporal'),
        isFalse,
        reason: 'the weekday is not a third option',
      );
      // The Immaculate Heart memorial offers a genuine choice between
      // «З дня» and the Marian Common, not a separate weekday Office card.
      final heartChoices = content.options.first.templates.map((t) => t.choice);
      expect(heartChoices, contains(kCurrentDayChoice), reason: diocese);
      expect(heartChoices, contains('blessed-virgin-mary'), reason: diocese);
      expect(
        content.options.first.templates.map((t) => t.label),
        contains(kCurrentDayLabel),
        reason: diocese,
      );
    }
  });

  test('a memorial defaults to «З дня»; a feast takes the Lauds psalms of '
      'Sunday I', () {
    final memorial = service
        .contentForDate(DateTime(2026, 10, 1))
        .options
        .first;
    expect(memorial.templates.first.label, 'З дня');
    expect(memorial.templates.first.choice, kCurrentDayChoice);
    final feast = service.contentForDate(DateTime(2026, 8, 6)).options.single;
    expect(feast.ordo!.officeKind, 'feast');
    final proper =
        HiveService.content
                .collection('liturgicalProperTexts')
                .get('06-08-transfiguration-lord')
            as Map;
    if (proper['laudesPs1'] == null) {
      expect(
        feast.day!.data['laudesPs1'],
        templates()['sunday-week-1']!['laudesPs1'],
      );
    }
    expect(feast.day!.data['officeOfReadingsTeDeum'], isTrue);
  });

  test('solemnity on a weekday: complementary psalmody; missing template is '
      'an integrity error, never the day', () {
    final day = OrdoRuntime.engine.resolve('2026-08-15');
    final office = day.office(day.primary.id)!;
    expect(office.slot('daytime', 'psalmody')!.chain, ['complementary']);
    final content = service.contentForDate(DateTime(2026, 8, 15));
    final assembled = content.options.single.day!.data;
    expect(
      assembled['sext1Ps1'],
      templates()[kComplementaryPsalmodyTemplate]!['sext1Ps1'],
    );

    final withoutComplementary = {...templates()}
      ..remove(kComplementaryPsalmodyTemplate);
    final assembly = assembleOffice(
      proper: {'id': 'x', '_rank': 'solemnitas', '_schema': 2},
      currentDay: {'sext1Ps1': 'DAY'},
      templates: withoutComplementary,
      isSunday: false,
      office: office,
    );
    expect(assembly.data['sext1Ps1'], '');
    expect(assembly.missing, contains('sext1Ps1'));
    expect(
      assembly.integrity.map((e) => (e.field, e.reason)),
      contains(('sext1Ps1', 'template-missing')),
    );
  });

  group('seasons, several years', () {
    test('17–24 December: weekday primary, memorials only commemorations', () {
      for (final year in [2025, 2026, 2027, 2028]) {
        for (var d = 17; d <= 24; d++) {
          final content = service.contentForDate(DateTime(year, 12, d));
          final ordo = content.ordo;
          expect(ordo.period, 'advent', reason: '$year-12-$d');
          expect(ordo.periodPhase, 'dec17-24');
          if (!ordo.season.isSunday) {
            expect(ordo.primary.isTemporal, isTrue, reason: '$year-12-$d');
            expect(ordo.alternatives, isEmpty);
          }
          expect(content.options.first.day!.id, startsWith('advent-$d-12'));
        }
      }
    });

    test('25 December – 12 January: octave, Mary Mother of God, Epiphany, '
        'Baptism of the Lord', () {
      for (final year in [2025, 2026, 2027]) {
        final engine = OrdoRuntime.engine;
        expect(engine.resolve('$year-12-25').primary.id, 'nativity-lord');
        expect(
          engine.resolve('${year + 1}-01-01').primary.id,
          'holy-mary-mother-of-god',
        );
        expect(engine.resolve('${year + 1}-01-06').primary.id, 'epiphany-lord');
        for (var d = 26; d <= 31; d++) {
          final day = engine.resolve('$year-12-$d');
          expect(day.period, 'christmas');
          expect(day.periodPhase, 'octave');
        }
        for (var d = 2; d <= 12; d++) {
          final iso = '${year + 1}-01-${d.toString().padLeft(2, '0')}';
          final content = service.contentForDate(dateOfIso(iso));
          expect(content.options, isNotEmpty, reason: iso);
          expect(content.options.first.day, isNotNull, reason: iso);
        }
      }
    });

    test('Holy Week and the Easter octave', () {
      for (final year in [2026, 2027, 2028]) {
        final engine = OrdoRuntime.engine;
        final easter = engine.plan(year, 'minsk-mohilev').anchors.easterSunday;
        OrdoDay at(int offset) => engine.resolve(addDays(easter, offset));
        expect(at(-7).primary.id, 'palm-sunday');
        for (final offset in [-6, -5, -4]) {
          expect(at(offset).period, 'holyweek');
          expect(at(offset).alternatives, isEmpty);
        }
        expect(at(-3).primary.officeKind, 'triduum');
        expect(at(-2).primary.color, 'ruber');
        expect(at(0).primary.id, 'easter-sunday');
        for (var offset = 1; offset <= 6; offset++) {
          expect(at(offset).primary.officeKind, 'easter-octave');
          expect(at(offset).alternatives, isEmpty);
          expect(
            service.contentForDate(dateOfIso(at(offset).date)).options,
            isNotEmpty,
          );
        }
      }
    });
  });

  test('legacy fixed days are a fallback only: no tested date needs them', () {
    var legacy = 0;
    for (final iso in daysOfYear(2026)) {
      final content = service.contentForDate(dateOfIso(iso));
      legacy += content.options
          .where((option) =>
              option.source == LiturgicalOptionSource.fixed &&
              option.properSource == ProperSource.legacyDays)
          .length;
    }
    expect(legacy, 0);
  });
}
