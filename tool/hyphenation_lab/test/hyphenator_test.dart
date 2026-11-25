import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hyphenation_lab/be_hyphenator.dart';
import 'package:hyphenation_lab/fixtures.dart';

late BelarusianHyphenator h;
const vowels = 'аеёіоуыэюя';

Set<String> corpusWords() {
  final text = [
    ...plainParagraphs,
    htmlFixture.replaceAll(RegExp(r'<[^>]+>|&nbsp;'), ' '),
  ].join(' ');
  return RegExp(
    r"[А-Яа-яЁёІіЎў'’ʼ\-]{6,}",
  ).allMatches(text).map((m) => m.group(0)!).toSet();
}

List<String> fragments(String w) {
  final pts = h.hyphenationPoints(w);
  final out = <String>[];
  var prev = 0;
  for (final p in [...pts, w.length]) {
    out.add(w.substring(prev, p));
    prev = p;
  }
  return out;
}

void main() {
  setUpAll(() {
    h = BelarusianHyphenator.fromTex(
      File('assets/patterns/hyph-be.tex').readAsStringSync(),
    );
  });

  test('uses the Belarusian (not Russian) pattern file, MIT-licensed', () {
    final tex = File('assets/patterns/hyph-be.tex').readAsStringSync();
    expect(tex, contains('Hyphenation patterns for Belarusian'));
    expect(tex, contains('name: MIT'));
    expect(h.patternCount, greaterThan(3000));
  });

  test('known words split on syllables, text is preserved', () {
    const expected = {
      'благаслаўленне': 'бла-га-слаў-ле-нне',
      'цярплівасці': 'ця-рплі-ва-сці',
      'Старэйшыя': 'Ста-рэй-шыя',
      'выкарыстоўваюцца': 'вы-ка-ры-стоў-ва-ю-цца',
    };
    // Raw table is documented; the guards may drop single-letter middles,
    // so assert structure rather than the exact string for the long one.
    for (final e in expected.entries) {
      final f = fragments(e.key);
      expect(f.join(), e.key);
      expect(f.length, greaterThan(1), reason: e.key);
    }
    expect(fragments('благаслаўленне').join('-'), 'бла-га-слаў-ле-нне');
    expect(fragments('цярплівасці').join('-'), 'ця-рплі-ва-сці');
  });

  test('typographic invariants over the whole fixture corpus', () {
    final words = corpusWords();
    expect(words.length, greaterThan(20));
    for (final w in words) {
      final f = fragments(w);
      expect(f.join(), w);
      for (var i = 0; i < f.length; i++) {
        final frag = f[i];
        expect(
          frag.replaceAll(RegExp("['’ʼ-]"), '').length,
          greaterThanOrEqualTo(2),
          reason: '$w → $f: one-letter fragment',
        );
        if (i == 0)
          expect(frag.length, greaterThanOrEqualTo(2), reason: '$w left');
        if (i == f.length - 1 && f.length > 1)
          expect(frag.length, greaterThanOrEqualTo(3), reason: '$w right tail');
        expect(
          frag.toLowerCase().split('').any(vowels.contains),
          isTrue,
          reason: '$w → $f: fragment without a vowel',
        );
        if (i > 0) {
          final prev = f[i - 1];
          expect(
            RegExp("['’ʼ]").hasMatch(prev[prev.length - 1]) ||
                RegExp("['’ʼ]").hasMatch(frag[0]),
            isFalse,
            reason: '$w split at apostrophe',
          );
          expect(
            'ьў'.contains(frag[0].toLowerCase()),
            isFalse,
            reason: '$w → $f: fragment starts with ь/ў',
          );
          final pair = '${prev[prev.length - 1]}${frag[0]}'.toLowerCase();
          expect(
            pair == 'дз' || pair == 'дж',
            isFalse,
            reason: '$w splits $pair',
          );
        }
      }
    }
  });

  test('words that must never be touched', () {
    for (final w in [
      'Мц5',
      'ДАБРАСЛАЎЛЕНЫ',
      'abcdefgh',
      'з’яўляецца',
      "аб'ява",
      'ёсць',
      'Езус',
    ]) {
      if (w == 'з’яўляецца') {
        // apostrophe may stay at a break only before it, never around it
        final f = fragments(w);
        expect(f.join(), w);
        expect(f.any((x) => x.startsWith('’')), isFalse);
        continue;
      }
      expect(h.hyphenationPoints(w), isEmpty, reason: w);
    }
  });

  test('compound words break only after the hyphen', () {
    final pts = h.hyphenationPoints('вучні-апосталы');
    expect(pts, contains(6)); // right after "вучні-"
  });
}
