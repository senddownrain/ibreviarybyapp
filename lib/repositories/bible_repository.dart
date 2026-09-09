import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:mybrev_flutter/services/bible_seed_loader.dart';

class BibleVerse {
  final int verse;
  final String text;

  const BibleVerse({required this.verse, required this.text});
}

class BibleBookInfo {
  final String id;
  final String name;
  final int chapterCount;
  final String versionId;

  /// Canonical order: OT 1-39, NT 40+
  final int order;

  /// Whether verses use Russified spelling (e.g. RST text)
  final bool isVerseTextRussian;
  final bool isNewTestament;

  const BibleBookInfo({
    required this.id,
    required this.name,
    required this.chapterCount,
    required this.versionId,
    this.order = 0,
    this.isVerseTextRussian = false,
    this.isNewTestament = false,
  });
}

class BibleVersionMeta {
  final String id;
  final String name;
  final String shortName;
  final String langLabel;
  final String shortLabel;
  final String attribution;

  const BibleVersionMeta({
    required this.id,
    required this.name,
    required this.shortName,
    required this.langLabel,
    required this.shortLabel,
    required this.attribution,
  });
}

const kBibleVersionMeta = {
  'bel': BibleVersionMeta(
    id: 'bel',
    name: 'Беларуская Біблія',
    shortName: 'ББ',
    langLabel: 'Беларуская',
    shortLabel: 'БЕЛ',
    attribution: 'А. Бокун · catholic.by',
  ),
  'ru': BibleVersionMeta(
    id: 'ru',
    name: 'Сінадальны пераклад',
    shortName: 'СП',
    langLabel: 'Руская',
    shortLabel: 'РУС',
    attribution: 'Синодальный перевод',
  ),
};

class BibleRepository {
  static Map<String, dynamic>? _data;
  static Map<String, dynamic>? _dataBel;

  static void setData(String versionId, Map<String, dynamic> data) {
    if (versionId == 'bel') {
      _dataBel = data;
    } else {
      _data = data;
    }
  }

  static Map<String, dynamic>? _versionData(String versionId) {
    return switch (versionId) {
      'bel' => _dataBel,
      'ru' => _data,
      _ => null,
    };
  }

  static List<BibleVersionMeta> getAvailableVersions() {
    final result = <BibleVersionMeta>[];
    if (_dataBel != null) result.add(kBibleVersionMeta['bel']!);
    if (_data != null) result.add(kBibleVersionMeta['ru']!);
    if (result.isEmpty) result.add(kBibleVersionMeta['bel']!);
    return result;
  }

  static List<BibleBookInfo> getBooks(String versionId) {
    final d = _versionData(versionId);
    if (d == null) return [];
    final books = d['books'];
    if (books is! List) return const [];
    final newTestamentIndex = books.indexWhere(
      (book) => book is Map && book['id']?.toString() == 'mt',
    );
    return books.asMap().entries.where((entry) => entry.value is Map).map((
      entry,
    ) {
      final b = entry.value as Map;
      final order = (b['order'] as num?)?.toInt() ?? (entry.key + 1);
      return BibleBookInfo(
        id: b['id']?.toString() ?? '',
        name: b['name']?.toString() ?? '',
        chapterCount: _chapterCount(b),
        versionId: versionId,
        order: order,
        isVerseTextRussian: versionId != 'bel',
        isNewTestament:
            newTestamentIndex >= 0 && entry.key >= newTestamentIndex,
      );
    }).toList();
  }

  static BibleBookInfo? getBook(String versionId, String bookId) {
    return getBooks(versionId).where((b) => b.id == bookId).firstOrNull;
  }

  /// Finds the same canonical book in another translation. The Russian seed
  /// has seven additional Old Testament books, so raw order is insufficient.
  static BibleBookInfo? getParallelBook(
    String fromVersionId,
    String bookId,
    String toVersionId,
  ) {
    const russianOnlyIds = {'tob', 'jdt', '1mac', '2mac', 'wis', 'sir', 'bar'};
    List<BibleBookInfo> canonicalBooks(String versionId) => getBooks(versionId)
        .where((book) => versionId != 'ru' || !russianOnlyIds.contains(book.id))
        .toList(growable: false);

    final source = canonicalBooks(fromVersionId);
    final sourceIndex = source.indexWhere((book) => book.id == bookId);
    if (sourceIndex < 0) return null;
    final target = canonicalBooks(toVersionId);
    return sourceIndex < target.length ? target[sourceIndex] : null;
  }

  static List<({int chapter, BibleVerse verse})> searchBook(
    String versionId,
    String bookId,
    String query, {
    int limit = 60,
  }) {
    final book = getBook(versionId, bookId);
    final normalized = query.trim().toLowerCase();
    if (book == null || normalized.length < 2) return const [];
    final results = <({int chapter, BibleVerse verse})>[];
    for (var chapter = 1; chapter <= book.chapterCount; chapter++) {
      for (final verse in getChapter(versionId, bookId, chapter)) {
        if (verse.text.toLowerCase().contains(normalized)) {
          results.add((chapter: chapter, verse: verse));
          if (results.length >= limit) return results;
        }
      }
    }
    return results;
  }

  /// Returns chapter verses as typed [BibleVerse] objects.
  /// Handles both the asset list-of-lists format and the Firestore map format.
  static List<BibleVerse> getChapter(
    String versionId,
    String bookId,
    int chapter,
  ) {
    final d = _versionData(versionId);
    if (d == null) return [];
    final books = d['books'];
    if (books is! List) return const [];
    for (final b in books) {
      if (b is! Map) continue;
      final bm = b;
      if (bm['id'] == bookId) {
        final rawVerses = _chapterVerses(bm, chapter);
        return rawVerses.asMap().entries.map((e) {
          final v = e.value;
          if (v is Map) {
            return BibleVerse(
              verse: (v['num'] as num?)?.toInt() ?? (e.key + 1),
              text: v['text']?.toString() ?? '',
            );
          }
          return BibleVerse(verse: e.key + 1, text: v.toString());
        }).toList();
      }
    }
    return [];
  }

  /// Chapter count — supports both List and Map formats.
  static int _chapterCount(Map b) {
    final explicit = b['chapterCount'];
    if (explicit is num) return explicit.toInt();
    final chapters = b['chapters'];
    if (chapters is List) return chapters.length;
    if (chapters is Map) return chapters.length;
    return 0;
  }

  /// Raw verse list for [chapter] (1-based) — supports both formats.
  static List _chapterVerses(Map book, int chapter) {
    final chapters = book['chapters'];
    if (chapters is List) {
      final idx = chapter - 1;
      if (idx < 0 || idx >= chapters.length) return [];
      final value = chapters[idx];
      return value is List ? value : const [];
    }
    if (chapters is Map) {
      final value = chapters[chapter.toString()];
      return value is List ? value : const [];
    }
    return [];
  }

  /// Load bundled assets then try Firestore in background.
  static Future<void> preload() async {
    _dataBel ??= await BibleSeedLoader.load(lang: 'bel');
    _data ??= await BibleSeedLoader.load(lang: 'ru');
    // Background: refresh both versions from Firestore when online.
    unawaited(_loadFromFirestore('bel'));
    unawaited(_loadFromFirestore('ru'));
  }

  static Future<void> _loadFromFirestore(String versionId) async {
    try {
      final collection = 'bible_$versionId';
      final snap = await FirebaseFirestore.instance
          .collection(collection)
          .get(const GetOptions(source: Source.serverAndCache));
      if (snap.docs.isEmpty) return;

      final books =
          snap.docs.map((doc) {
            final d = doc.data();
            return {
              'id': doc.id,
              'name': d['name'] ?? '',
              'order': d['order'] ?? 0,
              'chapterCount': d['chapterCount'] ?? 0,
              'chapters': d['chapters'] ?? {},
            };
          }).toList()..sort(
            (a, b) => ((a['order'] as num?)?.toInt() ?? 0).compareTo(
              (b['order'] as num?)?.toInt() ?? 0,
            ),
          );

      setData(versionId, {'books': books});
      if (kDebugMode) {
        debugPrint(
          '[BibleRepository] Loaded ${books.length} books from Firestore ($versionId)',
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[BibleRepository] Firestore load failed: $e');
    }
  }
}
