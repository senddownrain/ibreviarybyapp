import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/models/compendium.dart';
import 'package:mybrev_flutter/providers/compendium_provider.dart';
import 'package:mybrev_flutter/services/compendium_repository.dart';
import 'package:mybrev_flutter/utils/compendium_data.dart';
import 'package:mybrev_flutter/utils/compendium_search.dart';

/// The Compendium documents of the app's content bundle
/// (`compendiumMeta/current`, units in bundle order).
(Map<String, dynamic>, List<Map<String, dynamic>>) readCompendiumDocuments() {
  DecodedCollection read(String name) => decodeContentCollection(
    File('$kContentAssetDir/$name.json.gz').readAsBytesSync(),
  );
  final meta = read(
    CompendiumRepository.metaCollection,
  ).docs[CompendiumRepository.metaDocument]!;
  return (
    meta,
    read(CompendiumRepository.unitsCollection).docs.values.toList(),
  );
}

/// The canonical dataset map (as MyBrev exports it) from the bundle.
Map<String, dynamic> readCompendiumRaw() {
  final (meta, units) = readCompendiumDocuments();
  return compendiumFromDocuments(
    Map<String, dynamic>.from(meta)..remove('id'),
    units,
  );
}

/// The real bundled dataset, decoded synchronously from the content bundle.
/// Read it outside `testWidgets` bodies (file IO does not run under the
/// widget tester's fake clock).
CompendiumDataset readBundledCompendium() =>
    compendiumFromContent(readCompendiumDocuments());

Map<String, dynamic> readCompendiumAliasFile() =>
    jsonDecode(File(CompendiumRepository.aliasesAssetPath).readAsStringSync())
        as Map<String, dynamic>;

/// Provider overrides that serve the bundled dataset without asset loading,
/// isolates, Hive or network.
List<Override> compendiumOverrides(
  CompendiumDataset dataset, {
  Map<String, dynamic>? aliases,
  bool bundleFails = false,
}) => [
  compendiumDatasetProvider.overrideWith(
    (ref) async => bundleFails ? throw StateError('asset') : dataset,
  ),
  compendiumAliasesProvider.overrideWith(
    (ref) async => CompendiumSearchAliases.compile(aliases),
  ),
];
