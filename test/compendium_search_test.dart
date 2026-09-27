import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:mybrev_flutter/services/compendium_repository.dart';
import 'package:mybrev_flutter/utils/compendium_data.dart';
import 'package:mybrev_flutter/utils/compendium_search.dart';

/// Search is a port of MyBrev `compendiumSearch.js`; these checks mirror
/// `tests/compendium-search.test.mjs` and compare full rankings with a
/// fixture produced by the JavaScript implementation
/// (`scripts/compendium_search_parity.mjs`).
void main() {
  final dataset = decodeBundledCompendium(
    File(CompendiumRepository.assetPath).readAsBytesSync(),
  );
  final aliasFile =
      jsonDecode(File(CompendiumRepository.aliasesAssetPath).readAsStringSync())
          as Map<String, dynamic>;
  final index = CompendiumIndex(dataset);
  final search = CompendiumSearchIndex(
    index.questions,
    CompendiumSearchAliases.compile(aliasFile),
  );
  List<int> top(String query, [int count = 5]) => searchCompendium(
    search,
    query,
  ).take(count).map((result) => result.question.number).toList();

  group('normalisation', () {
    test('folds Belarusian orthographic variants', () {
      expect(
        normalizeCompendiumSearchText('Эўхарыстыя'),
        normalizeCompendiumSearchText('еухарыстыя'),
      );
      expect(normalizeCompendiumSearchText('Касцёл'), 'касцел');
      expect(normalizeCompendiumSearchText('Аб’яўленне'), 'абяуленне');
      expect(
        normalizeCompendiumSearchText('ПIСАННЕ'),
        normalizeCompendiumSearchText('Пісанне'),
      );
      expect(normalizeCompendiumSearchText(null), '');
      expect(tokenizeCompendiumSearchText('  —  '), isEmpty);
    });

    test('matches the MyBrev implementation character for character', () {
      final fixture = _parityFixture();
      final expected = Map<String, String>.from(fixture['normalize'] as Map);
      for (final entry in expected.entries) {
        expect(
          normalizeCompendiumSearchText(entry.key),
          entry.value,
          reason: entry.key,
        );
      }
    });
  });

  group('ranking', () {
    test('number search puts the exact question first', () {
      expect(top('1').first, 1);
      expect(top('100').first, 100);
      expect(top('598').first, 598);
      expect(top('№ 42').first, 42);
      expect(top('#7').first, 7);
      expect(
        searchCompendium(search, '1066').first.field,
        CompendiumSearchField.refs,
      );
      expect(searchCompendium(search, '999').first.question.number, isNot(999));
    });

    test('Belarusian search is case-insensitive and prefers questions', () {
      for (final query in [
        'Бог',
        'вера',
        'Касцёл',
        'сакрамэнт',
        'хрост',
        'Эўхарыстыя',
        'малітва',
        'грэх',
      ]) {
        final results = searchCompendium(search, query);
        expect(results, isNotEmpty, reason: query);
        expect(
          results.first.field,
          CompendiumSearchField.question,
          reason: query,
        );
      }
      expect(top('што такое малітва'), contains(534));
      expect(top('ЭЎХАРЫСТЫЯ', 10), contains(271));
      expect(top('Эўхарыстыя'), top('еухарыстыя'));
      expect(top('Касцёл', 20), top('касцел', 20));
      expect(searchCompendium(search, 'зззззз'), isEmpty);
      expect(searchCompendium(search, '   '), isEmpty);
    });

    test('rankings, fields and scores equal the MyBrev results', () {
      final fixture = _parityFixture();
      final results = Map<String, dynamic>.from(fixture['results'] as Map);
      final counts = Map<String, dynamic>.from(fixture['counts'] as Map);
      expect(results, hasLength(greaterThan(40)));
      for (final query in results.keys) {
        final actual = searchCompendium(search, query);
        expect(actual.length, counts[query], reason: 'count for "$query"');
        final expected = results[query] as List;
        for (var i = 0; i < expected.length; i++) {
          final [number, field, score] = expected[i] as List;
          final result = actual[i];
          expect(
            result.question.number,
            number,
            reason: '"$query" position $i',
          );
          expect(result.field?.name, field, reason: '"$query" position $i');
          expect(
            result.score,
            closeTo((score as num).toDouble(), 1e-6),
            reason: '"$query" position $i',
          );
        }
      }
    });
  });

  group('hidden Russian aliases', () {
    test('widen matching only', () {
      const expectations = {
        'крещение': 252,
        'исповедь': 296,
        'причастие': 271,
        'грех': 392,
        'священник': 328,
        'таинство брака': 337,
      };
      for (final MapEntry(key: query, value: number) in expectations.entries) {
        expect(
          searchCompendium(
            search,
            query,
          ).any((result) => result.question.number == number),
          isTrue,
          reason: query,
        );
      }
      // Results are the unchanged Belarusian records.
      final result = searchCompendium(search, 'исповедь').first.question;
      expect(identical(result, index.getQuestion(result.number)), isTrue);
      final visible = index.questions
          .map((question) => '${question.question} ${question.answer}')
          .join(' ');
      expect(visible, isNot(contains('исповед')));
      // Without the alias file a Russian-only word finds nothing.
      expect(
        searchCompendium(CompendiumSearchIndex(index.questions), 'исповедь'),
        isEmpty,
      );
    });

    test('every alias target exists in the Belarusian text', () {
      final words = {
        for (final entry in search.entries)
          for (final list in entry.words.values) ...list,
      };
      expect(search.aliases.groups, isNotEmpty);
      for (final group in search.aliases.groups) {
        for (final stem in group.be) {
          expect(
            words.any((word) => word.startsWith(stem)),
            isTrue,
            reason: stem,
          );
        }
      }
    });

    test('a malformed alias file is ignored', () {
      final aliases = CompendiumSearchAliases.compile({
        'groups': [
          'x',
          {
            'ru': <String>[],
            'be': ['a'],
          },
          {
            'ru': ['крещ'],
            'be': ['хрост'],
          },
        ],
      });
      expect(aliases.groups, hasLength(1));
      expect(aliases.expand('крещение'), ['хрост']);
      expect(CompendiumSearchAliases.compile(null).groups, isEmpty);
    });
  });
}

Map<String, dynamic> _parityFixture() =>
    jsonDecode(
          File(
            'test/fixtures/compendium_search_parity.json',
          ).readAsStringSync(),
        )
        as Map<String, dynamic>;
