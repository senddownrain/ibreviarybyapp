/// Mirrors the web server's priest-policy.mjs, including tag membership.
/// Broken ancestry and cycles fail closed.
class PriestAccessPolicy {
  PriestAccessPolicy(this.categories);
  final Map<String, Map<String, dynamic>> categories;
  final Map<String, bool> _restricted = {};

  bool categoryRestricted(String id, [Set<String> visiting = const {}]) {
    if (_restricted.containsKey(id)) return _restricted[id]!;
    final category = categories[id];
    if (category == null || visiting.contains(id)) return true;
    final parent = category['parentId']?.toString();
    return _restricted[id] =
        category['priestOnly'] == true ||
        category['effectivePriestOnly'] == true ||
        (parent != null &&
            parent.isNotEmpty &&
            categoryRestricted(parent, {...visiting, id}));
  }

  bool prayerRestricted(Map prayer) {
    if (prayer['priestOnly'] == true || prayer['effectivePriestOnly'] == true) {
      return true;
    }
    final tags = (prayer['tags'] as List?) ?? const [];
    for (final entry in categories.entries) {
      if (categoryRestricted(entry.key) &&
          ((entry.value['tags'] as List?) ?? const []).any(tags.contains)) {
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
