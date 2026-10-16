import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/ordo/definitions.dart';
import 'package:mybrev_flutter/ordo/engine.dart';
import 'package:mybrev_flutter/ordo/liturgical_catalog.dart';
import 'package:mybrev_flutter/screens/catalog_entry_screen.dart';
import 'package:mybrev_flutter/screens/liturgical_picker_screen.dart';
import 'package:mybrev_flutter/services/catalog_preview_service.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/content/content_store.dart';
import 'package:hive/hive.dart';
import 'support/ordo_fixture.dart';

void main() {
  final engine = bundledOrdoEngine();
  final feasts = feastCatalog(engine.definitions, kDioceses);
  final periods = periodCatalog(engine.definitions);
  CatalogEntry entry(String id, String diocese) =>
      [...feasts, ...periods].firstWhere(
        (e) => e.id == id && (e.isPeriod || e.dioceses.contains(diocese)),
      );
  final fixture =
      jsonDecode(
            File(
              'test/fixtures/liturgical-catalog-occurrences.json',
            ).readAsStringSync().replaceFirst('\ufeff', ''),
          )
          as List;
  for (final raw in fixture) {
    final expected = Map<String, dynamic>.from(raw);
    for (final mode in ['hours', 'readings']) {
      test(
        'Web fixture ${expected['entryId']} ${expected['year']} ${expected['diocese']} $mode',
        () {
          final actual = calendarOccurrence(
            engine,
            entry(expected['entryId'], expected['diocese']),
            expected['year'],
            expected['diocese'],
            mode,
          );
          for (final field in expected.keys) {
            expect(
              field == 'originalDate'
                  ? actual.originalDate
                  : actual.toJson()[field],
              expected[field],
              reason: field,
            );
          }
        },
      );
    }
  }
  test('Nicholas is searchable without year, with own color and rule', () {
    final n = entry('sv-nicholas', 'minsk-mohilev');
    expect(n.color, 'albus');
    expect(n.dateLabel, '06.12');
    expect(n.matches('06.12.2026', 'fixed'), isTrue);
    expect(n.matches('Мікала', 'all'), isTrue);
    expect(n.matches('ўспамін', 'all'), isTrue);
    expect(n.matches('Мінска', 'all'), isTrue);
    expect(n.matches('', 'dynamic'), isFalse);
    expect(
      nearestCatalogYear(engine, n, 2026, 'minsk-mohilev', 'hours')!.year,
      2027,
    );
  });
  test(
    'named and last weekday are movable; diocesan suppress/add/modify preserved',
    () {
      final defs = OrdoDefinitions.fromDocuments(
        celebrations: [
          {
            'id': 'base',
            'title': 'Святы',
            'scope': 'universal',
            'rank': 'memoria',
            'color': 'albus',
            'dateRule': {'type': 'fixed', 'month': 12, 'day': 6},
          },
          {
            'id': 'named',
            'title': 'Свята',
            'scope': 'universal',
            'rank': 'festum',
            'dateRule': {'type': 'named', 'rule': 'ascension'},
          },
          {
            'id': 'last',
            'title': 'Апошняя нядзеля',
            'scope': 'universal',
            'rank': 'festum',
            'dateRule': {
              'type': 'last-weekday-of-month',
              'month': 10,
              'isoWeekday': 7,
            },
          },
        ],
        dioceseOverrides: [
          {
            'id': 'supp',
            'dioceseId': 'grodno',
            'celebrationId': 'base',
            'action': 'suppress',
          },
          {
            'id': 'mod',
            'dioceseId': 'vitebsk',
            'celebrationId': 'base',
            'action': 'modify',
            'rank': 'festum',
            'color': 'ruber',
          },
          {
            'id': 'add',
            'dioceseId': 'pinsk',
            'celebrationId': 'local',
            'action': 'add',
            'title': 'Мясцовае',
            'rank': 'memoria',
            'dateRule': {'type': 'fixed', 'month': 6, 'day': 1},
          },
        ],
      );
      final catalog = feastCatalog(defs, kDioceses);
      final base = catalog.where((e) => e.id == 'base').toList();
      expect(base.length, 2);
      expect(base.every((e) => !e.dioceses.contains('grodno')), isTrue);
      expect(
        base.singleWhere((e) => e.dioceses.contains('vitebsk')).rank,
        'festum',
      );
      expect(catalog.singleWhere((e) => e.id == 'local').dioceses, ['pinsk']);
      expect(
        catalog
            .where((e) => ['last', 'named'].contains(e.id))
            .every((e) => e.matches('', 'dynamic')),
        isTrue,
      );
      final occurrence = calendarOccurrence(
        OrdoEngine(defs),
        base.first,
        2026,
        'grodno',
        'hours',
      );
      expect(occurrence.status, 'not-applicable-in-diocese');
      expect(occurrence.canOpen, isFalse);
    },
  );
  test(
    'Grodno 2027 has its own impediment, never inherits Minsk permission',
    () {
      final n = entry('sv-nicholas', 'grodno');
      final day = engine.resolve('2027-12-06', diocese: 'grodno');
      expect(day.primary.id, 'grodno-cathedral-dedication');
      final o = calendarOccurrence(engine, n, 2027, 'grodno', 'hours');
      expect(o.status, 'suppressed/impeded');
      expect(o.canOpenHours, isFalse);
      expect(o.canOpenReadings, isFalse);
      expect(o.color, 'albus');
    },
  );
  test('catalog does not add any legal day alternatives', () {
    final before = engine
        .resolve('2026-12-06')
        .options
        .map((e) => e.id)
        .toList();
    feastCatalog(engine.definitions, kDioceses);
    for (final mode in ['hours', 'readings']) {
      calendarOccurrence(
        engine,
        entry('sv-nicholas', 'minsk-mohilev'),
        2026,
        'minsk-mohilev',
        mode,
      );
    }
    expect(engine.resolve('2026-12-06').options.map((e) => e.id), before);
    expect(before, isNot(contains('sv-nicholas')));
  });
  test(
    'all semantic periods exist and every permitted occurrence matches exactly',
    () {
      expect(periods.map((e) => e.id).toSet().length, periods.length);
      for (var w = 1; w <= 34; w++) {
        expect(periods.any((e) => e.id == 'period:ordinary-w$w-d7'), isTrue);
      }
      for (var d = 17; d <= 24; d++) {
        expect(periods.any((e) => e.id == 'period:advent-$d-12'), isTrue);
      }
      for (final id in [
        'period:christmas-25-12',
        'period:christmas-13-01',
        'period:easter-w8-d1',
        'period:lent-w0-d4',
        'period:holyweek-w1-d5',
      ]) {
        expect(periods.any((e) => e.id == id), isTrue);
      }
      for (final e in periods) {
        final o = calendarOccurrence(engine, e, 2026, 'minsk-mohilev', 'hours');
        if (o.effectiveDate != null) {
          expect(
            periodMatchesDay(e, engine.resolve(o.effectiveDate!)),
            isTrue,
            reason: e.id,
          );
        }
        if (o.canOpen) {
          expect(
            engine
                .resolve(o.effectiveDate!)
                .officeOptions
                .any((v) => v.id == o.optionId),
            isTrue,
            reason: e.id,
          );
        }
      }
    },
  );
  test('split day gates Hours and Readings separately', () {
    final all = entry('all-faithful-departed', 'minsk-mohilev');
    final result = calendarOccurrence(
      engine,
      all,
      2025,
      'minsk-mohilev',
      'readings',
    );
    expect(result.canOpenReadings, isTrue);
    expect(result.canOpenHours, isFalse);
  });
  final collections = {
    for (final name in [
      'days',
      'liturgicalProperTexts',
      'liturgicalTemplates',
      'readings',
    ])
      name: bundledCollection(name),
  };
  ContentPreview preview(CatalogEntry e) => loadCatalogPreview(
    e,
    diocese: 'minsk-mohilev',
    document: (c, id) => collections[c]?[id],
    documents: (c) =>
        collections[c]?.entries.map((d) => {...d.value, 'id': d.key}) ?? [],
  );
  test(
    'Nicholas actual proper/common sources are independent of suppression',
    () {
      final n = preview(entry('sv-nicholas', 'minsk-mohilev'));
      expect(n.errors, isEmpty);
      expect(n.sources.any((s) => s.id == '06-12-sv-nicholas'), isTrue);
      expect(n.sources.any((s) => s.id == 'pastors'), isTrue);
      expect(n.hasHours, isTrue);
      expect(n.sources.any((s) => s.id.contains('advent-w2')), isFalse);
    },
  );
  test(
    'missing sources never substitute a Sunday; references are not prose',
    () {
      final e = CatalogEntry({
        'id': 'missing',
        'kind': 'feast',
        'title': 'Няма',
        'daysRef': {
          'dayIds': ['absent'],
        },
        'templates': ['pastors'],
      });
      final p = loadCatalogPreview(
        e,
        diocese: 'grodno',
        document: (c, id) => id == 'pastors'
            ? {
                'id': id,
                'laudesPr': 'from-day',
                'vesperPr': '[from-first-week]',
              }
            : null,
        documents: (_) => [],
      );
      expect(p.hasContent, isFalse);
      expect(p.missing, contains('absent'));
      expect(p.sources.single.fields, isEmpty);
    },
  );

  test('source errors are unavailable, not confirmed no-content', () {
    final result = loadCatalogPreview(
      CatalogEntry({
        'id': 'missing',
        'title': 'Крыніца',
        'daysRef': {'id': 'missing'},
      }),
      diocese: 'pinsk',
      document: (_, _) => throw StateError('offline'),
      documents: (_) => [],
    );
    expect(result.status, 'unavailable');
    expect(result.errors, isNotEmpty);
  });
  test(
    'seasonal Common deltas preserve omissions and field-rule instructions',
    () {
      final e = CatalogEntry({
        'id': 'source',
        'title': 'Тэксты',
        'templates': ['pastors'],
      });
      final result = loadCatalogPreview(
        e,
        diocese: 'pinsk',
        document: (_, _) => {
          'id': 'pastors',
          'laudesHymn': 'Асноўны гімн',
          'vesperPr': 'Асноўная малітва',
          '_fieldRules': {
            'laudesHymn': {'source': 'current-day'},
          },
          '_seasonalVariants': {
            'lent': {
              'laudesHymn': 'Посны гімн',
              'vesperPr': null,
              'laudesPr': {
                'rule': {'source': 'proper'},
              },
            },
          },
        },
        documents: (_) => [],
      );
      final lent = result.sources.singleWhere((s) => s.id == 'pastors:lent');
      expect(lent.fields['laudesHymn'], 'Посны гімн');
      expect(lent.fields.containsKey('vesperPr'), isFalse);
      expect(lent.fields.containsKey('laudesPr'), isFalse);
      expect(lent.instructions.any((s) => s.contains('З бягучага')), isFalse);
      expect(lent.instructions.any((s) => s.contains('З уласных')), isTrue);
    },
  );
  test('reading preview retains I/II cycles and excludes another period', () {
    final e = periods.singleWhere((e) => e.id == 'period:ordinary-w34-d2');
    final result = loadCatalogPreview(
      e,
      diocese: 'pinsk',
      document: (_, _) => null,
      documents: (collection) => collection == 'readings'
          ? [
              for (final cycle in ['1', '2'])
                {
                  'id': 'ordinary-34-2--$cycle',
                  'year': cycle,
                  '_periodType': 'ordinary',
                  '_periodWeekNumber': 34,
                  '_dayOfWeek': 2,
                  'reading': {'text': 'Чытанне цыкла $cycle'},
                },
              {
                'id': 'wrong',
                '_periodType': 'lent',
                '_periodWeekNumber': 34,
                '_dayOfWeek': 2,
                'reading': {'text': 'Чужое чытанне'},
              },
            ]
          : [],
    );
    expect(result.readings.map((r) => r.year), ['1', '2']);
  });
  test('a source for another saint on the same date is not a substitute', () {
    final e = CatalogEntry({
      'id': 'one',
      'title': 'Святы Першы',
      'daysRef': {
        'dayIds': ['one'],
      },
      'readingsRef': {'_date': '06.12'},
    });
    final result = loadCatalogPreview(
      e,
      diocese: 'pinsk',
      document: (_, _) => null,
      documents: (_) => [
        {
          'id': 'two',
          'title': 'Іншае святкаванне',
          '_date': '06.12',
          '_dayIds': ['two'],
          'reading': {'text': 'Чужы тэкст'},
        },
      ],
    );
    expect(result.readings, isEmpty);
    expect(result.status, 'no-content');
  });

  group('actual store and screens', () {
    late Directory temp;
    setUpAll(() async {
      temp = await Directory.systemTemp.createTemp('catalog-');
      await HiveService.init(path: temp.path, loadBundle: true);
      await ContentStore.instance.ensureLoaded(kContentCollections);
    });
    tearDownAll(() async {
      await Hive.close();
      await temp.delete(recursive: true);
    });
    for (final width in [320.0, 390.0]) {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        testWidgets(
          'yearless search / preview / blocked calendar $width $brightness at 200%',
          (tester) async {
            tester.view.physicalSize = Size(width, 900);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            await tester.pumpWidget(
              ProviderScope(
                child: MaterialApp(
                  theme: ThemeData(brightness: brightness),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: const TextScaler.linear(2)),
                    child: child!,
                  ),
                  home: const Scaffold(body: LiturgicalPickerScreen()),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(find.byKey(const Key('picker-year')), findsNothing);
            await tester.tap(find.text('Па свяце'));
            await tester.pumpAndSettle();
            await tester.enterText(
              find.byKey(const Key('picker-feast-search')),
              'Мікалая',
            );
            await tester.pumpAndSettle();
            tester.testTextInput.hide();
            await tester.pumpAndSettle();
            await tapCatalog(
              tester,
              find.byKey(const Key('picker-entry-sv-nicholas')),
            );
            expect(find.byKey(const Key('picker-year')), findsNothing);
            await tapCatalog(tester, find.byKey(const Key('catalog-preview')));
            expect(find.byType(CatalogSourceScreen), findsOneWidget);
            await tapCatalog(
              tester,
              find.text('liturgicalProperTexts/06-12-sv-nicholas'),
            );
            expect(
              find.text('liturgicalProperTexts/06-12-sv-nicholas'),
              findsOneWidget,
            );
            await tester.pageBack();
            await tester.pumpAndSettle();
            await tapCatalog(tester, find.byKey(const Key('catalog-calendar')));
            final state = tester.state(find.byType(CatalogEntryScreen));
            expect(state.mounted, isTrue);
            await tapCatalog(
              tester,
              find.byKey(const Key('catalog-open-occurrence')),
            );
            final button = tester.widget<FilledButton>(
              find.byKey(const Key('catalog-open-occurrence')),
            );
            if (DateTime.now().year == 2026) {
              expect(button.onPressed, isNull);
            }
            expect(tester.takeException(), isNull);
            await tester.pageBack();
            await tester.pumpAndSettle();
            expect(
              find.byKey(const Key('picker-entry-sv-nicholas')),
              findsOneWidget,
            );
            expect(
              tester
                      .widget<TextField>(
                        find.byKey(const Key('picker-feast-search')),
                      )
                      .controller
                      ?.text ??
                  'Мікалая',
              'Мікалая',
            );
          },
        );
      }
    }
  });
}

Future<void> tapCatalog(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    final scrollable = find
        .byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        )
        .last;
    await tester.scrollUntilVisible(target, 200, scrollable: scrollable);
  }
  await Scrollable.ensureVisible(tester.element(target), alignment: 0.5);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}
