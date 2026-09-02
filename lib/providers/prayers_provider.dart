import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/models/prayer.dart';
import 'package:mybrev_flutter/providers/cache_epoch_provider.dart';
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

  bool get isActive => selectedTags.isNotEmpty || searchQuery.isNotEmpty;

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

  if (!filter.isActive) return prayers;

  return prayers.where((p) {
    if (filter.selectedTags.isNotEmpty) {
      final hasTag = p.tags.any((t) => filter.selectedTags.contains(t));
      if (!hasTag) return false;
    }
    if (filter.searchQuery.isNotEmpty) {
      final q = filter.searchQuery.toLowerCase();
      if (!p.displayTitle.toLowerCase().contains(q)) return false;
    }
    return true;
  }).toList();
});
