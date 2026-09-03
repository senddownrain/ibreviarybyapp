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

  const BibleBookInfo({
    required this.id,
    required this.name,
    required this.chapterCount,
    required this.versionId,
    this.order = 0,
    this.isVerseTextRussian = false,
  });
}

class BibleVersionMeta {
  final String id;
  final String name;
  final String shortName;
  final String langLabel;

  const BibleVersionMeta({
    required this.id,
    required this.name,
    required this.shortName,
    required this.langLabel,
  });
}

const kBibleVersionMeta = {
  'bel': BibleVersionMeta(
    id: 'bel',
    name: 'Беларуская Біблія',
    shortName: 'ББ',
    langLabel: 'Беларуская',
  ),
  'ru': BibleVersionMeta(
    id: 'ru',
    name: 'Сінадальны пераклад',
    shortName: 'СП',
    langLabel: 'Руская',
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
    return versionId == 'bel' ? _dataBel : _data;
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
    final books = d['books'] as List? ?? [];
    return books.asMap().entries.map((entry) {
      final b = entry.value as Map;
      final order = (b['order'] as int?) ?? (entry.key + 1);
      return BibleBookInfo(
        id: b['id'] as String? ?? '',
        name: b['name'] as String? ?? '',
        chapterCount: _chapterCount(b),
        versionId: versionId,
        order: order,
        isVerseTextRussian: versionId != 'bel',
      );
    }).toList();
  }

  static BibleBookInfo? getBook(String versionId, String bookId) {
    return getBooks(versionId).where((b) => b.id == bookId).firstOrNull;
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
    final books = d['books'] as List? ?? [];
    for (final b in books) {
      final bm = b as Map;
      if (bm['id'] == bookId) {
        final rawVerses = _chapterVerses(bm, chapter);
        return rawVerses.asMap().entries.map((e) {
          final v = e.value;
          if (v is Map) {
            return BibleVerse(
              verse: (v['num'] as int?) ?? (e.key + 1),
              text: (v['text'] as String?) ?? '',
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
    if (explicit is int) return explicit;
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
      return chapters[idx] as List? ?? [];
    }
    if (chapters is Map) {
      return chapters[chapter.toString()] as List? ?? [];
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
            }).toList()
            ..sort((a, b) => (a['order'] as int).compareTo(b['order'] as int));

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
