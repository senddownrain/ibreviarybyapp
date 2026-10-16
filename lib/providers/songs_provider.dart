import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:mybrev_flutter/models/song.dart';
import 'package:mybrev_flutter/providers/cache_epoch_provider.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/services/song_repository.dart';
import 'package:mybrev_flutter/utils/song_chords.dart';
import 'package:mybrev_flutter/analytics/local_analytics.dart'
    show analyticsFeature;

// ── Data ─────────────────────────────────────────────────────────────────────

/// The songs of the app's content, decoded on first use of the songbook.
final songSeedProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  ref.watch(cacheEpochProvider);
  return SongRepository.loadSeed();
});

final songsProvider = Provider<AsyncValue<List<Song>>>(
  (ref) => ref
      .watch(songSeedProvider)
      .whenData((docs) => SongRepository.merge(docs, const [])),
);

final songByIdProvider = Provider.family<AsyncValue<Song?>, String>(
  (ref, id) => ref
      .watch(songsProvider)
      .whenData((songs) => songs.where((song) => song.id == id).firstOrNull),
);

/// All filterable tags: category names plus custom tags, alphabetical.
final songTagsProvider = Provider<List<String>>((ref) {
  final songs = ref.watch(songsProvider).valueOrNull ?? const <Song>[];
  final tags = {for (final song in songs) ...song.displayTags}.toList()
    ..sort(compareBelarusianTitles);
  return tags;
});

// ── Search and filter ────────────────────────────────────────────────────────

class SongsFilter {
  const SongsFilter({this.searchQuery = '', this.selectedTags = const {}});

  final String searchQuery;
  final Set<String> selectedTags;
  bool get isActive => searchQuery.trim().isNotEmpty || selectedTags.isNotEmpty;

  int get filterCount => selectedTags.length;

  SongsFilter copyWith({String? searchQuery, Set<String>? selectedTags}) =>
      SongsFilter(
        searchQuery: searchQuery ?? this.searchQuery,
        selectedTags: selectedTags ?? this.selectedTags,
      );
}

class SongsFilterNotifier extends Notifier<SongsFilter> {
  @override
  SongsFilter build() => const SongsFilter();

  void setSearch(String query) => state = state.copyWith(searchQuery: query);

  void toggleTag(String tag) {
    final tags = {...state.selectedTags};
    if (!tags.remove(tag)) tags.add(tag);
    state = state.copyWith(selectedTags: tags);
  }

  void clearFilters() => state = state.copyWith(selectedTags: const {});
}

final songsFilterProvider = NotifierProvider<SongsFilterNotifier, SongsFilter>(
  SongsFilterNotifier.new,
);

final filteredSongsProvider = Provider<AsyncValue<List<Song>>>((ref) {
  final filter = ref.watch(songsFilterProvider);
  final favorites = ref.watch(
    songPreferencesProvider.select((prefs) => prefs.favoriteSongIds),
  );
  return ref
      .watch(songsProvider)
      .whenData(
        (songs) => filterSongs(
          songs,
          query: filter.searchQuery,
          tags: filter.selectedTags,
          favorites: favorites,
        ),
      );
});

// ── Local preferences ────────────────────────────────────────────────────────

enum SongChordLayout {
  above('above', 'Над радкамі'),
  right('right', 'Справа ад тэксту');

  const SongChordLayout(this.storageValue, this.label);
  final String storageValue;
  final String label;

  /// The side layout used to be stored as `left` (and, in MyBrev, `right`);
  /// both now mean [right]. Anything else falls back to [above].
  static SongChordLayout parse(Object? value) =>
      value == 'right' || value == 'left' ? right : above;
}

class SongPreferences {
  const SongPreferences({
    this.favoriteSongIds = const [],
    this.showChords = false,
    this.chordLayout = SongChordLayout.above,
  });

  /// Songbook favorites, independent from prayer `favoriteIds`.
  final List<String> favoriteSongIds;
  final bool showChords;

  /// Preferred layout. [SongChordLayout.right] may render above lines at
  /// runtime when the width is too small; the preference itself is kept.
  final SongChordLayout chordLayout;

  SongPreferences copyWith({
    List<String>? favoriteSongIds,
    bool? showChords,
    SongChordLayout? chordLayout,
  }) => SongPreferences(
    favoriteSongIds: favoriteSongIds ?? this.favoriteSongIds,
    showChords: showChords ?? this.showChords,
    chordLayout: chordLayout ?? this.chordLayout,
  );
}

/// Device-local songbook preferences stored in the Hive `settings` box.
/// Nothing here is synchronized to Firestore.
class SongPreferencesNotifier extends Notifier<SongPreferences> {
  static const favoritesKey = 'favoriteSongIds';
  static const showChordsKey = 'songShowChords';
  static const chordLayoutKey = 'songChordLayout';

  /// Removed setting (the list is always compact). A stored value from an
  /// older version is ignored and deleted on first read.
  static const legacyCompactListKey = 'songCompactList';

  Box? get _box => HiveService.isSettingsReady ? HiveService.settingsBox : null;

  @override
  SongPreferences build() {
    final box = _box;
    if (box == null) return const SongPreferences();
    List<String> favorites;
    try {
      favorites = List<String>.from(
        jsonDecode(box.get(favoritesKey, defaultValue: '[]') as String) as List,
      );
    } catch (_) {
      favorites = const [];
    }
    final storedLayout = box.get(chordLayoutKey);
    final layout = SongChordLayout.parse(storedLayout);
    // Migrations: `left` → `right`, drop the compact-list flag. Idempotent:
    // once the box is normalized nothing is written again, and a failed
    // write never prevents the preferences from being read.
    try {
      if (storedLayout != null && storedLayout != layout.storageValue) {
        box.put(chordLayoutKey, layout.storageValue);
      }
      if (box.containsKey(legacyCompactListKey)) {
        box.delete(legacyCompactListKey);
      }
    } catch (_) {
      // The stored values are still read safely on the next start.
    }
    return SongPreferences(
      favoriteSongIds: favorites,
      showChords: box.get(showChordsKey, defaultValue: false) == true,
      chordLayout: layout,
    );
  }

  bool isFavorite(String id) => state.favoriteSongIds.contains(id);

  void toggleFavorite(String id) {
    final favorites = [...state.favoriteSongIds];
    if (favorites.remove(id)) {
      analyticsFeature('favorite_remove');
    } else {
      favorites.add(id);
      analyticsFeature('favorite_add');
    }
    state = state.copyWith(favoriteSongIds: favorites);
    _box?.put(favoritesKey, jsonEncode(favorites));
  }

  void setShowChords(bool value) {
    if (state.showChords != value) analyticsFeature('chords_toggle');
    state = state.copyWith(showChords: value);
    _box?.put(showChordsKey, value);
  }

  void setChordLayout(SongChordLayout layout) {
    if (state.chordLayout != layout) analyticsFeature('chord_layout_change');
    state = state.copyWith(chordLayout: layout);
    _box?.put(chordLayoutKey, layout.storageValue);
  }
}

final songPreferencesProvider =
    NotifierProvider<SongPreferencesNotifier, SongPreferences>(
      SongPreferencesNotifier.new,
    );
