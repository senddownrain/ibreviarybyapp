import 'package:mybrev_flutter/models/prayer.dart';
import 'package:mybrev_flutter/models/prayer_menu_category.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';

/// The Web contract's direct union. Descendants never expand membership.
/// Callers supply the document ID, even when the document has no `id` field.
bool matchesPrayerCategory({
  required String prayerId,
  required Iterable prayerTags,
  String? prayerCategoryId,
  Iterable prayerCategoryIds = const [],
  required String categoryId,
  Iterable categoryTags = const [],
  Iterable categoryPrayerIds = const [],
}) =>
    categoryTags.any(prayerTags.contains) ||
    categoryPrayerIds.contains(prayerId) ||
    prayerCategoryId == categoryId ||
    prayerCategoryIds.contains(categoryId);

bool prayerBelongsToCategory(
  Prayer prayer,
  PrayerMenuCategory category,
  SettingsState settings,
) {
  if (!category.isGlobal) {
    // Personal manual links remain exclusively in the user's local settings.
    if (settings.prayerCategoryMap[prayer.id]?.contains(category.id) == true) {
      return true;
    }
    final tags = category.tags.map((tag) => tag.trim().toLowerCase()).toSet();
    return prayer.categoryId == category.id ||
        prayer.categoryIds.contains(category.id) ||
        prayer.tags.any((tag) => tags.contains(tag.trim().toLowerCase()));
  }
  return matchesPrayerCategory(
    prayerId: prayer.id,
    prayerTags: prayer.tags,
    prayerCategoryId: prayer.categoryId,
    prayerCategoryIds: prayer.categoryIds,
    categoryId: category.id,
    categoryTags: category.tags,
    categoryPrayerIds: category.prayerIds,
  );
}

List<Prayer> prayersForCategory(
  List<Prayer> prayers,
  PrayerMenuCategory category,
  SettingsState settings,
) {
  final direct = {
    for (final prayer in prayers)
      if (prayerBelongsToCategory(prayer, category, settings))
        prayer.id: prayer,
  };
  if (category.isProtected &&
      (category.parentId == null || category.parentId!.isEmpty) &&
      category.prayerIds.isNotEmpty &&
      direct.keys.every(category.prayerIds.contains)) {
    return category.prayerIds
        .map((id) => direct[id])
        .whereType<Prayer>()
        .toList(growable: false);
  }
  return direct.values.toList(growable: false);
}
