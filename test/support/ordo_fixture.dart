import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/content/content_store.dart';
import 'package:mybrev_flutter/ordo/definitions.dart';
import 'package:mybrev_flutter/ordo/engine.dart';

/// Documents of a bundled collection (`assets/content/<name>.json.gz`).
Map<String, Map<String, dynamic>> bundledCollection(String name) =>
    decodeContentCollection(
      File('$kContentAssetDir/$name.json.gz').readAsBytesSync(),
    ).docs;

OrdoEngine? _engine;

/// The engine of the bundled calendar (what a fresh install resolves).
OrdoEngine bundledOrdoEngine() => _engine ??= OrdoEngine(
  OrdoDefinitions.fromDocuments(
    celebrations: bundledCollection('liturgicalCelebrations').values,
    dioceseOverrides: bundledCollection('liturgicalDioceseOverrides').values,
    yearOverrides: bundledCollection('liturgicalYearOverrides').values,
  ),
  notes: bundledCollection('liturgicalOrdoNotes').values,
);

/// Schema of the parity fixture this port is tested against (mybrev
/// `PARITY_SCHEMA_VERSION`). 2 = final phase: `sources` (Office/Mass split,
/// present only when split), `office` of `officeOptions`, `provisional`
/// options, `books` (present only when the day has volumes), transfers with
/// `computedDate`, `fieldRuleKinds`.
const kOrdoParitySchemaVersion = 2;

Map<String, dynamic>? _fixture;

/// The web-generated parity fixture (mybrev `npm run ordo:flutter-fixture`),
/// decoded once per test isolate.
Map<String, dynamic> ordoParityFixture() {
  final fixture = _fixture ??= _decodeFixture();
  final schema = fixture['schemaVersion'];
  if (schema != kOrdoParitySchemaVersion) {
    throw StateError(
      'ordo_parity.json.gz has schema $schema, '
      'the port expects $kOrdoParitySchemaVersion',
    );
  }
  return fixture;
}

/// `_fieldRules` kinds the fixture's Office hashes rely on (schema 2).
List<String> ordoParityFieldRuleKinds() => [
  ...?(ordoParityFixture()['fieldRuleKinds'] as List?)?.map((e) => '$e'),
];

Map<String, dynamic> _decodeFixture() =>
    jsonDecode(
          utf8.decode(
            GZipDecoder().decodeBytes(
              File('test/fixtures/ordo_parity.json.gz').readAsBytesSync(),
            ),
          ),
        )
        as Map<String, dynamic>;

/// Seeds the Ordo collections of the bundle into a store opened without
/// the bundle (tests that build their own `days`).
Future<void> seedOrdoCollections(ContentStore store) async {
  for (final name in const [
    'liturgicalCelebrations',
    'liturgicalDioceseOverrides',
    'liturgicalYearOverrides',
    'liturgicalCalendarMeta',
  ]) {
    await store.collection(name).putAll(bundledCollection(name));
  }
}
