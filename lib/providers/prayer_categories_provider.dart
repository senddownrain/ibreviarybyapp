import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/content/content_store.dart';
import 'package:mybrev_flutter/providers/cache_epoch_provider.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/services/hive_service.dart';

const kPrayerCategoriesCollection = 'prayerCategories';

class PrayerMenuCategory {
  final String id;
  final String name;
  final List<String> tags;
  final bool isGlobal;

  const PrayerMenuCategory({
    required this.id,
    required this.name,
    required this.tags,
    required this.isGlobal,
  });

  factory PrayerMenuCategory.global(String id, Map data) {
    return PrayerMenuCategory(
      id: id,
      name: data['name']?.toString().trim() ?? '',
      tags: _cleanTags(data['tags']),
      isGlobal: true,
    );
  }

  factory PrayerMenuCategory.personal(UserCategory category) =>
      PrayerMenuCategory(
        id: category.id,
        name: category.name,
        tags: category.tags,
        isGlobal: false,
      );
}

List<String> _cleanTags(dynamic value) {
  if (value is! Iterable) return const [];
  return value
      .map((tag) => tag.toString().trim())
      .where((tag) => tag.isNotEmpty)
      .toSet()
      .toList();
}

/// Categories of the Prayerbook from the app's content (bundled, kept
/// current by the content update), ordered by `order`, then by name.
final globalPrayerCategoriesProvider = StreamProvider<List<PrayerMenuCategory>>(
  (ref) async* {
    ref.watch(cacheEpochProvider);
    await ContentStore.instance.ensureLoaded(const [
      kPrayerCategoriesCollection,
    ]);
    final box = HiveService.prayerCategoriesBox;
    final documents = [
      for (final key in box.keys)
        if (box.get(key) case final Map data) (key, data),
    ];
    double order(Map data) =>
        (data['order'] is num ? (data['order'] as num).toDouble() : null) ??
        double.maxFinite;
    documents.sort((left, right) {
      final byOrder = order(left.$2).compareTo(order(right.$2));
      if (byOrder != 0) return byOrder;
      return (left.$2['name']?.toString() ?? '').toLowerCase().compareTo(
        (right.$2['name']?.toString() ?? '').toLowerCase(),
      );
    });
    yield documents
        .map((item) => PrayerMenuCategory.global(item.$1, item.$2))
        .where((category) => category.name.isNotEmpty)
        .toList(growable: false);
  },
);

/// Combines database-managed defaults with local user customizations.
/// Global categories win on duplicate names, matching the web application.
final prayerMenuCategoriesProvider = Provider<List<PrayerMenuCategory>>((ref) {
  final settings = ref.watch(settingsProvider);
  final globalCategories =
      ref.watch(globalPrayerCategoriesProvider).value ?? [];
  return buildPrayerCategoryMenu(
    globalCategories,
    settings.userCategories,
    settings.hiddenGlobalPrayerCategoryIds,
  );
});

List<PrayerMenuCategory> buildPrayerCategoryMenu(
  List<PrayerMenuCategory> globalCategories,
  List<UserCategory> personalCategories,
  List<String> hiddenGlobalCategoryIds,
) {
  final hiddenIds = hiddenGlobalCategoryIds.toSet();
  final names = <String>{};
  final result = <PrayerMenuCategory>[];

  for (final category in globalCategories) {
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

  return result;
}
