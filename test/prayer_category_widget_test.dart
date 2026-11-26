import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mybrev_flutter/dev/prayer_categories_harness.dart';
import 'package:mybrev_flutter/providers/prayers_provider.dart';
import 'package:mybrev_flutter/providers/priest_access_provider.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/screens/prayers_screen.dart';
import 'package:mybrev_flutter/widgets/category_icon.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'prayer_category_contract_test.dart' show fixtureContent;

final root = find.byKey(const ValueKey('category-root'));
final middle = find.byKey(const ValueKey('category-middle'));
final leaf = find.byKey(const ValueKey('category-leaf'));
Future<void> reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'comment-only leaf makes ancestors visible and reopens collapsed',
    (tester) async {
      final content = fixtureContent();
      content.categories['comment-parent'] = {'name': 'Comment parent'};
      content.categories['comment-leaf'] = {
        'name': 'Comment leaf',
        'parentId': 'comment-parent',
        'comment': {
          'content': 'Leaf fixture text',
          'sourceId': 'unknown-source',
        },
      };
      await tester.pumpWidget(PrayerCategoriesHarness(content: content));
      await tester.pumpAndSettle();
      final parent = find.byKey(const ValueKey('category-comment-parent'));
      final leaf = find.byKey(const ValueKey('category-comment-leaf'));
      final comment = find.text('Пра гэты раздзел');
      final body = find.text('Leaf fixture text', findRichText: true);
      await reveal(tester, parent);
      expect(leaf, findsNothing);
      await tester.tap(parent);
      await tester.pumpAndSettle();
      final router = GoRouter.of(tester.element(leaf));
      await tester.tap(leaf);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('prayer-list-empty')), findsNothing);
      expect(find.text('Малітвы гэтай катэгорыі'), findsNothing);
      expect(find.byType(PrayerListRow), findsNothing);
      expect(body, findsNothing);
      await tester.tap(comment);
      await tester.pumpAndSettle();
      expect(body, findsOneWidget);
      expect(find.byKey(const Key('prayer-source')), findsNothing);
      router.pop();
      await tester.pumpAndSettle();
      await tester.tap(leaf);
      await tester.pumpAndSettle();
      expect(comment, findsOneWidget);
      expect(body, findsNothing);
      final settings = ProviderScope.containerOf(
        tester.element(comment),
      ).read(settingsProvider.notifier);
      settings.hideGlobalPrayerCategory('comment-leaf');
      await tester.pumpAndSettle();
      expect(find.text('Катэгорыя не знойдзена'), findsOneWidget);
    },
  );

  testWidgets('expanded restricted comment disappears when the grant expires', (
    tester,
  ) async {
    final content = fixtureContent();
    content.categories['closed-comment'] = {
      'name': 'Restricted comment-only child',
      'parentId': 'closed',
      'comment': {'content': 'Synthetic restricted comment text'},
    };
    await tester.pumpWidget(PrayerCategoriesHarness(content: content));
    await tester.pumpAndSettle();
    final element = tester.element(find.byType(PrayersScreen));
    final router = GoRouter.of(element);
    final controller =
        ProviderScope.containerOf(element).read(priestAccessProvider.notifier)
            as CategorySmokeAccess;
    router.go('/prayers/category/closed-comment');
    await tester.pumpAndSettle();
    expect(find.text('Катэгорыя не знойдзена'), findsOneWidget);
    controller.setGranted(true);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Пра гэты раздзел'));
    await tester.pumpAndSettle();
    final text = find.text(
      'Synthetic restricted comment text',
      findRichText: true,
    );
    expect(text, findsOneWidget);
    controller.setGranted(true);
    await tester.pumpAndSettle();
    expect(text, findsNothing);
    await tester.tap(find.text('Пра гэты раздзел'));
    await tester.pumpAndSettle();
    expect(text, findsOneWidget);
    final updated = PrayerAccessContent(content.prayers, {
      ...content.categories,
      'closed-comment': {
        ...content.categories['closed-comment']!,
        'comment': {'content': 'Updated synthetic restricted comment'},
      },
    });
    controller.replaceAuthorized(updated);
    await tester.pump();
    final updatedText = find.text(
      'Updated synthetic restricted comment',
      findRichText: true,
    );
    expect(text, findsNothing);
    expect(updatedText, findsNothing);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Пра гэты раздзел'));
    await tester.pumpAndSettle();
    expect(updatedText, findsOneWidget);
    controller.setGranted(false);
    await tester.pump();
    expect(text, findsNothing);
    expect(updatedText, findsNothing);
    expect(find.text('Катэгорыя не знойдзена'), findsOneWidget);
  });

  testWidgets(
    'category pages: roots, keyboard, children before direct prayers, reader/back',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final content = fixtureContent();
        content.categories['root']!['iconKey'] = 'virgin-mary';
        content.categories['middle']!['iconKey'] = 'rosary';
        content.categories['leaf']!['iconKey'] = 'candle';
        content.prayers['leaf-prayer']!['text'] = 'Synthetic reader text';
        await tester.pumpWidget(PrayerCategoriesHarness(content: content));
        await tester.pumpAndSettle();
        await reveal(tester, root);
        expect(middle, findsNothing);
        expect(leaf, findsNothing);
        expect(
          tester.getSemantics(root).flagsCollection.isExpanded,
          Tristate.none,
        );
        void expectIcon(Finder row, String key) {
          expect(
            tester
                .widget<CategoryIcon>(
                  find.descendant(of: row, matching: find.byType(CategoryIcon)),
                )
                .iconKey,
            key,
          );
          expect(
            find.descendant(
              of: row,
              matching: find.byKey(ValueKey('category-svg-$key')),
            ),
            findsOneWidget,
          );
        }

        expectIcon(root, 'virgin-mary');
        final router = GoRouter.of(tester.element(root));
        bool rootFocused() {
          final title = FocusManager.instance.primaryFocus?.context
              ?.findAncestorWidgetOfExactType<ListTile>()
              ?.title;
          return title is Text && title.data == 'Fixture root';
        }

        for (var i = 0; i < 30 && !rootFocused(); i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
        }
        expect(rootFocused(), isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(find.byType(PrayerCategoryScreen), findsOneWidget);
        expectIcon(middle, 'rosary');
        expect(leaf, findsNothing);
        expect(find.text('Fixture manual'), findsOneWidget);
        expect(find.text('Fixture leaf prayer'), findsNothing);
        expect(find.text('PRIVATE SHARED FIXTURE'), findsNothing);
        expect(
          tester.getTopLeft(middle).dy,
          lessThan(
            tester
                .getTopLeft(find.byKey(const ValueKey('prayer-row-manual')))
                .dy,
          ),
        );
        await tester.tap(middle);
        await tester.pumpAndSettle();
        expectIcon(leaf, 'candle');
        expect(find.byKey(const Key('prayer-list-empty')), findsNothing);
        expect(find.text('Fixture manual'), findsNothing);
        await tester.tap(leaf);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Fixture leaf prayer'));
        await tester.pumpAndSettle();
        expect(
          find.text('Synthetic reader text', findRichText: true),
          findsWidgets,
        );
        router.pop();
        await tester.pumpAndSettle();
        expect(find.text('Fixture leaf prayer'), findsOneWidget);
        router.pop();
        await tester.pumpAndSettle();
        expect(leaf, findsOneWidget);
        router.pop();
        await tester.pumpAndSettle();
        expect(middle, findsOneWidget);
        expect(find.text('Fixture manual'), findsOneWidget);
        router.pop();
        await tester.pumpAndSettle();
        expect(root, findsOneWidget);
        expect(middle, findsNothing);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('category scroll survives child page and prayer reader Back', (
    tester,
  ) async {
    final content = fixtureContent();
    for (var i = 0; i < 30; i++) {
      content.categories['child-$i'] = {
        'name': 'Child $i',
        'parentId': 'root',
        'order': i,
        'prayerIds': ['tagged'],
      };
    }
    await tester.pumpWidget(PrayerCategoriesHarness(content: content));
    await tester.pumpAndSettle();
    await reveal(tester, root);
    final router = GoRouter.of(tester.element(root));
    await tester.tap(root);
    await tester.pumpAndSettle();
    final last = find.byKey(const ValueKey('category-child-29'));
    await reveal(tester, last);
    double offset() => tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .pixels;
    final beforeChild = offset();
    expect(beforeChild, greaterThan(300));
    await tester.tap(last);
    await tester.pumpAndSettle();
    router.pop();
    await tester.pumpAndSettle();
    expect(offset(), closeTo(beforeChild, 1));
    await reveal(tester, find.byKey(const ValueKey('prayer-row-manual')));
    final beforeReader = offset();
    await tester.tap(find.byKey(const ValueKey('prayer-row-manual')));
    await tester.pumpAndSettle();
    router.pop();
    await tester.pumpAndSettle();
    expect(offset(), closeTo(beforeReader, 1));
  });

  testWidgets(
    'protected collections use existing category rows and stay out of the menu',
    (tester) async {
      final content = fixtureContent();
      content.categories['closed']!['name'] = 'Для святара';
      content.categories['marian'] = {
        'name': 'Для марыянаў',
        'effectiveAccessSets': ['marian'],
        'order': 2,
        'prayerIds': ['marian-example'],
      };
      content.prayers['marian-example'] = {
        'title': 'Synthetic Marian title',
        'text': 'Synthetic Marian body',
        'effectiveAccessSets': ['marian'],
      };
      await tester.pumpWidget(PrayerCategoriesHarness(content: content));
      await tester.pumpAndSettle();
      final marian = find.byKey(const ValueKey('category-marian'));
      final priest = find.byKey(const ValueKey('category-closed'));
      expect(marian, findsNothing);
      expect(priest, findsNothing);
      await tester.tap(find.byTooltip('Grant'));
      await tester.pumpAndSettle();
      await reveal(tester, marian);
      expect(find.text('Для марыянаў'), findsOneWidget);
      final tile = tester.widget<ListTile>(
        find.descendant(of: marian, matching: find.byType(ListTile)),
      );
      final lock = tester.widget<PhosphorIcon>(
        find.descendant(
          of: marian,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is PhosphorIcon &&
                widget.icon == PhosphorIconsRegular.lockSimple,
          ),
        ),
      );
      expect(lock.icon, PhosphorIconsRegular.lockSimple);
      expect(tile.minTileHeight, 58);
      expect((tile.title! as Text).style?.color, lock.color);

      await tester.tap(find.byTooltip('Меню'));
      await tester.pumpAndSettle();
      final popup = find.byKey(const Key('app-overflow-content'));
      expect(
        find.descendant(of: popup, matching: find.text('Налады')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: popup, matching: find.text('Для марыянаў')),
        findsNothing,
      );
      expect(
        find.descendant(of: popup, matching: find.text('Для святароў')),
        findsNothing,
      );
      Navigator.of(tester.element(popup)).pop();
      await tester.pumpAndSettle();

      await reveal(tester, priest);
      expect(find.text('Для святароў'), findsOneWidget);
      await tester.ensureVisible(marian);
      await tester.tap(marian);
      await tester.pumpAndSettle();
      expect(find.text('Synthetic Marian title'), findsOneWidget);
      await tester.tap(find.text('Synthetic Marian title'));
      await tester.pumpAndSettle();
      expect(
        find.text('Synthetic Marian body', findRichText: true),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'revoke removes private lists, favorites/search, category management and deep links immediately',
    (tester) async {
      final content = fixtureContent();
      await tester.pumpWidget(PrayerCategoriesHarness(content: content));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Grant'));
      await tester.pumpAndSettle();
      final scope = ProviderScope.containerOf(
        tester.element(find.byType(PrayersScreen)),
      );
      final controller =
          scope.read(priestAccessProvider.notifier) as CategorySmokeAccess;
      final router = GoRouter.of(tester.element(find.byType(PrayersScreen)));
      expect(
        scope.read(allPrayersProvider).any((p) => p.id == 'shared-private'),
        isTrue,
      );
      await scope
          .read(settingsProvider.notifier)
          .toggleFavorite('shared-private');
      router.push('/prayers/categories');
      await tester.pumpAndSettle();
      expect(find.text('Fixture protected'), findsOneWidget);
      controller.setGranted(false);
      await tester.pump();
      expect(find.text('Fixture protected'), findsNothing);
      await tester.pumpAndSettle();
      expect(scope.read(favoritePrayersProvider), isEmpty);
      expect(
        scope.read(allPrayersProvider).any((p) => p.id == 'shared-private'),
        isFalse,
      );
      router.go('/prayers/category/closed');
      await tester.pumpAndSettle();
      expect(find.text('Катэгорыя не знойдзена'), findsOneWidget);
      expect(find.text('Fixture protected'), findsNothing);
      router.go('/prayers/prayer/shared-private');
      await tester.pumpAndSettle();
      expect(find.text('Малітва не знойдзена'), findsOneWidget);
    },
  );

  testWidgets(
    'hidden root promotes middle; personal categories remain separate pages',
    (tester) async {
      await tester.pumpWidget(
        PrayerCategoriesHarness(content: fixtureContent()),
      );
      await tester.pumpAndSettle();
      final scope = ProviderScope.containerOf(
        tester.element(find.byType(PrayersScreen)),
      );
      final router = GoRouter.of(tester.element(find.byType(PrayersScreen)));
      scope.read(settingsProvider.notifier).hideGlobalPrayerCategory('root');
      await tester.pumpAndSettle();
      await reveal(tester, middle);
      expect(root, findsNothing);
      expect(leaf, findsNothing);
      await tester.tap(middle);
      await tester.pumpAndSettle();
      expect(leaf, findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      final personal = find.byKey(const ValueKey('category-mine'));
      await reveal(tester, personal);
      await tester.tap(personal);
      await tester.pumpAndSettle();
      expect(find.text('Fixture tagged'), findsOneWidget);
      expect(middle, findsNothing);
      expect(leaf, findsNothing);
    },
  );

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final theme in ['light', 'dark', 'marian']) {
      for (final width in [320.0, 375.0, 768.0]) {
        for (final scale in [1.0, 2.0]) {
          testWidgets(
            'category page navigation ${platform.name} $theme width=$width scale=$scale',
            (tester) async {
              tester.view.devicePixelRatio = 1;
              tester.view.physicalSize = Size(width, 900);
              addTearDown(tester.view.resetDevicePixelRatio);
              addTearDown(tester.view.resetPhysicalSize);
              final content = fixtureContent();
              content.categories['root']!['name'] =
                  'Штодзённыя малітвы з доўгай назвай катэгорыі';
              content.categories['leaf']!['name'] =
                  'Ранішнія і вячэрнія малітвы для ўсёй сям’і';
              await tester.pumpWidget(
                PrayerCategoriesHarness(
                  content: content,
                  scheme: theme,
                  scale: scale,
                  platform: platform,
                ),
              );
              await tester.pumpAndSettle();
              await reveal(tester, root);
              await tester.tap(root);
              await tester.pumpAndSettle();
              expect(leaf, findsNothing);
              await reveal(tester, find.text('Fixture manual'));
              expect(find.text('Fixture manual'), findsOneWidget);
              await reveal(tester, middle);
              await tester.tap(middle);
              await tester.pumpAndSettle();
              await reveal(tester, leaf);
              expect(find.byKey(const Key('prayer-list-empty')), findsNothing);
              expect(find.text('Fixture manual'), findsNothing);
              expect(tester.getRect(leaf).right, lessThanOrEqualTo(width));
              expect(tester.getRect(leaf).height, greaterThanOrEqualTo(48));
              expect(find.text('PRIVATE SHARED FIXTURE'), findsNothing);
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }
  }
}
