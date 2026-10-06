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

  test('Belarusian testaments: 46 OT books, 27 NT books from mt to rev', () {
    final books = BibleRepository.getBooks('bel');
    final oldTestament = books.where((b) => !b.isNewTestament).toList();
    final newTestament = books.where((b) => b.isNewTestament).toList();
    expect(oldTestament, hasLength(46));
    expect(newTestament, hasLength(27));
    expect(oldTestament.last.id, 'ml');
    expect(oldTestament.last.isNewTestament, isFalse);
    expect(newTestament.first.id, 'mt');
    expect(newTestament.last.id, 'rev');
    expect(newTestament.map((b) => b.id).take(6), [
      'mt',
      'mk',
      'lk',
      'jn',
      'acts',
      'rom',
    ]);
  });

  test('Belarusian attribution depends on the testament', () {
    expect(kBibleVersionMeta['bel']?.name, 'Беларуская Біблія');
    expect(
      bibleAttribution(versionId: 'bel', isNewTestament: false),
      'Стары Запавет · пераклад кс. Уладзіслава Чарняўскага MIC',
    );
    expect(
      bibleAttribution(versionId: 'bel', isNewTestament: true),
      'Новы Запавет · Catholic.by',
    );
    expect(
      bibleAttribution(versionId: 'ru', isNewTestament: true),
      'Синодальный перевод',
    );
  });

  test('Belarusian New Testament text is Catholic.by, not Chernyavski', () {
    String verse(String book, int chapter, int number) =>
        BibleRepository.getChapter(
          'bel',
          book,
          chapter,
        ).firstWhere((v) => v.verse == number).text;

    // Mt 1:18 — Catholic.by «Юзафам», Chernyavski «Язэпам».
    expect(verse('mt', 1, 18), contains('з Юзафам'));
    expect(verse('mt', 1, 18), isNot(contains('Язэп')));
    // Lk 1:28 — the Catholic.by angelic greeting.
    expect(
      verse('lk', 1, 28),
      'Анёл, увайшоўшы да Яе, сказаў: «Вітай, поўная ласкі, Пан з Табою».',
    );
    // Jn 1:17 — Catholic.by «Езуса», Chernyavski «Ісуса».
    expect(verse('jn', 1, 17), contains('праз Езуса Хрыста'));
    // The Old Testament stays Chernyavski.
    expect(verse('gn', 1, 1), 'Спачатку стварыў Бог неба і зямлю.');
  });

  test('Belarusian New Testament keeps canonical verse numbering', () {
    // Verses omitted by Catholic.by do not shift the following numbers.
    final mt17 = BibleRepository.getChapter('bel', 'mt', 17);
    expect(mt17.map((v) => v.verse), isNot(contains(21)));
    expect(mt17.last.verse, 27);
    // Chapters merged in the source EPUB are split again.
    expect(BibleRepository.getBook('bel', 'rom')?.chapterCount, 16);
    expect(BibleRepository.getBook('bel', 'gal')?.chapterCount, 6);
    // Section headings are not glued to the end of verse text.
    // (Mt 26:68 was followed by the heading «Адрачэнне Пятра» in the EPUB.)
    final mt26v68 = BibleRepository.getChapter(
      'bel',
      'mt',
      26,
    ).firstWhere((v) => v.verse == 68).text;
    expect(mt26v68, endsWith('хто ўдарыў Цябе?»'));
    for (final book in BibleRepository.getBooks(
      'bel',
    ).where((b) => b.isNewTestament)) {
      for (var chapter = 1; chapter <= book.chapterCount; chapter++) {
        final verses = BibleRepository.getChapter('bel', book.id, chapter);
        expect(verses, isNotEmpty, reason: '${book.id} $chapter');
        expect(
          verses.map((v) => v.text).where((t) => t.contains('©')),
          isEmpty,
          reason: '${book.id} $chapter',
        );
      }
    }
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
    // Chernyavski (OT) wording differs from the retired Bokun translation.
    expect(
      BibleRepository.getChapter('bel', 'gn', 1).first.text,
      'Спачатку стварыў Бог неба і зямлю.',
    );
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
