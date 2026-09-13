import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Loads bundled bible seed data from assets (one cache entry per language).
class BibleSeedLoader {
  static final Map<String, Map<String, dynamic>> _cache = {};

  static Future<Map<String, dynamic>> load({String lang = 'bel'}) async {
    if (_cache.containsKey(lang)) return _cache[lang]!;
    final assetPath = 'assets/bible_seed_$lang.json.gz';
    final bytes = await rootBundle.load(assetPath);
    final rawBytes = bytes.buffer.asUint8List(
      bytes.offsetInBytes,
      bytes.lengthInBytes,
    );
    _cache[lang] = await compute(_decodeSeed, rawBytes);
    return _cache[lang]!;
  }

  static void clearCache([String? lang]) {
    if (lang != null) {
      _cache.remove(lang);
    } else {
      _cache.clear();
    }
  }
}

Map<String, dynamic> _decodeSeed(Uint8List bytes) =>
    jsonDecode(utf8.decode(GZipDecoder().decodeBytes(bytes)))
        as Map<String, dynamic>;
