import 'package:mybrev_flutter/content/content_store.dart';
import 'package:mybrev_flutter/models/song.dart';

/// The songbook from the app's content (bundled, kept current by the
/// content update). Decoded the first time the songbook is opened.
class SongRepository {
  const SongRepository._();

  static const collection = 'songs';

  static Future<List<Map<String, dynamic>>> loadSeed() async {
    final store = ContentStore.instance;
    await store.ensureLoaded(const [collection]);
    final songs = store.collection(collection);
    return [
      for (final key in songs.keys)
        if (songs.get(key) case final Map value)
          {...Map<String, dynamic>.from(value), 'id': key},
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
