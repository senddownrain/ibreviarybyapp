import 'dart:convert';
import 'dart:io';

/// Real Belarusian readings from the app's own offline bundle
/// (`assets/content/readings.json.gz`). Read-only; nothing is copied or
/// changed, no network, no Firebase. Strings are interned as "\u0001<index>".
class RealReading {
  RealReading(this.id, this.field, this.text);
  final String id;
  final String field;
  final String text;
}

List<RealReading> loadRealReadings({
  String path = '../../assets/content/readings.json.gz',
}) {
  final raw =
      jsonDecode(utf8.decode(gzip.decode(File(path).readAsBytesSync())))
          as Map<String, dynamic>;
  final strings = (raw['strings'] as List).cast<String>();
  String? resolve(Object? v) {
    if (v is! String) return null;
    return v.startsWith('\u0001') ? strings[int.parse(v.substring(1))] : v;
  }

  final out = <RealReading>[];
  final docs = (raw['docs'] as Map<String, dynamic>);
  for (final id in docs.keys.toList()..sort()) {
    final doc = docs[id] as Map<String, dynamic>;
    for (final f in ['reading1', 'reading2', 'gospel']) {
      final r = doc[f];
      if (r is! Map) continue;
      final t = resolve(r['text']);
      if (t != null && t.trim().isNotEmpty) out.add(RealReading(id, f, t));
    }
  }
  return out;
}

/// The app collapses blank lines in prose (`_ReadingText`): same here.
String proseOf(String text) =>
    text.replaceAll(RegExp(r'\r?\n[ \t]*\r?\n+'), '\n');

/// Deterministic sample: every [step]-th plain-text (non-HTML) reading ≥ [minLen].
List<RealReading> sampleReadings({int step = 12, int minLen = 150}) {
  final all = loadRealReadings()
      .where((r) => !r.text.contains('<') && r.text.length >= minLen)
      .toList();
  return [for (var i = 0; i < all.length; i += step) all[i]];
}
