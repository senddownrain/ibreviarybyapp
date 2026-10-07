/// Precedence + display resolver (port of mybrev `src/utils/ordo/display.js`):
/// PRIMARY, legal ALTERNATIVES, COMMEMORATIONS and SUPPRESSED candidates.
///
/// - A weekday is never an alternative to an obligatory memorial, a feast or
///   a solemnity.
/// - Optional memorials are alternatives to an ordinary weekday.
/// - On privileged weekdays (17–24 Dec, Christmas octave, Lent weekdays)
///   every memorial is only a commemoratio.
/// - On Sundays, solemnities, feasts, Ash Wednesday, Holy Week and the
///   Easter octave memorials are omitted.
library;

import 'package:mybrev_flutter/ordo/dates.dart';
import 'package:mybrev_flutter/ordo/definitions.dart';
import 'package:mybrev_flutter/ordo/precedence.dart';
import 'package:mybrev_flutter/ordo/season.dart';

bool _obligatory(Json c) => c['rankKind'] == 'memorial';

/// `concurrentObligatoryMemorials` values that open a memorial choice
/// ('legal-choice'; the legacy 'both-optional' of published definitions
/// revision 2 means the same).
const _concurrentChoiceValues = {'legal-choice', 'both-optional'};

/// Jesus Christ, the High and Eternal Priest (national feast, Thursday after
/// Pentecost).
const kChristHighPriestId = 'christ-the-high-priest';
bool _anyMemorial(Json c) =>
    c['rankKind'] == 'memorial' || c['rankKind'] == 'optional-memorial';

/// Office kind of a chosen celebration.
String officeKindOf(Json candidate, Season season) {
  final a = season.anchors;
  final date = season.date;
  if (candidate['kind'] == 'temporal' || candidate['temporal'] == true) {
    if (date == a.easterSunday) return 'solemnity';
    if (date.compareTo(a.holyThursday) >= 0 &&
        date.compareTo(a.holySaturday) <= 0) {
      return 'triduum';
    }
    if (candidate['id'] == 'pentecost') return 'solemnity';
    if (season.period == 'easter' &&
        season.periodPhase == 'octave' &&
        !season.isSunday) {
      return 'easter-octave';
    }
    if (season.isSunday) return 'sunday';
    if (season.period == 'christmas' && season.periodPhase == 'octave') {
      return 'christmas-octave';
    }
    return 'weekday';
  }
  switch (candidate['rankKind']) {
    case 'all-souls':
      return 'all-souls';
    case 'solemnity':
      return 'solemnity';
    case 'feast':
      return 'feast';
    case 'memorial':
      return 'memorial';
  }
  return 'optional-memorial';
}

class DisplayResult {
  const DisplayResult({
    required this.primary,
    required this.officePrimary,
    required this.alternatives,
    required this.commemorations,
    required this.suppressed,
    required this.appliedRules,
  });
  final Json primary;

  /// Office (Hours) source of the day: [primary], except where a rule
  /// splits the Office from the Mass (All Souls on a Sunday: the Sunday,
  /// marked `officeOnly`).
  final Json officePrimary;
  final List<Json> alternatives;
  final List<Json> commemorations;
  final List<Json> suppressed;
  final List<Json> appliedRules;
}

Json _suppress(Json candidate, String reason, [Json extra = const {}]) => {
  ...candidate,
  'role': 'suppressed',
  'reason': reason,
  ...extra,
};

DisplayResult resolveDisplay(List<Json> candidates, Season season) {
  final appliedRules = <Json>[];
  final suppressed = <Json>[];
  final alternatives = <Json>[];
  final commemorations = <Json>[];

  for (final item in candidates.where((c) => c['status'] == 'transferred')) {
    suppressed.add(
      _suppress(item, 'transferred', {'transferredTo': item['transferredTo']}),
    );
  }
  for (final item in candidates.where((c) => c['status'] == 'removed')) {
    suppressed.add(
      _suppress(item, (item['removalReason'] ?? 'removed') as String),
    );
  }

  final active = candidates.where((c) => c['status'] == 'active').toList();
  final temporal = active.firstWhere((c) => c['kind'] == 'temporal');
  var celebrations = active.where((c) => c['kind'] != 'temporal').toList();
  stableSort(celebrations, compareCandidates);

  // Product rule (Belarus, final phase §11.2–11.3): when the Immaculate
  // Heart or Mary, Mother of the Church meets another obligatory memorial,
  // both obligatory memorials are legal choices (Marian first) and the
  // weekday is NOT a third option.
  final obligatory = celebrations.where(_obligatory).toList();
  final memorialChoice =
      obligatory.length > 1 &&
      obligatory.any(
        (c) => _concurrentChoiceValues.contains(
          (c['rules'] as Map?)?['concurrentObligatoryMemorials'],
        ),
      );
  if (memorialChoice) {
    appliedRules.add({
      'rule': 'concurrent-obligatory-memorials-legal-choice',
      'ids': [for (final c in obligatory) c['id']],
      'basis': 'product-decision',
    });
  }

  // Optional memorials are never the primary office.
  final contender = celebrations
      .where(
        (c) =>
            c['rankKind'] != 'optional-memorial' &&
            c['id'] != 'saturday-blessed-virgin-mary',
      )
      .firstOrNull;
  final temporalCelebration = celebrations
      .where((c) => c['temporal'] == true)
      .firstOrNull;
  final temporalPrecedenceValue = temporal['precedence'] as int;
  Json primary;
  if (temporalCelebration != null) {
    primary = temporalCelebration;
  } else if (contender != null &&
      (contender['precedence'] as int) < temporalPrecedenceValue) {
    primary = contender;
  } else {
    primary = temporal;
  }

  Json? officePrimary;
  if (!identical(primary, temporal)) {
    if (primary['temporal'] == true) {
      suppressed.add(
        _suppress(temporal, 'merged-temporal', {'mergedInto': primary['id']}),
      );
    } else if (primary['rankKind'] == 'memorial') {
      suppressed.add(_suppress(temporal, 'weekday-under-memorial'));
      appliedRules.add({
        'rule': 'weekday-not-alternative-to-obligatory-memorial',
      });
    } else if (primary['rankKind'] == 'all-souls' && season.isSunday) {
      // Product rule (§11.1): All Souls on a Sunday — the Mass (and
      // readings) are of All Souls, the Liturgy of the Hours is of the
      // Sunday. The Sunday is not suppressed: it is the Office source.
      officePrimary = temporal;
      appliedRules.add({
        'rule': 'all-souls-sunday-split',
        'office': temporal['id'],
        'mass': primary['id'],
        'basis': 'product-decision',
      });
    } else {
      suppressed.add(_suppress(temporal, 'outranked'));
      if (season.isSunday &&
          temporalPrecedenceValue == 6 &&
          primary['rankKind'] == 'feast') {
        appliedRules.add({
          'rule': 'feast-of-the-lord-replaces-sunday',
          'id': primary['id'],
        });
      }
    }
  }

  final primaryIsPrivilegedWeekday =
      identical(primary, temporal) && temporalPrecedenceValue == 9;
  final primaryIsOrdinaryWeekday =
      identical(primary, temporal) && temporalPrecedenceValue == 13;
  final hasObligatoryMemorial = obligatory.isNotEmpty;

  for (final candidate in celebrations) {
    if (identical(candidate, primary)) continue;
    if (candidate['id'] == 'saturday-blessed-virgin-mary') {
      if (primaryIsOrdinaryWeekday && !hasObligatoryMemorial) {
        alternatives.add({...candidate, 'role': 'alternative'});
        appliedRules.add({'rule': 'saturday-memorial-of-mary'});
      } else {
        suppressed.add(_suppress(candidate, 'not-applicable'));
      }
      continue;
    }
    final kind = candidate['rankKind'];
    if (kind == 'solemnity' || kind == 'all-souls') {
      suppressed.add(
        _suppress(
          candidate,
          candidate['impededWithoutTransfer'] == true
              ? 'impeded-without-transfer'
              : 'outranked',
        ),
      );
      continue;
    }
    if (kind == 'feast') {
      // Provisional product rule (§11.4): Christ the High Priest meeting
      // another feast keeps both as legal options.
      if (primary['rankKind'] == 'feast' &&
          (candidate['id'] == kChristHighPriestId ||
              primary['id'] == kChristHighPriestId)) {
        alternatives.add({
          ...candidate,
          'role': 'alternative',
          'provisional': true,
        });
        appliedRules.add({
          'rule': 'christ-high-priest-collision-both-options',
          'id': candidate['id'],
          'with': primary['id'],
          'status': 'provisional',
        });
        continue;
      }
      suppressed.add(_suppress(candidate, 'impeded-omitted'));
      appliedRules.add({
        'rule': 'impeded-feast-omitted',
        'id': candidate['id'],
      });
      continue;
    }
    if (!_anyMemorial(candidate)) {
      suppressed.add(_suppress(candidate, 'outranked'));
      continue;
    }
    if (primaryIsPrivilegedWeekday) {
      commemorations.add({
        ...candidate,
        'role': 'commemoration',
        'mode': 'commemoratio',
        'optional': true,
      });
      appliedRules.add({
        'rule': 'memorial-as-commemoration',
        'id': candidate['id'],
        'season': season.periodPhase,
      });
      continue;
    }
    if (primaryIsOrdinaryWeekday) {
      alternatives.add({...candidate, 'role': 'alternative'});
      continue;
    }
    if (primary['rankKind'] == 'memorial') {
      if (_obligatory(candidate) &&
          (candidate['precedence'] == primary['precedence'] ||
              memorialChoice)) {
        alternatives.add({...candidate, 'role': 'alternative'});
        appliedRules.add({
          'rule': 'concurrent-obligatory-memorials-choice',
          'id': candidate['id'],
        });
      } else {
        suppressed.add(_suppress(candidate, 'impeded-by-obligatory-memorial'));
      }
      continue;
    }
    suppressed.add(_suppress(candidate, 'impeded-omitted'));
  }

  final resolvedPrimary = {
    ...primary,
    'role': 'primary',
    'officeKind': officeKindOf(primary, season),
  };
  return DisplayResult(
    primary: resolvedPrimary,
    officePrimary: officePrimary == null
        ? resolvedPrimary
        : {
            ...officePrimary,
            'role': 'primary',
            'officeKind': officeKindOf(officePrimary, season),
            'officeOnly': true,
          },
    alternatives: [
      for (final item in alternatives)
        {...item, 'officeKind': officeKindOf(item, season)},
    ],
    commemorations: commemorations,
    suppressed: suppressed,
    appliedRules: appliedRules,
  );
}
