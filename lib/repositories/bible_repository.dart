import 'package:mybrev_flutter/services/bible_seed_loader.dart';
import 'package:mybrev_flutter/services/hive_service.dart';

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
    name: 'Пераклад кс. Уладзіслава Чарняўскага MIC',
    shortName: 'ЧБ',
    langLabel: 'Беларуская',
    shortLabel: 'БЕЛ',
    attribution: 'Пераклад кс. Уладзіслава Чарняўскага MIC · bible.by',
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

String bibleAttribution({
  required String versionId,
  required bool isNewTestament,
}) {
  return kBibleVersionMeta[versionId]?.attribution ?? '';
}

class BibleRepository {
  static final Map<String, Map<String, dynamic>> _data = {};

  static void setData(String versionId, Map<String, dynamic> data) {
    _data[versionId] = data;
  }

  static Map<String, dynamic>? _versionData(String versionId) =>
      _data[versionId];

  static List<BibleVersionMeta> getAvailableVersions() {
    final result = <BibleVersionMeta>[];
    for (final version in kBibleVersionMeta.values) {
      if (_data.containsKey(version.id)) result.add(version);
    }
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
        isVerseTextRussian: versionId == 'ru',
        isNewTestament:
            newTestamentIndex >= 0 && entry.key >= newTestamentIndex,
      );
    }).toList();
  }

  static BibleBookInfo? getBook(String versionId, String bookId) {
    return getBooks(versionId).where((b) => b.id == bookId).firstOrNull;
  }

  /// Translates a Russian-seed book id into the shared Belarusian id scheme
  /// (used by the `bel` seed). The Russian seed uses
  /// different ids for several books (jn = Иона, jo = Иоанн, rm, act, …).
  static String _canonicalKey(String versionId, String bookId) {
    if (versionId != 'ru') return bookId;
    const ruToBel = {
      'jn': 'jon', // ru: Иона
      'jo': 'jn', // ru: Иоанн
      'act': 'acts',
      'rm': 'rom',
      'gl': 'gal',
      'ph': 'php',
      'cl': 'col',
      '1ts': '1th',
      '2ts': '2th',
      '1tm': '1ti',
      '2tm': '2ti',
      'tt': 'tit',
      'hb': 'heb',
      'jm': 'jas',
      'jd': 'jud', // ru: Иуды (bel 'jud' is also Иуды; ru 'jud' is Судьи)
      'jud': 'jdg', // ru: Судьи
      're': 'rev',
    };
    return ruToBel[bookId] ?? bookId;
  }

  /// Finds the same canonical book in another translation. Book ids differ
  /// between the Russian and Belarusian id schemes, so ids are matched via
  /// [_canonicalKey]. Returns null when the target translation lacks the book
  /// (e.g. deuterocanonical books absent from the `bel` translation).
  static BibleBookInfo? getParallelBook(
    String fromVersionId,
    String bookId,
    String toVersionId,
  ) {
    final key = _canonicalKey(fromVersionId, bookId);
    for (final book in getBooks(toVersionId)) {
      if (_canonicalKey(toVersionId, book.id) == key) return book;
    }
    return null;
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

  static final Map<String, Future<void>> _loading = {};

  static Future<void> ensureVersion(String versionId) {
    if (_versionData(versionId) != null) return Future.value();
    return _loading.putIfAbsent(versionId, () async {
      try {
        if (HiveService.isSettingsReady &&
            HiveService.getLastSync('bible_$versionId') != null &&
            HiveService.boxFor('bible_$versionId').isNotEmpty) {
          loadCachedVersion(versionId);
        } else {
          setData(versionId, await BibleSeedLoader.load(lang: versionId));
        }
      } finally {
        _loading.remove(versionId);
      }
    });
  }

  static void loadCachedVersion(String versionId) {
    final books =
        HiveService.boxFor(
            'bible_$versionId',
          ).values.map((raw) => Map<String, dynamic>.from(raw as Map)).toList()
          ..sort(
            (a, b) => ((a['order'] as num?)?.toInt() ?? 0).compareTo(
              (b['order'] as num?)?.toInt() ?? 0,
            ),
          );
    if (books.isNotEmpty) setData(versionId, {'books': books});
  }

  /// Offline data is decoded lazily, after the first frame.
  static Future<void> preload() =>
      Future.wait([ensureVersion('bel'), ensureVersion('ru')]);

  /// Replaces missing or corrupt in-memory corpora from bundled offline data.
  static Future<void> reloadBundled() async {
    _data['bel'] = await BibleSeedLoader.load(lang: 'bel');
    _data['ru'] = await BibleSeedLoader.load(lang: 'ru');
  }
}
