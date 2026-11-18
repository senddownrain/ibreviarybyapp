import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/models/prayer.dart';
import 'package:mybrev_flutter/models/prayer_menu_category.dart';
import 'package:mybrev_flutter/ordo/definitions.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/services/prayer_category_membership.dart';

import 'support/ordo_fixture.dart';

void main() {
  test('all reviewed devotions load from the bundled category once', () {
    final report =
        jsonDecode(
              File(
                'docs/release/final-test/nov18-refresh-report.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final docs = bundledCollection('prayers');
    final category = PrayerMenuCategory.global(
      'devotions',
      bundledCollection('prayerCategories')['devotions']!,
    );
    expect(category.name, 'Набажэнствы');
    expect(category.priestOnly, isFalse);
    expect(docs, hasLength(report['prayerCount'] as int));
    final listed = prayersForCategory(
      [for (final doc in docs.entries) Prayer.fromMap(doc.value, doc.key)],
      category,
      const SettingsState(),
    );

    final reviewed = (report['devotions'] as List).cast<Map<String, dynamic>>();
    expect(
      reviewed.map((entry) => entry['id']),
      unorderedEquals([
        'devotion-vigilijny-vechar',
        'devotion-zakanchenne-goda',
        'devotion-vystaulenne-euharystyja',
        'Fd9rN0S9NU1mAmqb2isZ',
      ]),
    );
    expect(docs, isNot(contains('devotion-euharystychnaja-pracesija')));
    for (final entry in reviewed) {
      final matches = listed.where((p) => p.displayTitle == entry['title']);
      expect(matches, hasLength(1));
      final prayer = matches.single;
      expect(prayer.id, entry['id']);
      expect(prayer.isMarkdown, isTrue);
      expect(prayer.priestOnly, isFalse);
      expect(prayer.source, '«Літургічная агенда» (Мінск, 2010)');
      expect(
        sha256.convert(utf8.encode(prayer.displayText)).toString(),
        entry['sha256'],
      );
    }

    for (final group in (report['sourceChanges'] as List).cast<Map>()) {
      for (final id in (group['ids'] as List).cast<String>()) {
        expect(docs[id]![group['field']], group['to'], reason: id);
      }
    }
  });

  test(
    'bundled calendar revision 6 resolves white basilicas on November 18',
    () {
      const basilicas = 'dedication-basilicas-peter-paul';
      final definitions = bundledCollection('liturgicalCelebrations');
      expect(
        bundledCollection('liturgicalCalendarMeta')['current']!['revision'],
        6,
      );
      expect(definitions[basilicas]!['color'], 'albus');
      expect(definitions['sv-juan-diego']!['enabled'], isFalse);
      expect(definitions['our-lady-guadalupe']!['enabled'], isFalse);
      expect(definitions['sv-andrew-apostle']!['color'], 'ruber');

      for (final diocese in kDioceses) {
        final day = bundledOrdoEngine().resolve('2026-11-18', diocese: diocese);
        expect(day.primary.color, 'viridis', reason: diocese);
        expect(day.option(basilicas)?.color, 'albus', reason: diocese);
      }
    },
  );
}
