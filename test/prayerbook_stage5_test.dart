import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_html/flutter_html.dart';

import 'package:mybrev_flutter/models/prayer.dart';
import 'package:mybrev_flutter/navigation/app_navigation.dart';
import 'package:mybrev_flutter/providers/local_prayers_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/providers/prayer_categories_provider.dart';
import 'package:mybrev_flutter/providers/prayers_provider.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/screens/my_prayers_screen.dart';
import 'package:mybrev_flutter/screens/prayer_detail_screen.dart';
import 'package:mybrev_flutter/screens/prayer_form_screen.dart';
import 'package:mybrev_flutter/screens/prayers_screen.dart';
import 'package:mybrev_flutter/widgets/reader/reader_scaffold.dart';

const _builtIn = [
  Prayer(
    id: 'morning',
    title: 'Ранішняя малітва',
    body: '<p>Добры Божа</p>',
    tags: ['ранішнія'],
  ),
  Prayer(
    id: 'evening',
    title: 'Вячэрняя малітва',
    body: '<p>Дзякуй Табе</p>',
    tags: ['вечар'],
  ),
];

const _local = Prayer(
  id: 'local_one',
  title: 'Мая малітва',
  body: 'Асабісты тэкст',
  tags: ['асабістае'],
  isLocal: true,
);

const _categories = [
  PrayerMenuCategory(
    id: 'global-morning',
    name: 'Ранішнія',
    tags: ['ранішнія'],
    isGlobal: true,
  ),
  PrayerMenuCategory(
    id: 'user-category',
    name: 'Мая катэгорыя',
    tags: ['асабістае'],
    isGlobal: false,
  ),
];

void main() {
  for (final sourceId in ['linked', 'eMmCtxwyJ75ogmL5rwye']) {
    testWidgets('prayer links navigate and return from $sourceId', (
      tester,
    ) async {
      final prayers = [
        Prayer(
          id: sourceId,
          title: 'Пачатак',
          textFormat: 'mybrev-markdown',
          body:
              'Уступ\n\n[Вечар](/prayer/evening)\n\n## Раздзел\n\n[Вечар](/prayer/evening)',
        ),
        _builtIn.last,
      ];
      final router = GoRouter(
        initialLocation: '/prayers/prayer/$sourceId',
        routes: [
          GoRoute(
            path: '/prayers/prayer/:id',
            builder: (context, state) =>
                PrayerDetailScreen(prayerId: state.pathParameters['id']!),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        _app(const SizedBox(), prayers: prayers, router: router),
      );
      await tester.pumpAndSettle();
      final html = tester.widgetList<Html>(find.byType(Html));
      expect(html.every((widget) => widget.onLinkTap != null), isTrue);
      await tester.tapAt(
        tester.getTopLeft(find.text('Вечар', findRichText: true).first) +
            const Offset(20, 10),
      );
      await tester.pumpAndSettle();
      expect(router.canPop(), isTrue);
      expect(find.text('Вячэрняя малітва'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('Пачатак'), findsOneWidget);
    });
  }
  testWidgets('My Prayers add button stays above the app dock', (tester) async {
    await tester.pumpWidget(
      _app(
        Scaffold(
          extendBody: true,
          body: const MyPrayersScreen(),
          bottomNavigationBar: const SizedBox(
            key: Key('test-app-dock'),
            height: 100,
          ),
        ),
      ),
    );
    await tester.pump();

    final button = tester.getRect(find.byType(FloatingActionButton));
    final dock = tester.getRect(find.byKey(const Key('test-app-dock')));

    expect(button.bottom, lessThan(dock.top));
  });

  test('category grouping uses tags and explicit persisted membership', () {
    const settings = SettingsState(
      prayerCategoryMap: {
        'evening': {'user-category'},
      },
    );
    final result = prayersForCategory(_builtIn, _categories.last, settings);
    expect(result.map((prayer) => prayer.id), ['evening']);
    expect(
      prayerBelongsToCategory(_builtIn.first, _categories.first, settings),
      isTrue,
    );
  });

  testWidgets('root order is Favorites, Holy Mass, Categories, All Prayers', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _app(
        const PrayersScreen(),
        settings: const SettingsState(
          favoriteIds: ['evening', 'morning'],
          userCategories: [
            UserCategory(
              id: 'user-category',
              name: 'Мая катэгорыя',
              tags: ['асабістае'],
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    final favoritesY = tester.getTopLeft(find.text('Абраныя')).dy;
    final massY = tester.getTopLeft(find.text('Святая Імша').first).dy;
    final categoriesY = tester.getTopLeft(find.text('Катэгорыі')).dy;
    final allY = tester.getTopLeft(find.text('Усе малітвы')).dy;
    expect(favoritesY, lessThan(massY));
    expect(massY, lessThan(categoriesY));
    expect(categoriesY, lessThan(allY));
    expect(find.byKey(const ValueKey('prayer-row-evening')), findsOneWidget);
    expect(find.byKey(const ValueKey('prayer-row-morning')), findsOneWidget);
    expect(find.text('Ранішнія'), findsOneWidget);
    expect(find.text('Мая катэгорыя'), findsOneWidget);
    expect(find.byKey(const Key('holy-mass-destination')), findsOneWidget);
  });

  testWidgets('empty favorites is compact and categories remain visible', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const Scaffold(body: PrayersScreen())));
    await tester.pump();

    expect(find.byKey(const Key('prayerbook-empty-favorites')), findsOneWidget);
    expect(find.text('Катэгорыі'), findsOneWidget);
    final emptySize = tester.getSize(
      find.byKey(const Key('prayerbook-empty-favorites')),
    );
    expect(emptySize.height, lessThan(80));
  });

  testWidgets('missing Holy Mass stays recognizable and offers sync', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const Scaffold(body: PrayersScreen())));
    await tester.pump();

    await tester.tap(find.byKey(const Key('holy-mass-destination')));
    await tester.pump();
    expect(find.text('Тэкст пакуль недаступны'), findsOneWidget);
    expect(find.text('Сінхранізацыя'), findsOneWidget);
  });

  testWidgets('favorite toggle is shared by catalog and root providers', (
    tester,
  ) async {
    final notifier = _TestSettingsNotifier();
    await tester.pumpWidget(
      _app(const _PrayerbookSwitchHost(), settingsOverride: notifier),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('favorite-morning')));
    await tester.pump();

    expect(notifier.current.favoriteIds, ['morning']);
    await tester.tap(find.byKey(const Key('switch-to-root')));
    await tester.pump();
    expect(find.byKey(const ValueKey('prayer-row-morning')), findsOneWidget);
  });

  testWidgets('All Prayers contains built-in and user prayers', (tester) async {
    await tester.pumpWidget(_app(const PrayerCatalogScreen()));
    await tester.pump();

    expect(find.byKey(const ValueKey('prayer-row-morning')), findsOneWidget);
    expect(find.byKey(const ValueKey('prayer-row-evening')), findsOneWidget);
    expect(find.byKey(const ValueKey('prayer-row-local_one')), findsOneWidget);
  });

  testWidgets('prayer catalog owns the contextual bottom slot', (tester) async {
    const descriptor = AppRouteDescriptor(
      id: 'prayer-list-test',
      branch: AppBranch.prayerbook,
      defaultChromeMode: ReaderChromeMode.full,
      topChromeOwner: TopChromeOwner.reader,
    );
    const entry = AppRouteEntry(
      id: 'prayer-list-entry',
      descriptor: descriptor,
    );
    final controller = BranchShellController(AppBranch.prayerbook, descriptor)
      ..activate(entry);

    await tester.pumpWidget(
      _app(
        AppRouteEntryScope(
          entry: entry,
          controller: controller,
          child: const PrayerCatalogScreen(),
        ),
      ),
    );
    await tester.pump();
    expect(controller.navigationDockSuppressed, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(controller.navigationDockSuppressed, isFalse);
    controller.dispose();
  });

  testWidgets('search and filter use reported system navigation inset', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const PrayerCatalogScreen()));
    await tester.pump();
    final screenHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;

    final searchDock = tester.getRect(
      find.byKey(const Key('prayer-search-dock')),
    );
    expect(screenHeight - searchDock.bottom, closeTo(14, 0.01));

    await tester.tap(find.byKey(const Key('prayer-filter-action')));
    await tester.pumpAndSettle();
    final doneButton = tester.getRect(find.text('Гатова'));
    expect(doneButton.bottom, lessThanOrEqualTo(screenHeight - 24));
  });

  testWidgets('search focuses, filters title/body, and keeps query state', (
    tester,
  ) async {
    final notifier = _TestSettingsNotifier();
    await tester.pumpWidget(
      _app(
        const PrayerCatalogScreen(searchInitially: true),
        settingsOverride: notifier,
      ),
    );
    await tester.pump();
    final field = find.byKey(const Key('prayer-search-field'));
    expect(field, findsOneWidget);
    expect(tester.testTextInput.isVisible, isTrue);

    await tester.enterText(field, 'дзякуй');
    await tester.pump();
    expect(find.byKey(const ValueKey('prayer-row-evening')), findsOneWidget);
    expect(find.byKey(const ValueKey('prayer-row-morning')), findsNothing);
    expect(tester.widget<TextField>(field).controller!.text, 'дзякуй');
  });

  testWidgets('All Prayers re-entry keeps query and results synchronized', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith(_TestSettingsNotifier.new),
        liturgicalSeasonColorProvider.overrideWithValue(Colors.indigo),
        allPrayersProvider.overrideWithValue(_builtIn),
        localPrayersProvider.overrideWith(_TestLocalPrayersNotifier.new),
        prayerMenuCategoriesProvider.overrideWithValue(_categories),
      ],
    );
    addTearDown(container.dispose);

    Widget app(Key key, {bool searchInitially = false}) =>
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: PrayerCatalogScreen(
              key: key,
              searchInitially: searchInitially,
            ),
          ),
        );

    await tester.pumpWidget(
      app(const ValueKey('search-entry'), searchInitially: true),
    );
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('prayer-search-field')),
      'дзякуй',
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(app(const ValueKey('all-prayers-reentry')));
    await tester.pump();

    final field = find.byKey(const Key('prayer-search-field'));
    expect(tester.widget<TextField>(field).controller!.text, 'дзякуй');
    expect(find.byKey(const ValueKey('prayer-row-evening')), findsOneWidget);
    expect(find.byKey(const ValueKey('prayer-row-morning')), findsNothing);
  });

  testWidgets('category page includes tag and explicit members', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const PrayerCategoryScreen(categoryId: 'user-category'),
        settings: const SettingsState(
          prayerCategoryMap: {
            'evening': {'user-category'},
          },
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('prayer-row-evening')), findsOneWidget);
    expect(find.byKey(const ValueKey('prayer-row-local_one')), findsOneWidget);
  });

  testWidgets('category management hides and shows defaults', (tester) async {
    final notifier = _TestSettingsNotifier();
    await tester.pumpWidget(
      _app(const PrayerCategoriesScreen(), settingsOverride: notifier),
    );
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey('category-visibility-global-morning')),
    );
    await tester.pump();
    expect(notifier.current.hiddenGlobalPrayerCategoryIds, ['global-morning']);
    await tester.tap(
      find.byKey(const ValueKey('category-visibility-global-morning')),
    );
    await tester.pump();
    expect(notifier.current.hiddenGlobalPrayerCategoryIds, isEmpty);
  });

  testWidgets('user category can be created, renamed, and deleted', (
    tester,
  ) async {
    final notifier = _TestSettingsNotifier();
    await tester.pumpWidget(
      _app(const PrayerCategoriesScreen(), settingsOverride: notifier),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('create-category-action')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('category-name-field')),
      'Новая',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('save-category-action')));
    await tester.pumpAndSettle();
    expect(notifier.current.userCategories.single.name, 'Новая');

    await tester.tap(find.byTooltip('Рэдагаваць'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('category-name-field')),
      'Змененая',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('save-category-action')));
    await tester.pumpAndSettle();
    expect(notifier.current.userCategories.single.name, 'Змененая');

    await tester.tap(find.byTooltip('Выдаліць'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Выдаліць'));
    await tester.pumpAndSettle();
    expect(notifier.current.userCategories, isEmpty);
  });

  testWidgets('category editor supports quick tags and searchable prayers', (
    tester,
  ) async {
    final notifier = _TestSettingsNotifier();
    await tester.pumpWidget(
      _app(const PrayerCategoriesScreen(), settingsOverride: notifier),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('create-category-action')));
    await tester.pumpAndSettle();
    expect(find.text('Хуткі выбар тэгаў'), findsOneWidget);
    expect(find.byKey(const Key('pick-category-prayers')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('category-name-field')),
      'На кожны дзень',
    );
    await tester.tap(find.byKey(const ValueKey('category-tag-ранішнія')));
    await tester.tap(find.byKey(const Key('pick-category-prayers')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('category-prayer-search')),
      'Вячэрняя',
    );
    await tester.pump();
    expect(find.text('Вячэрняя малітва'), findsOneWidget);
    expect(find.text('Ранішняя малітва'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('category-prayer-evening')));
    await tester.tap(find.byKey(const Key('confirm-category-prayers')));
    await tester.pumpAndSettle();

    expect(find.text('Выбрана: 1'), findsOneWidget);
    await tester.tap(find.byKey(const Key('save-category-action')));
    await tester.pumpAndSettle();

    expect(notifier.current.userCategories.single.tags, ['ранішнія']);
    expect(notifier.current.prayerCategoryMap['evening'], {'created-category'});
  });

  testWidgets('Prayer Detail uses shared reader and only local has edit', (
    tester,
  ) async {
    final controller = ReaderChromeModeController(ReaderChromeMode.compact);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(
        ReaderChromeModeScope(
          controller: controller,
          child: const PrayerDetailScreen(prayerId: 'morning'),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('reader-content-surface')), findsOneWidget);
    expect(find.byKey(const Key('text-scale-open')), findsOneWidget);
    expect(controller.value, ReaderChromeMode.compact);
    expect(find.byKey(const Key('reader-chrome-overflow')), findsNothing);
    expect(find.text('Падзяліцца'), findsNothing);
    expect(find.text('Рэдагаваць'), findsNothing);
    expect(find.text('Поўнаэкраннае чытанне'), findsNothing);
    await tester.tap(find.byKey(const Key('reader-double-tap-surface')));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(find.byKey(const Key('reader-double-tap-surface')));
    await tester.pump();
    expect(controller.value, ReaderChromeMode.hidden);
  });

  testWidgets('prayer reader shows scroll-to-top only outside fullscreen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = ReaderChromeModeController(ReaderChromeMode.compact);
    addTearDown(controller.dispose);
    final longPrayer = Prayer(
      id: 'long',
      title: 'Доўгая малітва',
      body: List.filled(80, '<p>Радок доўгай малітвы</p>').join(),
    );
    await tester.pumpWidget(
      _app(
        ReaderChromeModeScope(
          controller: controller,
          child: const PrayerDetailScreen(prayerId: 'long'),
        ),
        prayers: [longPrayer],
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('reader-scroll-to-top')), findsNothing);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reader-scroll-to-top')), findsOneWidget);

    controller.value = ReaderChromeMode.hidden;
    await tester.pump();
    expect(find.byKey(const Key('reader-scroll-to-top')), findsNothing);

    controller.value = ReaderChromeMode.compact;
    await tester.pump();
    await tester.tap(find.byKey(const Key('reader-scroll-to-top')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reader-scroll-to-top')), findsNothing);
  });

  testWidgets('Holy Mass exposes section navigation without sharing', (
    tester,
  ) async {
    const mass = Prayer(
      id: 'eMmCtxwyJ75ogmL5rwye',
      title: 'Парадак святой Імшы',
      body: '''### Уступныя абрады

Тэкст.

### Літургія слова

Тэкст.

### Эўхарыстычная літургія

Тэкст.''',
      textFormat: 'mybrev-markdown',
    );
    await tester.pumpWidget(
      _app(
        const PrayerDetailScreen(prayerId: 'eMmCtxwyJ75ogmL5rwye'),
        prayers: const [mass],
      ),
    );
    await tester.pump();

    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mass-section-selector')));
    await tester.pumpAndSettle();
    for (final id in [
      'introductory-rites',
      'liturgy-of-the-word',
      'eucharistic-liturgy',
    ]) {
      expect(find.byKey(ValueKey('mass-section-$id')), findsOneWidget);
    }
    expect(find.text('Падзяліцца'), findsNothing);
  });

  testWidgets('built-in prayer cannot be opened as a destructive edit', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const PrayerFormScreen(prayerId: 'morning')));
    await tester.pump();

    expect(find.text('Асабістая малітва не знойдзена'), findsOneWidget);
    expect(find.byTooltip('Выдаліць малітву'), findsNothing);
    expect(find.text('Захаваць змены'), findsNothing);
  });

  testWidgets('local prayer keeps editable form and detail edit action', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const PrayerDetailScreen(prayerId: 'local_one')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('reader-chrome-overflow')));
    await tester.pumpAndSettle();
    expect(find.text('Рэдагаваць'), findsOneWidget);

    await tester.pumpWidget(
      _app(const PrayerFormScreen(prayerId: 'local_one')),
    );
    await tester.pump();
    expect(find.text('Мая малітва'), findsOneWidget);
    expect(find.byTooltip('Выдаліць малітву'), findsOneWidget);
    expect(find.text('Захаваць змены'), findsOneWidget);
  });

  testWidgets('local prayer editor formats text and shows preview', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const PrayerFormScreen(prayerId: 'local_one')),
    );
    await tester.pump();

    final bodyField = find.byKey(const Key('prayer-body-field'));
    final controller = tester.widget<TextFormField>(bodyField).controller!;
    controller.selection = const TextSelection(baseOffset: 0, extentOffset: 8);
    await tester.tap(find.byKey(const Key('prayer-format-bold')));
    await tester.pump();

    expect(controller.text, startsWith('**Асабісты**'));

    await tester.tap(find.byKey(const Key('prayer-markdown-preview-toggle')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('prayer-markdown-preview')), findsOneWidget);
    expect(find.byKey(const Key('prayer-body-field')), findsNothing);
  });

  testWidgets('Prayerbook remains usable at 200 percent system text', (
    tester,
  ) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: _app(const PrayersScreen()),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('prayerbook-title')), findsOneWidget);
  });
}

Widget _app(
  Widget child, {
  SettingsState settings = const SettingsState(),
  _TestSettingsNotifier? settingsOverride,
  List<Prayer> prayers = _builtIn,
  GoRouter? router,
}) {
  final notifier = settingsOverride ?? _TestSettingsNotifier(settings);
  return ProviderScope(
    overrides: [
      settingsProvider.overrideWith(() => notifier),
      liturgicalSeasonColorProvider.overrideWithValue(Colors.indigo),
      allPrayersProvider.overrideWithValue(prayers),
      localPrayersProvider.overrideWith(_TestLocalPrayersNotifier.new),
      prayerMenuCategoriesProvider.overrideWithValue(_categories),
      globalPrayerCategoriesProvider.overrideWith(
        (ref) => Stream.value([_categories.first]),
      ),
    ],
    child: router == null
        ? MaterialApp(home: child)
        : MaterialApp.router(routerConfig: router),
  );
}

class _TestSettingsNotifier extends SettingsNotifier {
  _TestSettingsNotifier([this.initial = const SettingsState()]);
  final SettingsState initial;

  SettingsState get current => state;

  @override
  SettingsState build() => initial;

  @override
  Future<void> toggleFavorite(String id) async {
    final values = [...state.favoriteIds];
    values.contains(id) ? values.remove(id) : values.add(id);
    state = state.copyWith(favoriteIds: values);
  }

  @override
  String addCategory(String name, List<String> tags) {
    const id = 'created-category';
    state = state.copyWith(
      userCategories: [
        ...state.userCategories,
        UserCategory(id: id, name: name, tags: tags),
      ],
    );
    return id;
  }

  @override
  void updateCategory(String id, String name, List<String> tags) {
    state = state.copyWith(
      userCategories: [
        for (final category in state.userCategories)
          category.id == id
              ? UserCategory(id: id, name: name, tags: tags)
              : category,
      ],
    );
  }

  @override
  void deleteCategory(String id) {
    state = state.copyWith(
      userCategories: state.userCategories
          .where((category) => category.id != id)
          .toList(),
    );
  }

  @override
  void hideGlobalPrayerCategory(String id) {
    state = state.copyWith(
      hiddenGlobalPrayerCategoryIds: [
        ...state.hiddenGlobalPrayerCategoryIds,
        id,
      ],
    );
  }

  @override
  void showGlobalPrayerCategory(String id) {
    state = state.copyWith(
      hiddenGlobalPrayerCategoryIds: state.hiddenGlobalPrayerCategoryIds
          .where((categoryId) => categoryId != id)
          .toList(),
    );
  }

  @override
  void setPrayerCategory(String prayerId, String categoryId, bool selected) {
    final map = {
      for (final entry in state.prayerCategoryMap.entries)
        entry.key: Set<String>.from(entry.value),
    };
    final values = map[prayerId] ?? <String>{};
    selected ? values.add(categoryId) : values.remove(categoryId);
    if (values.isEmpty) {
      map.remove(prayerId);
    } else {
      map[prayerId] = values;
    }
    state = state.copyWith(prayerCategoryMap: map);
  }
}

class _TestLocalPrayersNotifier extends LocalPrayersNotifier {
  @override
  List<Prayer> build() => const [_local];
}

class _PrayerbookSwitchHost extends StatefulWidget {
  const _PrayerbookSwitchHost();

  @override
  State<_PrayerbookSwitchHost> createState() => _PrayerbookSwitchHostState();
}

class _PrayerbookSwitchHostState extends State<_PrayerbookSwitchHost> {
  bool _root = false;

  @override
  Widget build(BuildContext context) => Material(
    child: Stack(
      children: [
        _root ? const PrayersScreen() : const PrayerCatalogScreen(),
        Positioned(
          left: 0,
          bottom: 0,
          child: TextButton(
            key: const Key('switch-to-root'),
            onPressed: () => setState(() => _root = true),
            child: const Text('Root'),
          ),
        ),
      ],
    ),
  );
}
