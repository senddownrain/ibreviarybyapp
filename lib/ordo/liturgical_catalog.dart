/// Year-independent identities; only the existing Ordo resolves occurrences.
library;

import 'dart:convert';
import 'package:mybrev_flutter/constants/liturgical.dart';
import 'package:mybrev_flutter/ordo/definitions.dart';
import 'package:mybrev_flutter/ordo/engine.dart';
import 'package:mybrev_flutter/ordo/year_plan.dart';
import 'package:mybrev_flutter/providers/diocese_provider.dart';

String _pad(Object n) => '$n'.padLeft(2, '0');

class CatalogEntry {
  const CatalogEntry(this.data, {this.dioceses = const []});
  final Json data;
  final List<String> dioceses;
  String get id => '${data['id']}';
  String get title => '${data['title']}';
  bool get isPeriod => data['kind'] == 'period';
  String? get period => data['periodKey'] as String?;
  String get rank => '${data['rank'] ?? ''}';
  String get rankLabel =>
      feastTypeLabelMap[rank] ??
      (isPeriod ? 'Дзень перыяду' : 'Літургічны дзень');
  String get color => '${data['color'] ?? ''}';
  List<String> get colors => [
    if (color.isNotEmpty) color,
    ...?(data['colorAlternatives'] as List?)?.cast<String>(),
  ];
  Json get dateRule => Json.from(data['dateRule'] as Map? ?? const {});
  bool get isFixed => dateRule['type'] == 'fixed';
  String get dateLabel => catalogDateLabel(dateRule);
  String get contentLabel => isPeriod
      ? 'Крыніцы дня перыяду'
      : 'Уласныя і агульныя крыніцы — наяўнасць у картцы';
  String get description => [
    dateLabel,
    rankLabel,
    if (!isPeriod) isFixed ? 'Нерухомая дата' : 'Рухомая дата',
    ...colors.map(
      (c) =>
          const {
            'albus': 'Белы',
            'ruber': 'Чырвоны',
            'viridis': 'Зялёны',
            'violaceus': 'Фіялетавы',
            'rosaceus': 'Ружовы',
            'niger': 'Чорны',
          }[c] ??
          c,
    ),
    ...dioceses.map((d) => kDioceseNames[d] ?? d),
  ].where((s) => s.isNotEmpty).join(' · ');
  bool matches(String query, String filter) {
    if (filter == 'fixed' && !isFixed || filter == 'dynamic' && isFixed) {
      return false;
    }
    final q = query.trim().toLowerCase().replaceAllMapped(
      RegExp(r'(\d{2}\.\d{2})\.\d{4}'),
      (m) => m[1]!,
    );
    return '$title $description $id'.toLowerCase().contains(q);
  }
}

String catalogDateLabel(Json rule) => switch (rule['type']) {
  'fixed' => '${_pad(rule['day'])}.${_pad(rule['month'])}',
  'named' =>
    const {
          'ascension': 'Унебаўшэсце паводле календара краіны',
          'corpusChristi': 'Цела і Кроў Хрыста паводле календара краіны',
          'holyFamily': 'Свята Святой Сям’і паводле календара краіны',
          'baptismOfLord': 'Хрост Пана паводле календара краіны',
        }[rule['rule']] ??
        'Рухомая дата',
  'movable' =>
    '${rule['offsetDays'] ?? 0} дзён ад ${const {'easterSunday': 'Вялікадня', 'pentecost': 'Спаслання Духа Святога', 'firstAdventSunday': 'I нядзелі Адвэнту', 'christmas': 'Божага Нараджэння', 'epiphany': 'Аб’яўлення Пана'}[rule['anchor']] ?? 'літургічнай падзеі'}',
  'last-weekday-of-month' =>
    'Апошні дзень: ${weekdayLabelMap[(rule['isoWeekday'] as int) % 7 + 1]}, месяц ${rule['month']}',
  _ => '',
};

Object? _canonical(Object? value) => value is Map
    ? {
        for (final key in value.keys.map((e) => '$e').toList()..sort())
          key: _canonical(value[key]),
      }
    : value is List
    ? value.map(_canonical).toList()
    : value;

List<CatalogEntry> feastCatalog(
  OrdoDefinitions definitions,
  List<String> dioceses,
) {
  final rows = <String, CatalogEntry>{};
  for (final diocese in dioceses.toSet()) {
    for (final definition in buildCalendarLayers(
      definitions,
      diocese: diocese,
    ).celebrations.values) {
      if (definition['suppressedBy'] != null || definition['date'] is! Map) {
        continue;
      }
      final date = Json.from(definition['date'] as Map);
      final rule =
          date['type'] == 'movable' && kNamedDateRules.contains(date['anchor'])
          ? <String, dynamic>{'type': 'named', 'rule': date['anchor']}
          : date;
      final identity = Json.of(definition)
        ..remove('layerTrail')
        ..remove('inheritedFrom')
        ..remove('dioceseId');
      final signature = jsonEncode(_canonical(identity));
      final row = rows.putIfAbsent(
        signature,
        () => CatalogEntry({
          ...definition,
          'scope': definition['layer'],
          'dateRule': rule,
          'kind': 'feast',
        }, dioceses: []),
      );
      row.dioceses.add(diocese);
    }
  }
  return rows.values.toList()..sort((a, b) {
    int key(CatalogEntry e) => e.isFixed
        ? (e.dateRule['month'] as int) * 100 + (e.dateRule['day'] as int)
        : 10000;
    final date = key(a).compareTo(key(b));
    return date != 0
        ? date
        : '${a.title}|${a.id}|${a.rank}|${a.dioceses.join(',')}'.compareTo(
            '${b.title}|${b.id}|${b.rank}|${b.dioceses.join(',')}',
          );
  });
}

List<CatalogEntry> periodCatalog(OrdoDefinitions definitions) {
  final entries = <CatalogEntry>[];
  void weekly(String period, int week, int day) {
    final source = '$period-w$week-d$day';
    final opening = {
      4: 'Папялец',
      5: 'Чацвер пасля Папяльца',
      6: 'Пятніца пасля Папяльца',
      7: 'Субота пасля Папяльца',
    };
    entries.add(
      CatalogEntry({
        'id': 'period:$source',
        'kind': 'period',
        'periodKey': period,
        'week': week,
        'weekday': day,
        'title':
            '${periodLabelMap[period]} · ${week == 0 ? opening[day] : '$week тыдзень · ${weekdayLabelMap[day]}'}',
        'daysRef': {'id': source},
        'readingsRef': {
          '_periodType': period,
          '_periodWeekNumber': week == 0 ? [0, null] : week,
          '_dayOfWeek': day,
        },
      }),
    );
  }

  for (final pair in {
    'advent': 4,
    'lent': 5,
    'holyweek': 1,
    'easter': 7,
    'ordinary': 34,
  }.entries) {
    for (var week = 1; week <= pair.value; week++) {
      for (var day = 1; day <= 7; day++) {
        weekly(pair.key, week, day);
      }
    }
  }
  for (var day = 4; day <= 7; day++) {
    weekly('lent', 0, day);
  }
  weekly('easter', 8, 1);
  for (final week in [1, 2]) {
    weekly('christmas', week, 1);
  }
  final layered = buildCalendarLayers(definitions).celebrations.values;
  void special(String period, int month, int day) {
    final key = '${_pad(day)}.${_pad(month)}';
    final refs = [
      for (final d in layered)
        if (d['date'] is Map &&
            d['date']['type'] == 'fixed' &&
            d['date']['month'] == month &&
            d['date']['day'] == day &&
            (d['temporal'] == true ||
                period == 'christmas' &&
                    (month == 12 && day <= 28 ||
                        month == 1 && [1, 6].contains(day))))
          if (d['daysRef'] is Map) d['daysRef'],
    ];
    entries.add(
      CatalogEntry({
        'id': 'period:$period-${_pad(day)}-${_pad(month)}',
        'kind': 'period',
        'periodKey': period,
        'specialDateKey': key,
        'fixedSourceRefs': refs,
        'title': '${periodLabelMap[period]} · $key',
        'daysRef': {'id': '$period-${_pad(day)}-${_pad(month)}'},
        'readingsRef': {'_date': key, 'dateOnly': true},
      }),
    );
  }

  for (var d = 17; d <= 24; d++) {
    special('advent', 12, d);
  }
  for (var d = 25; d <= 31; d++) {
    special('christmas', 12, d);
  }
  for (var d = 1; d <= 13; d++) {
    special('christmas', 1, d);
  }
  return entries;
}

bool periodMatchesDay(CatalogEntry entry, OrdoDay day) {
  if (entry.period != day.period) return false;
  final special = entry.data['specialDateKey'];
  if (special != null) {
    final datedFeria =
        entry.period == 'advent' ||
        (entry.period == 'christmas' &&
            (entry.data['fixedSourceRefs'] as List? ?? []).isEmpty);
    return '${day.date.substring(8)}.${day.date.substring(5, 7)}' == special &&
        (!datedFeria || day.dayOfWeek != 1);
  }
  return entry.data['week'] == day.week &&
      entry.data['weekday'] == day.dayOfWeek;
}

const occurrenceLabels = {
  'primary': 'Асноўнае святкаванне',
  'legal-alternative': 'Дазволены варыянт',
  'commemoration': 'Памінанне — толькі далучэнне ўласных частак',
  'transferred': 'Перанесена',
  'suppressed/impeded': 'У гэтым годзе не адзначаецца',
  'not-applicable-in-diocese': 'Не адзначаецца ў гэтай дыяцэзіі',
  'no-content': 'Тэксты не знойдзены',
};

class CalendarOccurrence {
  const CalendarOccurrence({
    required this.entryId,
    required this.year,
    required this.diocese,
    required this.mode,
    required this.status,
    this.originalDate,
    this.effectiveDate,
    this.optionId,
    this.reason = '',
    this.canOpenHours = false,
    this.canOpenReadings = false,
    this.color = '',
  });
  final String entryId, diocese, mode, status, reason, color;
  final int year;
  final String? originalDate, effectiveDate, optionId;
  final bool canOpenHours, canOpenReadings;
  bool get canOpen => mode == 'readings' ? canOpenReadings : canOpenHours;
  Json toJson() => {
    'entryId': entryId,
    'year': year,
    'diocese': diocese,
    'status': status,
    'effectiveDate': effectiveDate,
    'canOpenHours': canOpenHours,
    'canOpenReadings': canOpenReadings,
    'color': color,
  };
}

CalendarOccurrence calendarOccurrence(
  OrdoEngine engine,
  CatalogEntry entry,
  int year,
  String diocese,
  String mode,
) {
  OrdoDay? day;
  String? original, effective, optionId = entry.id;
  Placement? removed;
  var applicable = true;
  if (year >= 1583 && year <= 4099) {
    if (entry.isPeriod) {
      // Civil-year semantics match the Web catalog; every candidate is checked
      // against the resolved Ordo identity, never a calculated nearby date.
      day = engine
          .year(year, diocese: diocese)
          .where((d) => periodMatchesDay(entry, d))
          .firstOrNull;
      original = effective = day?.date;
      if (day != null) {
        optionId =
            day.options
                .where((o) => o.id == day!.temporal.id)
                .firstOrNull
                ?.id ??
            (day.primary.temporal ? day.primary.id : day.temporal.id);
        final refs = entry.data['fixedSourceRefs'] as List? ?? [];
        final primaryIds = day.primary.daysRef?['dayIds'] as List? ?? [];
        if (refs.any(
          (r) =>
              r is Map && (r['dayIds'] as List? ?? []).any(primaryIds.contains),
        )) {
          optionId = day.primary.id;
        }
      }
    } else {
      final plan = engine.plan(year, diocese);
      final definition = plan.celebrations[entry.id];
      applicable = definition != null && definition['suppressedBy'] == null;
      final placement = plan.byDate.values
          .expand((v) => v)
          .where((p) => p.id == entry.id && !p.transferredOut)
          .firstOrNull;
      removed = plan.removedByDate.values
          .expand((v) => v)
          .where((p) => p.id == entry.id)
          .firstOrNull;
      original = (placement ?? removed)?.originalDate;
      effective = (placement ?? removed)?.date;
      if (effective != null) {
        day = engine.resolve(effective, diocese: diocese);
      }
    }
  }
  final hours =
      applicable &&
      removed == null &&
      (day?.officeOptions.any((o) => o.id == optionId) ?? false);
  final readings =
      applicable &&
      removed == null &&
      (day?.options.any((o) => o.id == optionId) ?? false);
  final legal = mode == 'readings' ? readings : hours;
  final commemoration =
      day?.commemorations.any((o) => o.id == optionId) ?? false;
  final suppressed = day?.suppressed.where((o) => o.id == optionId).firstOrNull;
  final status = !applicable
      ? 'not-applicable-in-diocese'
      : legal
      ? original != effective
            ? 'transferred'
            : (mode == 'readings' ? day?.primary.id : day?.officePrimary.id) ==
                  optionId
            ? 'primary'
            : 'legal-alternative'
      : commemoration
      ? 'commemoration'
      : 'suppressed/impeded';
  final reason = !applicable
      ? 'Святкаванне адсутнічае ў дзейным календары дыяцэзіі.'
      : removed != null
      ? 'Святкаванне прапушчана рашэннем Ordo на гэты год.'
      : day == null
      ? 'Гэтай літургічнай пазіцыі няма ў выбраным годзе.'
      : commemoration
      ? 'Памінанне не з’яўляецца асобным варыянтам літургіі гадзінаў або чытанняў.'
      : !legal
      ? 'Ordo не дазваляе асобны варыянт для гэтага рэжыму.${suppressed == null ? '' : ' ${catalogSuppressionReason(suppressed.reason)}'}'
      : '';
  return CalendarOccurrence(
    entryId: entry.id,
    year: year,
    diocese: diocese,
    mode: mode,
    status: status,
    originalDate: original,
    effectiveDate: effective,
    optionId: optionId,
    reason: reason,
    canOpenHours: hours,
    canOpenReadings: readings,
    color:
        day?.candidates.where((c) => c['id'] == optionId).firstOrNull?['color']
            as String? ??
        entry.color,
  );
}

String catalogSuppressionReason(String? reason) => switch (reason) {
  'outranked' => 'Перавагу мае святкаванне вышэйшага рангу.',
  'impeded-by-obligatory-memorial' => 'Перашкаджае абавязковы ўспамін.',
  'transferred' => 'Святкаванне перанесена на іншую дату.',
  'suppressed-by-layer' => 'Святкаванне выключана з календара дыяцэзіі.',
  _ => 'Святкаванне саступае літургічнаму дню паводле Ordo.',
};

CalendarOccurrence? nearestCatalogYear(
  OrdoEngine engine,
  CatalogEntry entry,
  int year,
  String diocese,
  String mode, {
  int limit = 12,
}) {
  for (var distance = 1; distance <= limit; distance++) {
    for (final y in [year + distance, year - distance]) {
      if (y < kCalendarFirstDate.year || y > kCalendarLastDate.year) continue;
      final occurrence = calendarOccurrence(engine, entry, y, diocese, mode);
      if (occurrence.canOpen) return occurrence;
    }
  }
  return null;
}
