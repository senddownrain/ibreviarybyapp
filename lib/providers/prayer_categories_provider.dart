import 'package:mybrev_flutter/models/prayer.dart';
import 'package:mybrev_flutter/models/prayer_menu_category.dart';
import 'package:mybrev_flutter/providers/prayers_provider.dart';
import 'package:mybrev_flutter/services/prayer_category_tree.dart';
export 'package:mybrev_flutter/models/prayer_menu_category.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/content/content_store.dart';
import 'package:mybrev_flutter/providers/cache_epoch_provider.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/providers/priest_access_provider.dart';
import 'package:mybrev_flutter/services/priest_access_policy.dart';

const kPrayerCategoriesCollection = 'prayerCategories';

/// Categories of the Prayerbook from the app's content (bundled, kept
/// current by the content update), ordered by `order`, then by name.
final globalPrayerCategoriesProvider = StreamProvider<List<PrayerMenuCategory>>(
  (ref) async* {
    ref.watch(cacheEpochProvider);
    final access = ref.watch(priestAccessProvider);
    await ContentStore.instance.ensureLoaded(const [
      kPrayerCategoriesCollection,
    ]);
    final box = HiveService.prayerCategoriesBox;
    final source =
        access.content?.categories ??
        access.publicContent?.categories ??
        {
          for (final key in box.keys)
            if (box.get(key) case final Map data)
              key: Map<String, dynamic>.from(data),
        };
    yield projectPrayerCategories(
      source,
      allowRestricted: access.content != null,
    );
  },
);

List<PrayerMenuCategory> projectPrayerCategories(
  Map<String, Map<String, dynamic>> source, {
  required bool allowRestricted,
}) {
  final policy = PriestAccessPolicy(source);
  return [
    for (final id in source.keys)
      ?_projectCategory(policy, id, allowRestricted),
  ]..sort(comparePrayerCategories);
}

PrayerMenuCategory? _projectCategory(
  PriestAccessPolicy policy,
  String id,
  bool allowRestricted,
) {
  if (!policy.categoryPublished(id)) return null;
  final restricted = policy.categoryRestricted(id);
  if (restricted && !allowRestricted) return null;
  final category = PrayerMenuCategory.global(id, {
    ...policy.categories[id]!,
    'effectivePriestOnly': restricted,
  });
  return category.name.isEmpty ? null : category;
}

/// Combines database-managed defaults with local user customizations.
/// Global categories win on duplicate names, matching the web application.
final prayerMenuCategoriesProvider = Provider<List<PrayerMenuCategory>>((ref) {
  final settings = ref.watch(settingsProvider);
  final globalCategories =
      ref.watch(visibleGlobalPrayerCategoriesProvider).value ?? [];
  return buildPrayerCategoryMenu(
    globalCategories,
    settings.userCategories,
    settings.hiddenGlobalPrayerCategoryIds,
    permittedPrayers: ref.watch(prayerCatalogProvider),
    settings: settings,
    allowRestricted: ref.watch(priestAccessProvider).content != null,
  );
});

// Riverpod retains the previous stream value while a new catalog is emitted.
// Gate that value against today's access before any screen can render it.
final visibleGlobalPrayerCategoriesProvider =
    Provider<AsyncValue<List<PrayerMenuCategory>>>((ref) {
      final access = ref.watch(priestAccessProvider);
      final categories = ref.watch(globalPrayerCategoriesProvider);
      final source = (access.content ?? access.publicContent)?.categories;
      final policy = source == null ? null : PriestAccessPolicy(source);
      if (policy == null) {
        return categories.whenData(
          (items) => items.where((item) => !item.isProtected).toList(),
        );
      }
      return categories.whenData(
        (items) => [
          for (final item in items)
            if (!item.isProtected &&
                policy.categoryPublished(item.id) &&
                !policy.categoryRestricted(item.id))
              item
            else
              ?_projectCategory(policy, item.id, access.content != null),
        ],
      );
    });

List<PrayerMenuCategory> buildPrayerCategoryMenu(
  List<PrayerMenuCategory> globalCategories,
  List<UserCategory> personalCategories,
  List<String> hiddenGlobalCategoryIds, {
  List<Prayer>? permittedPrayers,
  SettingsState settings = const SettingsState(),
  bool allowRestricted = false,
}) {
  final hiddenIds = hiddenGlobalCategoryIds.toSet();
  final names = <String>{};
  final result = <PrayerMenuCategory>[];
  final policy = PriestAccessPolicy({
    for (final category in globalCategories)
      category.id: {
        'parentId': category.parentId,
        'priestOnly': category.isProtected,
      },
  });

  for (final category in globalCategories) {
    if (!policy.categoryValid(category.id) ||
        (!allowRestricted && policy.categoryRestricted(category.id))) {
      continue;
    }
    if (hiddenIds.contains(category.id)) continue;
    final nameKey = category.name.toLowerCase();
    names.add(nameKey);
    result.add(category);
  }

  for (final category in personalCategories) {
    final nameKey = category.name.toLowerCase();
    if (!names.add(nameKey)) continue;
    result.add(PrayerMenuCategory.personal(category));
  }

  if (permittedPrayers == null) return result;
  final byId = {
    for (final category in result.where((c) => c.isGlobal))
      category.id: category,
  };
  final visible = <String>{};
  for (final category in byId.values) {
    if (!category.isProtected &&
        category.comment == null &&
        prayersForCategory(permittedPrayers, category, settings).isEmpty) {
      continue;
    }
    var current = category;
    final seen = <String>{};
    while (seen.add(current.id)) {
      visible.add(current.id);
      final parent = byId[current.parentId];
      if (parent == null) break;
      current = parent;
    }
  }
  return result
      .where(
        (category) => category.isGlobal
            ? visible.contains(category.id)
            : prayersForCategory(
                permittedPrayers,
                category,
                settings,
              ).isNotEmpty,
      )
      .toList(growable: false);
}
