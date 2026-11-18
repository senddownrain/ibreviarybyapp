import 'package:mybrev_flutter/models/prayer_menu_category.dart';

// Dart has no Intl.Collator. Explicit Belarusian alphabet weights keep ё, і,
// й and ў in their locale positions; case/accents compare at base sensitivity.
const _alphabet = 'абвгдеёжзійклмнопрстуўфхцчшыьэюя';
String _collationKey(String value) {
  final lower = value.toLowerCase().replaceAll(RegExp('[\u0300-\u036f]'), '');
  return String.fromCharCodes(
    lower.runes.map((rune) {
      final rank = _alphabet.indexOf(String.fromCharCode(rune));
      return rank < 0 ? rune + 256 : rank + 256;
    }),
  );
}

int comparePrayerCategories(PrayerMenuCategory left, PrayerMenuCategory right) {
  final a = left.order?.isFinite == true ? left.order : null;
  final b = right.order?.isFinite == true ? right.order : null;
  if (a != b) {
    if (a == null) return 1;
    if (b == null) return -1;
    return a.compareTo(b);
  }
  final name = _collationKey(left.name).compareTo(_collationKey(right.name));
  return name != 0 ? name : left.id.compareTo(right.id);
}

class PrayerCategoryNode {
  PrayerCategoryNode(this.category);
  final PrayerMenuCategory category;
  final List<PrayerCategoryNode> children = [];
}

/// Resolve any permitted category, including promoted children and personal roots.
PrayerCategoryNode? findPrayerCategoryNode(
  Iterable<PrayerCategoryNode> tree,
  String id,
) {
  for (final node in tree) {
    if (node.category.id == id) return node;
    final child = findPrayerCategoryNode(node.children, id);
    if (child != null) return child;
  }
  return null;
}

/// Input is access-filtered, then user-hidden. Only the latter may promote
/// children to roots. Never call this on an unvalidated canonical graph.
List<PrayerCategoryNode> buildPrayerCategoryTree(
  List<PrayerMenuCategory> categories,
) {
  final nodes = {
    for (final category in categories.where((c) => c.isGlobal))
      category.id: PrayerCategoryNode(category),
  };
  final roots = <PrayerCategoryNode>[];
  for (final node in nodes.values) {
    final parent = nodes[node.category.parentId];
    if (parent == null) {
      roots.add(node);
    } else {
      parent.children.add(node);
    }
  }
  int compare(PrayerCategoryNode a, PrayerCategoryNode b) =>
      comparePrayerCategories(a.category, b.category);
  roots.sort(compare);
  for (final node in nodes.values) {
    node.children.sort(compare);
  }
  return [
    ...roots,
    for (final category in categories.where((c) => !c.isGlobal))
      PrayerCategoryNode(category),
  ];
}
