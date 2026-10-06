import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:mybrev_flutter/content/content_store.dart';
import 'package:mybrev_flutter/models/compendium.dart';
import 'package:mybrev_flutter/utils/compendium_data.dart';

/// The Compendium of the Catechism from the app's content.
///
/// It ships and updates like every other text (`assets/content`, version
/// manifest): collection `compendium` (one document per unit) and
/// `compendiumMeta/current` (meta and parts). A patch that changes units
/// and meta is switched on at once, so a mixed dataset is never read; the
/// dataset is still validated before it is shown.
class CompendiumRepository {
  const CompendiumRepository._();

  static const aliasesAssetPath =
      'assets/compendium/compendium_search_aliases.json';
  static const unitsCollection = 'compendium';
  static const metaCollection = 'compendiumMeta';
  static const metaDocument = 'current';

  /// The validated dataset (decoding and validation run off the UI isolate).
  static Future<CompendiumDataset> load([ContentStore? store]) async {
    final content = store ?? ContentStore.instance;
    await content.ensureLoaded(const [unitsCollection, metaCollection]);
    final meta = content.collection(metaCollection).get(metaDocument);
    final units = content.collection(unitsCollection);
    return compute(compendiumFromContent, (
      meta is Map ? Map<String, dynamic>.from(meta) : null,
      [
        for (final key in units.keys)
          if (units.get(key) case final Map unit)
            Map<String, dynamic>.from(unit),
      ],
    ));
  }

  static Future<Map<String, dynamic>> loadAliases([AssetBundle? bundle]) async {
    final raw = await (bundle ?? rootBundle).loadString(aliasesAssetPath);
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }
}

/// `compendiumMeta/current` + unit documents → the validated dataset.
/// Throws [FormatException] for an incomplete or inconsistent dataset.
CompendiumDataset compendiumFromContent(
  (Map<String, dynamic>?, List<Map<String, dynamic>>) documents,
) {
  final (meta, units) = documents;
  // The stored `id` of the meta document is its document id (`current`),
  // not part of the dataset.
  final dataset = compendiumFromDocuments(
    meta == null ? null : (Map<String, dynamic>.from(meta)..remove('id')),
    units,
  );
  final errors = validateCompendiumDataset(dataset);
  if (errors.isNotEmpty) {
    throw FormatException('Compendium is invalid: ${errors.first}');
  }
  return CompendiumDataset.fromJson(dataset);
}
