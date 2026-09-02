import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';

/// Loads bundled bible seed data from assets (one cache entry per language).
class BibleSeedLoader {
  static final Map<String, Map<String, dynamic>> _cache = {};

  static Future<Map<String, dynamic>> load({String lang = 'bel'}) async {
    if (_cache.containsKey(lang)) return _cache[lang]!;
    final assetPath = 'assets/bible_seed_$lang.json.gz';
    final bytes = await rootBundle.load(assetPath);
    final rawBytes = bytes.buffer.asUint8List();
    final decompressed = GZipCodec().decode(rawBytes);
    final json = utf8.decode(decompressed);
    _cache[lang] = jsonDecode(json) as Map<String, dynamic>;
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
