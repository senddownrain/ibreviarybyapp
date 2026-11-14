import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/models/prayer.dart';
import 'package:mybrev_flutter/models/priest_access_content.dart';
import 'package:mybrev_flutter/providers/prayer_categories_provider.dart';
import 'package:mybrev_flutter/providers/prayers_provider.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/services/prayer_category_tree.dart';
import 'package:mybrev_flutter/services/priest_access_policy.dart';

const fixtureDirectory = 'test/fixtures/prayer-categories';
Map<String, dynamic> readCategoryFixture() =>
    jsonDecode(File('$fixtureDirectory/fixture.json').readAsStringSync())
        as Map<String, dynamic>;
Map<String, Map<String, dynamic>> documents(List rows) => {
  for (final row in rows)
    row['id'] as String: Map<String, dynamic>.from(row)..remove('id'),
};
PrayerAccessContent fixtureContent() {
  final fixture = readCategoryFixture();
  return PrayerAccessContent(
    documents(fixture['prayers'] as List),
    documents(fixture['categories'] as List),
  );
}

List<Prayer> prayerModels(PrayerAccessContent content) => [
  for (final e in content.prayers.entries) Prayer.fromMap(e.value, e.key),
];
List<PrayerMenuCategory> categoryModels(PrayerAccessContent content) => [
  for (final e in content.categories.entries)
    PrayerMenuCategory.global(e.key, e.value),
];
List<String> ids(Iterable<Prayer> prayers) =>
    prayers.map((p) => p.id).toList()..sort();

void main() {
  final fixture = readCategoryFixture();
  for (final raw in fixture['cases'] as List) {
    final c = raw as Map;
    test(c['caseId'] as String, () {
      final content = fixtureContent();
      final public = content.publicOnly;
      final categoryId = c['categoryId'];
      PrayerMenuCategory category() => PrayerMenuCategory.global(
        categoryId as String,
        content.categories[categoryId]!,
      );
      if (c['expectedDirectIds'] != null) {
        final prayers = prayerModels(content);
        expect(
          ids(
            prayersForCategory(
              [...prayers, ...prayers],
              category(),
              const SettingsState(),
            ),
          ),
          (c['expectedDirectIds'] as List).cast<String>()..sort(),
        );
        if (c['expectedPublicDirectIds'] != null) {
          expect(
            ids(
              prayersForCategory(
                prayerModels(public),
                category(),
                const SettingsState(),
              ),
            ),
            (c['expectedPublicDirectIds'] as List).cast<String>()..sort(),
          );
        }
      } else if ((c['caseId'] as String).startsWith('C05')) {
        expect(
          content.prayers.keys
              .where((id) => !public.prayers.containsKey(id))
              .toSet(),
          (c['expectedProtectedPrayerIds'] as List).toSet(),
        );
        expect(
          content.categories.keys
              .where((id) => !public.categories.containsKey(id))
              .toSet(),
          (c['expectedProtectedCategoryIds'] as List).toSet(),
        );
      } else if ((c['caseId'] as String).startsWith('C06')) {
        final menu = buildPrayerCategoryMenu(
          categoryModels(content),
          [],
          [],
          permittedPrayers: prayerModels(public),
        );
        expect(
          menu.map((c) => c.id).toSet(),
          (c['expectedPublicMenuIds'] as List).toSet(),
        );
        final tree = buildPrayerCategoryTree(menu);
        expect(tree.first.category.id, 'root');
        expect(tree.first.children.single.children.single.category.id, 'leaf');
      } else if ((c['caseId'] as String).startsWith('C07')) {
        (content.categories[categoryId]!['prayerIds'] as List).remove(
          c['removePrayerId'],
        );
        expect(
          prayerBelongsToCategory(
            Prayer.fromMap(
              content.prayers[c['removePrayerId']]!,
              c['removePrayerId'] as String,
            ),
            category(),
            const SettingsState(),
          ),
          c['expectedStillDirect'],
        );
      } else if ((c['caseId'] as String).startsWith('C08')) {
        (content.categories[categoryId]!['prayerIds'] as List).remove(
          c['removePrayerId'],
        );
        expect(
          content.publicOnly.prayers,
          contains(c['expectedNewPublicPrayerId']),
        );
      } else if ((c['caseId'] as String).startsWith('C09')) {
        content.categories[categoryId]!['parentId'] = c['newParentId'];
        expect(
          content.publicOnly.prayers,
          isNot(contains(c['expectedNewProtectedPrayerId'])),
        );
      } else {
        fail('Unhandled contract case ${c['caseId']}');
      }
    });
  }

  test(
    'new model uses the real Web gzip and preserves old icons and opaque IDs',
    () {
      final decoded = decodeContentCollection(
        File('$fixtureDirectory/prayerCategories.json.gz').readAsBytesSync(),
      );
      final root = PrayerMenuCategory.global('root', decoded.docs['root']!);
      expect(root.prayerIds, ['manual', 'both', 'shared-private']);
      expect(root.iconId, 'folder');
      expect(root.order, 10);
      final probe = PrayerMenuCategory.global(
        'codec-probe',
        decoded.docs['codec-probe']!,
      );
      expect(probe.iconKey, 'folder');
      expect(probe.icon, 'synthetic-existing-icon');
      expect(probe.iconId, 'synthetic-existing-icon-id');
      expect(
        PrayerMenuCategory.global('legacy', decoded.docs['legacy']!).prayerIds,
        isEmpty,
      );
      expect(
        ids(
          prayersForCategory(
            prayerModels(fixtureContent().publicOnly),
            root,
            const SettingsState(),
          ),
        ),
        ['both', 'manual', 'tagged'],
      );
    },
  );

  test(
    'personal membership stays local and cannot change global membership',
    () {
      const settings = SettingsState(
        prayerCategoryMap: {
          'unrelated': {'root', 'mine'},
        },
      );
      const prayer = Prayer(id: 'unrelated', title: 'Unrelated');
      final root = categoryModels(fixtureContent()).first;
      expect(prayerBelongsToCategory(prayer, root, settings), isFalse);
      expect(
        prayerBelongsToCategory(
          prayer,
          const PrayerMenuCategory(
            id: 'mine',
            name: 'Mine',
            tags: [],
            isGlobal: false,
          ),
          settings,
        ),
        isTrue,
      );
    },
  );

  test(
    'hidden parent promotes children; global duplicates retain distinct IDs',
    () {
      final content = fixtureContent().publicOnly;
      final menu = buildPrayerCategoryMenu(categoryModels(content), [], [
        'root',
      ], permittedPrayers: prayerModels(content));
      expect(buildPrayerCategoryTree(menu).first.category.id, 'middle');
      final globals = [
        const PrayerMenuCategory(id: 'a', name: 'A', tags: [], isGlobal: true),
        const PrayerMenuCategory(id: 'b', name: 'B', tags: [], isGlobal: true),
        const PrayerMenuCategory(
          id: 'x',
          name: 'Same',
          parentId: 'a',
          tags: [],
          isGlobal: true,
        ),
        const PrayerMenuCategory(
          id: 'y',
          name: 'Same',
          parentId: 'b',
          tags: [],
          isGlobal: true,
        ),
      ];
      expect(
        buildPrayerCategoryMenu(globals, [
          const UserCategory(id: 'mine', name: 'same', tags: []),
        ], []).map((c) => c.id),
        ['a', 'b', 'x', 'y'],
      );
    },
  );

  test('numeric finite order, Belarusian names and ID tie break', () {
    final categories = [
      for (final row in [
        {'id': 'missing', 'name': 'A'},
        {'id': 'nan', 'name': 'B', 'order': double.nan},
        {'id': 'inf', 'name': 'C', 'order': double.infinity},
        {'id': 'ya', 'name': 'Я', 'order': 2},
        {'id': 'io', 'name': 'Ё', 'order': 2},
        {'id': 'e-b', 'name': 'е', 'order': 2},
        {'id': 'e-a', 'name': 'Е', 'order': 2},
        {'id': 'first', 'name': 'Z', 'order': -1},
      ])
        PrayerMenuCategory.global(row['id'] as String, row),
    ]..sort(comparePrayerCategories);
    expect(categories.map((c) => c.id), [
      'first',
      'e-a',
      'e-b',
      'io',
      'ya',
      'missing',
      'nan',
      'inf',
    ]);
  });

  test(
    'missing/self/cycle/depth fail closed regardless of cache lookup order',
    () {
      final categories = <String, Map<String, dynamic>>{
        'missing': {
          'parentId': 'unknown',
          'prayerIds': ['p'],
        },
        'self': {
          'parentId': 'self',
          'prayerIds': ['p'],
        },
        'a': {
          'parentId': 'b',
          'prayerIds': ['p'],
        },
        'b': {'parentId': 'a'},
        for (var i = 0; i < 65; i++)
          'deep-$i': {
            'parentId': i == 0 ? null : 'deep-${i - 1}',
            'prayerIds': ['p-$i'],
            'name': 'Deep $i',
          },
      };
      final policy = PriestAccessPolicy(categories);
      for (var i = 0; i < 64; i++) {
        expect(policy.categoryRestricted('deep-$i'), isFalse);
      }
      expect(policy.categoryRestricted('deep-64'), isTrue);
      for (final id in ['missing', 'self', 'a', 'b', 'unknown']) {
        expect(policy.categoryRestricted(id), isTrue);
      }
      expect(policy.prayerRestricted(const {'tags': []}, id: 'p'), isTrue);
      expect(policy.prayerRestricted(const {'tags': []}, id: 'p-64'), isTrue);
      expect(
        policy.prayerRestricted(const {
          'categoryIds': ['unknown'],
        }),
        isTrue,
      );
      final menu = buildPrayerCategoryMenu(
        categoryModels(PrayerAccessContent({}, categories)),
        [],
        [],
        allowRestricted: true,
      );
      expect(menu.map((c) => c.id), isNot(contains('deep-64')));
      expect(menu.map((c) => c.id), isNot(contains('missing')));
    },
  );

  test(
    'own/effective/tag/manual/legacy restrictions each survive removing another reason',
    () {
      final content = fixtureContent();
      content.categories['closed']!['prayerIds'] = [];
      final policy = PriestAccessPolicy(content.categories);
      for (final prayer in [
        {'priestOnly': true},
        {'effectivePriestOnly': true},
        {'categoryId': 'closed'},
        {
          'categoryIds': ['closed-child'],
        },
      ]) {
        expect(policy.prayerRestricted(prayer, id: 'shared-private'), isTrue);
      }
      content.categories['closed']!['tags'] = ['closed-tag'];
      expect(
        PriestAccessPolicy(content.categories).prayerRestricted({
          'tags': ['closed-tag'],
        }, id: 'shared-private'),
        isTrue,
      );
      expect(
        content.publicOnly.categories['root']!['prayerIds'],
        contains('shared-private'),
      );
    },
  );
}
