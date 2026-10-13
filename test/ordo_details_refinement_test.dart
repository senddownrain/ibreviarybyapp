import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/content/content_store.dart';
import 'package:mybrev_flutter/providers/diocese_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/screens/ordo_screen.dart';
import 'package:mybrev_flutter/services/hive_service.dart';

class _Dioceses extends DioceseSelectionNotifier {
  @override
  DioceseSelection build() => const DioceseSelection(
    primary: 'minsk-mohilev',
    selected: ['minsk-mohilev', 'grodno'],
  );
}

class _NotesBundle extends CachingAssetBundle {
  final release = Completer<void>();
  @override
  Future<ByteData> load(String key) async {
    if (key.contains('liturgicalOrdoNotes.json')) await release.future;
    return rootBundle.load(key);
  }
}

void main() {
  late Directory directory;
  final bundle = _NotesBundle();
  setUpAll(() async {
    await initializeDateFormatting('be');
    directory = await Directory.systemTemp.createTemp('ordo-details-');
    await HiveService.init(
      path: directory.path,
      loadBundle: true,
      bundle: bundle,
    );
    await ContentStore.instance.ensureLoaded(kLiturgicalCollections);
  });
  tearDownAll(() async {
    if (!bundle.release.isCompleted) bundle.release.complete();
    await ContentStore.instance.ensureLoaded(kOrdoNotesCollections);
    await Hive.close();
    await directory.delete(recursive: true);
  });

  Future<void> start(
    WidgetTester tester, {
    Future<void>? notes,
    bool error = false,
    double scale = 1,
    DateTime? date,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          dioceseSelectionProvider.overrideWith(_Dioceses.new),
          liturgicalContentReadyProvider.overrideWith((ref) async {}),
          ordoNotesReadyProvider.overrideWith((ref) async {
            if (error) throw StateError('Notes unavailable');
            await notes;
          }),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: OrdoScreen(initialDate: date ?? DateTime(2026, 4, 4)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> open(
    WidgetTester tester,
    String id,
    String label, {
    String date = '2026-04-04',
  }) async {
    final tile = find.byKey(PageStorageKey('ordo-$id-$date'));
    final title = find.descendant(of: tile, matching: find.text(label)).first;
    await Scrollable.ensureVisible(tester.element(title), alignment: .2);
    await tester.pumpAndSettle();
    await tester.tap(title);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'lazy notes show loading while the day and directions stay usable',
    (tester) async {
      final pending = Completer<void>();
      await start(tester, notes: pending.future);
      expect(find.text('4 красавіка 2026'), findsOneWidget);
      await open(tester, 'notes', 'Літургічныя заўвагі');
      expect(find.text('Заўвагі адкрываюцца…'), findsOneWidget);
      await open(tester, 'directions', 'Асаблівыя ўказанні');
      expect(find.text('Камплета'), findsOneWidget);
      expect(find.text('Te Deum'), findsOneWidget);
      expect(find.text('Не спяваецца'), findsOneWidget);
      expect(tester.takeException(), isNull);
      pending.complete();
      await tester.pumpAndSettle();
    },
  );

  testWidgets('failed notes retain the primary day and an explicit status', (
    tester,
  ) async {
    await start(tester, error: true);
    await open(tester, 'notes', 'Літургічныя заўвагі');
    expect(
      find.textContaining('Не ўдалося прачытаць літургічныя заўвагі'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('ordo-open-hours')), findsOneWidget);
    expect(find.text('4 красавіка 2026'), findsOneWidget);
    expect(find.text('Заўвагі адкрываюцца…'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'one parent hairline survives closed, one, two and all expanded sections at 200 percent',
    (tester) async {
      bundle.release.complete();
      await tester.runAsync(
        () => ContentStore.instance.ensureLoaded(kOrdoNotesCollections),
      );
      await start(tester, scale: 2, date: DateTime(2026, 10, 11));
      final dividers = find
          .byType(Divider, skipOffstage: false)
          .evaluate()
          .length;
      expect(dividers, greaterThanOrEqualTo(4));
      for (final (id, label) in const [
        ('office', 'Літургія гадзінаў'),
        ('directions', 'Асаблівыя ўказанні'),
        ('notes', 'Літургічныя заўвагі'),
        ('books', 'Літургічныя кнігі'),
      ]) {
        await open(tester, id, label, date: '2026-10-11');
        expect(
          find.byType(Divider, skipOffstage: false).evaluate().length,
          dividers,
        );
        for (final tile in tester.widgetList<ExpansionTile>(
          find.byType(ExpansionTile, skipOffstage: false),
        )) {
          expect(tile.shape, const Border());
          expect(tile.collapsedShape, const Border());
        }
        expect(tester.takeException(), isNull);
      }
      expect(find.byKey(const Key('ordo-office-options')), findsNothing);
      expect(find.text('Том III'), findsWidgets);
      await open(tester, 'notes', 'Літургічныя заўвагі', date: '2026-10-11');
      await open(tester, 'notes', 'Літургічныя заўвагі', date: '2026-10-11');
      expect(
        find.byType(Divider, skipOffstage: false).evaluate().length,
        dividers,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'diocesan note variants, sources and long paragraphs survive grouping',
    (tester) async {
      final collection = ContentStore.instance.collection(
        'liturgicalOrdoNotes',
      );
      final longText = List.filled(
        35,
        'Доўгая заўвага пра малітву і набажэнствы.',
      ).join(' ');
      final documents = <String, Map<String, dynamic>>{
        for (final key in collection.keys)
          key: Map<String, dynamic>.from(collection.get(key) as Map),
        'ux-variants': {
          'category': 'devotion',
          'text': 'Заўвага Мінска',
          'selector': {'type': 'exact-date', 'date': '2026-04-04'},
          'variants': [
            {'diocese': 'minsk-mohilev', 'text': 'Заўвага Мінска'},
            {'diocese': 'grodno', 'text': 'Заўвага Гродна'},
          ],
          'observed': [
            {
              'diocese': 'minsk-mohilev',
              'dates': ['2026-04-04'],
            },
            {
              'diocese': 'grodno',
              'dates': ['2026-04-04'],
            },
          ],
        },
        'ux-long': {
          'category': 'blessing',
          'text': longText,
          'source': 'Крыніца тэставай заўвагі',
          'scope': {'level': 'diocese', 'dioceseId': 'grodno'},
          'selector': {'type': 'exact-date', 'date': '2026-04-04'},
        },
        'ux-empty': {
          'category': 'announcement',
          'text': '',
          'selector': {'type': 'exact-date', 'date': '2026-04-04'},
        },
      };
      await tester.runAsync(
        () => collection.applyUpdate(documents, {
          for (final entry in documents.entries)
            entry.key: documentHash(entry.value),
        }, DateTime(2030).millisecondsSinceEpoch),
      );
      await start(tester, scale: 2);
      await open(tester, 'notes', 'Літургічныя заўвагі');
      expect(find.text('Заўвага Мінска'), findsOneWidget);
      expect(find.text('Заўвага Гродна'), findsOneWidget);
      expect(find.text('Крыніца: Мінск · 2026'), findsOneWidget);
      expect(find.text('Крыніца: Гродна · 2026'), findsOneWidget);
      expect(find.text(longText), findsOneWidget);
      expect(find.text('Крыніца: Крыніца тэставай заўвагі'), findsOneWidget);
      expect(find.text('Аб’явы'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
