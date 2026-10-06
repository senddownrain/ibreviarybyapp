// Sparse feast documents: the Flutter assembly must give exactly what the
// web assembles (fixture generated from mybrev `officeAssembly.js`).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mybrev_flutter/constants/liturgical.dart';
import 'package:mybrev_flutter/providers/calendar_provider.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/services/liturgical_content_service.dart';
import 'package:mybrev_flutter/utils/hours_liturgical_options.dart';
import 'package:mybrev_flutter/utils/liturgical_calendar.dart';
import 'package:mybrev_flutter/utils/office_assembly.dart';

void main() {
  final fixture =
      jsonDecode(
            File(
              'test/fixtures/office_assembly_parity.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final templates = {
    for (final entry in (fixture['templates'] as Map).entries)
      entry.key.toString(): Map<String, dynamic>.from(entry.value as Map),
  };
  final currentDay = Map<String, dynamic>.from(fixture['currentDay'] as Map);

  test('assembly equals the web for memorial, feast and solemnity', () {
    final cases = (fixture['cases'] as List).cast<Map<String, dynamic>>();
    expect(cases.map((c) => c['officeKind']).toSet(), {
      'memorial',
      'feast',
      'solemnity',
    });
    for (final item in cases) {
      final proper = Map<String, dynamic>.from(item['proper'] as Map);
      final date = DateTime.parse(item['date'] as String);
      expect(
        officeKindOfRank(proper['_rank']?.toString()),
        item['officeKind'],
        reason: item['id'] as String,
      );
      expect(
        assemblyChoices(proper, item['officeKind'] as String),
        item['choices'],
      );
      final results = item['results'] as Map<String, dynamic>;
      for (final choice in results.keys) {
        final assembled = assembleOffice(
          proper: proper,
          currentDay: currentDay,
          templates: templates,
          isSunday: date.weekday == DateTime.sunday,
          choice: choice,
        );
        (results[choice] as Map<String, dynamic>).forEach((field, expected) {
          expect(
            jsonEncode(assembled.data[field]),
            jsonEncode(expected),
            reason: '${item['id']} ${item['date']} $choice $field',
          );
        });
      }
    }
  });

  test('choice ids round-trip and the default id is the document id', () {
    expect(assemblyDayId('x', 'pastors', isDefault: true), 'x');
    expect(assemblyDayId('x', 'pastors', isDefault: false), 'x--pastors');
    expect(assemblyDayId('x', kCurrentDayChoice, isDefault: false), 'x--day');
    expect(parseAssemblyDayId('x--pastors'), ('x', 'pastors'));
    expect(parseAssemblyDayId('x--day'), ('x', kCurrentDayChoice));
    expect(parseAssemblyDayId('plain'), isNull);
  });

  group('with the device cache', () {
    late Directory directory;
    setUp(() async {
      directory = await Directory.systemTemp.createTemp('sparse-');
      await HiveService.init(path: directory.path);
      for (final entry in templates.entries) {
        await HiveService.templatesBox.put(entry.key, entry.value);
      }
    });
    tearDown(() async {
      await Hive.close();
      await directory.delete(recursive: true);
    });

    final date = DateTime(2028, 8, 1); // St Alphonsus, Tuesday
    final calendar = CalendarService();

    Future<void> seed({bool withLegacy = true}) async {
      final proper = (fixture['cases'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((c) => c['id'] == '01-08-sv-alphonsus-liguori');
      await HiveService.daysBox.putAll({
        'ordinary-w17-d3': {
          'id': 'ordinary-w17-d3',
          '_periodType': 'ordinary',
          '_periodWeekNumber': '17',
          '_dayOfWeek': '3',
          ...currentDay,
        },
        '01-08-sv-alphonsus-liguori': {
          ...Map<String, dynamic>.from(proper['proper'] as Map),
          'id': '01-08-sv-alphonsus-liguori',
          '_legacyIds': [
            '01-08-sv-alphonsus-liguori--pastors',
            '01-08-sv-alphonsus-liguori--doctors-of-church',
          ],
        },
        if (withLegacy)
          '01-08-sv-alphonsus-liguori--pastors': {
            'id': '01-08-sv-alphonsus-liguori--pastors',
            '_date': '01.08',
            '_rank': 'memoria',
            '_feastName': 'Стары дакумент',
            '_currentVersion': 'pastors',
          },
      });
    }

    List<DayOption> options() => LiturgicalContentService().getContentForDate(
      date,
      calendar.getYearOptionsCached(2028),
      calendar.getYearOptionsCached(2029),
      calendar.getDynamicDatesCached(2028),
    );

    test('one card with «З дня» and the Commons; old copies hidden', () async {
      await seed();
      final fixed = options().where(
        (o) => o.dayId?.startsWith('01-08') ?? false,
      );
      expect(fixed, hasLength(1));
      final option = fixed.single;
      expect(option.templates.map((t) => t.label), [
        'З дня',
        'Пра пастыраў',
        'Пра доктараў Касцёла',
      ]);
      expect(option.templates.map((t) => t.id), [
        '01-08-sv-alphonsus-liguori',
        '01-08-sv-alphonsus-liguori--pastors',
        '01-08-sv-alphonsus-liguori--doctors-of-church',
      ]);
      expect(option.day!.data['laudesHymn'], 'day:laudesHymn');
      final pastors = option.templates[1].day.data;
      expect(pastors['laudesHymn'], templates['pastors']!['laudesHymn']);
      expect(pastors['laudesPs1'], 'day:laudesPs1');
      expect(
        pastors['officeOfReadingsR2'],
        option.day!.data['officeOfReadingsR2'],
      );
      expect(option.day!.data['_periodType'], 'ordinary');
    });

    test(
      'a choice id resolves locally, like a route from an old link',
      () async {
        await seed(withLegacy: false);
        final content = LiturgicalContentService();
        final day = content.resolveDayLocal(
          date,
          '01-08-sv-alphonsus-liguori--doctors-of-church',
          calendar.getYearOptionsCached(2028),
          calendar.getYearOptionsCached(2029),
          calendar.getDynamicDatesCached(2028),
        )!;
        expect(day.id, '01-08-sv-alphonsus-liguori--doctors-of-church');
        expect(
          day.data['laudesHymn'],
          templates['doctors-of-church']!['laudesHymn'],
        );
        expect(day.data['_calendarDate'], '2028-08-01');
        final byDay = content.resolveDayLocal(
          date,
          '01-08-sv-alphonsus-liguori',
          calendar.getYearOptionsCached(2028),
          calendar.getYearOptionsCached(2029),
          calendar.getDynamicDatesCached(2028),
        )!;
        expect(byDay.data['laudesHymn'], 'day:laudesHymn');
      },
    );

    test('an obligatory memorial is primary over the weekday', () async {
      await seed(withLegacy: false);
      final selection = resolveHoursLiturgicalSelection(options());
      expect(selection.primary?.dayId, '01-08-sv-alphonsus-liguori');
      expect(
        options().any((o) => o.source == LiturgicalOptionSource.period),
        isTrue,
      );
    });

    test('obsolete documents are never offered', () async {
      await seed(withLegacy: false);
      await HiveService.daysBox.put('01-08-old', {
        'id': '01-08-old',
        '_date': '01.08',
        '_rank': 'memoria',
        '_feastName': 'Састарэлы',
        '_obsolete': true,
      });
      expect(options().any((o) => o.dayId == '01-08-old'), isFalse);
    });

    test(
      'without the Commons the Office is still complete, from the day',
      () async {
        await seed(withLegacy: false);
        await HiveService.templatesBox.clearOverlay();
        final option = options().firstWhere(
          (o) => o.dayId == '01-08-sv-alphonsus-liguori',
        );
        expect(option.day!.data['vesperHymn'], 'day:vesperHymn');
        expect(option.day!.data['officeOfReadingsR2'], isNot(''));
      },
    );
  });

  group('obligatory memorial against the weekday', () {
    LiturgicalContext ctx(String period, [int week = 3]) =>
        LiturgicalContext(periodType: period, periodWeek: week, dayOfWeek: 2);

    test('leads on ordinary, Advent, Christmas and Easter weekdays', () {
      expect(
        obligatoryMemorialOutranksDay(DateTime(2026, 10, 1), ctx('ordinary')),
        isTrue,
      );
      expect(
        obligatoryMemorialOutranksDay(DateTime(2026, 12, 7), ctx('advent')),
        isTrue,
      );
      expect(
        obligatoryMemorialOutranksDay(DateTime(2027, 1, 2), ctx('christmas')),
        isTrue,
      );
      expect(
        obligatoryMemorialOutranksDay(DateTime(2026, 4, 29), ctx('easter', 3)),
        isTrue,
      );
    });

    test('yields on Sundays, in Lent, 17-24 December and the octaves', () {
      expect(
        obligatoryMemorialOutranksDay(DateTime(2026, 10, 4), ctx('ordinary')),
        isFalse,
      );
      expect(
        obligatoryMemorialOutranksDay(DateTime(2027, 3, 17), ctx('lent')),
        isFalse,
      );
      expect(
        obligatoryMemorialOutranksDay(DateTime(2027, 3, 23), ctx('holyweek')),
        isFalse,
      );
      expect(
        obligatoryMemorialOutranksDay(DateTime(2026, 12, 21), ctx('advent')),
        isFalse,
      );
      expect(
        obligatoryMemorialOutranksDay(DateTime(2026, 12, 29), ctx('christmas')),
        isFalse,
      );
      expect(
        obligatoryMemorialOutranksDay(DateTime(2027, 1, 1), ctx('christmas')),
        isFalse,
      );
      expect(
        obligatoryMemorialOutranksDay(DateTime(2027, 3, 30), ctx('easter', 1)),
        isFalse,
      );
    });
  });
}
