import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';

/// Loads the bundled bible seed data from assets.
class BibleSeedLoader {
  static Map<String, dynamic>? _cache;

  static Future<Map<String, dynamic>> load({String lang = 'bel'}) async {
    if (_cache != null) return _cache!;
    final assetPath = lang == 'bel'
        ? 'assets/bible_seed_bel.json.gz'
        : 'assets/bible_seed.json.gz';
    final bytes = await rootBundle.load(assetPath);
    final rawBytes = bytes.buffer.asUint8List();
    final decompressed = GZipCodec().decode(rawBytes);
    final json = utf8.decode(decompressed);
    _cache = jsonDecode(json) as Map<String, dynamic>;
    return _cache!;
  }

  static void clearCache() => _cache = null;
}
