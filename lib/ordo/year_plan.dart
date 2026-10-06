/// Year plan (port of mybrev `yearPlan.js`, `yearOverrides.js`,
/// `transfers.js`): layered celebrations placed on the dates of one civil
/// year, with the year overrides and the permanent transfer rules applied.
/// Resolution of a single date reads from this plan, so transfers are the
/// same for the whole year and for both Hours and Readings.
library;

import 'package:mybrev_flutter/ordo/dates.dart';
import 'package:mybrev_flutter/ordo/definitions.dart';
import 'package:mybrev_flutter/ordo/movable_feasts.dart';
import 'package:mybrev_flutter/ordo/precedence.dart';
import 'package:mybrev_flutter/ordo/season.dart';

/// A celebration on a date of the year.
class Placement {
  Placement({
    required this.celebration,
    required this.date,
    String? originalDate,
    this.order = 0,
    this.precedence = 0,
    this.movedFrom,
    this.yearOverride,
    this.noAutoTransfer = false,
    this.transferredFrom,
    this.transferRule,
    this.reason,
  }) : originalDate = originalDate ?? date;

  Json celebration;
  String date;
  String originalDate;
  int order;
  int precedence;
  String? movedFrom;
  Json? yearOverride;
  bool noAutoTransfer;
  bool transferredOut = false;
  String? transferredTo;
  String? transferredFrom;
  String? transferRule;
  bool impededWithoutTransfer = false;

  /// Why a removed placement is not celebrated.
  String? reason;

  Placement copy() =>
      Placement(
          celebration: celebration,
          date: date,
          originalDate: originalDate,
          order: order,
          precedence: precedence,
          movedFrom: movedFrom,
          yearOverride: yearOverride,
          noAutoTransfer: noAutoTransfer,
          transferredFrom: transferredFrom,
          transferRule: transferRule,
          reason: reason,
        )
        ..transferredOut = transferredOut
        ..transferredTo = transferredTo
        ..impededWithoutTransfer = impededWithoutTransfer;

  String get id => celebration['id'].toString();
}

class TransferRecord {
  const TransferRecord(this.celebrationId, this.from, this.to, this.rule);
  final String celebrationId;
  final String from;
  final String to;
  final String rule;

  Json toJson() => {
    'celebrationId': celebrationId,
    'from': from,
    'to': to,
    'rule': rule,
  };
}

class YearPlan {
  YearPlan._({
    required this.year,
    required this.diocese,
    required this.anchors,
    required this.celebrations,
    required this.byDate,
    required this.removedByDate,
    required this.transfers,
    required this.celebrationDates,
  });

  final int year;
  final String diocese;
  final YearAnchors anchors;
  final Map<String, Json> celebrations;
  final Map<String, List<Placement>> byDate;
  final Map<String, List<Placement>> removedByDate;
  final List<TransferRecord> transfers;

  /// celebration id → final (post-transfer) date.
  final Map<String, String> celebrationDates;
  final Map<String, Season> _seasons = {};

  Season seasonOf(String iso) =>
      _seasons.putIfAbsent(iso, () => computeSeason(iso));
}

String? _placeCelebration(Json celebration, int year, YearAnchors anchors) {
  final date = celebration['date'];
  if (date is! Map) return null;
  switch (date['type']) {
    case 'fixed':
      final month = (date['month'] as num).toInt();
      final day = (date['day'] as num).toInt();
      final iso = isoFromParts(year, month, day);
      return parseIso(iso).month == month ? iso : null;
    case 'movable':
      final anchor = anchors[date['anchor'].toString()];
      return anchor == null
          ? null
          : addDays(anchor, (date['offsetDays'] as num?)?.toInt() ?? 0);
    case 'last-weekday-of-month':
      final month = (date['month'] as num).toInt();
      final weekday = (date['isoWeekday'] as num).toInt();
      var iso = addDays(isoFromParts(year, month + 1, 1), -1);
      while (isoWeekday(iso) != weekday) {
        iso = addDays(iso, -1);
      }
      return iso;
  }
  return null;
}

// ── Year overrides ──────────────────────────────────────────────────────

const kYearOverrideActions = [
  'move',
  'suppress',
  'add',
  'replace',
  'changeRank',
  'changeColor',
  'changeRule',
];
const _scopeOrder = {'universal': 0, 'belarus': 1, 'diocese': 2};
final _isoDate = RegExp(r'^\d{4}-\d{2}-\d{2}$');

int? _intOf(Object? value) => value is num
    ? (value == value.toInt() ? value.toInt() : null)
    : int.tryParse(value?.toString() ?? '');

List<String> validateYearOverride(Json override) {
  final year = _intOf(override['year']);
  final action = override['action'];
  return [
    if (year == null) 'year must be an integer',
    if (!_scopeOrder.containsKey(override['scope']))
      'scope must be universal, belarus or diocese',
    if (override['scope'] == 'diocese' &&
        (override['dioceseId'] ?? '').toString().isEmpty)
      'dioceseId is required for diocese scope',
    if (!kYearOverrideActions.contains(action)) 'unknown action $action',
    if (action != 'add' &&
        (override['targetCelebrationId'] ?? '').toString().isEmpty)
      'targetCelebrationId is required',
    if (action == 'move' && !_isoDate.hasMatch('${override['to'] ?? ''}'))
      'move requires ISO `to`',
    if (action == 'add' &&
        ((override['celebration'] as Map?)?['id'] == null ||
            !_isoDate.hasMatch('${override['to'] ?? ''}')))
      'add requires `celebration.id` and ISO `to`',
    if (action == 'changeRank' &&
        override['rank'] == null &&
        override['to'] == null)
      'changeRank requires `rank`',
    if (action == 'changeColor' &&
        !kLiturgicalColors.contains(override['color']))
      'changeColor requires a liturgical `color`',
    if (action == 'replace' && override['celebration'] == null)
      'replace requires `celebration` changes',
    for (final field in const ['from', 'to'])
      if (override[field] != null &&
          _isoDate.hasMatch('${override[field]}') &&
          int.parse('${override[field]}'.substring(0, 4)) != year &&
          action != 'changeRank')
        '`$field` must be a date of $year',
  ];
}

/// Overrides of [year] for [diocese], in application order.
List<Json> selectYearOverrides(List<Json> overrides, int year, String diocese) {
  final indexed = [
    for (var i = 0; i < overrides.length; i++)
      if (_intOf(overrides[i]['year']) == year &&
          overrides[i]['enabled'] != false &&
          (overrides[i]['scope'] != 'diocese' ||
              normalizeDioceseId(overrides[i]['dioceseId']?.toString()) ==
                  diocese))
        (i, overrides[i]),
  ];
  indexed.sort((a, b) {
    final scope = (_scopeOrder[a.$2['scope']] ?? 9).compareTo(
      _scopeOrder[b.$2['scope']] ?? 9,
    );
    return scope != 0 ? scope : a.$1.compareTo(b.$1);
  });
  return [for (final item in indexed) item.$2];
}

void _applyYearOverrides(
  List<Placement> placements,
  List<Placement> removed,
  List<Json> overrides,
  Map<String, Json> celebrations,
) {
  for (final override in overrides) {
    if (validateYearOverride(override).isNotEmpty) continue;
    bool matches(Placement placement) =>
        placement.id == override['targetCelebrationId'] &&
        (override['from'] == null || placement.date == override['from']);
    final tag = {
      'action': override['action'],
      'scope': override['scope'],
      'reason': override['reason'] ?? '',
    };
    switch (override['action']) {
      case 'move':
        for (final placement in placements.where(matches)) {
          placement
            ..movedFrom = placement.date
            ..date = override['to'] as String
            ..yearOverride = tag
            ..noAutoTransfer = true;
        }
      case 'suppress':
        for (final placement in placements.where(matches).toList()) {
          removed.add(placement.copy()..reason = 'suppressed-by-year-override');
          placements.remove(placement);
        }
      case 'add':
        final celebration = {
          'layer': 'override',
          ...Json.from(override['celebration'] as Map),
        };
        placements.add(
          Placement(
            celebration: celebration,
            date: override['to'] as String,
            yearOverride: tag,
          ),
        );
        celebrations[celebration['id'].toString()] = Json.from(
          override['celebration'] as Map,
        );
      case 'replace':
        for (final placement in placements.where(matches)) {
          placement
            ..celebration = {
              ...placement.celebration,
              ...Json.from(override['celebration'] as Map),
              'id': placement.celebration['id'],
              'replacedByOverride': true,
            }
            ..yearOverride = tag;
        }
      case 'changeRank':
        for (final placement in placements.where(matches)) {
          placement
            ..celebration = {
              ...placement.celebration,
              'rank': override['rank'] ?? override['to'],
            }
            ..yearOverride = tag;
          placement.celebration.remove('precedence');
        }
      case 'changeColor':
        for (final placement in placements.where(matches)) {
          placement
            ..celebration = ({
              ...placement.celebration,
              'color': override['color'],
            }..remove('colorAlternatives'))
            ..yearOverride = tag;
        }
      case 'changeRule':
        for (final placement in placements.where(matches)) {
          placement
            ..celebration = {
              ...placement.celebration,
              'rules': {
                ...?(placement.celebration['rules'] as Map?)
                    ?.cast<String, dynamic>(),
                ...?(override['rule'] as Map?)?.cast<String, dynamic>(),
              },
            }
            ..yearOverride = tag;
        }
    }
  }
}

// ── Transfers ───────────────────────────────────────────────────────────

class _SpecialTransfer {
  const _SpecialTransfer(
    this.celebrationId,
    this.id,
    this.applies,
    this.target,
  );
  final String celebrationId;
  final String id;
  final bool Function(Season) applies;
  final String Function(YearAnchors) target;
}

final _specialTransfers = [
  _SpecialTransfer(
    'annunciation-lord',
    'annunciation-after-easter-octave',
    (season) =>
        season.period == 'holyweek' ||
        (season.period == 'easter' && season.periodPhase == 'octave'),
    (anchors) => addDays(anchors.divineMercySunday, 1),
  ),
  _SpecialTransfer(
    'sv-joseph',
    'joseph-anticipated-before-palm-sunday',
    (season) => season.period == 'holyweek',
    (anchors) => addDays(anchors.palmSunday, -1),
  ),
];

Json _comparable(Placement placement) => {
  'precedence': placement.precedence,
  'category': placement.celebration['category'],
  'layer': placement.celebration['layer'],
  'order': placement.order,
};

int _comparePlacements(Placement a, Placement b) =>
    compareCandidates(_comparable(a), _comparable(b));

List<TransferRecord> _resolveTransfers(
  Map<String, List<Placement>> byDate,
  Season Function(String) seasonOf,
) {
  final transfers = <TransferRecord>[];
  int? strongestOn(String iso, Placement exclude) {
    int? best;
    for (final item in byDate[iso] ?? const <Placement>[]) {
      if (identical(item, exclude) || item.transferredOut) continue;
      if (best == null || item.precedence < best) best = item.precedence;
    }
    return best;
  }

  bool isFree(String iso, Placement placement) {
    if (isImpedingPrecedence(temporalPrecedence(seasonOf(iso)))) return false;
    final strongest = strongestOn(iso, placement);
    return strongest == null || !isImpedingPrecedence(strongest);
  }

  String? nextFreeDay(String iso, Placement placement) {
    for (var offset = 1; offset <= 90; offset++) {
      final candidate = addDays(iso, offset);
      if (isFree(candidate, placement)) return candidate;
    }
    return null;
  }

  final dates = byDate.keys.toList()..sort();
  for (final iso in dates) {
    final season = seasonOf(iso);
    final base = temporalPrecedence(season);
    final list = (byDate[iso] ?? const <Placement>[])
        .where((item) => !item.transferredOut)
        .toList();
    final solemnities = list
        .where(
          (item) =>
              rankKind(item.celebration['rank']) == 'solemnity' &&
              item.celebration['temporal'] != true &&
              item.precedence >= 3,
        )
        .toList();
    stableSort(solemnities, _comparePlacements);
    for (final placement in solemnities) {
      final others = list.where(
        (item) =>
            !identical(item, placement) &&
            !item.transferredOut &&
            item.celebration['temporal'] != true,
      );
      final beatenByBase = base < placement.precedence;
      final beatenByOther = others.any(
        (item) => _comparePlacements(item, placement) < 0,
      );
      if (!beatenByBase && !beatenByOther) continue;
      if (placement.noAutoTransfer) {
        placement.impededWithoutTransfer = true;
        continue;
      }
      final special = _specialTransfers
          .where(
            (rule) =>
                rule.celebrationId == placement.id && rule.applies(season),
          )
          .firstOrNull;
      String? target = special != null
          ? special.target(season.anchors)
          : nextFreeDay(iso, placement);
      if (special != null && !isFree(target!, placement)) {
        target = nextFreeDay(target, placement);
      }
      if (target == null) continue;
      placement
        ..transferredOut = true
        ..transferredTo = target;
      final rule =
          special?.id ??
          (beatenByBase ? 'impeded-by-day' : 'impeded-by-celebration');
      final moved = placement.copy()
        ..transferredOut = false
        ..transferredTo = null
        ..date = target
        ..transferredFrom = iso
        ..transferRule = rule;
      byDate.putIfAbsent(target, () => []).add(moved);
      transfers.add(TransferRecord(placement.id, iso, target, rule));
    }
  }
  return transfers;
}

// ── Plan ────────────────────────────────────────────────────────────────

YearPlan buildYearPlan(
  int year,
  OrdoDefinitions definitions, {
  String diocese = '',
}) {
  final dioceseId = normalizeDioceseId(diocese);
  final anchors = yearAnchors(year);
  final layers = buildCalendarLayers(definitions, diocese: dioceseId);
  final celebrations = layers.celebrations;
  final removed = <Placement>[];
  final placements = <Placement>[];
  var order = 0;
  for (final celebration in celebrations.values.toList()) {
    final date = _placeCelebration(celebration, year, anchors);
    if (date == null) continue;
    final placement = Placement(
      celebration: celebration,
      date: date,
      order: order++,
    );
    if (celebration['suppressedBy'] != null) {
      removed.add(placement..reason = 'suppressed-by-layer');
    } else {
      placements.add(placement);
    }
  }

  final overrides = selectYearOverrides(
    [
      for (final item in definitions.yearOverrides)
        if (item['enabled'] != false) item,
    ],
    year,
    dioceseId,
  );
  _applyYearOverrides(placements, removed, overrides, celebrations);

  final byDate = <String, List<Placement>>{};
  for (final placement in placements) {
    final item = placement.copy()
      ..precedence = celebrationPrecedence(placement.celebration);
    byDate.putIfAbsent(item.date, () => []).add(item);
  }

  final seasons = <String, Season>{};
  Season seasonOf(String iso) =>
      seasons.putIfAbsent(iso, () => computeSeason(iso));
  final transfers = _resolveTransfers(byDate, seasonOf);

  final removedByDate = <String, List<Placement>>{};
  for (final item in removed) {
    removedByDate.putIfAbsent(item.date, () => []).add(item);
  }

  final celebrationDates = <String, String>{};
  byDate.forEach((iso, list) {
    for (final item in list) {
      if (item.transferredOut) continue;
      celebrationDates[item.id] = iso;
    }
  });

  final plan = YearPlan._(
    year: year,
    diocese: dioceseId,
    anchors: anchors,
    celebrations: celebrations,
    byDate: byDate,
    removedByDate: removedByDate,
    transfers: transfers,
    celebrationDates: celebrationDates,
  );
  plan._seasons.addAll(seasons);
  return plan;
}
