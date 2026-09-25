import 'package:flutter/foundation.dart';

/// Canonical numeric song categories (MyBrev `TAGS_LIST`).
///
/// The Firestore `songCategories` collection mirrors these definitions, but
/// the app does not read it: the ten categories are stable and bundled, so the
/// songbook works fully offline without a second cache target.
@immutable
class SongCategory {
  const SongCategory(this.id, this.title);

  final int id;
  final String title;
}

const kSongCategories = <SongCategory>[
  SongCategory(1, 'Да Духа'),
  SongCategory(2, 'Эўхарыстычныя'),
  SongCategory(3, 'Праслаўленне'),
  SongCategory(4, 'Пакланенне'),
  SongCategory(5, 'Пілігрымкавыя'),
  SongCategory(6, 'Марыйныя'),
  SongCategory(7, 'Калядныя'),
  SongCategory(8, 'Постныя'),
  SongCategory(9, 'Велікодныя'),
  SongCategory(10, 'Часткі Імшы'),
];

final Map<int, String> _categoryTitles = {
  for (final category in kSongCategories) category.id: category.title,
};

/// Port of MyBrev `songCategoryIds`: accepts an array, a single number or a
/// comma-separated export string (`'2,3,4'`) and keeps only known IDs.
List<int> songCategoryIds(Object? tag) {
  final values = tag is Iterable
      ? tag.toList()
      : (tag?.toString() ?? '').split(',');
  final ids = <int>{};
  for (final value in values) {
    final number = value is num ? value : num.tryParse('$value'.trim());
    if (number == null || number != number.roundToDouble()) continue;
    final id = number.toInt();
    if (_categoryTitles.containsKey(id)) ids.add(id);
  }
  return ids.toList(growable: false);
}

String _normalizeLines(Object? value) =>
    (value?.toString() ?? '').replaceAll(RegExp(r'\r\n?'), '\n');

List<String> _customTags(Object? value) {
  if (value is! Iterable) return const [];
  final tags = <String>{};
  for (final tag in value) {
    final trimmed = '$tag'.trim();
    if (tag != null && trimmed.isNotEmpty) tags.add(trimmed);
  }
  return tags.toList(growable: false);
}

/// Public, read-only song document (Firestore collection `songs`).
///
/// Lyrics and chords are stored separately; chord line N belongs to lyric
/// line N, including blank lines.
@immutable
class Song {
  const Song({
    required this.id,
    required this.title,
    this.text = '',
    this.chord = '',
    this.tag = const [],
    this.tags = const [],
    this.source = '',
  });

  /// Robust port of MyBrev `normalizeSong`: missing chords, empty or string
  /// category values and CRLF line endings are accepted.
  factory Song.fromMap(Map<String, dynamic> map, [String? id]) => Song(
    id: id ?? map['id']?.toString() ?? '',
    title: (map['title']?.toString() ?? '').trim(),
    text: _normalizeLines(map['text']),
    chord: _normalizeLines(map['chord']),
    tag: songCategoryIds(map['tag']),
    tags: _customTags(map['tags']),
    source: (map['source']?.toString() ?? '').trim(),
  );

  final String id;
  final String title;
  final String text;
  final String chord;

  /// Numeric category IDs from [kSongCategories].
  final List<int> tag;

  /// Additional free-form tags.
  final List<String> tags;
  final String source;

  bool get hasChords => chord.trim().isNotEmpty;

  /// Category names followed by custom tags, without duplicates
  /// (MyBrev `getSongTags`).
  List<String> get displayTags => {
    for (final id in tag) _categoryTitles[id]!,
    ...tags,
  }.toList(growable: false);
}
