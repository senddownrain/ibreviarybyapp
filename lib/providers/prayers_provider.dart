import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/models/prayer.dart';
import 'package:mybrev_flutter/providers/cache_epoch_provider.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/services/hive_service.dart';

// ── Filter state ──────────────────────────────────────────────────────────────

class PrayersFilter {
  final Set<String> selectedTags;
  final String searchQuery;
  final String? selectedCategoryName;

  const PrayersFilter({
    this.selectedTags = const {},
    this.searchQuery = '',
    this.selectedCategoryName,
  });

  bool get isActive => selectedTags.isNotEmpty || searchQuery.trim().isNotEmpty;

  PrayersFilter copyWith({
    Set<String>? selectedTags,
    String? searchQuery,
    String? selectedCategoryName,
    bool clearCategory = false,
  }) => PrayersFilter(
    selectedTags: selectedTags ?? this.selectedTags,
    searchQuery: searchQuery ?? this.searchQuery,
    selectedCategoryName: clearCategory
        ? null
        : selectedCategoryName ?? this.selectedCategoryName,
  );
}

class PrayersFilterNotifier extends Notifier<PrayersFilter> {
  @override
  PrayersFilter build() => const PrayersFilter();

  void setSearch(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void toggleTag(String tag) {
    final tags = Set<String>.from(state.selectedTags);
    if (tags.contains(tag)) {
      tags.remove(tag);
    } else {
      tags.add(tag);
    }
    state = state.copyWith(selectedTags: tags, clearCategory: true);
  }

  void clearFilters() {
    state = const PrayersFilter();
  }

  void clearTags() {
    state = state.copyWith(selectedTags: const {}, clearCategory: true);
  }

  /// Select a user category: sets selectedTags to the category's tags.
  void selectCategory(String categoryId, List<String> tags, {String? name}) {
    state = state.copyWith(
      selectedTags: Set<String>.from(tags),
      selectedCategoryName: name,
    );
  }
}

// ── Prayers from Hive ─────────────────────────────────────────────────────────

final allPrayersProvider = Provider<List<Prayer>>((ref) {
  ref.watch(cacheEpochProvider);
  final box = HiveService.prayersBox;
  final prayers = <Prayer>[];
  for (final key in box.keys) {
    final raw = box.get(key);
    if (raw == null) continue;
    try {
      prayers.add(
        Prayer.fromMap(Map<String, dynamic>.from(raw), key as String),
      );
    } catch (_) {}
  }
  prayers.sort((a, b) => a.displayTitle.compareTo(b.displayTitle));
  return prayers;
});

final allTagsProvider = Provider<List<String>>((ref) {
  final prayers = ref.watch(allPrayersProvider);
  final tags = <String>{};
  for (final p in prayers) {
    tags.addAll(p.tags);
  }
  final sorted = tags.toList()..sort();
  return sorted;
});

final prayersFilterProvider =
    NotifierProvider<PrayersFilterNotifier, PrayersFilter>(
      PrayersFilterNotifier.new,
    );

final filteredPrayersProvider = Provider<List<Prayer>>((ref) {
  final prayers = ref.watch(allPrayersProvider);
  final filter = ref.watch(prayersFilterProvider);
  final favoriteIds = ref.watch(
    settingsProvider.select((settings) => settings.favoriteIds),
  );

  return filterAndSortPrayers(prayers, filter, favoriteIds);
});

/// Mirrors the web prayer list: selected tags use OR semantics, search checks
/// both the resolved title and plain prayer text, and favorites stay on top.
List<Prayer> filterAndSortPrayers(
  List<Prayer> prayers,
  PrayersFilter filter,
  List<String> favoriteIds,
) {
  final favorites = favoriteIds.toSet();

  final filtered = prayers.where((p) {
    if (filter.selectedTags.isNotEmpty) {
      final hasTag = p.tags.any((t) => filter.selectedTags.contains(t));
      if (!hasTag) return false;
    }
    final query = filter.searchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      final title = p.displayTitle.toLowerCase();
      final text = p.displayText
          .replaceAll(RegExp(r'<[^>]*>'), '')
          .toLowerCase();
      if (!title.contains(query) && !text.contains(query)) return false;
    }
    return true;
  }).toList();

  filtered.sort((a, b) {
    final aFavorite = favorites.contains(a.id);
    final bFavorite = favorites.contains(b.id);
    if (aFavorite != bFavorite) return aFavorite ? -1 : 1;
    return _comparePrayerTitles(a.displayTitle, b.displayTitle);
  });

  return filtered;
}

int _comparePrayerTitles(String a, String b) {
  final titleA = a.trim().toLowerCase();
  final titleB = b.trim().toLowerCase();
  final alphabetDifference = _alphabetRank(titleA) - _alphabetRank(titleB);
  return alphabetDifference != 0
      ? alphabetDifference
      : titleA.compareTo(titleB);
}

// Belarusian locale collation keeps Cyrillic prayer titles before Latin ones.
// Dart has no browser-style Intl.Collator, so preserve that visible behavior
// explicitly before applying the stable alphabetical comparison.
int _alphabetRank(String value) {
  if (value.isEmpty) return 2;
  final first = value.runes.first;
  if (first >= 0x0400 && first <= 0x052f) return 0;
  if ((first >= 0x0041 && first <= 0x005a) ||
      (first >= 0x0061 && first <= 0x007a) ||
      (first >= 0x00c0 && first <= 0x024f)) {
    return 1;
  }
  return 2;
}
