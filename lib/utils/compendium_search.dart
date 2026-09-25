// Deterministic local search over the Compendium: a faithful Dart port of
// MyBrev `src/utils/compendiumSearch.js`, so that both apps rank the same
// questions for the same query. Normalisation, field weights, stems, bonuses
// and hidden Russian aliases are documented in docs/compendium.md.

import 'package:mybrev_flutter/models/compendium.dart';
import 'package:mybrev_flutter/utils/compendium_fold_table.dart';

const _latinLookalikes = {
  'a': 'а',
  'e': 'е',
  'i': 'и',
  'o': 'о',
  'p': 'р',
  'c': 'с',
  'x': 'х',
  'y': 'у',
};

final Map<int, int> _fold = {
  for (var i = 0; i < kCompendiumFoldSources.length; i++)
    kCompendiumFoldSources.codeUnitAt(i): kCompendiumFoldTargets.codeUnitAt(i),
};
final _lookalike = RegExp(r'[aeiopcxy](?=[Ѐ-ӿ])|(?<=[Ѐ-ӿ])[aeiopcxy]');
final _iLetters = RegExp('[іi]');
final _dropped = RegExp("[ъ’'ʼ`]");
final _digits = RegExp(r'^\d+$');
final _numberQuery = RegExp(r'^(?:№\s*|#\s*)?(\d{1,4})\.?$', unicode: true);

// Unicode property classes (`\p{M}`, `[^\p{L}\p{N}]`) are slow in Dart's
// regular expressions over long texts, so each code point is classified once
// with the same properties and cached.
final _markPattern = RegExp(r'^\p{M}$', unicode: true);
final _wordPattern = RegExp(r'^[\p{L}\p{N}]$', unicode: true);
final _markCache = <int, bool>{};
final _wordCache = <int, bool>{};
const _space = 0x20;

bool _isMark(int rune) => _markCache[rune] ??= rune < 0x300
    ? false
    : _markPattern.hasMatch(String.fromCharCode(rune));

bool _isWordChar(int rune) => _wordCache[rune] ??=
    (rune >= 0x30 && rune <= 0x39) ||
    (rune >= 0x61 && rune <= 0x7a) ||
    (rune >= 0x430 && rune <= 0x45f) ||
    _wordPattern.hasMatch(String.fromCharCode(rune));

/// Folds text for matching (MyBrev `normalizeSearchText`):
/// - lower case, NFD with combining marks removed (ё→е, й→и, ў→у, stress);
/// - Belarusian/Russian orthographic variants: і→и, э→е, ъ removed;
/// - apostrophes removed (’ ' ʼ `), Latin lookalike letters next to Cyrillic
///   letters → Cyrillic;
/// - every other non-letter/digit becomes a space.
String normalizeCompendiumSearchText(Object? value) {
  final lower = '${value ?? ''}'.toLowerCase();
  // NFD + removal of combining marks.
  final folded = StringBuffer();
  for (final rune in lower.runes) {
    final base = _fold[rune] ?? rune;
    if (!_isMark(base)) folded.writeCharCode(base);
  }
  final text = folded
      .toString()
      .replaceAllMapped(_lookalike, (match) => _latinLookalikes[match[0]]!)
      .replaceAll(_iLetters, 'и')
      .replaceAll('э', 'е')
      .replaceAll(_dropped, '');
  // Every run of non-letters/digits becomes one space, then trim.
  final out = StringBuffer();
  var pendingSpace = false;
  for (final rune in text.runes) {
    if (_isWordChar(rune)) {
      if (pendingSpace && out.isNotEmpty) out.writeCharCode(_space);
      pendingSpace = false;
      out.writeCharCode(rune);
    } else {
      pendingSpace = true;
    }
  }
  return out.toString();
}

List<String> tokenizeCompendiumSearchText(Object? value) {
  final normalized = normalizeCompendiumSearchText(value);
  return normalized.isEmpty ? const [] : normalized.split(' ');
}

/// `"1066-1075"` → `(1066, 1075)`; `"1076"` → `(1076, 1076)`.
(double, double) parseCccRef(String ref) {
  final parts = ref.split('-');
  final from = double.tryParse(parts[0]) ?? double.nan;
  final to = parts.length > 1 ? double.tryParse(parts[1]) ?? double.nan : from;
  return (from, to);
}

/// Hidden Russian → Belarusian aliases:
/// `{schemaVersion: 1, groups: [{ru: [stems], be: [prefixes]}]}`.
/// A query word that starts with a `ru` stem also matches the group's `be`
/// prefixes. Aliases only widen matching and are never displayed.
class CompendiumSearchAliases {
  const CompendiumSearchAliases._(this.groups);

  factory CompendiumSearchAliases.compile(Map<String, dynamic>? aliasFile) {
    final groups = <({List<String> ru, List<String> be})>[];
    final raw = aliasFile?['groups'];
    if (raw is List) {
      for (final group in raw) {
        if (group is! Map) continue;
        List<String> fold(Object? values) => [
          if (values is List)
            for (final value in values) normalizeCompendiumSearchText(value),
        ].where((value) => value.isNotEmpty).toList();
        final entry = (ru: fold(group['ru']), be: fold(group['be']));
        if (entry.ru.isNotEmpty && entry.be.isNotEmpty) groups.add(entry);
      }
    }
    return CompendiumSearchAliases._(List.unmodifiable(groups));
  }

  static const empty = CompendiumSearchAliases._([]);

  final List<({List<String> ru, List<String> be})> groups;

  /// Extra Belarusian prefixes for one normalised query word.
  List<String> expand(String token) {
    final extra = <String>{};
    for (final group in groups) {
      if (group.ru.any(token.startsWith)) extra.addAll(group.be);
    }
    extra.remove(token);
    return extra.toList();
  }
}

enum CompendiumSearchField { number, question, answer, context, refs }

const _fieldWeights = {
  CompendiumSearchField.question: 12.0,
  CompendiumSearchField.answer: 5.0,
  CompendiumSearchField.context: 3.0,
  CompendiumSearchField.refs: 4.0,
};

const _textFields = [
  CompendiumSearchField.question,
  CompendiumSearchField.answer,
  CompendiumSearchField.context,
];

class CompendiumSearchEntry {
  CompendiumSearchEntry._(this.question)
    : questionText = normalizeCompendiumSearchText(question.question),
      answerText = normalizeCompendiumSearchText(question.answer),
      refs = [for (final ref in question.cccRefs) parseCccRef(ref)] {
    final context = [
      question.partTitle,
      question.sectionTitle,
      question.chapterTitle,
      question.topicTitle,
      question.subtopicTitle,
    ].where((value) => value != null && value.isNotEmpty).join(' ');
    words = {
      CompendiumSearchField.question: questionText.split(' ').toSet().toList(),
      CompendiumSearchField.answer: answerText.split(' ').toSet().toList(),
      CompendiumSearchField.context: tokenizeCompendiumSearchText(
        context,
      ).toSet().toList(),
    };
  }

  final CompendiumQuestion question;
  final String questionText;
  final String answerText;
  final List<(double, double)> refs;
  late final Map<CompendiumSearchField, List<String>> words;
}

/// Normalised word lists, precomputed once per dataset (not per keystroke).
class CompendiumSearchIndex {
  CompendiumSearchIndex(
    List<CompendiumQuestion> questions, [
    CompendiumSearchAliases? aliases,
  ]) : aliases = aliases ?? CompendiumSearchAliases.empty,
       entries = List.unmodifiable([
         for (final question in questions) CompendiumSearchEntry._(question),
       ]);

  final List<CompendiumSearchEntry> entries;
  final CompendiumSearchAliases aliases;
}

class CompendiumSearchResult {
  const CompendiumSearchResult({
    required this.question,
    required this.score,
    required this.field,
  });

  final CompendiumQuestion question;
  final double score;

  /// Field of the strongest match; `null` only when nothing scored.
  final CompendiumSearchField? field;
}

/// Light, language-agnostic stemming for inflected Belarusian words.
List<String> _stemVariants(String token) {
  if (_digits.hasMatch(token) || token.length < 4) return const [];
  return [
    token.substring(0, token.length - 1),
    if (token.length >= 7) token.substring(0, token.length - 2),
  ];
}

bool _matchWords(List<String> words, List<String> prefixes) =>
    words.any((word) => prefixes.any((prefix) => word.startsWith(prefix)));

/// Per-field scores of one query word, in field order.
List<(CompendiumSearchField, double)> _scoreToken(
  CompendiumSearchEntry entry,
  String token,
  CompendiumSearchAliases aliases,
) {
  // Pure numbers match Catechism paragraph references (range-aware) only;
  // digits inside Scripture citations would only add noise.
  if (_digits.hasMatch(token)) {
    final number = double.parse(token);
    return entry.refs.any((ref) => number >= ref.$1 && number <= ref.$2)
        ? [
            (
              CompendiumSearchField.refs,
              _fieldWeights[CompendiumSearchField.refs]!,
            ),
          ]
        : const [];
  }
  final alternatives = [
    (prefixes: [token], factor: 1.0),
    (prefixes: aliases.expand(token), factor: 0.85),
    (prefixes: _stemVariants(token), factor: 0.6),
  ].where((alternative) => alternative.prefixes.isNotEmpty);
  final scores = <(CompendiumSearchField, double)>[];
  for (final field in _textFields) {
    final words = entry.words[field]!;
    final alternative = alternatives
        .where((candidate) => _matchWords(words, candidate.prefixes))
        .firstOrNull;
    if (alternative == null) continue;
    // A whole-word hit ranks slightly above a prefix hit.
    final exact = alternative.factor == 1 && words.contains(token);
    scores.add((
      field,
      _fieldWeights[field]! *
          alternative.factor *
          (exact || alternative.factor != 1 ? 1 : 0.9),
    ));
  }
  return scores;
}

/// Searches questions (MyBrev `searchCompendium`). Ranking: the exact question
/// number, then matches in the question text, the answer, the headings and
/// the Catechism references. Every query word must match somewhere (AND).
List<CompendiumSearchResult> searchCompendium(
  CompendiumSearchIndex index,
  String? query, {
  int limit = 200,
}) {
  final raw = (query ?? '').trim();
  final tokens = tokenizeCompendiumSearchText(raw);
  if (tokens.isEmpty) return const [];
  final numberMatch = _numberQuery.firstMatch(raw)?.group(1);
  final numberQuery = numberMatch == null ? null : int.parse(numberMatch);
  final phrase = tokens.join(' ');
  final results = <CompendiumSearchResult>[];

  for (final entry in index.entries) {
    if (numberQuery != null && entry.question.number == numberQuery) {
      results.add(
        CompendiumSearchResult(
          question: entry.question,
          score: 1000,
          field: CompendiumSearchField.number,
        ),
      );
      continue;
    }
    var total = 0.0;
    CompendiumSearchField? bestField;
    var bestFieldScore = 0.0;
    final fieldHits = {for (final field in _fieldWeights.keys) field: 0};
    var matchedAll = true;
    for (final token in tokens) {
      final values = _scoreToken(entry, token, index.aliases);
      if (values.isEmpty) {
        matchedAll = false;
        break;
      }
      final best = values.reduce((a, b) => b.$2 > a.$2 ? b : a);
      // The best field counts fully, other matching fields add a little.
      total +=
          best.$2 +
          values.fold<double>(
            0,
            (sum, value) => sum + (value.$1 == best.$1 ? 0 : value.$2 * 0.25),
          );
      for (final value in values) {
        fieldHits[value.$1] = fieldHits[value.$1]! + 1;
      }
      if (best.$2 > bestFieldScore) {
        bestFieldScore = best.$2;
        bestField = best.$1;
      }
    }
    if (!matchedAll) continue;
    final questionHits = fieldHits[CompendiumSearchField.question]!;
    // Short questions that are "about" the query come first.
    if (questionHits > 0) {
      total +=
          (4 * questionHits) /
          entry.words[CompendiumSearchField.question]!.length;
    }
    if (tokens.length > 1) {
      if (entry.questionText.contains(phrase)) {
        total += 20;
      } else if (entry.answerText.contains(phrase)) {
        total += 8;
      }
      if (questionHits == tokens.length) total += 10;
      if (fieldHits[CompendiumSearchField.context] == tokens.length) {
        total += 8;
      }
    }
    results.add(
      CompendiumSearchResult(
        question: entry.question,
        score: total,
        field: bestField,
      ),
    );
  }

  results.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    return byScore != 0
        ? byScore
        : a.question.number.compareTo(b.question.number);
  });
  return results.length > limit ? results.sublist(0, limit) : results;
}
