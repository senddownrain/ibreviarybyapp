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
      final chapters = b['chapters'] as List? ?? [];
      final order = (b['order'] as int?) ?? (entry.key + 1);
      return BibleBookInfo(
        id: b['id'] as String? ?? '',
        name: b['name'] as String? ?? '',
        chapterCount: chapters.length,
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
  static List<BibleVerse> getChapter(
      String versionId, String bookId, int chapter) {
    final d = _versionData(versionId);
    if (d == null) return [];
    final books = d['books'] as List? ?? [];
    for (final b in books) {
      final bm = b as Map;
      if (bm['id'] == bookId) {
        final chapters = bm['chapters'] as List? ?? [];
        final idx = chapter - 1;
        if (idx < 0 || idx >= chapters.length) return [];
        final rawVerses = chapters[idx] as List? ?? [];
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

  static Future<void> preload() async {
    if (_dataBel == null) {
      _dataBel = await BibleSeedLoader.load(lang: 'bel');
    }
  }
}
