import 'package:mybrev_flutter/constants/prayer_category_icons.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';

class PrayerMenuCategory {
  final String id;
  final String name;
  final List<String> tags;
  final bool isGlobal;
  final bool priestOnly;
  final String? parentId;
  final List<String> prayerIds;
  final double? order;
  final String? icon;
  final String? iconId;

  /// Stored icon key (may be null or unknown); draw with [displayIconKey].
  final String? iconKey;

  const PrayerMenuCategory({
    required this.id,
    required this.name,
    required this.tags,
    required this.isGlobal,
    this.priestOnly = false,
    this.parentId,
    this.prayerIds = const [],
    this.order,
    this.icon,
    this.iconId,
    this.iconKey,
  });

  /// The key to draw: the stored one, or a deterministic suggestion until the
  /// category has one (e.g. a global category not yet migrated in Firestore).
  String get displayIconKey =>
      displayCategoryIconKey(iconKey: iconKey, id: id, name: name, tags: tags);

  factory PrayerMenuCategory.global(String id, Map data) {
    return PrayerMenuCategory(
      id: id,
      name: data['name']?.toString().trim() ?? '',
      tags: _cleanTags(data['tags']),
      isGlobal: true,
      priestOnly:
          data['priestOnly'] == true || data['effectivePriestOnly'] == true,
      parentId: data['parentId']?.toString(),
      prayerIds: _cleanTags(data['prayerIds']),
      order: data['order'] is num && (data['order'] as num).isFinite
          ? (data['order'] as num).toDouble()
          : null,
      icon: data['icon']?.toString(),
      iconId: data['iconId']?.toString(),
      iconKey: data['iconKey'] is String ? data['iconKey'] as String : null,
    );
  }

  factory PrayerMenuCategory.personal(UserCategory category) =>
      PrayerMenuCategory(
        id: category.id,
        name: category.name,
        tags: category.tags,
        isGlobal: false,
        iconKey: category.iconKey,
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
