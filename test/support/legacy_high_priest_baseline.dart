// Reconstruct the pre-reference-patch document for migration regression tests.
//
// The current shipped baseline already contains the approved 12-field
// null -> from-day correction. Keep the historic migration scenario without
// replacing or downgrading production assets/content.
import 'dart:convert';
import 'dart:io';

import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/services/hive_service.dart';

const legacyHighPriestId = 'feast-christthehighpriest';

Future<void> installLegacyHighPriestBaseline() async {
  final days = HiveService.daysBox;
  final plan = jsonDecode(
    File('reports/liturgy/christ-high-priest-daytime-patch.json')
        .readAsStringSync(),
  ) as Map<String, dynamic>;
  final patch = (plan['updates'] as List).single as Map;
  if (patch['id'] != legacyHighPriestId) {
    throw StateError('Unexpected historic patch document id');
  }
  final changes = Map<String, dynamic>.from(patch['set'] as Map);
  final expected = {
    for (final hour in [1, 2, 3])
      for (final suffix in ['Hymn', 'Ps1', 'Ps2', 'Ps3'])
        'sext$hour$suffix',
  };
  if (changes.keys.toSet().difference(expected).isNotEmpty ||
      expected.difference(changes.keys.toSet()).isNotEmpty ||
      changes.values.any((value) => value != 'from-day')) {
    throw StateError('Historic correction is no longer the known 12 fields');
  }

  final documents = <String, Map<String, dynamic>>{
    for (final id in days.keys)
      id: Map<String, dynamic>.from(days.baselineDocument(id) as Map),
  };
  final current = documents[legacyHighPriestId];
  if (current == null || documentHash(current) != patch['resultHash']) {
    throw StateError('Current bundled High Priest baseline does not match');
  }
  final legacy = Map<String, dynamic>.from(current);
  for (final field in changes.keys) {
    if (legacy[field] != 'from-day') {
      throw StateError('Expected from-day in current baseline: $field');
    }
    legacy[field] = null;
  }
  if (documentHash(legacy) != patch['preconditionHash']) {
    throw StateError('Reconstructed legacy document hash mismatch');
  }
  documents[legacyHighPriestId] = legacy;
  await days.debugReplaceBaseline(
    documents,
    {for (final entry in documents.entries) entry.key: documentHash(entry.value)},
    days.baselineVersion - 1,
  );
}
