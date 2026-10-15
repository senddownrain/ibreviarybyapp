import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/analytics/contract.dart';
import 'package:mybrev_flutter/analytics/public_inventory.dart';

void main() {
  final fixture =
      jsonDecode(
            File(
              'test/fixtures/analytics/public-inventory.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final ids = (fixture['ids'] as List).cast<String>();
  const kindSection = {
    'prayer': 'prayers',
    'song': 'songs',
    'comp': 'compendium',
    'mass': 'mass',
    'hour': 'hours',
    'bible': 'bible',
  };

  test('the generated Dart set equals the web inventory copy', () {
    expect(kAnalyticsPublicIds.length, ids.length);
    expect(kAnalyticsPublicIds.containsAll(ids), isTrue);
    expect(kAnalyticsInventorySha256, fixture['sha256']);
  });

  test('the fixture checksum matches its own ids (copy is not edited)', () {
    expect(
      sha256.convert(utf8.encode(jsonEncode(ids))).toString(),
      fixture['sha256'],
    );
    expect(ids.toSet().length, ids.length);
  });

  test('every id is well-formed for its section', () {
    for (final id in ids) {
      final section = kindSection[id.split(':').first]!;
      expect(
        validateContentId(section, id, publicIds: kAnalyticsPublicIds),
        isEmpty,
        reason: id,
      );
    }
  });

  test(
    'fixed sets are present: mass order, nine hours, both Bible languages',
    () {
      expect(kAnalyticsPublicIds.contains('mass:order'), isTrue);
      for (final hour in hourIds) {
        expect(
          kAnalyticsPublicIds.contains('hour:$hour'),
          isTrue,
          reason: hour,
        );
      }
      expect(ids.where((id) => id.startsWith('bible:bel:')).length, 73);
      expect(ids.where((id) => id.startsWith('bible:ru:')).length, 73);
    },
  );
}
