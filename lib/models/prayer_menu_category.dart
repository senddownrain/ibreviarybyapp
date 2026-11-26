import 'package:mybrev_flutter/constants/prayer_category_icons.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';

class PrayerMenuCategory {
  final String id;
  final String name;
  final List<String> tags;
  final bool isGlobal;
  final bool priestOnly;
  final List<String> effectiveAccessSets;
  final String? parentId;
  final List<String> prayerIds;
  final double? order;
  final String? icon;
  final String? iconId;
  final PrayerCategoryComment? comment;

  /// Stored icon key (may be null or unknown); draw with [displayIconKey].
  final String? iconKey;

  const PrayerMenuCategory({
    required this.id,
    required this.name,
    required this.tags,
    required this.isGlobal,
    this.priestOnly = false,
    this.effectiveAccessSets = const [],
    this.parentId,
    this.prayerIds = const [],
    this.order,
    this.icon,
    this.iconId,
    this.iconKey,
    this.comment,
  });

  /// The key to draw: the stored one, or a deterministic suggestion until the
  /// category has one (e.g. a global category not yet migrated in Firestore).
  String get displayIconKey =>
      displayCategoryIconKey(iconKey: iconKey, id: id, name: name, tags: tags);

  bool get isProtected => priestOnly || effectiveAccessSets.isNotEmpty;

  String get readerName =>
      isProtected &&
          (parentId == null || parentId!.isEmpty) &&
          name == 'Для святара' &&
          (effectiveAccessSets.isEmpty ||
              (effectiveAccessSets.length == 1 &&
                  effectiveAccessSets.single == 'priest'))
      ? 'Для святароў'
      : name;

  factory PrayerMenuCategory.global(String id, Map data) {
    return PrayerMenuCategory(
      id: id,
      name: data['name']?.toString().trim() ?? '',
      tags: _cleanTags(data['tags']),
      isGlobal: true,
      priestOnly:
          data['priestOnly'] == true || data['effectivePriestOnly'] == true,
      effectiveAccessSets: _cleanTags(data['effectiveAccessSets']),
      parentId: data['parentId']?.toString(),
      prayerIds: _cleanTags(data['prayerIds']),
      order: data['order'] is num && (data['order'] as num).isFinite
          ? (data['order'] as num).toDouble()
          : null,
      icon: data['icon']?.toString(),
      iconId: data['iconId']?.toString(),
      iconKey: data['iconKey'] is String ? data['iconKey'] as String : null,
      comment: PrayerCategoryComment.fromCategory(data),
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

class PrayerCategoryComment {
  const PrayerCategoryComment({
    required this.content,
    this.title,
    this.sourceId,
  });

  final String content;
  final String? title;
  final String? sourceId;

  static PrayerCategoryComment? fromCategory(Map category) {
    final raw = category['comment'];
    if (raw is! Map || _unpublished(category) || _unpublished(raw)) return null;
    final content = raw['content'];
    if (content is! String || content.trim().isEmpty) return null;
    return PrayerCategoryComment(
      content: content,
      title: _nonblankString(raw['title']),
      sourceId: _nonblankString(raw['sourceId']),
    );
  }

  static bool _unpublished(Map document) =>
      document['published'] == false ||
      const {
        'draft',
        'pending',
        'review',
        'rejected',
        'archived',
      }.contains(_nonblankString(document['status'])?.toLowerCase());

  static String? _nonblankString(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

List<String> _cleanTags(dynamic value) {
  if (value is! Iterable) return const [];
  return value
      .map((tag) => tag.toString().trim())
      .where((tag) => tag.isNotEmpty)
      .toSet()
      .toList();
}
