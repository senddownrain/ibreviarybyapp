/// Readings resolution (port of mybrev `src/utils/ordo/readings.js` and the
/// readings half of `runtime.js`): derived from the SAME resolved day as the
/// Office. `lookup` entries are `readings` identities in the order they are
/// tried; the texts stay in `readings`.
library;

import 'package:mybrev_flutter/ordo/dates.dart';
import 'package:mybrev_flutter/ordo/definitions.dart';
import 'package:mybrev_flutter/ordo/memorial_readings.dart';
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
    this.defaultPurpose = '',
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

  /// `allowedChoices[0].default` of the web descriptor: the purpose whose
  /// readings open by default (a memorial: `weekday`, or `proper` where the
  /// Lectionary prescribes proper readings).
  final String defaultPurpose;
  final String? readingsReference;
  final String? readingsStatus;

  bool get isMemorial =>
      officeKind == 'memorial' || officeKind == 'optional-memorial';
}

List<ReadingLookup> readingsLookupOf(
  Json candidate,
  Json temporal,
  Season season, {
  String diocese = '',
}) {
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
  List<ReadingLookup> lookup;
  if (kind == 'memorial' || kind == 'optional-memorial') {
    // GIRM 357 / OLM 83: the weekday readings are kept on memorials; PROPER
    // readings the Lectionary prescribes replace them (`memorialReadingsRule`);
    // own readings stay a legal alternative.
    final rule = memorialReadingsRule('${candidate['id']}', '$kind', diocese)!;
    lookup = rule.prescribed ? [?proper, weekday] : [weekday, ?proper];
  } else if (candidate['kind'] == 'temporal') {
    // 24 December on a Sunday: the Sunday of Advent (morning) and, in the
    // evening, the Mass of the Christmas Vigil (its own legacy document, the
    // projection of the `vigil` set of `advent-24-12`).
    final vigil = season.date.endsWith('-12-24') && season.dayOfWeek == 1
        ? ReadingLookup('weekday', {
            '_date': '24.12',
            'dateOnly': true,
            '_variant': 'christmas-vigil',
          })
        : null;
    lookup = [weekday, ?vigil];
  } else if (candidate['temporal'] == true) {
    lookup = [?proper, weekday];
  } else {
    lookup = [?proper];
  }
  // The Saturday before Pentecost taken by a feast (the Visitation on
  // 31 May 2031): the morning Mass is that celebration, the evening Mass is
  // the Vigil Mass of Pentecost (the weekday document `_variant:
  // pentecost-vigil`); a memorial keeps its weekday lookup.
  if (candidate['kind'] != 'temporal' &&
      candidate['role'] == 'primary' &&
      season.date == addDays(season.anchors.pentecost, -1) &&
      !lookup.any((entry) => entry.purpose == 'weekday')) {
    lookup.add(
      ReadingLookup('weekday', {
        ...Json.from(temporal['readingsRef'] as Map),
        '_variant': 'pentecost-vigil',
      }),
    );
  }
  return lookup;
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
