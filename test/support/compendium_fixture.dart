import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mybrev_flutter/models/compendium.dart';
import 'package:mybrev_flutter/providers/compendium_provider.dart';
import 'package:mybrev_flutter/services/compendium_repository.dart';
import 'package:mybrev_flutter/utils/compendium_search.dart';

/// The real bundled dataset, decoded synchronously from the asset file.
/// Read it outside `testWidgets` bodies (file IO does not run under the
/// widget tester's fake clock).
CompendiumDataset readBundledCompendium() => decodeBundledCompendium(
  File(CompendiumRepository.assetPath).readAsBytesSync(),
);

Map<String, dynamic> readCompendiumAliasFile() =>
    jsonDecode(File(CompendiumRepository.aliasesAssetPath).readAsStringSync())
        as Map<String, dynamic>;

/// Provider overrides that serve the bundled dataset without asset loading,
/// isolates, Hive or network.
List<Override> compendiumOverrides(
  CompendiumDataset dataset, {
  Map<String, dynamic>? aliases,
  CompendiumDataset? stored,
  void Function()? onRefresh,
  bool bundleFails = false,
}) => [
  compendiumBundledProvider.overrideWith(
    (ref) async => bundleFails ? throw StateError('asset') : dataset,
  ),
  compendiumAliasesProvider.overrideWith(
    (ref) async => CompendiumSearchAliases.compile(aliases),
  ),
  compendiumStoredProvider.overrideWithValue(stored),
  compendiumRefreshProvider.overrideWithValue(onRefresh ?? () {}),
];
