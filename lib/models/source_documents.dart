import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const sourcesRoute = '/sources';

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
    final title = id == 'compendium-kkbb-2010'
        ? raw['officialEdition'] as String
        : '«${raw['officialEdition']}»';
    final years = id == 'liturgy-hours-2012-2020'
        ? (raw['years'] as String).replaceFirst('-', '–')
        : raw['years'];
    final details = [
      raw['publicationPlace'],
      years,
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
