import 'package:mybrev_flutter/ordo/season.dart';

/// Season of the selected Office, including its own date for I Vespers.
String? commonSeasonVariant(Season? season) => switch (season?.period) {
  'advent' || 'christmas' || 'lent' || 'easter' => season!.period,
  'holyweek'
      when const {'palm-sunday', 'holy-week'}.contains(season?.periodPhase) =>
    'lent',
  _ => null,
};

/// A private view of a cached Common. Seasonal deltas never mutate storage.
Map<String, dynamic>? materializeCommonForSeason(
  Map<String, dynamic>? template,
  Season? season,
  Set<String> contentFields,
) {
  final variants = template?['_seasonalVariants'];
  final variant = commonSeasonVariant(season);
  final delta = variants is Map ? variants[variant] : null;
  if (template == null || delta is! Map || delta.isEmpty) return template;
  final flat = {...template}..remove('_seasonalVariants');
  final rules = template['_fieldRules'] is Map
      ? Map<String, dynamic>.from(template['_fieldRules'] as Map)
      : <String, dynamic>{};
  final applied = <String>[];
  for (final entry in delta.entries) {
    final field = entry.key.toString();
    final value = entry.value;
    if (!contentFields.contains(field)) continue;
    if (value is String || (value is List && value.every((v) => v is String))) {
      flat[field] = value is List ? [...value] : value;
      rules.remove(field);
    } else if (value == null) {
      flat.remove(field);
      rules[field] = {'omit': true};
    } else if (value is Map && _validRule(value['rule'])) {
      flat.remove(field);
      rules[field] = Map<String, dynamic>.from(value['rule'] as Map);
    } else {
      continue;
    }
    applied.add(field);
  }
  if (rules.isEmpty) {
    flat.remove('_fieldRules');
  } else {
    flat['_fieldRules'] = rules;
  }
  flat['_seasonal'] = {'variant': variant, 'fields': applied};
  return flat;
}

bool _validRule(Object? value) {
  if (value is! Map) return false;
  if (value['omit'] == true) return true;
  if (value.containsKey('ref')) {
    final refs = value['ref'] is List ? value['ref'] as List : [value['ref']];
    return refs.isNotEmpty && refs.every((v) => v is String && v.isNotEmpty);
  }
  return const {
        'current-day',
        'sunday-week-1',
        'common',
        'template',
        'proper',
        'complementary',
        'office-for-dead',
      }.contains(value['source']) &&
      (value['source'] != 'template' ||
          (value['template']?.toString().isNotEmpty ?? false));
}
