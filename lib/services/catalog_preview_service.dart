import 'package:mybrev_flutter/content/content_store.dart';
import 'package:mybrev_flutter/constants/liturgical.dart';
import 'package:mybrev_flutter/models/parsed_reading.dart';
import 'package:mybrev_flutter/ordo/definitions.dart';
import 'package:mybrev_flutter/ordo/liturgical_catalog.dart';
import 'package:mybrev_flutter/ordo/reading_references.dart';
import 'package:mybrev_flutter/ordo/readings_plan.dart';
import 'package:mybrev_flutter/utils/liturgical_day_resolution.dart';
import 'package:mybrev_flutter/utils/office_assembly.dart';
import 'package:mybrev_flutter/utils/readings_selection.dart';

class PreviewSource {
  const PreviewSource(
    this.id,
    this.collection,
    this.label,
    this.fields,
    this.instructions,
  );
  final String id, collection, label;
  final Map<String, String> fields;
  final List<String> instructions;
}

class ContentPreview {
  const ContentPreview({
    required this.sources,
    required this.readings,
    required this.missing,
    required this.errors,
  });
  final List<PreviewSource> sources;
  final List<ParsedReading> readings;
  final List<String> missing, errors;
  bool get hasHours => sources.any((s) => s.fields.isNotEmpty);
  bool get hasContent => hasHours || readings.isNotEmpty;
  String get status => hasContent
      ? 'available-sources'
      : errors.isNotEmpty
      ? 'unavailable'
      : 'no-content';
  String get availability {
    final own = sources.any(
      (s) => s.collection != 'liturgicalTemplates' && s.fields.isNotEmpty,
    );
    final common = sources.any(
      (s) => s.collection == 'liturgicalTemplates' && s.fields.isNotEmpty,
    );
    return own && common
        ? 'proper-and-common'
        : own
        ? 'proper-only'
        : common
        ? 'common-only'
        : 'none';
  }
}

typedef PreviewDocument = Json? Function(String collection, String id);
typedef PreviewDocuments = Iterable<Json> Function(String collection);

/// Source-only access. Never calls contentForDate or assembles an Office.
ContentPreview loadCatalogPreview(
  CatalogEntry entry, {
  required PreviewDocument document,
  required PreviewDocuments documents,
  required String diocese,
}) {
  final missing = <String>[], errors = <String>[], sources = <PreviewSource>[];
  Json? read(String collection, String id) {
    try {
      final doc = document(collection, id);
      return doc == null || doc['_obsolete'] == true
          ? null
          : {...doc, 'id': id};
    } catch (_) {
      errors.add('$collection/$id');
      return null;
    }
  }

  Iterable<Json> query(String collection) {
    try {
      return documents(
        collection,
      ).where((d) => d['_obsolete'] != true).toList();
    } catch (_) {
      errors.add(collection);
      return const [];
    }
  }

  bool nonempty(Object? v) =>
      v is String &&
      v.trim().isNotEmpty &&
      !isFromDayReference(v) &&
      !RegExp(
        r'^\[?from-(?:first-week|own-texts)\]?$',
      ).hasMatch(v.replaceAll(RegExp('<[^>]*>'), '').trim());
  String text(Object? v) => v is List
      ? v.where(nonempty).join('\n\n')
      : nonempty(v)
      ? '$v'
      : '';
  void source(Json doc, String collection, String label) {
    final fields = <String, String>{
      for (final key in {
        ...kOfficeFieldSlots.keys,
        ...kFirstVesperFields,
        'officeOfReadingsTeDeum',
      })
        if (text(doc[key]).isNotEmpty) key: text(doc[key]),
    };
    final rules = doc['_fieldRules'] as Map? ?? {};
    final instructions = <String>[];
    for (final rule in rules.entries) {
      if (rule.value is! Map || rule.value['omit'] == true) continue;
      final value = rule.value as Map;
      final description = value['ref'] != null
          ? 'З іншай часткі гэтых тэкстаў'
          : switch (value['source']) {
              'current-day' =>
                'З бягучага літургічнага дня — патрэбны каляндарны кантэкст',
              'common' || 'template' => 'З агульных тэкстаў',
              'sunday-week-1' => 'З нядзелі I тыдня псалтыра',
              'proper' => 'З уласных тэкстаў',
              'complementary' => 'З дадатковай псальмодыі',
              'office-for-dead' => 'З тэкстаў за памерлых',
              _ => 'Крыніца патрабуе літургічнага кантэксту',
            };
      instructions.add('${previewFieldLabel('${rule.key}')}: $description');
    }
    sources.add(
      PreviewSource('${doc['id']}', collection, label, fields, instructions),
    );
  }

  final proper = <(Json, String)>[];
  void resolveRef(Map ref) {
    final ids = ref['dayIds'] as List? ?? [if (ref['id'] != null) ref['id']];
    for (final id in ids) {
      final sparse = entry.isPeriod
          ? null
          : read('liturgicalProperTexts', '$id');
      final doc = sparse ?? read('days', '$id');
      if (doc == null) {
        missing.add('$id');
        continue;
      }
      if (isSparseDayData(doc)) {
        proper
          ..clear()
          ..add((doc, sparse == null ? 'days' : 'liturgicalProperTexts'));
        break;
      }
      proper.add((doc, sparse == null ? 'days' : 'liturgicalProperTexts'));
    }
    if (proper.isEmpty && ref['_feast'] != null) {
      proper.addAll(
        query('days')
            .where(
              (d) =>
                  '${d['_feast']}'.replaceFirst('feast-', '') ==
                  '${ref['_feast']}'.replaceFirst('feast-', ''),
            )
            .map((d) => (d, 'days')),
      );
    }
  }

  for (final ref in [
    entry.data['daysRef'],
    ...?(entry.data['fallbackDaysRefs'] as List?),
  ]) {
    if (ref is Map) resolveRef(ref);
    if (proper.isNotEmpty) break;
  }
  if (proper.isEmpty && entry.isPeriod) {
    for (final ref in entry.data['fixedSourceRefs'] as List? ?? []) {
      for (final id in (ref as Map)['dayIds'] as List? ?? []) {
        final sparse = read('liturgicalProperTexts', '$id');
        final doc = sparse ?? read('days', '$id');
        if (doc != null) {
          proper.add((doc, sparse == null ? 'days' : 'liturgicalProperTexts'));
        }
      }
    }
  }
  for (final (doc, collection) in proper) {
    source(
      doc,
      collection,
      entry.isPeriod ? 'Тэксты дня перыяду' : 'Уласныя тэксты',
    );
  }
  final templates = <String>{
    ...?((entry.data['templates'] as List?)?.cast<String>()),
    if (entry.data['defaultTemplate'] is String)
      entry.data['defaultTemplate'] as String,
    for (final (doc, _) in proper)
      ...?((doc['_templates'] as List?)?.cast<String>()),
  }..remove('current-day');
  for (final id in templates) {
    final doc = read('liturgicalTemplates', id);
    if (doc == null) {
      missing.add('liturgicalTemplates/$id');
      continue;
    }
    source(doc, 'liturgicalTemplates', 'Агульныя тэксты');
    // Preserve any published seasonal source parts independently; no season
    // is silently selected on behalf of a calendar date.
    final variants = doc['_seasonalVariants'] ?? doc['_seasons'];
    if (variants is Map) {
      for (final v in variants.entries) {
        if (v.value is Map) {
          final variant = {...doc, 'id': '$id:${v.key}'};
          final rules = Json.from(doc['_fieldRules'] as Map? ?? {});
          for (final delta in (v.value as Map).entries) {
            if (delta.value is Map && delta.value['rule'] is Map) {
              variant.remove(delta.key);
              rules['${delta.key}'] = delta.value['rule'];
            } else {
              variant['${delta.key}'] = delta.value;
              rules.remove(delta.key);
              if (delta.value == null) rules['${delta.key}'] = {'omit': true};
            }
          }
          variant['_fieldRules'] = rules;
          source(
            variant,
            'liturgicalTemplates',
            'Агульныя тэксты · ${periodLabelMap[v.key] ?? 'сезонны варыянт'}',
          );
        }
      }
    }
  }
  final readings = <ParsedReading>[];
  final ref = entry.data['readingsRef'];
  if (ref is Map) {
    try {
      final pool = [
        for (final d in query('readings'))
          if (d['_place'] == null ||
              (d['_place'] is List
                  ? (d['_place'] as List).isEmpty ||
                        (d['_place'] as List).contains(diocese)
                  : d['_place'] == diocese))
            ParsedReading.fromMap('${d['id']}', d),
      ];
      readings.addAll(
        selectReadingDocuments(
          ReadingLookup(entry.isPeriod ? 'weekday' : 'proper', Json.from(ref)),
          entry.data,
          pool,
        ),
      );
    } catch (_) {
      errors.add('readings');
    }
  }
  return ContentPreview(
    sources: sources,
    readings: collapseCoveredReadings(readings),
    missing: missing.toSet().toList(),
    errors: errors.toSet().toList(),
  );
}

Future<ContentPreview> catalogPreviewFromStore(
  CatalogEntry entry,
  String diocese,
) async {
  final store = ContentStore.instance;
  await store.ensureLoaded([
    'days',
    'liturgicalProperTexts',
    'liturgicalTemplates',
    'readings',
  ]);
  return loadCatalogPreview(
    entry,
    diocese: diocese,
    document: (collection, id) {
      final raw = store.collection(collection).get(id);
      return raw is Map ? Json.from(raw) : null;
    },
    documents: (collection) sync* {
      final items = store.collection(collection);
      for (final key in items.keys) {
        final raw = items.get(key);
        if (raw is Map) yield {...Json.from(raw), 'id': key};
      }
    },
  );
}

String previewFieldLabel(String field) {
  final slot =
      kOfficeFieldSlots[field] ??
      kOfficeFieldSlots[field.replaceFirst('vesper1', 'vesper')];
  const hours = {
    'invitatory': 'Запрашэнне',
    'officeOfReadings': 'Афіцый чытанняў',
    'lauds': 'Ютрань',
    'daytime': 'Малая гадзіна',
    'vespers': 'Нешпары',
  };
  const parts = {
    'antiphon': 'Антыфона',
    'hymn': 'Гімн',
    'antiphons': 'Антыфона',
    'psalmody': 'Псальм',
    'versicle': 'Верш',
    'reading1': 'Першае чытанне',
    'reading2': 'Другое чытанне',
    'reading': 'Чытанне',
    'prayer': 'Малітва',
    'canticleAntiphon': 'Антыфона да песні',
    'intercessions': 'Просьбы',
  };
  return '${field.startsWith('vesper1') ? 'I Нешпары' : hours[slot?.$1] ?? 'Тэкст'} · ${parts[slot?.$2] ?? 'Гімн'}';
}
