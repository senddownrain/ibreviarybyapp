import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mybrev_flutter/constants/prayer_category_icons.dart';
import 'package:mybrev_flutter/providers/prayer_categories_provider.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/theme/app_theme_controller.dart';
import 'package:mybrev_flutter/theme/app_theme_preference.dart';
import 'package:mybrev_flutter/widgets/category_icon.dart';
import 'package:mybrev_flutter/widgets/category_icon_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

Map<String, dynamic> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

void main() {
  group('catalog contract (shared with the web app)', () {
    test('48 keys, 12 per group, identical to the exported catalog.json', () {
      final catalog = _json('assets/category_icons/catalog.json');
      final icons = (catalog['icons'] as List).cast<Map<String, dynamic>>();
      expect(kCategoryIcons, hasLength(48));
      expect(kCategoryIcons.map((i) => i.key).toSet(), hasLength(48));
      expect(
        kCategoryIcons.map((i) => i.key).toList(),
        icons.map((i) => i['key']).toList(),
      );
      for (var i = 0; i < icons.length; i++) {
        expect(kCategoryIcons[i].label, icons[i]['label'], reason: '$i');
        expect(kCategoryIcons[i].group, icons[i]['group'], reason: '$i');
        expect(
          kCategoryIcons[i].phosphor == null ? 'svg' : 'phosphor',
          icons[i]['kind'],
          reason: icons[i]['key'] as String,
        );
      }
      expect(
        [for (final g in kCategoryIconGroups) '${g.id}|${g.label}'],
        [
          for (final g in (catalog['groups'] as List))
            '${(g as Map)['id']}|${g['label']}',
        ],
      );
      for (final group in kCategoryIconGroups) {
        expect(kCategoryIcons.where((i) => i.group == group.id), hasLength(12));
      }
      expect(kCategoryIcons.where((i) => i.phosphor == null), hasLength(12));
      expect(catalog['seeds'], kSeedCategoryIconKeys);
    });

    test(
      'all 12 authored SVG assets exist, are 24x24 and use currentColor',
      () {
        for (final icon in kCategoryIcons.where((i) => i.phosphor == null)) {
          final file = File(icon.svgAsset!);
          expect(file.existsSync(), isTrue, reason: icon.svgAsset);
          final svg = file.readAsStringSync();
          expect(svg, contains('viewBox="0 0 24 24"'));
          expect(svg, contains('stroke="currentColor"'));
          expect(svg, isNot(contains('<script')));
        }
      },
    );

    test('suggestions match the shared vectors and are deterministic', () {
      final vectors =
          jsonDecode(
                File(
                  'test/fixtures/prayer_category_icon_vectors.json',
                ).readAsStringSync(),
              )
              as List;
      for (final raw in vectors) {
        final v = raw as Map<String, dynamic>;
        final key = suggestCategoryIconKey(
          id: v['id'] as String,
          name: v['name'] as String,
          tags: List<String>.from(v['tags'] as List),
        );
        expect(key, v['expected'], reason: v['name'] as String);
        expect(isValidCategoryIconKey(key), isTrue);
      }
      expect(stableCategoryHash('abc'), 440920331);
    });

    test('allowlist normaliser and display fallback', () {
      expect(normalizeCategoryIconKey('virgin-mary'), 'virgin-mary');
      for (final bad in ['mdi-folder', '<svg/>', '🙏', '', null, 7, 'PRAYER']) {
        expect(normalizeCategoryIconKey(bad), isNull);
      }
      expect(
        displayCategoryIconKey(iconKey: 'from-the-future', name: 'Ружанец'),
        'from-the-future',
      );
      expect(displayCategoryIconKey(name: 'Ружанец'), 'rosary');
      expect(kSeedCategoryIconKeys, {
        'mary': 'virgin-mary',
        'litanies': 'litany',
        'novenas': 'novena',
      });
    });
  });

  group('UserCategory', () {
    test('legacy map without iconKey still loads; icon round-trips', () {
      final legacy = UserCategory.fromMap({
        'id': '1',
        'name': 'Мая',
        'tags': ['a'],
      });
      expect(legacy.iconKey, isNull);
      expect(legacy.toMap().containsKey('iconKey'), isFalse);
      final withIcon = legacy.withIconKey('angel');
      expect(UserCategory.fromMap(withIcon.toMap()).iconKey, 'angel');
      expect(
        UserCategory.fromMap({
          'id': '2',
          'name': 'Н',
          'tags': [],
          'iconKey': 'from-the-future',
        }).iconKey,
        'from-the-future',
      );
    });
  });

  group('settings storage', () {
    late Directory directory;
    late Box box;
    late ProviderContainer container;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('category-icons-');
      Hive.init(directory.path);
      box = await Hive.openBox('settings');
      container = ProviderContainer();
    });
    tearDown(() async {
      await Future<void>.delayed(
        const Duration(milliseconds: 200),
      ); // let queued Hive writes finish
      container.dispose();
      await Hive.close();
      await directory.delete(recursive: true);
      setActiveThemePreference(AppThemePreference.system);
    });

    test(
      'old categories get a meaningful icon once and it is persisted',
      () async {
        await box.put(
          'userCategories',
          jsonEncode([
            {
              'id': '1',
              'name': 'Мой ружанец',
              'tags': ['Ружанец'],
            },
            {'id': '2', 'name': 'Мая', 'tags': <String>[], 'iconKey': 'angel'},
            {
              'id': '3',
              'name': 'Новая',
              'tags': <String>[],
              'iconKey': 'from-the-future',
            },
          ]),
        );
        final categories = container.read(settingsProvider).userCategories;
        expect(categories.map((c) => c.iconKey), [
          'rosary',
          'angel',
          'from-the-future',
        ]);
        final stored = jsonDecode(box.get('userCategories') as String) as List;
        expect(stored.map((c) => (c as Map)['iconKey']), [
          'rosary',
          'angel',
          'from-the-future',
        ]);

        // Renaming keeps the stored choice; a second start changes nothing.
        container.read(settingsProvider.notifier).updateCategory(
          '1',
          'Зусім іншая',
          ['Ружанец'],
        );
        expect(
          container.read(settingsProvider).userCategories.first.iconKey,
          'rosary',
        );
        final snapshot = box.get('userCategories');
        final second = ProviderContainer();
        addTearDown(second.dispose);
        expect(
          second.read(settingsProvider).userCategories.first.iconKey,
          'rosary',
        );
        expect(box.get('userCategories'), snapshot);
      },
    );

    test('add and update keep the chosen icon, reject unknown keys', () async {
      final notifier = container.read(settingsProvider.notifier);
      final id = notifier.addCategory('Раніца', ['t'], iconKey: 'candle');
      expect(
        container.read(settingsProvider).userCategories.single.iconKey,
        'candle',
      );
      notifier.updateCategory(id, 'Раніца', ['t', 'u']);
      expect(
        container.read(settingsProvider).userCategories.single.iconKey,
        'candle',
      );
      notifier.updateCategory(id, 'Раніца', ['t'], iconKey: '<svg/>');
      expect(
        container.read(settingsProvider).userCategories.single.iconKey,
        'candle',
      );
      notifier.updateCategory(id, 'Раніца', ['t'], iconKey: 'bell');
      expect(
        container.read(settingsProvider).userCategories.single.iconKey,
        'bell',
      );
      await Future<void>.delayed(
        const Duration(milliseconds: 3),
      ); // ids are millisecond timestamps
      final bare = notifier.addCategory('Вечар', ['v']);
      expect(
        container
            .read(settingsProvider)
            .userCategories
            .firstWhere((c) => c.id == bare)
            .iconKey,
        'evening',
      );
    });

    test(
      'hide/restore global categories and memberships are untouched',
      () async {
        final notifier = container.read(settingsProvider.notifier);
        final id = notifier.addCategory('Мая', ['t'], iconKey: 'cross');
        notifier.setPrayerCategory('p1', id, true);
        notifier.hideGlobalPrayerCategory('mary');
        notifier.showGlobalPrayerCategory('mary');
        notifier.updateCategory(id, 'Мая 2', ['t'], iconKey: 'bell');
        final state = container.read(settingsProvider);
        expect(state.prayerCategoryMap['p1'], {id});
        expect(state.hiddenGlobalPrayerCategoryIds, isEmpty);
      },
    );
  });

  group('global categories', () {
    test('iconKey passes from bundle data; missing ones get a suggestion', () {
      final withKey = PrayerMenuCategory.global('mary', {
        'name': 'Марыйныя',
        'tags': ['Марыя'],
        'iconKey': 'virgin-mary',
      });
      expect(withKey.iconKey, 'virgin-mary');
      expect(withKey.displayIconKey, 'virgin-mary');
      final without = PrayerMenuCategory.global('x', {
        'name': 'Ружанец',
        'tags': <String>[],
      });
      expect(without.iconKey, isNull);
      expect(without.displayIconKey, 'rosary');
      final personal = PrayerMenuCategory.personal(
        const UserCategory(id: 'u', name: 'Мая', tags: [], iconKey: 'bell'),
      );
      expect(personal.displayIconKey, 'bell');
    });
  });

  group('rendering', () {
    testWidgets('every one of the 48 icons renders real, non-empty artwork', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Wrap(
              children: [
                for (final icon in kCategoryIcons)
                  CategoryIcon(icon.key, size: 24),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PhosphorIcon), findsNWidgets(36));
      expect(find.byType(SvgPicture), findsNWidgets(12));
      for (final icon in kCategoryIcons.where((i) => i.phosphor == null)) {
        expect(
          find.byKey(ValueKey('category-svg-${icon.key}')),
          findsOneWidget,
        );
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('unknown or missing keys fall back without errors', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Row(children: [CategoryIcon('nope'), CategoryIcon(null)]),
        ),
      );
      expect(find.byType(PhosphorIcon), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'picker lists 48 icons; choosing changes, dismissing does not',
      (tester) async {
        tester.view.physicalSize = const Size(900, 3200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        var value = 'prayer';
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) => CategoryIconField(
                  iconKey: value,
                  onChanged: (key) => setState(() => value = key),
                ),
              ),
            ),
          ),
        );
        expect(find.text('Малітва'), findsOneWidget);
        await tester.tap(find.byKey(const Key('category-icon-field')));
        await tester.pumpAndSettle();
        expect(
          find.byWidgetPredicate(
            (w) =>
                w.key is ValueKey &&
                '${(w.key! as ValueKey).value}'.startsWith(
                  'category-icon-option-',
                ),
          ),
          findsNWidgets(48),
        );
        // Dismiss: nothing changes.
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
        expect(value, 'prayer');
        await tester.tap(find.byKey(const Key('category-icon-field')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('category-icon-option-candle')),
        );
        await tester.pumpAndSettle();
        expect(value, 'candle');
        expect(find.text('Свечка'), findsOneWidget);
      },
    );
  });
}
