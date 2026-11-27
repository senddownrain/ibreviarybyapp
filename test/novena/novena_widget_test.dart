import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/analytics/route_mapper.dart';
import 'package:mybrev_flutter/dev/novena_harness.dart';
import 'package:mybrev_flutter/models/priest_access_content.dart';
import 'package:mybrev_flutter/novena/novena_store.dart';
import 'package:mybrev_flutter/novena/ui/novena_routes.dart';
import 'package:mybrev_flutter/screens/prayer_detail_screen.dart';

import 'support.dart';

const _joseph = 'cn_05b28c5bea797880';

void main() {
  late PrayerAccessContent content;
  late List<Map> definitions;
  late MemoryNovenaBox box;
  var today = DateTime(2027, 3, 10);

  setUpAll(() {
    content = PrayerAccessContent(
      bundledDocs('prayers'),
      bundledDocs('prayerCategories'),
    ).publicOnly;
    definitions = [
      for (final item in readyDefinitions()) NovenaHarness.published(item),
    ];
  });

  setUp(() {
    box = MemoryNovenaBox();
    today = DateTime(2027, 3, 10);
  });

  Future<NovenaHarnessState> pump(
    WidgetTester tester, {
    String location = '/prayers/prayer/$_joseph',
    List<Map>? documents,
    PrayerAccessContent? prayers,
    double scale = 1,
    String scheme = 'light',
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      NovenaHarness(
        key: UniqueKey(),
        content: prayers ?? content,
        definitions: documents ?? definitions,
        box: box,
        clock: () => today,
        initialLocation: location,
        scale: scale,
        scheme: scheme,
      ),
    );
    await tester.pumpAndSettle();
    return tester.state<NovenaHarnessState>(find.byType(NovenaHarness));
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    // Mid-screen: the floating reader chrome covers the very top.
    await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// A day of the strip on the day page (the page underneath has one too).
  Finder dayDot(int day) => find.descendant(
    of: find.byKey(const Key('novena-day-reader')),
    matching: find.byKey(Key('novena-day-$day'), skipOffstage: false),
    skipOffstage: false,
  );

  const badge = Key('novena-badge');
  const start = Key('novena-start');
  const pray = Key('novena-pray');
  const mark = Key('novena-mark');

  testWidgets('start, pray, mark, undo, restart of the app', (tester) async {
    final app = await pump(tester);
    expect(find.byKey(badge), findsNothing);
    expect(find.text('9 дзён малітвы'), findsOneWidget);
    await tap(tester, find.byKey(start, skipOffstage: false));
    expect(find.text('Дзень 1 з 9'), findsOneWidget);
    expect(find.text('Засталося 9 дзён'), findsOneWidget);
    expect(find.byKey(start), findsNothing);
    expect(find.byKey(badge), findsOneWidget);
    // The ordinary prayer stays below the tracker.
    expect(find.textContaining('Парадак навэнны'), findsWidgets);

    await tap(tester, find.byKey(pray, skipOffstage: false));
    // Neither id is part of the address.
    final uri = app.router.routerDelegate.currentConfiguration;
    expect(uri.last.matchedLocation, novenaDayLocation);
    expect(find.text('10 сакавіка · Дзень 1 з 9'), findsOneWidget);
    expect(find.textContaining('Першы дзень'), findsOneWidget);
    // Reading marks nothing.
    expect(find.text('Завершана 0 з 9 дзён'), findsOneWidget);
    await tap(tester, find.byKey(mark, skipOffstage: false));
    expect(find.text('Завершана 1 з 9 дзён'), findsOneWidget);
    await tap(tester, find.byKey(const Key('novena-unmark')));
    expect(find.text('Завершана 0 з 9 дзён'), findsOneWidget);
    await tap(tester, find.byKey(mark, skipOffstage: false));

    // A future day is only readable.
    await tap(tester, dayDot(2));
    expect(find.byKey(const Key('novena-future-day')), findsOneWidget);
    expect(find.byKey(mark), findsNothing);

    // The app starts again, without definitions: the snapshot is enough.
    await pump(tester, documents: const []);
    expect(find.text('Дзень 1 з 9'), findsOneWidget);
    expect(find.text('Завершана 1 з 9 дзён'), findsOneWidget);
    expect(find.byKey(badge), findsNothing);
    await tap(tester, find.byKey(pray, skipOffstage: false));
    expect(find.textContaining('Першы дзень'), findsOneWidget);
  });

  testWidgets('the date changes in the foreground and on resume', (
    tester,
  ) async {
    await pump(tester);
    await tap(tester, find.byKey(start, skipOffstage: false));
    today = DateTime(2027, 3, 11, 9);
    await tester.pump(const Duration(minutes: 16));
    await tester.pumpAndSettle();
    expect(find.text('Дзень 2 з 9'), findsOneWidget);

    today = DateTime(2027, 3, 25, 9);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Дні навэнны мінулі'), findsOneWidget);
    expect(find.text('Працягнуць навэнну'), findsOneWidget);
    expect(find.text('Навэнна завершана'), findsNothing);
    expect(find.byKey(badge), findsOneWidget);
  });

  testWidgets('menu, list of several novenas, stop with confirmation', (
    tester,
  ) async {
    await pump(tester, location: '/prayers');
    await tester.tap(find.byTooltip('Меню'));
    await tester.pumpAndSettle();
    expect(find.text('Мае навэнны'), findsNothing);
    await tester.tapAt(const Offset(5, 800));
    await tester.pumpAndSettle();

    for (final id in [_joseph, 'Iiufha8NyLABTw92rA5S']) {
      final app = await pump(tester);
      app.router.go('/prayers/prayer/$id');
      await tester.pumpAndSettle();
      if (find.byKey(start).evaluate().isNotEmpty) {
        await tap(tester, find.byKey(start, skipOffstage: false));
      }
    }
    await pump(tester, location: '/prayers');
    expect(
      find.descendant(of: find.byKey(badge), matching: find.text('2')),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Меню'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Мае навэнны'));
    await tester.pumpAndSettle();
    expect(find.text('АКТЫЎНЫЯ'), findsOneWidget);
    expect(find.byKey(pray), findsNWidgets(2));

    await tap(tester, find.byKey(const Key('novena-session-menu')).first);
    await tester.tap(find.text('Спыніць навэнну'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('novena-confirm')));
    await tester.pumpAndSettle();
    expect(find.byKey(pray), findsOneWidget);

    await tap(tester, find.byKey(const Key('novena-start-new')));
    await tester.scrollUntilVisible(
      find.text('Навэнна да святога Казіміра'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Навэнна да святога Казіміра'), findsOneWidget);
  });

  testWidgets('a finished novena is history and can be started again', (
    tester,
  ) async {
    await pump(tester);
    await tap(tester, find.byKey(start, skipOffstage: false));
    today = DateTime(2027, 3, 18);
    await pump(tester);
    await tap(tester, find.byKey(pray, skipOffstage: false));
    for (var day = 1; day <= 9; day++) {
      await tap(tester, dayDot(day));
      await tap(tester, find.byKey(mark, skipOffstage: false));
    }
    expect(find.text('Навэнна завершана'), findsOneWidget);

    await pump(tester);
    expect(find.byKey(start), findsOneWidget);
    await tap(tester, find.text('Гісторыя навэнн'));
    expect(find.text('ЗАВЕРШАНЫЯ'), findsOneWidget);
    expect(find.text('10 сакавіка – 18 сакавіка'), findsOneWidget);
  });

  testWidgets('suggestion only on the start date; «Не цяпер» and the switch', (
    tester,
  ) async {
    const card = Key('novena-suggestion');
    today = DateTime(2027, 3, 11);
    await pump(tester, location: '/prayers');
    // Not afterwards.
    expect(find.byKey(card), findsNothing);

    today = DateTime(2027, 3, 10);
    await pump(tester, location: '/prayers');
    expect(find.byKey(card), findsOneWidget);
    expect(find.text('Навэнна да святога Юзафа'), findsOneWidget);
    await tap(tester, find.byKey(const Key('novena-suggestion-dismiss')));
    expect(find.byKey(card), findsNothing);
    await pump(tester, location: '/prayers');
    expect(find.byKey(card), findsNothing);

    // The next year it returns; switched off it does not.
    today = DateTime(2028, 3, 10);
    await pump(tester, location: '/prayers');
    expect(find.byKey(card), findsOneWidget);
    await pump(tester, location: novenasLocation);
    await tap(tester, find.byKey(const Key('novena-suggestions-switch')));
    await pump(tester, location: '/prayers');
    expect(find.byKey(card), findsNothing);
  });

  testWidgets('several suggestions share one card; start from it', (
    tester,
  ) async {
    today = DateTime(2027, 10, 24);
    await pump(
      tester,
      location: '/prayers',
      documents: [
        for (final item in definitions)
          if (item['novenaId'] == _joseph ||
              item['novenaId'] == 'Iiufha8NyLABTw92rA5S')
            {
              ...item,
              'schedule': {
                'enabled': true,
                'type': 'manual',
                'extraDates': ['2027-10-24'],
              },
            },
      ],
    );
    expect(find.byKey(const Key('novena-suggestion')), findsOneWidget);
    expect(find.text('Распачаць навэнну'), findsNWidgets(2));
    await tap(tester, find.text('Распачаць навэнну').first);
    expect(find.byType(PrayerDetailScreen), findsOneWidget);
    expect(find.text('Дзень 1 з 9'), findsOneWidget);
  });

  testWidgets('compact mode folds prayers and keeps them in order', (
    tester,
  ) async {
    await pump(tester);
    await tap(tester, find.byKey(start, skipOffstage: false));
    await tap(tester, find.byKey(pray, skipOffstage: false));
    final linked =
        content.prayers[(definitions.firstWhere(
                  (d) => d['novenaId'] == _joseph,
                )['template']
                as List)
            .last['prayerId']]!;
    final title = linked['title'] as String;
    await tap(tester, find.text('Кампактны'));
    expect(find.widgetWithText(ListTile, title), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    await tap(tester, find.widgetWithText(ListTile, title));
    expect(find.byIcon(Icons.remove_rounded), findsOneWidget);
    await tap(tester, find.text('Поўны', skipOffstage: false));
    expect(find.widgetWithText(ListTile, title), findsNothing);
  });

  testWidgets('a withdrawn prayer is not shown from the snapshot', (
    tester,
  ) async {
    await pump(tester);
    await tap(tester, find.byKey(start, skipOffstage: false));
    final linked =
        (definitions.firstWhere((d) => d['novenaId'] == _joseph)['template']
                as List)
            .last['prayerId'];
    final closed = PrayerAccessContent(
      {...content.prayers}..remove(linked),
      content.categories,
    );
    await pump(tester, prayers: closed);
    await tap(tester, find.byKey(pray, skipOffstage: false));
    expect(
      find.textContaining('цяпер недаступны', skipOffstage: false),
      findsOneWidget,
    );

    // The novena itself withdrawn: nothing of it is shown.
    await pump(
      tester,
      prayers: PrayerAccessContent(
        {...content.prayers}..remove(_joseph),
        content.categories,
      ),
      location: novenasLocation,
    );
    await tap(tester, find.byKey(pray, skipOffstage: false));
    expect(find.textContaining('Першы дзень'), findsNothing);
  });

  testWidgets('no tracker for drafts or ordinary prayers', (tester) async {
    await pump(
      tester,
      documents: [
        {
          ...definitions.firstWhere((d) => d['novenaId'] == _joseph),
          'status': 'draft',
        },
      ],
    );
    expect(find.byKey(const Key('novena-panel')), findsNothing);
  });

  testWidgets('narrow screen, large text and dark theme do not overflow', (
    tester,
  ) async {
    await pump(tester, scale: 2, scheme: 'dark', size: const Size(320, 640));
    await tap(tester, find.byKey(start, skipOffstage: false));
    await tap(tester, find.byKey(pray, skipOffstage: false));
    await tap(tester, find.byKey(mark, skipOffstage: false));
    await pump(
      tester,
      scale: 2,
      scheme: 'marian',
      size: const Size(320, 640),
      location: novenasLocation,
    );
    today = DateTime(2027, 10, 24);
    await pump(
      tester,
      scale: 2,
      size: const Size(320, 640),
      location: '/prayers',
    );
    expect(tester.takeException(), isNull);
  });

  test('novena pages are not measured', () {
    for (final location in [novenasLocation, novenaDayLocation]) {
      expect(mapLocation(Uri.parse(location), massOrderPrayerId: 'x'), isNull);
    }
  });
}
