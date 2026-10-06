/// Readings resolution (port of mybrev `src/utils/ordo/readings.js` and the
/// readings half of `runtime.js`): derived from the SAME resolved day as the
/// Office. `lookup` entries are `readings` identities in the order they are
/// tried; the texts stay in `readings`.
library;

import 'package:mybrev_flutter/ordo/definitions.dart';
import 'package:mybrev_flutter/ordo/season.dart';

/// One lookup of a readings plan.
class ReadingLookup {
  const ReadingLookup(this.purpose, this.where, {this.title});

  /// `weekday`, `proper` or `common`.
  final String purpose;
  final Json where;
  final String? title;
}

/// What the readings of one legal option are.
class OptionReadingsPlan {
  const OptionReadingsPlan({
    required this.optionId,
    required this.title,
    required this.role,
    required this.kind,
    required this.officeKind,
    required this.lookup,
    required this.option,
    this.readingsReference,
    this.readingsStatus,
  });

  final String optionId;
  final String title;
  final String role;
  final String kind;
  final String officeKind;

  /// Without the `common` lookup (the Readings screen does not use it).
  final List<ReadingLookup> lookup;
  final Json option;
  final String? readingsReference;
  final String? readingsStatus;

  bool get isMemorial =>
      officeKind == 'memorial' || officeKind == 'optional-memorial';
}

List<ReadingLookup> readingsLookupOf(Json candidate, Json temporal) {
  final kind = candidate['officeKind'];
  final weekday = ReadingLookup(
    'weekday',
    Json.from(temporal['readingsRef'] as Map),
  );
  final proper = candidate['kind'] == 'temporal'
      ? null
      : ReadingLookup(
          'proper',
          Json.from((candidate['readingsRef'] as Map?) ?? const {}),
          title: candidate['title'] as String?,
        );
  if (kind == 'memorial' || kind == 'optional-memorial') {
    // GIRM 357: on memorials the weekday readings are normally kept.
    return [weekday, ?proper];
  }
  if (candidate['kind'] == 'temporal') return [weekday];
  if (candidate['temporal'] == true) return [?proper, weekday];
  return [?proper];
}

/// Lectionary cycle a reading of [officeKind] follows.
String? readingCycleFor(String officeKind, Season season) {
  if (officeKind == 'sunday' || officeKind == 'solemnity') {
    return season.readingCycle.sunday;
  }
  if (officeKind == 'feast') return season.readingCycle.sunday;
  if (season.period == 'ordinary') return season.readingCycle.weekday;
  return null;
}
