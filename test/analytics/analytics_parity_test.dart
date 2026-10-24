// WEB <-> Flutter parity guard. Replays the golden generated from the WEB
// reference (test/fixtures/analytics/analytics-parity-v2.json, a byte-identical
// copy of mybrev tests/fixtures/analytics-parity-v2.json) through the Dart
// contract, route mapper and collector. A drift on either side fails here.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/analytics/collector.dart';
import 'package:mybrev_flutter/analytics/contract.dart' as c;
import 'package:mybrev_flutter/analytics/public_inventory.dart';
import 'package:mybrev_flutter/analytics/route_mapper.dart';

const _fixtures = 'test/fixtures/analytics';

Map<String, Object?> _json(String name) =>
    jsonDecode(File('$_fixtures/$name').readAsStringSync())
        as Map<String, Object?>;

List<Object?> _list(Object? v) => (v! as List).cast<Object?>();

String _cellKey(Map<String, Object?> cell) {
  final keys = cell.keys.toList()..sort();
  return jsonEncode([
    for (final k in keys) [k, cell[k]],
  ]);
}

List<Map<String, Object?>> _replay(
  List<Object?> steps, {
  required String platform,
}) {
  var t = DateTime.utc(2026, 10, 15, 10).millisecondsSinceEpoch;
  final collector = AnalyticsCollector(
    platform: platform,
    appVersion: '4.5.2',
    enabled: true,
    publicIds: kAnalyticsPublicIds,
    now: () => t,
  );
  for (final raw in steps) {
    final s = raw! as Map<String, Object?>;
    switch (s['op']) {
      case 'enter':
        collector.enterView(
          section: s['section'] as String?,
          contentId: s['contentId'] as String?,
          catalogId: s['catalogId'] as String?,
          totalChars: (s['totalChars'] as num?)?.toInt(),
          fits: (s['fits'] as bool?) ?? false,
        );
      case 'tick':
        t += ((s['seconds']! as num) * 1000).round();
      case 'scroll':
        collector.reportScroll((s['fraction']! as num).toDouble());
      case 'fits':
        collector.reportFits(s['value']! as bool);
      case 'leave':
        collector.leaveView();
      case 'discard':
        collector.discardView();
      case 'hide':
        collector.setVisible(false);
      case 'show':
        collector.setVisible(true);
      case 'feature':
        collector.featureUse(s['id']! as String, s['section']! as String);
      case 'error':
        collector.reportError(s['id']! as String);
      default:
        fail('unknown op ${s['op']}');
    }
  }
  collector.flush();
  final packets = collector.snapshot();
  for (final p in packets) {
    expect(c.validatePacket(p, publicIds: kAnalyticsPublicIds), isEmpty);
  }
  return [
    for (final p in packets)
      ...(p['cells']! as List).cast<Map<String, Object?>>(),
  ]..sort((a, b) => _cellKey(a).compareTo(_cellKey(b)));
}

Map<String, Object?>? _target(AnalyticsTarget? t) => t == null
    ? null
    : {
        'section': ?t.section,
        'contentId': ?t.contentId,
        'catalogId': ?t.catalogId,
      };

void main() {
  final golden = _json('analytics-parity-v2.json');
  final surface = golden['contract']! as Map<String, Object?>;

  test(
    'golden and shared contract fixture are the WEB bytes it was built from',
    () {
      final sources = golden['sources']! as Map<String, Object?>;
      final fixtureSha = sha256
          .convert(
            File('$_fixtures/analytics-contract-v2.json').readAsBytesSync(),
          )
          .toString();
      expect(fixtureSha, sources['contract_fixture_sha256']);
      expect(kAnalyticsInventorySha256, sources['inventory_sha256']);
      expect(kAnalyticsPublicIds.length, sources['inventory_count']);
    },
  );

  test('contract surface (ids, buckets, limits, constants) equals WEB', () {
    expect(c.schemaVersion, surface['schema_version']);
    expect(c.platforms, surface['platforms']);
    expect(c.regions, surface['regions']);
    expect(c.sections, surface['sections']);
    expect(c.sectionContentKind, surface['section_content_kind']);
    expect(c.hourIds, surface['hour_ids']);
    expect(c.featureIds, surface['feature_ids']);
    expect(c.featureIds.length, 27);
    expect(c.errorIds, surface['error_ids']);
    expect(c.catalogIds, surface['catalog_ids']);
    expect(c.events, surface['events']);
    expect(c.textMetrics, surface['text_metrics']);
    expect(c.timeBuckets, surface['time_buckets']);
    expect(c.scrollBuckets, surface['scroll_buckets']);
    expect({
      'maxCellsPerPacket': c.maxCellsPerPacket,
      'maxCellCount': c.maxCellCount,
      'maxPacketBytes': c.maxPacketBytes,
      'maxLocalDays': c.maxLocalDays,
    }, surface['limits']);
    expect({
      'max_visit_seconds': c.maxVisitSeconds,
      'min_counted_visit_seconds': c.minCountedVisitSeconds,
      'short_open_seconds': c.shortOpenSeconds,
      'reading_words_per_minute': c.readingWordsPerMinute,
      'chars_per_word': c.charsPerWord,
    }, surface['constants']);
  });

  test('content id probes give the WEB verdict', () {
    for (final raw in _list(golden['contentIdProbes'])) {
      final p = raw! as Map<String, Object?>;
      final ok = c
          .validateContentId(
            p['section']! as String,
            p['content_id'],
            publicIds: kAnalyticsPublicIds,
          )
          .isEmpty;
      expect(ok, p['valid'], reason: '${p['section']} ${p['content_id']}');
    }
  });

  test('routes: every Flutter location maps to the WEB-equivalent target', () {
    final massId = golden['massOrderPrayerId']! as String;
    var checked = 0;
    for (final raw in _list(golden['routes'])) {
      final r = raw! as Map<String, Object?>;
      final location = r['flutter'] as String?;
      // NOT APPLICABLE: no such screen in Flutter.
      if (location == null) continue;
      checked++;
      expect(
        _target(mapLocation(Uri.parse(location), massOrderPrayerId: massId)),
        r['expect'],
        reason: '${r['id']} $location',
      );
    }
    expect(checked, greaterThan(20));
  });

  test('synthetic visits replay to the WEB cells on android and ios', () {
    for (final raw in _list(golden['visits'])) {
      final v = raw! as Map<String, Object?>;
      final expected = [
        for (final cell in _list(v['cells'])) cell! as Map<String, Object?>,
      ];
      for (final platform in ['android', 'ios']) {
        expect(
          _replay(_list(v['steps']), platform: platform).map(_cellKey).toList(),
          expected.map(_cellKey).toList(),
          reason: '${v['id']} on $platform',
        );
      }
    }
  });
}
