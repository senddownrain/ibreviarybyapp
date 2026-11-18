import 'package:mybrev_flutter/services/prayer_category_membership.dart';

const kMaxPrayerCategoryDepth = 64;

/// Mirrors the Web contract. Invalid ancestry and overlapping restrictions
/// fail closed; a cached parent must never bypass the full path depth check.
class PriestAccessPolicy {
  PriestAccessPolicy(this.categories);
  final Map<String, Map<String, dynamic>> categories;
  final Map<String, bool> _restricted = {};
  final Map<String, bool> _valid = {};

  bool categoryValid(String id) {
    if (_valid.containsKey(id)) return _valid[id]!;
    final seen = <String>{};
    var current = id;
    while (true) {
      final category = categories[current];
      if (category == null ||
          !seen.add(current) ||
          seen.length > kMaxPrayerCategoryDepth) {
        return _valid[id] = false;
      }
      final parent = category['parentId']?.toString();
      if (parent == null || parent.isEmpty) return _valid[id] = true;
      current = parent;
    }
  }

  bool categoryRestricted(String id) {
    if (_restricted.containsKey(id)) return _restricted[id]!;
    if (!categoryValid(id)) return _restricted[id] = true;
    var current = id;
    while (true) {
      final category = categories[current]!;
      if (category['priestOnly'] == true ||
          category['effectivePriestOnly'] == true) {
        return _restricted[id] = true;
      }
      final parent = category['parentId']?.toString();
      if (parent == null || parent.isEmpty) return _restricted[id] = false;
      current = parent;
    }
  }

  bool prayerRestricted(Map prayer, {String? id}) {
    if (prayer['priestOnly'] == true || prayer['effectivePriestOnly'] == true) {
      return true;
    }
    final prayerId = id ?? prayer['id']?.toString() ?? '';
    for (final entry in categories.entries) {
      if (categoryRestricted(entry.key) &&
          matchesPrayerCategory(
            prayerId: prayerId,
            prayerTags: (prayer['tags'] as List?) ?? const [],
            prayerCategoryId: prayer['categoryId']?.toString(),
            prayerCategoryIds: (prayer['categoryIds'] as List?) ?? const [],
            categoryId: entry.key,
            categoryTags: (entry.value['tags'] as List?) ?? const [],
            categoryPrayerIds: (entry.value['prayerIds'] as List?) ?? const [],
          )) {
        return true;
      }
    }
    final ids = [prayer['categoryId'], ...?prayer['categoryIds'] as List?];
    return ids
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .any(categoryRestricted);
  }
}
