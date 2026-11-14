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
import 'package:mybrev_flutter/ordo/transfer_rank_evidence.dart';

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

  /// `rank-not-source-confirmed`: a diocesan solemnity kept impeded.
  String? transferBlocked;

  /// Provenance of a stored transfer override that placed this celebration
  /// (`{id?, source, status, computedDate}`).
  Json? transferOverride;

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
        ..impededWithoutTransfer = impededWithoutTransfer
        ..transferBlocked = transferBlocked
        ..transferOverride = transferOverride;

  String get id => celebration['id'].toString();
}

class TransferRecord {
  const TransferRecord(
    this.celebrationId,
    this.from,
    this.to,
    this.rule, {
    String? computedDate,
    this.override,
  }) : computedDate = computedDate ?? to;
  final String celebrationId;
  final String from;

  /// Effective date (where the celebration is kept).
  final String to;
  final String rule;

  /// The date the transfer algorithm computed; differs from [to] only when
  /// a stored (manual) transfer override corrects it.
  final String computedDate;

  /// Provenance of the stored transfer override used (`{id?, source,
  /// status}`), or null for the pure algorithm.
  final Json? override;

  /// Fixture shape (mybrev `build-flutter-parity-fixture.mjs`, schema 2).
  Json toJson() => {
    'celebrationId': celebrationId,
    'from': from,
    'to': to,
    'rule': rule,
    'computedDate': computedDate,
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
    required this.appliedOverrides,
    required this.staleTransferOverrides,
  });

  final int year;
  final String diocese;
  final YearAnchors anchors;
  final Map<String, Json> celebrations;
  final Map<String, List<Placement>> byDate;
  final Map<String, List<Placement>> removedByDate;
  final List<TransferRecord> transfers;

  /// Year overrides applied (normalized): plain overrides and confirmed
  /// transfer overrides the algorithm no longer produces (applied as moves).
  final List<Json> appliedOverrides;

  /// Pending auto transfer overrides the algorithm no longer produces
  /// (reported only, never applied).
  final List<Json> staleTransferOverrides;

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
const kYearOverrideSources = ['auto-transfer', 'manual'];
const kYearOverrideStatuses = ['needs-review', 'confirmed'];
const _scopeOrder = {'universal': 0, 'belarus': 1, 'diocese': 2};
final _isoDate = RegExp(r'^\d{4}-\d{2}-\d{2}$');
bool _isIso(Object? value) => _isoDate.hasMatch('${value ?? ''}');

int? _intOf(Object? value) => value is num
    ? (value == value.toInt() ? value.toInt() : null)
    : int.tryParse(value?.toString() ?? '');

bool _present(Object? value) =>
    value != null && value != '' && value != false && value != 0;

/// Canonical form of a stored Year Override (port of
/// `normalizeYearOverride`, final phase §12). Pure; never mutates.
///  - `originalDate` ← `from`, `effectiveDate` ← `to` (move / add);
///  - a free-text legacy `source` becomes `sourceNote`;
///  - `source` / `status` get their defaults (manual + confirmed, or
///    auto-transfer + needs-review);
///  - `from` / `to` are kept as mirrors of the canonical dates.
Json normalizeYearOverride(Json override) {
  final result = Json.from(override);
  final usesTarget =
      override['action'] == 'move' || override['action'] == 'add';
  final originalDate = override['originalDate'] ?? override['from'];
  final effectiveDate = usesTarget
      ? (override['effectiveDate'] ?? override['to'])
      : override['effectiveDate'];
  if (_present(originalDate)) result['originalDate'] = originalDate;
  if (_present(effectiveDate)) result['effectiveDate'] = effectiveDate;
  if (_present(originalDate)) result['from'] = originalDate;
  if (usesTarget && _present(effectiveDate)) result['to'] = effectiveDate;
  final source = override['source'];
  if (_present(source) && !kYearOverrideSources.contains(source)) {
    if (!_present(override['sourceNote'])) result['sourceNote'] = source;
    result['source'] = 'manual';
  }
  if (!_present(result['source'])) result['source'] = 'manual';
  if (!kYearOverrideStatuses.contains(result['status'])) {
    result['status'] = result['source'] == 'auto-transfer'
        ? 'needs-review'
        : 'confirmed';
  }
  return result;
}

/// Materialized record of a computed transfer (auto or manually corrected):
/// applied by the transfer step, not by the plain Year Override step.
bool isTransferOverride(Json override) =>
    override['action'] == 'move' &&
    (override['source'] == 'auto-transfer' ||
        _present(override['computedDate']));

List<String> validateYearOverride(Json raw) {
  final override = normalizeYearOverride(raw);
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
    if (action == 'move' && !_isIso(override['effectiveDate']))
      'move requires ISO `to`',
    if (action == 'add' &&
        ((override['celebration'] as Map?)?['id'] == null ||
            !_isIso(override['effectiveDate'])))
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
    if (_present(override['computedDate']) && !_isIso(override['computedDate']))
      'computedDate must be an ISO date',
    if (_present(override['originalDate']) && !_isIso(override['originalDate']))
      'originalDate must be an ISO date',
    if (!kYearOverrideSources.contains(override['source']))
      'unknown source ${override['source']}',
    if (!kYearOverrideStatuses.contains(override['status']))
      'unknown status ${override['status']}',
    if (override['source'] == 'auto-transfer' && action != 'move')
      'auto-transfer overrides must be moves',
    for (final field in const ['originalDate', 'effectiveDate'])
      if (_present(override[field]) &&
          _isIso(override[field]) &&
          int.parse('${override[field]}'.substring(0, 4)) != year &&
          action != 'changeRank')
        '`${field == 'originalDate' ? 'from' : 'to'}` must be a date of $year',
  ];
}

/// Overrides of [year] for [diocese], in application order (normalized).
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
  return [for (final item in indexed) normalizeYearOverride(item.$2)];
}

/// `yearOverride` tag of a placement changed by [override].
Json _overrideTag(Json override) => {
  'action': override['action'],
  'scope': override['scope'],
  'reason': override['reason'] ?? '',
  'source': override['source'],
  'status': override['status'],
  if (_present(override['id'])) 'overrideId': override['id'],
};

List<Json> _applyYearOverrides(
  List<Placement> placements,
  List<Placement> removed,
  List<Json> overrides,
  Map<String, Json> celebrations,
) {
  final applied = <Json>[];
  for (final raw in overrides) {
    final override = normalizeYearOverride(raw);
    if (validateYearOverride(override).isNotEmpty) continue;
    applied.add(override);
    bool matches(Placement placement) =>
        placement.id == override['targetCelebrationId'] &&
        (!_present(override['originalDate']) ||
            placement.date == override['originalDate']);
    final tag = _overrideTag(override);
    switch (override['action']) {
      case 'move':
        for (final placement in placements.where(matches)) {
          placement
            ..movedFrom = placement.date
            ..date = override['effectiveDate'] as String
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
            date: override['effectiveDate'] as String,
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
  return applied;
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

/// Diocesan solemnity whose transferable rank no published calendar
/// confirms (final phase §12): impeded without transfer.
bool unconfirmedDiocesanSolemnity(Json celebration) {
  final dioceseId = celebration['dioceseId'];
  if (celebration['layer'] != 'diocese' || dioceseId == null) return false;
  return rankEvidenceOf('$dioceseId', '${celebration['id']}').isEmpty;
}

/// The stored transfer override of a placement impeded on [iso], if any.
Json? _overrideFor(List<Json> overrides, Placement placement, String iso) =>
    overrides
        .where(
          (item) =>
              item['targetCelebrationId'] == placement.id &&
              (!_present(item['originalDate']) || item['originalDate'] == iso),
        )
        .firstOrNull;

/// Transfers of impeded solemnities (port of `resolveTransfers`). The
/// algorithm date is `computedDate`; a stored transfer override matching
/// the celebration and its original date sets the effective date
/// (`effectiveDate` equal to the original date = impeded without transfer).
/// Returns the transfer records and the overrides that were used.
(List<TransferRecord>, Set<Json>) _resolveTransfers(
  Map<String, List<Placement>> byDate,
  Season Function(String) seasonOf, {
  List<Json> overrides = const [],
}) {
  final transfers = <TransferRecord>[];
  final usedOverrides = Set<Json>.identity();
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
      if (unconfirmedDiocesanSolemnity(placement.celebration)) {
        placement
          ..impededWithoutTransfer = true
          ..transferBlocked = 'rank-not-source-confirmed';
        continue;
      }
      final special = _specialTransfers
          .where(
            (rule) =>
                rule.celebrationId == placement.id && rule.applies(season),
          )
          .firstOrNull;
      String? computed = special != null
          ? special.target(season.anchors)
          : nextFreeDay(iso, placement);
      if (special != null && !isFree(computed!, placement)) {
        computed = nextFreeDay(computed, placement);
      }
      final override = _overrideFor(overrides, placement, iso);
      var target = computed;
      if (override != null) {
        usedOverrides.add(override);
        final staleAuto =
            override['source'] == 'auto-transfer' &&
            override['status'] != 'confirmed' &&
            override['effectiveDate'] == override['computedDate'] &&
            override['computedDate'] != computed;
        if (!staleAuto && _isIso(override['effectiveDate'])) {
          target = override['effectiveDate'] as String;
        }
      }
      if (target == null) continue;
      if (target == iso) {
        // A Year Override keeps the impeded celebration where it is.
        placement.impededWithoutTransfer = true;
        continue;
      }
      final rule =
          special?.id ??
          (beatenByBase ? 'impeded-by-day' : 'impeded-by-celebration');
      final provenance = override == null
          ? null
          : <String, dynamic>{
              if (_present(override['id'])) 'id': override['id'],
              'source': override['source'],
              'status': override['status'],
            };
      placement
        ..transferredOut = true
        ..transferredTo = target;
      final moved = placement.copy()
        ..transferredOut = false
        ..transferredTo = null
        ..date = target
        ..transferredFrom = iso
        ..transferRule = rule
        ..transferOverride = provenance == null
            ? null
            : {...provenance, 'computedDate': computed};
      byDate.putIfAbsent(target, () => []).add(moved);
      transfers.add(
        TransferRecord(
          placement.id,
          iso,
          target,
          rule,
          computedDate: computed,
          override: provenance,
        ),
      );
    }
  }
  return (transfers, usedOverrides);
}

/// Transfer overrides the algorithm no longer produces: a confirmed
/// (manual) one is still the administrator's decision and is applied as a
/// plain move; an auto one awaiting review is stale and only reported.
(List<Json>, List<Json>) _applyUnusedTransferOverrides(
  Map<String, List<Placement>> byDate,
  Iterable<Json> unused,
) {
  final applied = <Json>[];
  final stale = <Json>[];
  for (final override in unused) {
    if (override['status'] != 'confirmed') {
      stale.add(override);
      continue;
    }
    final originalDate = '${override['originalDate'] ?? ''}';
    final effectiveDate = override['effectiveDate'];
    final list = byDate[originalDate] ?? <Placement>[];
    final index = list.indexWhere(
      (item) =>
          item.id == override['targetCelebrationId'] && !item.transferredOut,
    );
    if (index < 0 ||
        !_present(effectiveDate) ||
        effectiveDate == originalDate) {
      stale.add(override);
      continue;
    }
    final placement = list.removeAt(index);
    final moved = placement.copy()
      ..date = '$effectiveDate'
      ..movedFrom = originalDate
      ..noAutoTransfer = true
      ..yearOverride = {..._overrideTag(override), 'action': 'move'};
    byDate.putIfAbsent('$effectiveDate', () => []).add(moved);
    applied.add(override);
  }
  return (applied, stale);
}

// ── Plan ────────────────────────────────────────────────────────────────

/// [ignoreTransferOverrides] gives the pure transfer algorithm (stored
/// transfer overrides are not used).
YearPlan buildYearPlan(
  int year,
  OrdoDefinitions definitions, {
  String diocese = '',
  bool ignoreTransferOverrides = false,
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
    if (date == null ||
        (celebration['validFrom'] is String &&
            date.compareTo(celebration['validFrom'] as String) < 0) ||
        (celebration['validUntil'] is String &&
            date.compareTo(celebration['validUntil'] as String) > 0)) {
      continue;
    }
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

  final selected = selectYearOverrides(
    [
      for (final item in definitions.yearOverrides)
        if (item['enabled'] != false) item,
    ],
    year,
    dioceseId,
  );
  // Materialized transfers are applied by the transfer step (they keep the
  // computed date).
  final transferOverrides = ignoreTransferOverrides
      ? const <Json>[]
      : selected.where(isTransferOverride).toList();
  final appliedOverrides = _applyYearOverrides(
    placements,
    removed,
    selected.where((item) => !isTransferOverride(item)).toList(),
    celebrations,
  );

  final byDate = <String, List<Placement>>{};
  for (final placement in placements) {
    final item = placement.copy()
      ..precedence = celebrationPrecedence(placement.celebration);
    byDate.putIfAbsent(item.date, () => []).add(item);
  }

  final seasons = <String, Season>{};
  Season seasonOf(String iso) =>
      seasons.putIfAbsent(iso, () => computeSeason(iso));
  final (transfers, usedOverrides) = _resolveTransfers(
    byDate,
    seasonOf,
    overrides: transferOverrides,
  );
  final (lateMoves, staleTransferOverrides) = _applyUnusedTransferOverrides(
    byDate,
    transferOverrides.where((item) => !usedOverrides.contains(item)),
  );

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
    appliedOverrides: [...appliedOverrides, ...lateMoves],
    staleTransferOverrides: staleTransferOverrides,
  );
  plan._seasons.addAll(seasons);
  return plan;
}
