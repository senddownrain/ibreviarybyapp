import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/repositories/bible_repository.dart';
import 'package:mybrev_flutter/services/bible_seed_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    BibleRepository.setData('bel', await BibleSeedLoader.load(lang: 'bel'));
    BibleRepository.setData(
      'bel_charniauski',
      await BibleSeedLoader.load(lang: 'bel_charniauski'),
    );
    BibleRepository.setData('ru', await BibleSeedLoader.load(lang: 'ru'));
  });

  test('testament boundary accounts for Russian additional books', () {
    expect(BibleRepository.getBook('ru', 'ml')?.isNewTestament, isFalse);
    expect(BibleRepository.getBook('ru', 'mt')?.isNewTestament, isTrue);
    expect(BibleRepository.getBook('bel', 'ml')?.isNewTestament, isFalse);
    expect(BibleRepository.getBook('bel', 'mt')?.isNewTestament, isTrue);
  });

  test('Belarusian attribution follows the opened testament', () {
    expect(
      bibleAttribution(versionId: 'bel', isNewTestament: false),
      'Пераклад Антонія Бокуна · bible.by',
    );
    expect(
      bibleAttribution(versionId: 'bel', isNewTestament: true),
      'Афіцыйны пераклад · catholic.by',
    );
  });

  test('parallel translation keeps the canonical book', () {
    expect(BibleRepository.getParallelBook('bel', 'jn', 'ru')?.id, 'jo');
    expect(BibleRepository.getParallelBook('ru', 'jn', 'bel')?.id, 'jon');
    expect(BibleRepository.getParallelBook('ru', 'tob', 'bel'), isNull);
  });

  test('Chernyavski version carries the full catholic canon', () {
    expect(BibleRepository.getBooks('bel_charniauski').length, 73);
    expect(BibleRepository.getBook('bel_charniauski', 'tob'), isNotNull);
    expect(BibleRepository.getBook('bel_charniauski', 'sir'), isNotNull);
    expect(
      BibleRepository.getChapter('bel_charniauski', 'jn', 3).length,
      greaterThanOrEqualTo(16),
    );
    expect(
      BibleRepository.getChapter('bel_charniauski', 'jn', 3)[15].text,
      contains('палюбіў Бог свет'),
    );
  });

  test('parallel mapping aligns all three translations', () {
    expect(
      BibleRepository.getParallelBook('bel_charniauski', 'jn', 'ru')?.id,
      'jo',
    );
    expect(
      BibleRepository.getParallelBook('ru', 'jo', 'bel_charniauski')?.id,
      'jn',
    );
    expect(
      BibleRepository.getParallelBook('bel', 'jn', 'bel_charniauski')?.id,
      'jn',
    );
    expect(
      BibleRepository.getParallelBook('bel_charniauski', 'jon', 'ru')?.id,
      'jn',
    );
    // Deuterocanonical books exist in both full-canon translations.
    expect(
      BibleRepository.getParallelBook('ru', 'wis', 'bel_charniauski')?.id,
      'wis',
    );
    expect(
      BibleRepository.getParallelBook('bel_charniauski', 'sir', 'bel'),
      isNull,
    );
  });

  test('book search returns matches with chapter and verse', () {
    final firstVerse = BibleRepository.getChapter('bel', 'gn', 1).first;
    final word = firstVerse.text
        .split(RegExp(r'\s+'))
        .firstWhere((part) => part.length >= 2)
        .replaceAll(RegExp(r'[^\p{L}]', unicode: true), '');
    final results = BibleRepository.searchBook('bel', 'gn', word);
    expect(results, isNotEmpty);
    expect(results.first.chapter, greaterThanOrEqualTo(1));
  });
}
