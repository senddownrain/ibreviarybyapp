import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/repositories/bible_repository.dart';

void main() {
  test('BibleRepository exposes loaded books and chapters', () {
    BibleRepository.setData('bel', {
      'books': [
        {
          'id': 'gen',
          'name': 'Быццё',
          'order': 1,
          'chapters': [
            [
              {'num': 1, 'text': 'На пачатку...'},
            ],
          ],
        },
      ],
    });

    final books = BibleRepository.getBooks('bel');
    expect(books.single.name, 'Быццё');
    expect(books.single.chapterCount, 1);
    expect(
      BibleRepository.getChapter('bel', 'gen', 1).single.text,
      'На пачатку...',
    );
  });
}
