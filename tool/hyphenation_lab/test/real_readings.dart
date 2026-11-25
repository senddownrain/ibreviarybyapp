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

// ---- other real texts from the same offline bundle (read-only) -------------

List<String> loadBundleStrings(String name) {
  final raw =
      jsonDecode(
            utf8.decode(
              gzip.decode(
                File('../../assets/content/$name.json.gz').readAsBytesSync(),
              ),
            ),
          )
          as Map<String, dynamic>;
  return (raw['strings'] as List).whereType<String>().toList();
}

/// A real Hours/Mass HTML reading with a red rubric, an <em> title, a long
/// prose paragraph and psalmody lines (shortest match, deterministic).
String pickMixedHtml() {
  bool isProse(String p) =>
      !p.contains('<br') &&
      !p.contains('*') &&
      p.replaceAll(RegExp(r'<[^>]+>'), '').length > 350;
  final c = loadBundleStrings('liturgicalProperTexts').where((t) {
    if (!t.contains('#ff0000') || !t.contains('<em>') || t.length >= 3500)
      return false;
    final ps = RegExp(
      r'<p[^>]*>(.*?)</p>',
      dotAll: true,
    ).allMatches(t).map((m) => m.group(1)!);
    return ps.any(isProse);
  }).toList()..sort((a, b) => a.length.compareTo(b.length));
  return c.first;
}

/// A real psalm (HTML, `*<br />` cadences, red rubric heading).
String pickPsalmHtml() {
  final c =
      loadBundleStrings('liturgicalProperTexts')
          .where(
            (t) =>
                t.contains('Псальм') &&
                t.contains('*<br') &&
                t.contains('#ff0000') &&
                t.length < 2500,
          )
          .toList()
        ..sort((a, b) => a.length.compareTo(b.length));
  return c.first;
}

/// A real Belarusian prayer (mybrev-markdown) by title.
(String, String) pickPrayer(String titlePart) {
  final raw =
      jsonDecode(
            utf8.decode(
              gzip.decode(
                File('../../assets/content/prayers.json.gz').readAsBytesSync(),
              ),
            ),
          )
          as Map<String, dynamic>;
  final strings = (raw['strings'] as List).cast<String>();
  String? r(Object? v) => v is String && v.startsWith('\u0001')
      ? strings[int.parse(v.substring(1))]
      : (v as String?);
  for (final doc in (raw['docs'] as Map<String, dynamic>).values) {
    final d = doc as Map<String, dynamic>;
    final title = r((d['titleVersions'] as Map?)?['be']);
    final text = r((d['textVersions'] as Map?)?['be']);
    if (title != null && text != null && title.contains(titlePart))
      return (title, text);
  }
  throw StateError('prayer not found: $titlePart');
}
