import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/models/song.dart';
import 'package:mybrev_flutter/services/song_repository.dart';
import 'package:mybrev_flutter/utils/song_chords.dart';

const _std = ChordNotation.standard;

void main() {
  group('transposeChord (port of MyBrev song-chords.test.mjs)', () {
    test('roots, lowercase minors, suffixes and slash bass', () {
      expect(transposeChord('e', 2), 'f#');
      expect(transposeChord('Am7', 2, _std), 'Bm7');
      expect(transposeChord('D/F#', -2), 'C/E');
      expect(transposeChord('B♭', 2), 'C');
      expect(
        transposeChord('Gsus4', 1, _std, ChordAccidentals.flats),
        'Absus4',
      );
      expect(transposeChord('H7', 1), 'C7');
      expect(transposeChord('Cmaj7', 2), 'Dmaj7');
      expect(transposeChord('F#m7b5', 2, _std), 'G#m7b5');
      expect(transposeChord('d', 0, _std), 'Dm');
      expect(transposeChord('C', -12), 'C');
      expect(transposeChord('слова', 2), 'слова');
    });

    test('major chords move by semitones', () {
      expect(transposeChord('C', 1), 'C#');
      expect(transposeChord('G', 5), 'C');
      expect(transposeChord('A', -2), 'G');
      expect(transposeChord('E7', 1), 'F7');
    });

    test('minor forms: lowercase, m, min and dash', () {
      expect(transposeChord('a', 3), 'c');
      expect(transposeChord('Am', 3), 'c');
      expect(transposeChord('Am', 3, _std), 'Cm');
      expect(transposeChord('Amin', 2, _std), 'Bm');
      expect(transposeChord('A-', 2, _std), 'Bm');
      expect(transposeChord('A-7', 2), 'b7');
    });

    test('H is B natural and B is B natural', () {
      expect(transposeChord('H', 0), 'B');
      expect(transposeChord('B', 1), 'C');
      expect(transposeChord('h', 2), 'c#');
    });

    test('sharps, flats and Unicode accidentals', () {
      expect(transposeChord('F#', 1), 'G');
      expect(transposeChord('C#m', 1, _std), 'Dm');
      expect(transposeChord('Eb', 2), 'F');
      expect(transposeChord('Eb', 1), 'E');
      expect(transposeChord('Ab', 1), 'A');
      expect(transposeChord('Bb', 1), 'B');
      expect(transposeChord('Db', 1), 'D');
      expect(transposeChord('Eb', 3), 'Gb', reason: 'flat input keeps flats');
      expect(transposeChord('F♯', 1), 'G');
      expect(transposeChord('E♭', 3), 'Gb');
      expect(transposeChord('C', 1, _std, ChordAccidentals.flats), 'Db');
      expect(transposeChord('Eb', 1, _std, ChordAccidentals.sharps), 'E');
      expect(transposeChord('Eb', 3, _std, ChordAccidentals.sharps), 'F#');
    });

    test('slash bass transposes independently', () {
      expect(transposeChord('C/E', 2), 'D/F#');
      expect(transposeChord('G/H', 2), 'A/C#');
      expect(transposeChord('a/g', 2), 'b/A');
      expect(transposeChord('Bb/D', 2), 'C/E');
    });

    test('+12 and -12 return the original pitch', () {
      for (final chord in ['C', 'e', 'F#m7', 'D/F#', 'Bb', 'H7']) {
        expect(transposeChord(chord, 12), transposeChord(chord, 0));
        expect(transposeChord(chord, -12), transposeChord(chord, 0));
      }
      expect(transposeChord('D', 12), 'D');
      expect(transposeChord('e', -12), 'e');
    });
  });

  group('transposeChordLine', () {
    test(
      'compact progressions transpose; chorus words and punctuation stay',
      () {
        expect(
          transposeChordLine('DG ea D/F# (B♭ A7)', 2),
          'E A f# b E/G# (C B7)',
        );
        expect(
          transposeChordLine('Adonai, Adonai!\n. (x2) ›', 3),
          'Adonai, Adonai!\n. (x2) ›',
        );
        expect(
          transposeChordLine('C7(b9) Dm7(b5) (G C)', 2, _std),
          'D7(b9) Em7(b5) (A D)',
        );
      },
    );

    test('compact chord run DGea', () {
      expect(transposeChordLine('DGea', 2), 'E A f# b');
      expect(transposeChordLine('DGea', 0), 'D G e a');
    });

    test('non-chord words remain unchanged', () {
      for (final line in [
        'Алілуя, алілуя!',
        'Adonai, Adonai',
        'Прыпеў:',
        'Ave Maria',
        'Bog',
        'x2',
      ]) {
        expect(transposeChordLine(line, 5), line);
      }
      // Like MyBrev, a word spelled only with chord letters is a chord run.
      expect(transposeChordLine('Bad', 2), 'C# b e');
      expect(transposeChordLine('G D Прыпеў', 2), 'A E Прыпеў');
    });

    test('whitespace and separators are preserved', () {
      expect(transposeChordLine('  C   G | a, F', 2), '  D   A | b, G');
    });

    test('original input is never mutated', () {
      const song = Song(id: 's', title: 'T', text: 'Радок', chord: 'C G');
      final original = song.chord;
      final shown = transposeChordLine(song.chord, 7);
      expect(shown, 'G D');
      expect(song.chord, original);
      expect(song.chord, 'C G');
    });
  });

  group('songLines', () {
    test('keeps blank lines and overflow chord rows', () {
      expect(songLines(text: 'Першы\r\n\r\nТрэці', chord: 'C\n\nG\nAm'), [
        const SongLine(text: 'Першы', chord: 'C'),
        const SongLine(text: '', chord: ''),
        const SongLine(text: 'Трэці', chord: 'G'),
        const SongLine(text: '', chord: 'Am'),
      ]);
    });

    test('missing chords yield lyric-only rows', () {
      expect(songLines(text: 'А\nБ'), [
        const SongLine(text: 'А', chord: ''),
        const SongLine(text: 'Б', chord: ''),
      ]);
    });
  });

  group('categories and normalization', () {
    test('numeric export categories map to names', () {
      expect(songCategoryIds('2,3,4'), [2, 3, 4]);
      expect(songCategoryIds(6), [6]);
      expect(songCategoryIds(['1', 1, '9', 99, '', 'bad']), [1, 9]);
      expect(songCategoryIds(''), isEmpty);
      expect(songCategoryIds(null), isEmpty);
      expect(kSongCategories, hasLength(10));
      final song = Song.fromMap({
        'title': 'Песня',
        'text': 'Тэкст',
        'tag': '2,3,4',
      }, 'id');
      expect(song.tag, [2, 3, 4]);
      expect(song.displayTags, ['Эўхарыстычныя', 'Праслаўленне', 'Пакланенне']);
    });

    test('category and custom tags merge without duplicates', () {
      final song = Song.fromMap({
        'title': 'Святы',
        'text': 'Святы, святы',
        'tag': [10],
        'tags': ['Часткі Імшы', ' Уваход ', '', 'Уваход'],
      }, 'x');
      expect(song.displayTags, ['Часткі Імшы', 'Уваход']);
    });

    test('robust against missing chord, empty tags and CRLF', () {
      final song = Song.fromMap({
        'title': '  Назва ',
        'text': 'А\r\nБ\rВ',
        'tag': null,
        'tags': null,
      }, 'id');
      expect(song.title, 'Назва');
      expect(song.text, 'А\nБ\nВ');
      expect(song.chord, '');
      expect(song.hasChords, isFalse);
      expect(song.tag, isEmpty);
      expect(song.tags, isEmpty);
      expect(song.source, '');
    });
  });

  group('filterSongs', () {
    const songs = [
      Song(id: '1', title: 'А', text: 'Надзея', tags: ['Дух']),
      Song(id: '2', title: 'Б', text: 'Надзея', tags: ['Марыя']),
      Song(id: '3', title: 'В', text: 'Любоў', tags: ['Дух']),
    ];
    List<String> ids(List<Song> list) => [for (final s in list) s.id];

    test('favorite songs sort first', () {
      expect(ids(filterSongs(songs, favorites: ['3'])), ['3', '1', '2']);
    });

    test('search and tags combine while favorites remain a sort key', () {
      expect(
        ids(
          filterSongs(songs, query: 'НАДЗЕЯ', tags: {'Дух'}, favorites: ['1']),
        ),
        ['1'],
      );
    });

    test('title, text and tag search', () {
      expect(ids(filterSongs(songs, query: 'б')), ['2', '3']);
      expect(ids(filterSongs(songs, query: 'любоў')), ['3']);
      expect(ids(filterSongs(songs, query: 'Марыя')), ['2']);
      final categorized = Song.fromMap({
        'title': 'Песня',
        'text': 'Тэкст',
        'tag': '2,3,4',
      }, 'c');
      expect(filterSongs([categorized], query: 'пакланенне'), hasLength(1));
    });

    test('multi-tag filter uses OR semantics', () {
      expect(ids(filterSongs(songs, tags: {'Дух', 'Марыя'})), ['1', '2', '3']);
      expect(ids(filterSongs(songs, tags: {'Марыя'})), ['2']);
      expect(filterSongs(songs, tags: {'Калядныя'}), isEmpty);
    });

    test('favorites never hide songs', () {
      expect(ids(filterSongs(songs, favorites: ['3'])), ['3', '1', '2']);
      expect(ids(filterSongs(songs, tags: {'Дух'}, favorites: ['2'])), [
        '1',
        '3',
      ]);
    });

    test('alphabetical order follows the Belarusian alphabet', () {
      const unordered = [
        Song(id: 'lat', title: 'Ave Maria'),
        Song(id: 'u', title: 'Ўсё'),
        Song(id: 'f', title: 'Фатыма'),
        Song(id: 'yo', title: 'Ёсць'),
        Song(id: 'ye', title: 'Ехаў'),
        Song(id: 'zh', title: 'Жыццё'),
        Song(id: 'i', title: 'Імя'),
        Song(id: 'k', title: 'Каралева'),
        Song(id: 'a', title: 'алілуя'),
        Song(id: 'b', title: 'Бог'),
        Song(id: 'q', title: '«Будзь»'),
      ];
      expect(ids(filterSongs(unordered)), [
        'q',
        'a',
        'b',
        'ye',
        'yo',
        'zh',
        'i',
        'k',
        'u',
        'f',
        'lat',
      ]);
      expect(compareBelarusianTitles('У', 'Ў'), lessThan(0));
      expect(compareBelarusianTitles('Ў', 'Ф'), lessThan(0));
      expect(compareBelarusianTitles('а', 'А'), 0);
    });
  });

  group('bundled seed', () {
    test('contains all 447 songs with unique IDs, text and categories', () {
      final seed = decodeContentCollection(
        File('assets/content/songs.json.gz').readAsBytesSync(),
      ).docs.values.toList();
      final songs = SongRepository.merge(seed, const []);
      expect(songs, hasLength(447));
      expect({for (final s in songs) s.id}, hasLength(447));
      expect(songs.every((s) => s.text.trim().isNotEmpty), isTrue);
      expect(songs.where((s) => s.tag.contains(10)), hasLength(11));
      expect(filterSongs(songs, tags: {'Часткі Імшы'}), hasLength(11));
      expect(
        songs.firstWhere((s) => s.title == 'LAUDATE OMNES GENTES').displayTags,
        ['Эўхарыстычныя'],
      );
    });

    test('saved documents override by ID and new songs are appended', () {
      final seed = [
        {'id': 'a', 'title': 'Першы', 'text': 'Стары', 'chord': 'C'},
        {'id': 'b', 'title': 'Другі', 'text': 'Тэкст'},
      ];
      final merged = SongRepository.merge(seed, [
        {'id': 'a', 'text': 'Новы'},
        {'id': 'n', 'title': 'Новая', 'text': 'З сервера'},
      ]);
      final byId = {for (final s in merged) s.id: s};
      expect(byId.keys, containsAll(['a', 'b', 'n']));
      expect(byId['a']!.text, 'Новы');
      expect(byId['a']!.chord, 'C', reason: 'unset fields keep seed values');
      expect(byId['a']!.title, 'Першы');
      expect(seed.first['text'], 'Стары', reason: 'seed is not mutated');
    });
  });
}
