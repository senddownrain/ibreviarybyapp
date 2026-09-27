// Faithful Dart port of MyBrev `src/utils/songChords.js`.
//
// Transposition only changes the displayed chord column. It never mutates or
// persists the song's stored `chord` text.

import 'package:mybrev_flutter/models/song.dart';

/// How minor chords are rendered after transposition.
enum ChordNotation {
  /// Legacy songbook style: minor chords are written in lowercase (`e`, `f#`).
  lowercase,

  /// Explicit `m` suffix (`Em`, `F#m`).
  standard,
}

enum ChordAccidentals { auto, sharps, flats }

const kMinTranspose = -12;
const kMaxTranspose = 12;

const _sharps = [
  'C',
  'C#',
  'D',
  'D#',
  'E',
  'F',
  'F#',
  'G',
  'G#',
  'A',
  'A#',
  'B',
];
const _flats = [
  'C',
  'Db',
  'D',
  'Eb',
  'E',
  'F',
  'Gb',
  'G',
  'Ab',
  'A',
  'Bb',
  'B',
];
const _pitch = {
  'C': 0,
  'D': 2,
  'E': 4,
  'F': 5,
  'G': 7,
  'A': 9,
  'B': 11,
  'H': 11,
};

final _chord = RegExp(
  r'^([A-Ha-h])([#♯b♭]?)(maj|min|sus|dim|aug|add|m|M|ø|°|\+|-)?(\d{0,2})'
  r'(?:\([^\s()]*\))?(?:[#♯b♭]\d{1,2})*(?:\/([A-Ha-h])([#♯b♭]?))?$',
);
final _chordInRun = RegExp(
  r'[A-Ha-h][#♯b♭]?(?:(?:maj|min|sus|dim|aug|add|m|M)\d*|\d+)?'
  r'(?:\([^\s()]*\))?(?:[#♯b♭]\d{1,2})*(?:\/[A-Ha-h][#♯b♭]?)?',
);
final _run = RegExp(r'[^\s\[\],;|]+');
final _runPrefix = RegExp(r'^[(!]+');
final _runSuffix = RegExp(r'[)!?.:]+$');
final _minorQuality = RegExp(r'^(?:min|m(?!aj)|-)');
final _slashBass = RegExp(r'\/([A-Ha-h])([#♯b♭]?)$');
final _flatAccidental = RegExp(r'[b♭]');

String _transposeRoot(String root, String accidental, int steps, bool flats) {
  final offset = accidental == '#' || accidental == '♯'
      ? 1
      : accidental == 'b' || accidental == '♭'
      ? -1
      : 0;
  final notes = flats ? _flats : _sharps;
  return notes[((_pitch[root.toUpperCase()]! + offset + steps) % 12 + 12) % 12];
}

/// Transposes one chord token. Non-chords are returned unchanged.
String transposeChord(
  String chord, [
  int steps = 0,
  ChordNotation notation = ChordNotation.lowercase,
  ChordAccidentals accidentalStyle = ChordAccidentals.auto,
]) {
  final match = _chord.firstMatch(chord);
  if (match == null) return chord;
  final root = match.group(1)!;
  final accidental = match.group(2) ?? '';
  final quality = match.group(3) ?? '';
  final minor =
      root == root.toLowerCase() ||
      quality == 'm' ||
      quality == 'min' ||
      quality == '-';
  final flats =
      accidentalStyle == ChordAccidentals.flats ||
      (accidentalStyle == ChordAccidentals.auto &&
          _flatAccidental.hasMatch(accidental));
  var suffix = chord.substring(root.length + accidental.length);
  if (minor && _minorQuality.hasMatch(suffix)) {
    suffix = suffix.replaceFirst(_minorQuality, '');
  }
  suffix = suffix.replaceFirstMapped(
    _slashBass,
    (bass) =>
        '/${_transposeRoot(bass.group(1)!, bass.group(2) ?? '', steps, flats)}',
  );
  var note = _transposeRoot(root, accidental, steps, flats);
  if (minor) {
    note = notation == ChordNotation.lowercase
        ? note.toLowerCase()
        : '${note}m';
  }
  return note + suffix;
}

/// Transposes only complete chord runs. Words in the legacy chord column are
/// lyrics (for example a chorus) and survive unchanged. Compact runs such as
/// `DGea` and slash chords such as `D/F#` are supported.
String transposeChordLine(
  String line, [
  int steps = 0,
  ChordNotation notation = ChordNotation.lowercase,
  ChordAccidentals accidentalStyle = ChordAccidentals.auto,
]) {
  String convert(String chord) =>
      transposeChord(chord, steps, notation, accidentalStyle);

  return line.replaceAllMapped(_run, (match) {
    final run = match.group(0)!;
    if (_chord.hasMatch(run)) return convert(run);
    final prefix = _runPrefix.firstMatch(run)?.group(0) ?? '';
    final suffix = _runSuffix.firstMatch(run)?.group(0) ?? '';
    final end = run.length - suffix.length;
    final middle = end > prefix.length ? run.substring(prefix.length, end) : '';
    if (_chord.hasMatch(middle)) return prefix + convert(middle) + suffix;
    final chords = _chordInRun
        .allMatches(middle)
        .map((chord) => chord.group(0)!)
        .toList(growable: false);
    if (chords.isEmpty ||
        chords.join() != middle ||
        chords.any((chord) => !_chord.hasMatch(chord))) {
      return run;
    }
    return prefix + chords.map(convert).join(' ') + suffix;
  });
}

/// One rendered song row: lyric line N paired with chord line N.
class SongLine {
  const SongLine({required this.text, required this.chord});

  final String text;
  final String chord;

  @override
  bool operator ==(Object other) =>
      other is SongLine && other.text == text && other.chord == chord;

  @override
  int get hashCode => Object.hash(text, chord);

  @override
  String toString() => 'SongLine($text | $chord)';
}

/// Pairs lyric and chord columns line by line, keeping blank lines and any
/// overflow chord rows (MyBrev `songLines`).
List<SongLine> songLines({String text = '', String chord = ''}) {
  final lyrics = text.replaceAll(RegExp(r'\r\n?'), '\n').split('\n');
  final chords = chord.replaceAll(RegExp(r'\r\n?'), '\n').split('\n');
  final length = lyrics.length > chords.length ? lyrics.length : chords.length;
  return [
    for (var index = 0; index < length; index++)
      SongLine(
        text: index < lyrics.length ? lyrics[index] : '',
        chord: index < chords.length ? chords[index] : '',
      ),
  ];
}

final Expando<String> _searchIndex = Expando('songSearchIndex');
final Expando<List<int>> _sortKeys = Expando('songSortKey');

String _searchTextOf(Song song) => _searchIndex[song] ??= [
  song.title,
  song.text,
  ...song.displayTags,
].join('\u0000').toLowerCase();

/// Search, tag and favorites filter with MyBrev semantics:
/// * the query matches title, lyrics or any resolved tag (case-insensitive);
/// * selected tags use OR semantics;
/// * favorites sort first, then titles in Belarusian alphabetical order.
List<Song> filterSongs(
  Iterable<Song> songs, {
  String query = '',
  Set<String> tags = const {},
  Iterable<String> favorites = const [],
  bool favoritesOnly = false,
}) {
  final needle = query.trim().toLowerCase();
  final favoriteSet = favorites.toSet();
  final result = songs
      .where(
        (song) =>
            (!favoritesOnly || favoriteSet.contains(song.id)) &&
            (tags.isEmpty || song.displayTags.any(tags.contains)) &&
            (needle.isEmpty || _searchTextOf(song).contains(needle)),
      )
      .toList();
  result.sort((a, b) {
    final aFavorite = favoriteSet.contains(a.id);
    final bFavorite = favoriteSet.contains(b.id);
    if (aFavorite != bFavorite) return aFavorite ? -1 : 1;
    return compareSongs(a, b);
  });
  return result;
}

int compareSongs(Song a, Song b) {
  final byTitle = _compareKeys(
    _sortKeys[a] ??= belarusianSortKey(a.title),
    _sortKeys[b] ??= belarusianSortKey(b.title),
  );
  if (byTitle != 0) return byTitle;
  final raw = a.title.trim().compareTo(b.title.trim());
  return raw != 0 ? raw : a.id.compareTo(b.id);
}

/// Compares titles like `localeCompare(…, 'be', {sensitivity: 'base'})`:
/// case-insensitive, Belarusian letter order (Ё after Е, І after И, Ў after
/// У), Cyrillic before Latin, punctuation and digits before letters.
int compareBelarusianTitles(String a, String b) =>
    _compareKeys(belarusianSortKey(a), belarusianSortKey(b));

int _compareKeys(List<int> a, List<int> b) {
  final length = a.length < b.length ? a.length : b.length;
  for (var i = 0; i < length; i++) {
    final difference = a[i] - b[i];
    if (difference != 0) return difference;
  }
  return a.length - b.length;
}

const _cyrillicOrder =
    'аәбвгґдђѓеёєжҗзѕиіїйјкқлљмнңњоөпрстћќуўүұфхһцчҷџшщъыьэюя';
const _latinOrder = 'abcdefghijklmnopqrstuvwxyz';

final Map<int, int> _letterRanks = {
  for (var i = 0; i < _cyrillicOrder.length; i++)
    _cyrillicOrder.codeUnitAt(i): 1000 + i,
  for (var i = 0; i < _latinOrder.length; i++)
    _latinOrder.codeUnitAt(i): 2000 + i,
};

List<int> belarusianSortKey(String value) {
  final key = <int>[];
  for (final rune in value.trim().toLowerCase().runes) {
    final letter = _letterRanks[rune];
    if (letter != null) {
      key.add(letter);
    } else if (rune >= 0x30 && rune <= 0x39) {
      key.add(500 + rune - 0x30);
    } else if (rune == 0x20 || rune == 0xa0 || rune == 0x09) {
      key.add(1);
    } else if (rune < 0x80 ||
        (rune >= 0x2000 && rune <= 0x206f) ||
        rune == 0xab ||
        rune == 0xbb) {
      // Punctuation and symbols precede digits and letters.
      key.add(10 + (rune % 400));
    } else {
      key.add(3000 + rune);
    }
  }
  return key;
}
