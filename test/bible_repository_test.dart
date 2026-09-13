import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/repositories/bible_repository.dart';
import 'package:mybrev_flutter/services/bible_seed_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    BibleRepository.setData('bel', await BibleSeedLoader.load(lang: 'bel'));
    BibleRepository.setData('ru', await BibleSeedLoader.load(lang: 'ru'));
  });

  test('testament boundary accounts for Russian additional books', () {
    expect(BibleRepository.getBook('ru', 'ml')?.isNewTestament, isFalse);
    expect(BibleRepository.getBook('ru', 'mt')?.isNewTestament, isTrue);
    expect(BibleRepository.getBook('bel', 'ml')?.isNewTestament, isFalse);
    expect(BibleRepository.getBook('bel', 'mt')?.isNewTestament, isTrue);
  });

  test('Belarusian version is attributed to the Chernyavski translation', () {
    expect(
      bibleAttribution(versionId: 'bel', isNewTestament: false),
      'Пераклад Ўладзіслава Чарняўскага · bible.by',
    );
    expect(
      bibleAttribution(versionId: 'bel', isNewTestament: true),
      'Пераклад Ўладзіслава Чарняўскага · bible.by',
    );
  });

  test('parallel translation keeps the canonical book', () {
    expect(BibleRepository.getParallelBook('bel', 'jn', 'ru')?.id, 'jo');
    expect(BibleRepository.getParallelBook('ru', 'jn', 'bel')?.id, 'jon');
    // Both translations now carry the full catholic canon.
    expect(BibleRepository.getParallelBook('ru', 'tob', 'bel')?.id, 'tob');
  });

  test('Belarusian version carries the full catholic canon', () {
    expect(BibleRepository.getBooks('bel').length, 73);
    expect(BibleRepository.getBook('bel', 'tob'), isNotNull);
    expect(BibleRepository.getBook('bel', 'sir'), isNotNull);
    expect(
      BibleRepository.getChapter('bel', 'jn', 3).length,
      greaterThanOrEqualTo(16),
    );
    expect(
      BibleRepository.getChapter('bel', 'jn', 3)[15].text,
      contains('палюбіў Бог свет'),
    );
    // Chernyavski wording differs from the retired Bokun translation.
    expect(BibleRepository.getChapter('bel', 'gn', 1).first.text, 'Спачатку стварыў Бог неба і зямлю.');
  });

  test('parallel mapping aligns both translations', () {
    expect(BibleRepository.getParallelBook('bel', 'jn', 'ru')?.id, 'jo');
    expect(BibleRepository.getParallelBook('ru', 'jo', 'bel')?.id, 'jn');
    expect(BibleRepository.getParallelBook('bel', 'jon', 'ru')?.id, 'jn');
    // Deuterocanonical books exist in both translations.
    expect(BibleRepository.getParallelBook('ru', 'wis', 'bel')?.id, 'wis');
    expect(BibleRepository.getParallelBook('bel', 'sir', 'ru')?.id, 'sir');
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
