import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:mybrev_flutter/content/content_store.dart';
import 'package:mybrev_flutter/content/content_updater.dart';

Map<String, dynamic> _gz(String path) =>
    jsonDecode(
          utf8.decode(GZipDecoder().decodeBytes(File(path).readAsBytesSync())),
        )
        as Map<String, dynamic>;

Map<String, dynamic>? _parity;
Map<String, dynamic>? _delivery;

/// The web-generated Readings parity fixture
/// (`scripts/lectionary/build_parity_fixture.mjs`): every legal Mass option
/// of every date 2025–2035 × four dioceses as the web Readings screen
/// resolves it, with section content hashes.
Map<String, dynamic> lectionaryParityFixture() =>
    _parity ??= _gz('test/fixtures/lectionary_parity.json.gz');

/// The delivery-chain fixture (`build_delivery_fixture.mjs`) with the captured
/// readings index, pending index if any, and documents needed for updates.
Map<String, dynamic> lectionaryDeliveryFixture() =>
    _delivery ??= _gz('test/fixtures/lectionary_delivery.json.gz');

/// What the published manifest offers for `readings`: the real manifest
/// document (hashes and sizes of all documents) and the real documents the
/// bundle does not have in this version — nothing else is served.
class ProductionReadingsRemote implements ContentRemote {
  ProductionReadingsRemote({
    this.failFetch = false,
    this.corrupt = const {},
    this.usePlannedIndex = false,
  });

  final Map<String, dynamic> _fixture = lectionaryDeliveryFixture();

  /// Lose connectivity partway through fetching the requested documents.
  final bool failFetch;

  /// Ids served with another text than the manifest hash promises.
  final Set<String> corrupt;

  /// Serve the reviewed next index for pre-publication testing.
  final bool usePlannedIndex;

  final List<String> fetched = [];
  int indexReads = 0;

  Map<String, dynamic> get _index =>
      _fixture[usePlannedIndex ? 'planned' : 'manifest']
          as Map<String, dynamic>;

  Map<String, dynamic> get _readings =>
      _index['readings'] as Map<String, dynamic>;

  @override
  Future<Map<String, dynamic>?> fetchCurrent() async {
    final current = _index['current'] as Map;
    return {
      'schemaVersion': current['schemaVersion'],
      'contentVersion': current['contentVersion'],
      'collections': {'readings': (current['collections'] as Map)['readings']},
    };
  }

  @override
  Future<Map<String, dynamic>?> fetchCollectionManifest(
    String collection,
  ) async {
    if (collection != 'readings') return null;
    indexReads++;
    return _readings;
  }

  @override
  Future<Map<String, Map<String, dynamic>>> fetchDocuments(
    String collection,
    List<String> ids,
  ) async {
    if (failFetch) {
      fetched.addAll(ids.take(ids.length ~/ 2));
      throw const SocketException('offline');
    }
    fetched.addAll(ids);
    final documents = _fixture['documents'] as Map<String, dynamic>;
    return {
      for (final id in ids)
        if (documents[id] case final Map doc)
          id: corrupt.contains(id)
              ? {...Map<String, dynamic>.from(doc), 'title': 'tampered'}
              : Map<String, dynamic>.from(doc),
    };
  }
}

/// Brings the effective `readings` to the published manifest the way an
/// installed app does: version check, download, verify, activate.
Future<ContentCheck> applyPublishedReadings({
  ProductionReadingsRemote? remote,
}) async {
  final updater = ContentUpdater(remote: remote ?? ProductionReadingsRemote());
  await ContentStore.instance.ensureLoaded(const ['readings']);
  final check = await updater.check();
  if (check.kind == ContentCheckKind.patch) await updater.apply(check.plan!);
  return check;
}
