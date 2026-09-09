import 'package:mybrev_flutter/repositories/bible_repository.dart';

class BibleLocation {
  const BibleLocation({
    required this.versionId,
    required this.bookId,
    required this.chapter,
    this.verse,
  });

  final String versionId;
  final String bookId;
  final int chapter;
  final int? verse;

  String get documentKey => '$versionId:$bookId:$chapter';
}

class BibleNavigation {
  const BibleNavigation._();

  static const defaultVersionId = 'bel';

  static String lastLocationKey(String versionId) =>
      'bibleLastLocation:$versionId';

  static String highlightKey(BibleLocation location) =>
      'bibleHighlight:${location.documentKey}';

  static String scrollKey(BibleLocation location) =>
      'bibleScroll:${location.documentKey}';

  static BibleLocation? resolve({
    required String versionId,
    String? requestedBookId,
    int? requestedChapter,
    Map? saved,
  }) {
    final books = BibleRepository.getBooks(versionId);
    if (books.isEmpty) return null;
    final requestedBook = requestedBookId == null
        ? null
        : BibleRepository.getBook(versionId, requestedBookId);
    final savedBook = BibleRepository.getBook(
      versionId,
      saved?['bookId']?.toString() ?? '',
    );
    final book = requestedBook ?? savedBook ?? books.first;
    final savedChapter = int.tryParse(saved?['chapter']?.toString() ?? '');
    final chapter = (requestedChapter ?? savedChapter ?? 1).clamp(
      1,
      book.chapterCount,
    );
    return BibleLocation(
      versionId: versionId,
      bookId: book.id,
      chapter: chapter,
    );
  }

  static BibleLocation? switchTranslation({
    required BibleLocation current,
    required String targetVersionId,
    Map? targetSaved,
  }) {
    final parallel = BibleRepository.getParallelBook(
      current.versionId,
      current.bookId,
      targetVersionId,
    );
    if (parallel != null) {
      return BibleLocation(
        versionId: targetVersionId,
        bookId: parallel.id,
        chapter: current.chapter.clamp(1, parallel.chapterCount),
      );
    }
    return resolve(versionId: targetVersionId, saved: targetSaved);
  }

  static BibleLocation? relative(BibleLocation current, int direction) {
    if (direction != -1 && direction != 1) return current;
    final books = BibleRepository.getBooks(current.versionId);
    final index = books.indexWhere((book) => book.id == current.bookId);
    if (index < 0) return null;
    final book = books[index];
    if (direction < 0 && current.chapter > 1) {
      return BibleLocation(
        versionId: current.versionId,
        bookId: book.id,
        chapter: current.chapter - 1,
      );
    }
    if (direction > 0 && current.chapter < book.chapterCount) {
      return BibleLocation(
        versionId: current.versionId,
        bookId: book.id,
        chapter: current.chapter + 1,
      );
    }
    final adjacentIndex = index + direction;
    if (adjacentIndex < 0 || adjacentIndex >= books.length) return null;
    final adjacent = books[adjacentIndex];
    return BibleLocation(
      versionId: current.versionId,
      bookId: adjacent.id,
      chapter: direction < 0 ? adjacent.chapterCount : 1,
    );
  }

  static String route(BibleLocation location, {bool searchResult = false}) =>
      Uri(
        path: searchResult ? '/bible/search/result' : '/bible',
        queryParameters: {
          'version': location.versionId,
          'book': location.bookId,
          'chapter': '${location.chapter}',
          if (location.verse != null) 'verse': '${location.verse}',
        },
      ).toString();
}
