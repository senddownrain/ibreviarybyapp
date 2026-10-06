/// Calendar resolver: every candidate of a date, nothing discarded (port of
/// mybrev `src/utils/ordo/candidates.js`). Candidates carry their precedence
/// and the `days` / `readings` identities; status is informational here.
library;

import 'package:mybrev_flutter/ordo/dates.dart';
import 'package:mybrev_flutter/ordo/definitions.dart';
import 'package:mybrev_flutter/ordo/precedence.dart';
import 'package:mybrev_flutter/ordo/season.dart';
import 'package:mybrev_flutter/ordo/year_plan.dart';
import 'package:mybrev_flutter/utils/liturgical_day_resolution.dart';
import 'package:mybrev_flutter/utils/liturgical_titles.dart';

const _seasonColor = {
  'advent': 'violaceus',
  'lent': 'violaceus',
  'holyweek': 'violaceus',
  'christmas': 'albus',
  'easter': 'albus',
  'ordinary': 'viridis',
};

String temporalColor(Season season) {
  if (season.date == season.anchors.goodFriday) return 'ruber';
  if (season.date == season.anchors.holyThursday) return 'albus';
  return _seasonColor[season.period] ?? 'viridis';
}

/// Gaudete and Laetare may use rose; Holy Saturday prints the Vigil's white.
List<String> temporalColorAlternatives(Season season) {
  final rose =
      season.isSunday &&
      ((season.period == 'advent' && season.periodWeek == 3) ||
          (season.period == 'lent' && season.periodWeek == 4));
  if (rose) return const ['rosaceus'];
  if (season.date == season.anchors.holySaturday) return const ['albus'];
  return const [];
}

/// Existing `days` identities of the temporal day.
Json temporalDaysRef(Season season) {
  final date = dateOfIso(season.date);
  final period = season.period;
  final week = season.periodWeek;
  final day = season.dayOfWeek;
  String? psalterDayId;
  if (period == 'ordinary') {
    psalterDayId = periodPsalterDayDocumentId(period, week, day);
  } else if (period != 'christmas') {
    psalterDayId = ordinaryPsalterDayDocumentId(week, day);
  }
  return {
    'source': 'period',
    'id': periodDayDocumentId(period, week, day),
    '_periodType': period,
    '_periodWeekNumber': week,
    '_dayOfWeek': day,
    'seasonalDateId': seasonalDateExceptionId(date, period),
    'fixedDateOnly': isChristmasDateExceptionExclusion(date),
    'psalterDayId': (psalterDayId?.isEmpty ?? true) ? null : psalterDayId,
  };
}

/// Existing `readings` identities of the temporal day.
Json temporalReadingsRef(Season season) {
  final date = dateOfIso(season.date);
  final dateOnly =
      isSeasonalDateException(date, season.period) ||
      isChristmasDateExceptionExclusion(date);
  if (dateOnly) return {'_date': fixedDateKey(season.date), 'dateOnly': true};
  return {
    '_periodType': season.period,
    '_periodWeekNumber': season.periodWeek == 0 ? [0, null] : season.periodWeek,
    '_dayOfWeek': season.dayOfWeek,
  };
}

String _candidateKind(Json celebration) {
  if (celebration['layer'] == 'override') return 'override';
  final daysRef = celebration['daysRef'];
  if (daysRef is Map && daysRef['source'] == 'dynamic') return 'dynamic';
  return 'fixed';
}

Json celebrationCandidate(Placement placement, {String status = 'active'}) {
  final c = placement.celebration;
  final tieBreak = c['manualTieBreakPriority'];
  final templates = c['templates'];
  return {
    'id': c['id'],
    'kind': _candidateKind(c),
    'title': c['title'],
    'rank': c['rank'],
    'rankKind': rankKind(c['rank']),
    'category': c['category'],
    'layer': c['layer'],
    if (c['dioceseId'] != null) 'dioceseId': c['dioceseId'],
    if (c['properKind'] != null) 'properKind': c['properKind'],
    if (c['feastCode'] != null) 'feastCode': c['feastCode'],
    'temporal': c['temporal'] == true,
    'precedence': placement.precedence,
    'color': (c['color'] as String?)?.isNotEmpty == true ? c['color'] : 'albus',
    if (c['colorAlternatives'] != null)
      'colorAlternatives': c['colorAlternatives'],
    'daysRef': c['daysRef'],
    if (c['fallbackDaysRefs'] != null)
      'fallbackDaysRefs': c['fallbackDaysRefs'],
    'readingsRef': c['readingsRef'],
    if (templates is List && templates.isNotEmpty) 'templates': templates,
    if ((c['defaultTemplate'] ?? '').toString().isNotEmpty)
      'defaultTemplate': c['defaultTemplate'],
    if (c['contentStatus'] != null) 'contentStatus': c['contentStatus'],
    if ((c['readingsReference'] ?? '').toString().isNotEmpty)
      'readingsReference': c['readingsReference'],
    if (tieBreak is num) 'manualTieBreakPriority': tieBreak,
    'rules': c['rules'] ?? const <String, dynamic>{},
    'layerTrail': c['layerTrail'] ?? const [],
    if (c['inheritedFrom'] != null) 'inheritedFrom': c['inheritedFrom'],
    if (placement.transferredFrom != null) ...{
      'transferredFrom': placement.transferredFrom,
      'transferRule': placement.transferRule,
    },
    if (placement.transferredTo != null)
      'transferredTo': placement.transferredTo,
    if (placement.movedFrom != null) 'movedFrom': placement.movedFrom,
    if (placement.yearOverride != null) 'yearOverride': placement.yearOverride,
    'order': placement.order,
    'status': status,
  };
}

Json temporalCandidate(Season season) => {
  'id': 'temporal:${season.period}-w${season.periodWeek}-d${season.dayOfWeek}',
  'kind': 'temporal',
  'title': formatLiturgicalPeriodTitle(
    periodType: season.period,
    periodWeek: season.periodWeek,
    dayOfWeek: season.dayOfWeek,
    date: dateOfIso(season.date),
  ),
  'rank': season.isSunday ? 'dominica' : 'feria',
  'rankKind': season.isSunday ? 'sunday' : 'weekday',
  'category': 'season',
  'layer': 'universal',
  'temporal': true,
  'precedence': temporalPrecedence(season),
  'color': temporalColor(season),
  'colorAlternatives': temporalColorAlternatives(season),
  'daysRef': temporalDaysRef(season),
  'readingsRef': temporalReadingsRef(season),
  'rules': const <String, dynamic>{},
  'layerTrail': const ['universal'],
  'order': -1,
  'status': 'active',
};

/// Optional memorial of the BVM on Saturdays of Ordinary Time (GNLYC 15).
Json? saturdayMaryCandidate(Season season) {
  if (season.period != 'ordinary' || season.dayOfWeek != 7) return null;
  return {
    'id': 'saturday-blessed-virgin-mary',
    'kind': 'votive-memorial',
    'title': 'Успамін Найсв. Панны Марыі ў суботу',
    'rank': 'memoria-ad-libitum',
    'rankKind': 'optional-memorial',
    'category': 'mary',
    'layer': 'universal',
    'temporal': false,
    'precedence': 12,
    'color': 'albus',
    'daysRef': {'source': 'template', 'template': 'blessed-virgin-mary'},
    'readingsRef': {'common': 'blessed-virgin-mary'},
    'templates': const ['blessed-virgin-mary'],
    'defaultTemplate': 'blessed-virgin-mary',
    'contentStatus': {'hours': 'common-only'},
    'rules': {'onlyWithoutObligatoryMemorial': true},
    'layerTrail': const ['universal'],
    'order': 10000,
    'status': 'active',
  };
}

/// All candidates of [iso] from the year plan.
(Season, List<Json>) collectCandidates(String iso, YearPlan plan) {
  final season = plan.seasonOf(iso);
  final list = <Json>[temporalCandidate(season)];
  for (final placement in plan.byDate[iso] ?? const <Placement>[]) {
    list.add(
      celebrationCandidate(
        placement,
        status: placement.transferredOut ? 'transferred' : 'active',
      ),
    );
  }
  for (final item in plan.removedByDate[iso] ?? const <Placement>[]) {
    list.add({
      ...celebrationCandidate(item.copy()..precedence = 99, status: 'removed'),
      'removalReason': item.reason,
    });
  }
  final saturday = saturdayMaryCandidate(season);
  if (saturday != null) list.add(saturday);
  return (season, list);
}
