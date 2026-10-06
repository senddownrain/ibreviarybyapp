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

/// The web-generated parity fixture (mybrev `npm run ordo:flutter-fixture`).
Map<String, dynamic> ordoParityFixture() =>
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
