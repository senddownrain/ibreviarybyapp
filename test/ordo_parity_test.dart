// Web ↔ Flutter parity of the Ordo engine: the Dart port must give exactly
// the liturgical day of the web engine on every date 2025–2032 in all four
// dioceses (fixture: mybrev `npm run ordo:flutter-fixture`, generated from
// the same snapshot the bundle is built from).
//
// ORDO_PARITY_REPORT=1 flutter test test/ordo_parity_test.dart
//   also writes reports/flutter-ordo-parity.json.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/ordo/engine.dart';

import 'support/ordo_fixture.dart';

/// Intentional differences between web and Flutter (none for the engine).
const kIntentionalDifferences = <String, String>{};

void main() {
  final fixture = ordoParityFixture();
  final engine = bundledOrdoEngine();
  final days = (fixture['days'] as Map).cast<String, dynamic>();

  Map<String, dynamic> optionOf(OrdoOption item, OrdoDay day) => {
    'id': item.id,
    'kind': item.kind,
    'rank': item.rank,
    'rankKind': item.rankKind,
    'color': item.color.isEmpty ? day.color : item.color,
    if (item.colorAlternatives.isNotEmpty)
      'colorAlternatives': item.colorAlternatives,
    'officeKind': item.officeKind.isEmpty ? null : item.officeKind,
    'precedence': item.precedence,
    'category': item.category.isEmpty ? null : item.category,
    'dioceseId': ?item.dioceseId,
    'transferredFrom': ?item.transferredFrom,
    'movedFrom': ?item.movedFrom,
    'demotedFrom': ?item.demotedFrom,
  };

  Map<String, dynamic> actualOf(OrdoDay day) => {
    'date': day.date,
    'period': day.period,
    'periodPhase': day.periodPhase,
    'week': day.week,
    'dayOfWeek': day.dayOfWeek,
    'psalterWeek': day.psalterWeek,
    'cycle': [day.readingCycle.sunday, day.readingCycle.weekday],
    'color': day.color,
    'colorAlternatives': day.colorAlternatives,
    'primary': optionOf(day.primary, day),
    'alternatives': [for (final item in day.alternatives) optionOf(item, day)],
    'commemorations': [
      for (final item in day.commemorations) {'id': item.id, 'rank': item.rank},
    ],
    'suppressed': [
      for (final item in day.suppressed) {'id': item.id, 'reason': item.reason},
    ],
    'transfers': [for (final item in day.transfers) item.toJson()],
    'evening': {
      'type': day.evening.vespersType,
      'celebrationId': day.evening.celebrationId,
      'compline': day.evening.compline,
    },
    'office': [
      for (final option in day.options)
        () {
          final descriptor = optionDescriptor(day, option);
          return {
            'id': option.id,
            'teDeum': descriptor.teDeum,
            'compline': descriptor.compline,
            'complineDay': descriptor.complineDay,
            'vespers': descriptor.vespersType,
            'firstVespersByRight': descriptor.firstVespersByRight,
          };
        }(),
    ],
    'notes': [for (final note in engine.notesOf(day)) '${note['id']}']..sort(),
  };

  const fields = [
    'period',
    'periodPhase',
    'week',
    'dayOfWeek',
    'psalterWeek',
    'cycle',
    'color',
    'colorAlternatives',
    'primary',
    'alternatives',
    'commemorations',
    'suppressed',
    'transfers',
    'evening',
    'office',
    'notes',
  ];

  test('the Dart Ordo engine equals the web engine, 2025–2032 × 4 dioceses', () {
    final mismatches = <String, List<String>>{};
    var compared = 0;
    final watch = Stopwatch()..start();
    for (final MapEntry(key: diocese, value: list) in days.entries) {
      for (final expected in (list as List).cast<Map<String, dynamic>>()) {
        final date = expected['date'] as String;
        final actual = actualOf(engine.resolve(date, diocese: diocese));
        compared++;
        for (final field in fields) {
          final want = jsonEncode(expected[field]);
          final got = jsonEncode(actual[field]);
          if (want == got) continue;
          if (kIntentionalDifferences.containsKey('$field|$date|$diocese')) {
            continue;
          }
          mismatches
              .putIfAbsent(field, () => [])
              .add('$date $diocese\n  web:     $want\n  flutter: $got');
        }
      }
    }
    final summary = {
      for (final entry in mismatches.entries) entry.key: entry.value.length,
    };
    if (Platform.environment['ORDO_PARITY_REPORT'] == '1') {
      final report = File('reports/flutter-ordo-parity.json');
      report.parent.createSync(recursive: true);
      report.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert({
          'generatedFrom': {'snapshot': fixture['snapshot'], 'fixtureGeneratedAt': fixture['generatedAt']},
          'years': fixture['years'],
          'dioceses': fixture['dioceses'],
          'daysCompared': compared,
          'fieldsCompared': fields,
          'mismatches': summary,
          'mismatchExamples': {for (final entry in mismatches.entries) entry.key: entry.value.take(5).toList()},
          'intentionalDifferences': kIntentionalDifferences,
          'engineMilliseconds': watch.elapsedMilliseconds,
        })}\n',
      );
    }
    expect(compared, greaterThan(11000));
    expect(
      mismatches,
      isEmpty,
      reason: mismatches.entries
          .map((e) => '${e.key}: ${e.value.length}\n${e.value.take(4).join('\n')}')
          .join('\n\n'),
    );
  });
}
