import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:mybrev_flutter/models/song.dart';
import 'package:mybrev_flutter/models/sync_plan.dart';
import 'package:mybrev_flutter/providers/cache_epoch_provider.dart';
import 'package:mybrev_flutter/providers/connectivity_provider.dart';
import 'package:mybrev_flutter/providers/sync_provider.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/services/song_repository.dart';
import 'package:mybrev_flutter/utils/song_chords.dart';

// ── Data ─────────────────────────────────────────────────────────────────────

/// Bundled initial songs, parsed on first use of the songbook.
final songSeedProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) => SongRepository.loadSeed(),
);

/// Songs saved by the `songs` SyncTarget.
final cachedSongDocsProvider = Provider<List<Map<String, dynamic>>>((ref) {
  ref.watch(cacheEpochProvider);
  return SongRepository.readCached();
});

/// Bundled seed merged with synced documents. When the seed cannot be read,
/// synced documents alone remain available offline.
final songsProvider = Provider<AsyncValue<List<Song>>>((ref) {
  final seed = ref.watch(songSeedProvider);
  final cached = ref.watch(cachedSongDocsProvider);
  return switch (seed) {
    AsyncData(:final value) => AsyncData(SongRepository.merge(value, cached)),
    AsyncError(:final error, :final stackTrace) =>
      cached.isEmpty
          ? AsyncError(error, stackTrace)
          : AsyncData(SongRepository.merge(const [], cached)),
    _ => const AsyncLoading(),
  };
});

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
  const SongsFilter({
    this.searchQuery = '',
    this.selectedTags = const {},
    this.favoritesOnly = false,
  });

  final String searchQuery;
  final Set<String> selectedTags;
  final bool favoritesOnly;

  bool get isActive =>
      searchQuery.trim().isNotEmpty || selectedTags.isNotEmpty || favoritesOnly;

  int get filterCount => selectedTags.length + (favoritesOnly ? 1 : 0);

  SongsFilter copyWith({
    String? searchQuery,
    Set<String>? selectedTags,
    bool? favoritesOnly,
  }) => SongsFilter(
    searchQuery: searchQuery ?? this.searchQuery,
    selectedTags: selectedTags ?? this.selectedTags,
    favoritesOnly: favoritesOnly ?? this.favoritesOnly,
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

  void setFavoritesOnly(bool value) =>
      state = state.copyWith(favoritesOnly: value);

  void clearFilters() =>
      state = state.copyWith(selectedTags: const {}, favoritesOnly: false);
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
          favoritesOnly: filter.favoritesOnly,
        ),
      );
});

// ── Local preferences ────────────────────────────────────────────────────────

enum SongChordLayout {
  above('above', 'Над радкамі'),
  left('left', 'Злева ад тэксту');

  const SongChordLayout(this.storageValue, this.label);
  final String storageValue;
  final String label;

  /// Legacy MyBrev `right` values are treated as the side layout.
  static SongChordLayout parse(Object? value) =>
      value == 'left' || value == 'right' ? left : above;
}

class SongPreferences {
  const SongPreferences({
    this.favoriteSongIds = const [],
    this.showChords = false,
    this.chordLayout = SongChordLayout.above,
    this.compactList = false,
  });

  /// Songbook favorites, independent from prayer `favoriteIds`.
  final List<String> favoriteSongIds;
  final bool showChords;
  final SongChordLayout chordLayout;
  final bool compactList;

  SongPreferences copyWith({
    List<String>? favoriteSongIds,
    bool? showChords,
    SongChordLayout? chordLayout,
    bool? compactList,
  }) => SongPreferences(
    favoriteSongIds: favoriteSongIds ?? this.favoriteSongIds,
    showChords: showChords ?? this.showChords,
    chordLayout: chordLayout ?? this.chordLayout,
    compactList: compactList ?? this.compactList,
  );
}

/// Device-local songbook preferences stored in the Hive `settings` box.
/// Nothing here is synchronized to Firestore.
class SongPreferencesNotifier extends Notifier<SongPreferences> {
  static const favoritesKey = 'favoriteSongIds';
  static const showChordsKey = 'songShowChords';
  static const chordLayoutKey = 'songChordLayout';
  static const compactListKey = 'songCompactList';

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
    return SongPreferences(
      favoriteSongIds: favorites,
      showChords: box.get(showChordsKey, defaultValue: false) == true,
      chordLayout: SongChordLayout.parse(box.get(chordLayoutKey)),
      compactList: box.get(compactListKey, defaultValue: false) == true,
    );
  }

  bool isFavorite(String id) => state.favoriteSongIds.contains(id);

  void toggleFavorite(String id) {
    final favorites = [...state.favoriteSongIds];
    if (!favorites.remove(id)) favorites.add(id);
    state = state.copyWith(favoriteSongIds: favorites);
    _box?.put(favoritesKey, jsonEncode(favorites));
  }

  void setShowChords(bool value) {
    state = state.copyWith(showChords: value);
    _box?.put(showChordsKey, value);
  }

  void setChordLayout(SongChordLayout layout) {
    state = state.copyWith(chordLayout: layout);
    _box?.put(chordLayoutKey, layout.storageValue);
  }

  void setCompactList(bool value) {
    state = state.copyWith(compactList: value);
    _box?.put(compactListKey, value);
  }
}

final songPreferencesProvider =
    NotifierProvider<SongPreferencesNotifier, SongPreferences>(
      SongPreferencesNotifier.new,
    );

// ── Opportunistic refresh ────────────────────────────────────────────────────

/// Called when the songbook is opened. If the device is online and songs
/// were not synced during the last day, queue a background, cancellable
/// `songs`-only sync. Bundled songs remain visible meanwhile.
final songbookRefreshProvider = Provider<void Function()>((ref) {
  return () {
    if (ref.read(isOfflineProvider)) return;
    if (!Hive.isBoxOpen('meta')) return;
    final last = HiveService.getLastSync(SyncTarget.songs.collection);
    if (last != null &&
        DateTime.now().difference(last) < const Duration(days: 1)) {
      return;
    }
    ref
        .read(syncStatusProvider.notifier)
        .synchronize(
          const SyncPlan(
            targets: {SyncTarget.songs},
            forceRefresh: false,
            background: true,
          ),
        );
  };
});
