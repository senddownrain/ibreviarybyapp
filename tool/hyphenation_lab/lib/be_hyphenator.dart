import 'package:flutter/services.dart' show rootBundle;

/// Belarusian hyphenation: Liang's algorithm over the `hyph-be` TeX patterns
/// (Maksim Salau, MIT licence, based on the 2008 orthography law no. 420-Z and
/// the OpenOffice dictionary by A. Bulojchyk / S. Liasovich).
///
/// The patterns are loaded from the TeX source shipped as an asset, so the
/// licence header travels with the data. Nothing here touches the network.
///
/// On top of the raw patterns this class applies *typographic* guards the TeX
/// file does not know about (see [hyphenationPoints]).
class BelarusianHyphenator {
  BelarusianHyphenator._(this._patterns, this._maxPatternLength);

  final Map<String, List<int>> _patterns;
  final int _maxPatternLength;

  int get patternCount => _patterns.length;

  static Future<BelarusianHyphenator> loadAsset([
    String asset = 'assets/patterns/hyph-be.tex',
  ]) async => BelarusianHyphenator.fromTex(await rootBundle.loadString(asset));

  factory BelarusianHyphenator.fromTex(String tex) {
    final start = tex.indexOf(r'\patterns{');
    if (start < 0) throw const FormatException('no \\patterns block');
    final end = tex.indexOf('\n}', start);
    final body = tex
        .substring(start + r'\patterns{'.length, end)
        .split('\n')
        .map((l) => l.contains('%') ? l.substring(0, l.indexOf('%')) : l)
        .join(' ');
    final patterns = <String, List<int>>{};
    var longest = 0;
    for (final raw in body.split(RegExp(r'\s+'))) {
      if (raw.isEmpty) continue;
      final letters = StringBuffer();
      final weights = <int>[0];
      for (final unit in raw.runes) {
        final ch = String.fromCharCode(unit);
        final digit = int.tryParse(ch);
        if (digit != null) {
          weights[weights.length - 1] = digit;
        } else {
          letters.write(ch);
          weights.add(0);
        }
      }
      final key = letters.toString();
      patterns[key] = weights;
      if (key.length > longest) longest = key.length;
    }
    return BelarusianHyphenator._(patterns, longest);
  }

  static const _apostrophes = {"'", '’', 'ʼ', '`', '´'};
  static final _word = RegExp("^[А-Яа-яЁёІіЎўЬьЫыЭэ'’ʼ\\-]+\$");
  static const _vowels = 'аеёіоуыэюя';

  /// Is [word] something this hyphenator is allowed to touch at all?
  static bool isHyphenatable(String word) =>
      _word.hasMatch(word) && !_isShoutedAcronym(word);

  static bool _isShoutedAcronym(String w) =>
      w.length > 1 && w == w.toUpperCase() && w != w.toLowerCase();

  /// Raw Liang result: offsets (1..length-1) *before which* a break is legal.
  List<int> _liang(String lower) {
    final w = '.$lower.';
    final weights = List<int>.filled(w.length + 1, 0);
    for (var i = 0; i < w.length; i++) {
      final maxLen = (w.length - i).clamp(0, _maxPatternLength);
      for (var len = 1; len <= maxLen; len++) {
        final p = _patterns[w.substring(i, i + len)];
        if (p == null) continue;
        for (var k = 0; k < p.length; k++) {
          if (p[k] > weights[i + k]) weights[i + k] = p[k];
        }
      }
    }
    // weights[j] sits between w[j-1] and w[j]; w has a leading '.', so the
    // gap before original char c (0-based) is weights[c + 1].
    final result = <int>[];
    for (var c = 1; c < lower.length; c++) {
      if (weights[c + 1].isOdd) result.add(c);
    }
    return result;
  }

  /// Break offsets inside [word] (each is an index into [word] where a hyphen
  /// may be inserted *before* that character), after typographic guards:
  ///
  /// * [minLeft]/[minRight] letters stay on either side (no single letters,
  ///   no 2-letter tails by default);
  /// * never next to an apostrophe or an existing hyphen-minus;
  /// * never before `ь`, never splitting `дж`, `дз` (one sound) — the TeX file
  ///   usually respects this, the guard is a safety net;
  /// * a fragment must contain a vowel (so no consonant-only stubs);
  /// * words with digits/Latin/acronyms are not hyphenated at all.
  List<int> hyphenationPoints(
    String word, {
    int minLeft = 2,
    int minRight = 3,
    int minWordLength = 6,
  }) {
    if (word.length < minWordLength || !isHyphenatable(word)) return const [];
    final normalised = word
        .split('')
        .map((c) => _apostrophes.contains(c) ? "'" : c.toLowerCase())
        .join();

    // Hyphenate each hyphen-minus separated part independently, break after
    // the hyphen itself (rule: a compound may be split after its dash).
    if (word.contains('-')) {
      final points = <int>[];
      var offset = 0;
      for (final part in word.split('-')) {
        for (final p in hyphenationPoints(
          part,
          minLeft: minLeft,
          minRight: minRight,
          minWordLength: minWordLength,
        )) {
          points.add(offset + p);
        }
        offset += part.length + 1;
        if (offset < word.length && part.length >= 2) points.add(offset);
      }
      return points;
    }

    final out = <int>[];
    final seenGaps = <int>{};
    for (final p in _liang(normalised)) {
      if (p < minLeft || word.length - p < minRight) continue;
      final before = normalised[p - 1];
      final after = normalised[p];
      if (before == "'" || after == "'" || after == 'ь') continue;
      if (before == 'д' && (after == 'з' || after == 'ж')) continue;
      // Every fragment keeps at least one vowel: only the earliest legal
      // break between two vowels is used (no "го-д-ныя", "ця-р-п-лі").
      final vowelsBefore = _countVowels(normalised.substring(0, p));
      if (vowelsBefore == 0 || vowelsBefore == _countVowels(normalised))
        continue;
      if (!seenGaps.add(vowelsBefore)) continue;
      out.add(p);
    }
    // No one-letter fragment between two breaks ("гва-е-цца").
    for (var i = out.length - 1; i > 0; i--) {
      if (out[i] - out[i - 1] < 2) out.removeAt(i);
    }
    return out;
  }

  static int _countVowels(String s) =>
      s.split('').where(_vowels.contains).length;

  /// Debug/test helper: `благаслаўленне` → `бла-га-сла-ўлен-не`.
  String visualise(
    String word, {
    String sep = '-',
    int minLeft = 2,
    int minRight = 3,
  }) {
    final pts = hyphenationPoints(word, minLeft: minLeft, minRight: minRight);
    final b = StringBuffer();
    for (var i = 0; i < word.length; i++) {
      if (pts.contains(i)) b.write(sep);
      b.write(word[i]);
    }
    return b.toString();
  }
}
