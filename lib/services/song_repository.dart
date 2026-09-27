import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:mybrev_flutter/models/song.dart';

/// Reads the bundled initial songbook and the synced `songs` Hive cache.
///
/// The bundled seed is parsed lazily the first time the songbook is opened;
/// it never runs in the startup path.
class SongRepository {
  const SongRepository._();

  static const seedAsset = 'assets/songs_seed.json';
  static const boxName = 'songs';

  static Future<List<Map<String, dynamic>>> loadSeed([
    AssetBundle? bundle,
  ]) async {
    final raw = await (bundle ?? rootBundle).loadString(seedAsset);
    return parseSeed(raw);
  }

  static List<Map<String, dynamic>> parseSeed(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return [
      for (final item in decoded)
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  }

  /// Synced Firestore documents. Returns an empty list when the cache is not
  /// open (for example in isolated widget tests).
  static List<Map<String, dynamic>> readCached() {
    if (!Hive.isBoxOpen(boxName)) return const [];
    final box = Hive.box(boxName);
    return [
      for (final key in box.keys)
        if (box.get(key) case final Map value)
          {...Map<String, dynamic>.from(value), 'id': key.toString()},
    ];
  }

  /// Saved documents override bundled songs by ID field by field, and new
  /// server songs are appended (MyBrev `getSavedSongs`). Documents without a
  /// title are dropped rather than shown as blank rows.
  static List<Song> merge(
    List<Map<String, dynamic>> seed,
    List<Map<String, dynamic>> cached,
  ) {
    final merged = <String, Map<String, dynamic>>{
      for (final song in seed)
        if (song['id'] != null) song['id'].toString(): song,
    };
    for (final doc in cached) {
      final id = doc['id']?.toString();
      if (id == null || id.isEmpty) continue;
      merged[id] = {...?merged[id], ...doc, 'id': id};
    }
    return [
      for (final entry in merged.entries) Song.fromMap(entry.value, entry.key),
    ].where((song) => song.title.isNotEmpty).toList(growable: false);
  }
}
