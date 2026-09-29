import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:mybrev_flutter/models/mass_ritual.dart';
import 'package:mybrev_flutter/navigation/app_navigation.dart';
import 'package:mybrev_flutter/providers/data_bootstrap_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_navigation_sync_provider.dart';
import 'package:mybrev_flutter/models/prayer.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/providers/local_prayers_provider.dart';
import 'package:mybrev_flutter/providers/mass_ritual_provider.dart';
import 'package:mybrev_flutter/providers/prayers_provider.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/router/router.dart'
    show massReaderRoute, prayerDetailDescriptorFor;
import 'package:mybrev_flutter/screens/prayer_detail_screen.dart';
import 'package:mybrev_flutter/widgets/app_shell.dart';
import 'package:mybrev_flutter/widgets/reader/reader_scaffold.dart';

const _massId = 'eMmCtxwyJ75ogmL5rwye';
const _latinId = 'zdro66KYVuQ9p2KbqizD';

String _long(String label) =>
    List.generate(14, (i) => '$label $i.').join('\n\n');

final _belarusian = Prayer(
  id: _massId,
  title: 'Парадак святой Імшы',
  textFormat: 'mybrev-markdown',
  body:
      '### Уступныя абрады\n\n${_long('Уступ')}\n\n'
      '### Літургія слова\n\n${_long('Слова')}\n\n'
      '**Вызнанне веры**\n\n${_long('Вера')}\n\n'
      '### Эўхарыстычная літургія\n\n${_long('Эўх')}\n\n'
      '### Абрад Камуніі\n\n${_long('Камунія')}\n\n'
      '### Абрад заканчэння\n\n${_long('Канец')}',
);

final _latin = Prayer(
  id: _latinId,
  title: 'Ordo Missae',
  textFormat: 'mybrev-markdown',
  body:
      ':::rubric\nВступительные обряды\n:::\n\n${_long('Intro')}\n\n'
      ':::rubric\nЛитургия Слова\n:::\n\n${_long('Verbum')}\n\n'
      ':::rubric\nИсповедание веры\n:::\n\n${_long('Credo')}\n\n'
      ':::rubric\nЕвхаристическая Литургия\n:::\n\n${_long('Euch')}\n\n'
      ':::rubric\nОбряд причащения\n:::\n\n${_long('Communio')}\n\n'
      ':::rubric\nЗаключительный обряд\n:::\n\n${_long('Finis')}',
);

final _englishBundled =
    '## The Introductory Rites\n\n${_long('Intro')}\n\n'
    '## The Liturgy of the Word\n\n${_long('Word')}\n\n'
    '### Gospel\n\nThe Gospel of the Lord.\n**Praise to you, Lord Jesus Christ.**\n\n${_long('Gospel')}\n\n'
    '### The Creed\n\n**I believe in one God,**\n\n${_long('Creed')}\n\n'
    '## The Liturgy of the Eucharist\n\n${_long('Eucharist')}\n\n'
    '## The Communion Rite\n\n${_long('Communion')}\n\n'
    '## The Concluding Rites\n\n${_long('End')}';

Widget _app(
  Widget child, {
  List<Prayer>? prayers,
  TargetPlatform platform = TargetPlatform.android,
}) => ProviderScope(
  overrides: [
    settingsProvider.overrideWith(_TestSettingsNotifier.new),
    liturgicalSeasonColorProvider.overrideWithValue(Colors.indigo),
    allPrayersProvider.overrideWithValue(prayers ?? [_belarusian, _latin]),
    localPrayersProvider.overrideWith(_TestLocalPrayersNotifier.new),
    massBundledTextProvider.overrideWith((ref, asset) async => _englishBundled),
  ],
  child: MaterialApp(
    theme: ThemeData(platform: platform),
    home: child,
  ),
);

Future<void> _openSheetAndPick(WidgetTester tester, String sectionId) async {
  await tester.tap(find.byKey(const Key('mass-section-selector')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('mass-section-$sectionId')));
  await tester.pumpAndSettle();
}

/// The compact «n/5» indicator of the Mass controls.
String _position(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('mass-section-position'))).data!;

/// Ids highlighted in the sections sheet (the sheet is closed afterwards).
Future<Set<String>> _highlighted(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('mass-section-selector')));
  await tester.pumpAndSettle();
  final selected = {
    for (final tile in tester.widgetList<ListTile>(
      find.descendant(
        of: find.byKey(const Key('mass-sections-sheet')),
        matching: find.byType(ListTile),
      ),
    ))
      if (tile.selected)
        (tile.key! as ValueKey<String>).value.replaceFirst('mass-section-', ''),
  };
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
  return selected;
}

bool _onScreen(WidgetTester tester, Finder finder) {
  final top = tester.getTopLeft(finder).dy;
  return top >= 0 &&
      top < tester.view.physicalSize.height / tester.view.devicePixelRatio;
}

void main() {
  testWidgets('Holy Mass opens in Belarusian with compact Mass controls', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const PrayerDetailScreen(prayerId: _massId)));
    await tester.pumpAndSettle();

    expect(find.text('Парадак святой Імшы'), findsOneWidget);
    final bar = find.byKey(const Key('mass-navigator-bar'));
    expect(bar, findsOneWidget);
    expect(
      find.descendant(of: bar, matching: find.text('Раздзелы')),
      findsOneWidget,
    );
    expect(_position(tester), '1/5');
    // The long section names are never squeezed into the bar.
    for (final major in kMassRitual.majorSections) {
      expect(
        find.descendant(of: bar, matching: find.text(major.title)),
        findsNothing,
      );
    }
    // One language selector only (bottom controls, not the top chrome).
    expect(find.byKey(const Key('mass-language-selector')), findsOneWidget);
  });

  testWidgets('sections sheet lists the five Belarusian sections and jumps', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const PrayerDetailScreen(prayerId: _massId, massLanguage: 'la')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('mass-section-selector')));
    await tester.pumpAndSettle();
    final sheet = find.byKey(const Key('mass-sections-sheet'));
    expect(sheet, findsOneWidget);
    for (final (id, title) in [
      ('introductory-rites', 'Уступныя абрады'),
      ('liturgy-of-the-word', 'Літургія слова'),
      ('eucharistic-liturgy', 'Эўхарыстычная літургія'),
      ('communion-rite', 'Абрад Камуніі'),
      ('concluding-rites', 'Заключныя абрады'),
    ]) {
      expect(
        find.descendant(
          of: find.byKey(ValueKey('mass-section-$id')),
          matching: find.text(title),
        ),
        findsOneWidget,
      );
    }
    // Subsections are nested only under the current section.
    expect(find.byKey(const ValueKey('mass-section-creed')), findsNothing);
    await tester.tap(
      find.byKey(const ValueKey('mass-section-liturgy-of-the-word')),
    );
    await tester.pumpAndSettle();
    expect(sheet, findsNothing);
    expect(_position(tester), '2/5');

    await _openSheetAndPick(tester, 'creed');
    expect(_position(tester), '2/5');
    expect(await _highlighted(tester), {'liturgy-of-the-word', 'creed'});
    expect(_onScreen(tester, find.text('Credo 0.')), isTrue);

    await _openSheetAndPick(tester, 'concluding-rites');
    expect(_position(tester), '5/5');
  });

  testWidgets('scrolling updates the current section', (tester) async {
    await tester.pumpWidget(_app(const PrayerDetailScreen(prayerId: _massId)));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -1900));
    await tester.pumpAndSettle();
    expect(_position(tester), '3/5');
    expect(await _highlighted(tester), {'eucharistic-liturgy'});
  });

  testWidgets('switching language keeps the semantic section', (tester) async {
    await tester.pumpWidget(
      _app(const PrayerDetailScreen(prayerId: _massId, massLanguage: 'la')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ordo Missae'), findsOneWidget);

    await _openSheetAndPick(tester, 'liturgy-of-the-word');
    await _openSheetAndPick(tester, 'creed');
    await tester.tap(find.byKey(const Key('mass-language-en')));
    await tester.pumpAndSettle();
    expect(_position(tester), '2/5');
    expect(await _highlighted(tester), {'liturgy-of-the-word', 'creed'});
    expect(_onScreen(tester, find.text('I believe in one God,')), isTrue);

    await _openSheetAndPick(tester, 'communion-rite');
    await tester.tap(find.byKey(const Key('mass-language-be')));
    await tester.pumpAndSettle();
    expect(_position(tester), '4/5');
    expect(_onScreen(tester, find.text('Камунія 0.')), isTrue);
  });

  testWidgets('missing section falls back to its parent', (tester) async {
    await tester.pumpWidget(
      _app(const PrayerDetailScreen(prayerId: _massId, massLanguage: 'en')),
    );
    await tester.pumpAndSettle();
    await _openSheetAndPick(tester, 'liturgy-of-the-word');
    await _openSheetAndPick(tester, 'gospel');
    expect(await _highlighted(tester), {'liturgy-of-the-word', 'gospel'});

    await tester.tap(find.byKey(const Key('mass-language-be')));
    await tester.pumpAndSettle();
    expect(_position(tester), '2/5');
    expect(await _highlighted(tester), {'liturgy-of-the-word'});
    expect(_onScreen(tester, find.text('Слова 0.')), isTrue);
  });

  testWidgets('legacy Latin prayer id opens the Mass reader in Latin', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const PrayerDetailScreen(prayerId: _latinId)));
    await tester.pumpAndSettle();
    expect(find.text('Ordo Missae'), findsOneWidget);
    expect(find.byKey(const Key('mass-navigator-bar')), findsOneWidget);
    expect(_position(tester), '1/5');
  });

  testWidgets('controls fit a narrow phone with large text', (tester) async {
    tester.view
      ..physicalSize = const Size(320 * 3, 640 * 3)
      ..devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      await tester.pumpWidget(
        _app(const PrayerDetailScreen(prayerId: _massId), platform: platform),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final bar = tester.getRect(find.byKey(const Key('mass-navigator-bar')));
      expect(bar.left, greaterThanOrEqualTo(0));
      expect(bar.right, lessThanOrEqualTo(320));
      await tester.tap(find.byKey(const Key('mass-section-selector')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('mass-section-eucharistic-liturgy')),
          matching: find.text('Эўхарыстычная літургія'),
        ),
        findsOneWidget,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('English works offline from the bundled asset', (tester) async {
    await tester.pumpWidget(
      _app(const PrayerDetailScreen(prayerId: _massId, massLanguage: 'en')),
    );
    await tester.pumpAndSettle();
    expect(find.text('The Order of Mass'), findsOneWidget);
    expect(find.byKey(const Key('mass-variant-source')), findsOneWidget);
  });

  testWidgets('system back closes the sections sheet before the reader', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const PrayerDetailScreen(prayerId: _massId)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mass-section-selector')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mass-sections-sheet')), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mass-sections-sheet')), findsNothing);
    expect(find.byKey(const Key('mass-navigator-bar')), findsOneWidget);
  });

  for (final (platform, key) in [
    (TargetPlatform.android, 'adaptive-chrome-ambient'),
    (TargetPlatform.iOS, 'adaptive-chrome-glass'),
  ]) {
    testWidgets('section bar uses the $platform chrome surface', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(const PrayerDetailScreen(prayerId: _massId), platform: platform),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const Key('mass-navigator-bar')),
          matching: find.byKey(Key(key)),
        ),
        findsOneWidget,
      );
    });
  }

  testWidgets('ordinary prayers keep the regular reader', (tester) async {
    await tester.pumpWidget(
      _app(
        const PrayerDetailScreen(prayerId: 'morning'),
        prayers: const [
          Prayer(id: 'morning', title: 'Ранішняя', body: '<p>Добры Божа</p>'),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mass-navigator-bar')), findsNothing);
  });

  test('Mass variant ids open the dedicated Mass reader route', () {
    expect(massReaderRoute.showsNavigationDock, isFalse);
    for (final variant in kMassRitual.variants) {
      expect(prayerDetailDescriptorFor(variant.prayerId), massReaderRoute);
    }
    final ordinary = prayerDetailDescriptorFor('morning');
    expect(ordinary.showsNavigationDock, isTrue);
    expect(ordinary.id, 'prayerbook.detail');
  });

  testWidgets('app dock is hidden in the Mass reader and restored on leave', (
    tester,
  ) async {
    final shellState = AppShellState(
      roots: [
        for (final branch in AppBranch.values)
          AppRouteDescriptor(
            id: branch.name,
            branch: branch,
            defaultChromeMode: ReaderChromeMode.full,
            topChromeOwner: TopChromeOwner.shell,
            isBranchRoot: true,
          ),
      ],
    );
    addTearDown(shellState.dispose);
    final insets = <String, double>{};
    Page<void> page(
      GoRouterState state,
      AppRouteDescriptor descriptor,
      String name,
    ) {
      final entry = AppRouteEntry(
        id: state.pageKey.value,
        descriptor: descriptor,
      );
      return MaterialPage<void>(
        key: state.pageKey,
        arguments: entry,
        child: AppRouteEntryAdapter(
          entry: entry,
          controller: shellState.branches[descriptor.branch]!,
          child: Builder(
            builder: (context) {
              insets[name] = MediaQuery.paddingOf(context).bottom;
              return Scaffold(body: Text(name));
            },
          ),
        ),
      );
    }

    final router = GoRouter(
      initialLocation: '/prayerbook',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => AppShell(
            navigationShell: shell,
            shellState: shellState,
            activeBranch: AppBranch.values[shell.currentIndex],
          ),
          branches: [
            for (final branch in AppBranch.values)
              StatefulShellBranch(
                observers: [BranchRouteObserver(shellState.branches[branch]!)],
                routes: [
                  GoRoute(
                    path: '/${branch.name}',
                    pageBuilder: (context, state) => page(
                      state,
                      shellState.branches[branch]!.rootDescriptor,
                      branch.name,
                    ),
                    routes: [
                      if (branch == AppBranch.prayerbook)
                        GoRoute(
                          path: 'prayer/:id',
                          pageBuilder: (context, state) => page(
                            state,
                            prayerDetailDescriptorFor(
                              state.pathParameters['id']!,
                            ),
                            state.pathParameters['id']!,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(_TestSettingsNotifier.new),
          dataBootstrapProvider.overrideWith(_IdleBootstrap.new),
          liturgicalSeasonColorProvider.overrideWithValue(Colors.indigo),
          liturgicalNavigationSyncProvider.overrideWith((ref) {}),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('app-dock-full')), findsOneWidget);
    expect(insets['prayerbook'], greaterThan(0));

    router.push('/prayerbook/prayer/$_massId');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('app-dock-hidden')), findsOneWidget);
    expect(find.byKey(const Key('app-dock-full')), findsNothing);
    // No space is reserved for the removed dock.
    expect(insets[_massId], 0);

    router.pop();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('app-dock-full')), findsOneWidget);

    router.push('/prayerbook/prayer/morning');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('app-dock-hidden')), findsNothing);
    expect(insets['morning'], greaterThan(0));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _TestSettingsNotifier extends SettingsNotifier {
  @override
  SettingsState build() => const SettingsState();

  @override
  Future<void> toggleFavorite(String id) async {}

  @override
  void rememberLastSection(String section) {}
}

class _IdleBootstrap extends DataBootstrapNotifier {
  @override
  DataBootstrapState build() => const DataBootstrapState(initialComplete: true);
}

class _TestLocalPrayersNotifier extends LocalPrayersNotifier {
  @override
  List<Prayer> build() => const [];
}
