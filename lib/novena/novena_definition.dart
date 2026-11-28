/// Novena definitions and the day resolver (shared contract 1.0, §2–§3).
///
/// Pure: no Flutter, Hive or Firestore. The resolver is the Dart twin of the
/// reference `resolveDay()` of the Web side and must produce the same output
/// (`test/novena/novena_resolver_test.dart`).
library;

const kNovenaSchemaVersion = 1;
const kNovenaCollection = 'novenaDefinitions';

/// A prayer a definition may refer to.
class NovenaPrayer {
  const NovenaPrayer({
    required this.id,
    required this.title,
    required this.text,
    this.priestOnly = false,
  });

  factory NovenaPrayer.fromMap(Map data, [String? id]) => NovenaPrayer(
    id: id ?? '${data['id']}',
    title: '${data['title'] ?? ''}',
    text: '${data['text'] ?? ''}',
    priestOnly:
        data['priestOnly'] == true || data['effectivePriestOnly'] == true,
  );

  final String id;
  final String title;
  final String text;
  final bool priestOnly;
}

/// One resolved piece of a day, in reading order.
class NovenaBlock {
  const NovenaBlock({
    required this.kind,
    required this.title,
    required this.markdown,
    required this.collapsible,
    required this.prayerId,
  });

  factory NovenaBlock.fromMap(Map data) => NovenaBlock(
    kind: '${data['kind']}',
    title: data['title'] as String?,
    markdown: '${data['markdown'] ?? ''}',
    collapsible: data['collapsible'] == true,
    prayerId: data['prayerId'] as String?,
  );

  /// `text`, `rubric`, `prayer`, `section` or `part` (always folded).
  final String kind;
  final String? title;
  final String markdown;
  final bool collapsible;

  /// Source of the text; null for inline blocks.
  final String? prayerId;

  Map<String, dynamic> toMap() => {
    'kind': kind,
    'title': title,
    'markdown': markdown,
    'collapsible': collapsible,
    'prayerId': prayerId,
  };
}

class NovenaResolveError implements Exception {
  const NovenaResolveError(this.code);
  final String code;
  @override
  String toString() => code;
}

// A Markdown heading, or a whole line in bold (except «**Молімся…»).
final _heading = RegExp(
  r'^(?:(#{1,6})\s+\S.*|\*\*(?!Молімся)[^*]{1,140}\*\*)\s*$',
);

int _level(String line) {
  final match = _heading.firstMatch(line);
  if (match == null) return 0;
  return match.group(1)?.length ?? 7;
}

List<String> _lines(String text) => text.replaceAll('\r\n', '\n').split('\n');

/// The [occurrence]-th section headed by [heading], or null.
String? novenaSectionText(String text, String heading, [int occurrence = 1]) {
  final all = _lines(text);
  var seen = 0;
  for (var i = 0; i < all.length; i++) {
    if (all[i].trim() != heading || (seen += 1) != occurrence) continue;
    final level = _level(all[i]);
    final own = level == 0 ? 7 : level;
    var end = i + 1;
    while (end < all.length &&
        !(_level(all[end]) != 0 && _level(all[end]) <= own)) {
      end++;
    }
    return all.sublist(i, end).join('\n').trim();
  }
  return null;
}

NovenaBlock _resolveBlock(Map block, Map<String, NovenaPrayer> prayers) {
  final type = block['type'];
  if (type == 'inline') {
    final kind = block['kind'] as String?;
    return NovenaBlock(
      kind: kind == null || kind.isEmpty ? 'text' : kind,
      title: null,
      markdown: '${block['text'] ?? ''}',
      collapsible: false,
      prayerId: null,
    );
  }
  final prayer = prayers[block['prayerId']];
  if (prayer == null || prayer.priestOnly) {
    throw NovenaResolveError('missing-or-closed-prayer:${block['prayerId']}');
  }
  if (type == 'prayer') {
    return NovenaBlock(
      kind: 'prayer',
      title: prayer.title,
      markdown: prayer.text.trim(),
      collapsible: true,
      prayerId: prayer.id,
    );
  }
  if (type == 'section') {
    final occurrence = (block['occurrence'] as num?)?.toInt() ?? 1;
    final markdown = novenaSectionText(
      prayer.text,
      '${block['heading']}',
      occurrence == 0 ? 1 : occurrence,
    );
    if (markdown == null) {
      throw NovenaResolveError(
        'missing-section:${block['prayerId']}:${block['heading']}',
      );
    }
    return NovenaBlock(
      kind: 'section',
      title: null,
      markdown: markdown,
      collapsible: false,
      prayerId: prayer.id,
    );
  }
  throw NovenaResolveError('unknown-block:$type');
}

/// A definition document (`novenaDefinitions/{novenaId}`).
class NovenaDefinition {
  NovenaDefinition._({
    required this.schemaVersion,
    required this.novenaId,
    required this.sourcePrayerId,
    required this.title,
    required this.contentVersion,
    required this.durationDays,
    required this.status,
    required this.trackerEnabled,
    required this.template,
    required this.days,
    required this.schedule,
  });

  /// A tracker whose days the app assembles itself (no document, no
  /// recommended date): only its identity and length are used.
  factory NovenaDefinition.builtIn({
    required String novenaId,
    required String title,
    required int durationDays,
  }) => NovenaDefinition._(
    schemaVersion: kNovenaSchemaVersion,
    novenaId: novenaId,
    sourcePrayerId: novenaId,
    title: title,
    contentVersion: 1,
    durationDays: durationDays,
    status: 'published',
    trackerEnabled: true,
    template: const [],
    days: const [],
    schedule: const {},
  );

  /// Null when the document does not have the shape of a definition.
  static NovenaDefinition? tryParse(Map data) {
    int? integer(Object? value) =>
        value is num && value == value.roundToDouble() ? value.toInt() : null;
    List<Map> maps(Object? value) =>
        value is List ? [for (final item in value) item as Map] : const [];
    try {
      final id = data['novenaId'] as String?;
      final source = data['sourcePrayerId'] as String?;
      if (id == null || id.isEmpty || source == null || source.isEmpty) {
        return null;
      }
      return NovenaDefinition._(
        schemaVersion: integer(data['schemaVersion']) ?? 0,
        novenaId: id,
        sourcePrayerId: source,
        title: '${data['title'] ?? ''}',
        contentVersion: integer(data['contentVersion']) ?? 0,
        durationDays: integer(data['durationDays']) ?? 0,
        status: '${data['status'] ?? ''}',
        trackerEnabled: data['trackerEnabled'] == true,
        template: maps(data['template']),
        days: maps(data['days']),
        schedule: data['schedule'] is Map ? data['schedule'] as Map : const {},
      );
    } on TypeError {
      return null;
    }
  }

  final int schemaVersion;
  final String novenaId;
  final String sourcePrayerId;
  final String title;
  final int contentVersion;
  final int durationDays;
  final String status;
  final bool trackerEnabled;
  final List<Map> template;
  final List<Map> days;
  final Map schedule;

  bool get isPublished => status == 'published' && trackerEnabled;

  /// The whole text order of one day (1-based).
  List<NovenaBlock> resolveDay(int number, Map<String, NovenaPrayer> prayers) {
    final day = days.where((item) => item['number'] == number).firstOrNull;
    if (day == null) throw NovenaResolveError('missing-day:$number');
    return [
      for (final block in template)
        if (block['type'] == 'daySection')
          for (final own in (day['blocks'] as List? ?? const []))
            _resolveBlock(own as Map, prayers)
        else
          _resolveBlock(block, prayers),
    ];
  }

  /// All days, or null when any of them cannot be assembled from the public
  /// [prayers]: the novena is then unsupported (no start button), and no text
  /// is ever substituted.
  List<List<NovenaBlock>>? resolveAll(Map<String, NovenaPrayer> prayers) {
    final source = prayers[sourcePrayerId];
    if (schemaVersion != kNovenaSchemaVersion ||
        source == null ||
        source.priestOnly ||
        durationDays < 1 ||
        durationDays > 31 ||
        contentVersion < 1 ||
        template.isEmpty ||
        days.length != durationDays) {
      return null;
    }
    for (var i = 0; i < days.length; i++) {
      if (days[i]['number'] != i + 1) return null;
    }
    try {
      final result = [
        for (var n = 1; n <= durationDays; n++) resolveDay(n, prayers),
      ];
      if (result.any(
        (day) => !day.any((block) => block.markdown.trim().isNotEmpty),
      )) {
        return null;
      }
      return result;
    } on NovenaResolveError {
      return null;
    } on TypeError {
      return null;
    }
  }
}
