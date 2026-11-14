import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mybrev_flutter/dev/prayer_categories_harness.dart';
import 'package:mybrev_flutter/providers/prayer_categories_provider.dart';
import 'package:mybrev_flutter/providers/prayers_provider.dart';
import 'package:mybrev_flutter/providers/priest_access_provider.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/screens/prayers_screen.dart';
import 'package:mybrev_flutter/widgets/category_icon.dart';

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
    'accordion, keyboard/focus, direct-only list, leaf reader/back and scroll',
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
        expect(
          tester.getSemantics(root).flagsCollection.isExpanded,
          Tristate.isFalse,
        );
        await tester.tap(root);
        await tester.pumpAndSettle();
        expect(middle, findsOneWidget);
        expect(leaf, findsNothing);
        expect(
          tester.getSemantics(root).flagsCollection.isExpanded,
          Tristate.isTrue,
        );
        // Touch does not focus a tile on every platform. Reach it through actual
        // keyboard traversal before checking the Material activation shortcuts.
        bool rootFocused() =>
            FocusManager.instance.primaryFocus?.context
                ?.findAncestorWidgetOfExactType<ListTile>()
                ?.key ==
            const ValueKey('category-root');
        for (var i = 0; i < 30 && !rootFocused(); i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
        }
        expect(rootFocused(), isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pumpAndSettle();
        expect(middle, findsNothing);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(middle, findsOneWidget);
        final router = GoRouter.of(tester.element(root));
        await tester.tap(find.byKey(const ValueKey('category-direct-root')));
        await tester.pumpAndSettle();
        expect(find.text('Fixture manual'), findsOneWidget);
        expect(find.text('Fixture leaf prayer'), findsNothing);
        expect(find.text('PRIVATE SHARED FIXTURE'), findsNothing);
        router.pop();
        await tester.pumpAndSettle();
        await reveal(tester, middle);
        await tester.tap(middle);
        await tester.pumpAndSettle();
        await reveal(tester, leaf);
        for (final pair in [
          (root, 'virgin-mary'),
          (middle, 'rosary'),
          (leaf, 'candle'),
        ]) {
          final icon = tester.widget<CategoryIcon>(
            find.descendant(of: pair.$1, matching: find.byType(CategoryIcon)),
          );
          expect(icon.iconKey, pair.$2);
          expect(
            find.descendant(
              of: pair.$1,
              matching: find.byKey(ValueKey('category-svg-${pair.$2}')),
            ),
            findsOneWidget,
          );
        }
        final scroll = tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .pixels;
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
        router.pop();
        await tester.pumpAndSettle();
        expect(leaf, findsOneWidget);
        expect(
          tester
              .state<ScrollableState>(find.byType(Scrollable).first)
              .position
              .pixels,
          closeTo(scroll, 1),
        );
      } finally {
        semantics.dispose();
      }
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
    'hidden root promotes middle and expansion survives root remount',
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
      await tester.tap(middle);
      await tester.pumpAndSettle();
      expect(leaf, findsOneWidget);
      router.go('/prayers/all');
      await tester.pumpAndSettle();
      router.go('/prayers');
      await tester.pumpAndSettle();
      expect(scope.read(expandedPrayerCategoryIdsProvider), contains('middle'));
      await reveal(tester, leaf);
      expect(leaf, findsOneWidget);
    },
  );

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final theme in ['light', 'dark', 'marian']) {
      for (final width in [320.0, 375.0, 768.0]) {
        for (final scale in [1.0, 2.0]) {
          testWidgets(
            'expanded tree ${platform.name} $theme width=$width scale=$scale',
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
              await reveal(tester, middle);
              await tester.tap(middle);
              await tester.pumpAndSettle();
              await reveal(tester, leaf);
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
