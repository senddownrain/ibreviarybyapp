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
