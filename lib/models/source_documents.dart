import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const sourcesRoute = '/sources';
const hoursDecreesRoute = '/documents/liturgy-hours-decrees';
const properCalendarRoute = '/documents/proper-calendar';
const properCalendarPdfAsset = 'assets/legal/proper-calendar.pdf';

Future<Map<String, dynamic>> _read(String name) async =>
    jsonDecode(await rootBundle.loadString('assets/legal/$name.json'))
        as Map<String, dynamic>;

final sourceRegistryProvider = FutureProvider<SourceRegistry>(
  (ref) => SourceRegistry.load(),
);

/// The original Web JSON remains the only registry, including nullable rights,
/// verification evidence, digital permissions and decree metadata. The UI uses
/// only the explicitly selected bibliographic fields below.
class SourceRegistry {
  SourceRegistry.fromJson(this.raw) {
    if (raw['schemaVersion'] != 1) {
      throw const FormatException('Unsupported source registry');
    }
    entries = (raw['entries'] as List)
        .map((e) => SourceEntry(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  final Map<String, dynamic> raw;
  late final List<SourceEntry> entries;
  static Future<SourceRegistry>? _loading;
  static SourceRegistry? current;

  static Future<SourceRegistry> load() {
    if (current case final registry?) {
      return Future.value(registry);
    }
    return _loading ??= () async {
      try {
        return current = SourceRegistry.fromJson(await _read('sources'));
      } finally {
        _loading = null;
      }
    }();
  }

  SourceEntry entry(String id) => entries.singleWhere((e) => e.id == id);

  String? bibleId(String version, bool newTestament) =>
      (raw['bindings']['bible'][version] as Map?)?[newTestament ? 'new' : 'old']
          as String?;

  String bibleLabel(String version, bool newTestament) {
    final id = bibleId(version, newTestament);
    return id == null ? '' : entry(id).translationLabel ?? '';
  }

  List<({String title, List<SourceEntry> entries})> get groups {
    final bindings = raw['bindings'] as Map;
    return [
      (
        title: 'Святое Пісанне',
        entries: [
          entry(bibleId('bel', true)!),
          entry(bibleId('bel', false)!),
          entry(bibleId('ru', false)!),
        ],
      ),
      for (final section in ['readings', 'liturgy-hours', 'compendium'])
        (
          title: raw['sections'][section] as String,
          entries: (bindings[section] as List)
              .map((id) => entry(id as String))
              .toList(growable: false),
        ),
    ];
  }
}

class SourceEntry {
  const SourceEntry(this.raw);
  final Map<String, dynamic> raw;
  String get id => raw['id'] as String;
  String get digitalLabel => raw['digitalSources'][0]['label'] as String;
  String get digitalUrl => raw['digitalSources'][0]['url'] as String;
  String? get translationLabel => raw['translation']['label'] as String?;

  // Presentation matches SourceRights.vue at the pinned Web revision.
  String get textLabel => id == 'bible-nt-kkbb-2017'
      ? ''
      : (translationLabel ?? '')
            .replaceFirst(' · ', ' — ')
            .replaceFirst(', ${raw['years']}', '');

  String get edition {
    if (id == 'bible-ru-synodal') return '';
    final title =
        ['liturgy-hours-2012-2020', 'compendium-kkbb-2010'].contains(id)
        ? raw['officialEdition'] as String
        : '«${raw['officialEdition']}»';
    final details = [
      raw['publicationPlace'],
      raw['years'],
    ].whereType<String>().where((s) => s.isNotEmpty).join(', ');
    return '$title${details.isEmpty ? '' : ' ($details)'}';
  }

  List<String> get notices {
    final notices = (raw['copyrightNotices'] as List).cast<String>();
    if (notices.isEmpty) {
      return [if (raw['rightsholder'] case final String holder) holder];
    }
    return notices
        .map(
          (notice) => notice.replaceFirstMapped(
            RegExp(r'^© Copyright (\d+) — (.+)$'),
            (m) => '© ${m[2]}, ${m[1]}',
          ),
        )
        .toList(growable: false);
  }
}

class HoursDecrees {
  HoursDecrees.fromJson(Map<String, dynamic> json)
    : title = json['title'] as String,
      documents = (json['documents'] as List)
          .map((d) => HoursDecree(d as Map<String, dynamic>))
          .toList(growable: false);
  final String title;
  final List<HoursDecree> documents;
  static Future<HoursDecrees> load() async =>
      HoursDecrees.fromJson(await _read('liturgy-hours-decrees'));
}

class HoursDecree {
  const HoursDecree(this.raw);
  final Map<String, dynamic> raw;
  String get id => raw['id'] as String;
  String get roman => raw['roman'] as String;
  String get number => raw['number'] as String;
  String get heading => raw['heading'] as String;
  List<String> lines(String field) => (raw[field] as List).cast<String>();
}

class DocumentRun {
  const DocumentRun({
    required this.text,
    this.tone = 'black',
    this.italic = false,
    this.small = false,
    this.bold = false,
  });
  factory DocumentRun.fromJson(Map<String, dynamic> json) => DocumentRun(
    text: json['text'] as String,
    tone: json['tone'] as String,
    italic: json['italic'] as bool,
    small: json['small'] as bool,
    bold: json['bold'] as bool,
  );
  final String text;
  final String tone;
  final bool italic, small, bold;
}

class CalendarRow {
  CalendarRow.fromJson(Map<String, dynamic> json)
    : kind = json['kind'] as String,
      month = json['month'] as int?,
      date = json['date'] as int?,
      dateTone = json['dateTone'] as String?,
      indent = json['indent'] as bool? ?? false,
      text = json['text'] as String?,
      runs = _runs(json['runs']),
      rank = _runs(json['rank']);
  final String kind;
  final int? month, date;
  final String? text, dateTone;
  final bool indent;
  final List<DocumentRun> runs, rank;
  static List<DocumentRun> _runs(dynamic value) => (value as List? ?? [])
      .map((r) => DocumentRun.fromJson(r as Map<String, dynamic>))
      .toList(growable: false);
}

class CalendarPage {
  CalendarPage.fromJson(Map<String, dynamic> json)
    : number = json['number'] as int,
      rows = (json['rows'] as List)
          .map((r) => CalendarRow.fromJson(r as Map<String, dynamic>))
          .toList(growable: false);
  final int number;
  final List<CalendarRow> rows;
}

class ProperCalendarDocument {
  ProperCalendarDocument.fromJson(Map<String, dynamic> json)
    : title = json['title'] as String,
      months = (json['months'] as List)
          .map((m) => (number: m['number'] as int, title: m['title'] as String))
          .toList(growable: false),
      pages = (json['pages'] as List)
          .map((p) => CalendarPage.fromJson(p as Map<String, dynamic>))
          .toList(growable: false);
  final String title;
  final List<({int number, String title})> months;
  final List<CalendarPage> pages;
  Iterable<CalendarRow> get rows => pages.expand((p) => p.rows);

  /// Five PDF lines, one logical paragraph, exactly as corrected in Web.
  List<DocumentRun> get introRuns => [
    for (final row in rows.where((r) => r.kind == 'intro').indexed) ...[
      if (row.$1 > 0)
        DocumentRun(
          text: ' ',
          tone: row.$2.runs.first.tone,
          italic: row.$2.runs.first.italic,
          small: row.$2.runs.first.small,
          bold: row.$2.runs.first.bold,
        ),
      ...row.$2.runs,
    ],
  ];

  static Future<ProperCalendarDocument> load() async =>
      ProperCalendarDocument.fromJson(await _read('proper-calendar'));
}
