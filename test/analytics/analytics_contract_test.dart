import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/analytics/contract.dart';

Map<String, dynamic> _fixture() =>
    jsonDecode(
          File(
            'test/fixtures/analytics/analytics-contract-v2.json',
          ).readAsStringSync(),
        )
        as Map<String, dynamic>;

void main() {
  final fixture = _fixture();

  test('contract is v2 and matches the shared fixture version', () {
    expect(schemaVersion, 2);
    expect(fixture['schema_version'], schemaVersion);
  });

  test('visible-time buckets follow the golden vectors', () {
    for (final row in fixture['visibleSecondsBuckets'] as List) {
      final seconds = row[0] as num;
      expect(bucketVisibleSeconds(seconds), row[1], reason: '$seconds s');
    }
    expect(bucketVisibleSeconds(-1), isNull);
    expect(bucketVisibleSeconds(double.nan), isNull);
  });

  test('scroll-depth buckets follow the golden vectors', () {
    for (final row in fixture['scrollBuckets'] as List) {
      expect(
        bucketScrollDepth(row[0] as num, fits: row[1] as bool),
        row[2],
        reason: '$row',
      );
    }
    expect(bucketScrollDepth(-0.1), isNull);
    expect(bucketScrollDepth(double.nan), isNull);
  });

  test('reading estimates follow the golden vectors', () {
    for (final row in fixture['readingEstimates'] as List) {
      final seconds = estimateReadingSeconds(
        visibleSeconds: row['visibleSeconds'] as num,
        totalChars: row['totalChars'] as num,
        maxScrollFraction: row['maxScrollFraction'] as num,
      );
      expect(seconds, closeTo((row['seconds'] as num).toDouble(), 1e-9));
    }
    expect(estimateReadingSeconds(visibleSeconds: -1, totalChars: 10), isNull);
  });

  test('the golden packet is valid and every invalid cell is rejected', () {
    expect(validatePacket(fixture['validPacket']), isEmpty);
    for (final entry in fixture['invalidCells'] as List) {
      expect(
        validateCell(entry['cell']),
        isNotEmpty,
        reason: entry['why'] as String,
      );
    }
  });

  test('packets reject identifiers, unknown fields and bad envelopes', () {
    Map<String, dynamic> packet() =>
        jsonDecode(jsonEncode(fixture['validPacket'])) as Map<String, dynamic>;
    expect(validatePacket(packet()..['user_id'] = 'x'), isNotEmpty);
    expect(validatePacket(packet()..['platform'] = 'desktop'), isNotEmpty);
    expect(validatePacket(packet()..['app_version'] = '4.5.2'), isNotEmpty);
    expect(validatePacket(packet()..['region'] = 'EU'), isNotEmpty);
    expect(validatePacket(packet()..['day'] = '2026-02-30'), isNotEmpty);
    expect(validatePacket(packet()..['schema_version'] = 1), isNotEmpty);
    expect(validatePacket(packet()..['cells'] = []), isNotEmpty);
    final duplicated = packet();
    final cells = duplicated['cells'] as List;
    cells.add(Map<String, dynamic>.from(cells.first as Map));
    expect(validatePacket(duplicated), isNotEmpty);
  });

  test('closed material cannot pass: content_id must be in the inventory', () {
    const open = 'prayer:AbCdEfGhIjKlMnOpQrSt';
    const closed = 'prayer:ZZZZZZZZZZZZZZZZZZZZ';
    expect(validateContentId('prayers', open, publicIds: {open}), isEmpty);
    expect(validateContentId('prayers', closed, publicIds: {open}), isNotEmpty);
    expect(validateContentId('today', open), isNotEmpty);
    expect(validateContentId('prayers', null), isNotEmpty);
  });

  test('whitelists contain no closed or personal sections', () {
    for (final forbidden in ['admin', 'login', 'priest', 'my', 'notes']) {
      expect(sections.contains(forbidden), isFalse, reason: forbidden);
    }
    expect(featureIds.length, 27);
    expect(catalogIds.length, 7);
    expect(hourIds.contains('vespers'), isFalse);
  });
}
