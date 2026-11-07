import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:html/parser.dart' show parseFragment;
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/utils/liturgical_alternatives.dart';

String plain(String html) =>
    parseFragment(html).text!.replaceAll(RegExp(r'\s+'), ' ').trim();

void expectEnding(String html, {bool daniel = false}) {
  final text = plain(html);
  expect('Хвала Айцу і Сыну'.allMatches(text).length, daniel ? 0 : 1);
  if (daniel) {
    expect(text, contains('Благаславім Айца і Сына, і Духа Святога'));
  } else {
    expect(text, contains('і Духу Святому.'));
    expect(text, contains('Як была спрадвеку, цяпер і заўсёды,'));
    expect(text, contains('і на векі вечныя. Амэн.'));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final templates = decodeContentCollection(
    File('assets/content/liturgicalTemplates.json.gz').readAsBytesSync(),
  ).docs;

  test('Josaphat: both Commons have three complete Reading Office endings', () {
    for (final id in ['martyr-one', 'pastors']) {
      for (var n = 1; n <= 3; n++) {
        expectEnding(templates[id]!['officeOfReadingsPs$n'] as String);
      }
    }
  });

  test('Dead: every hour and both third Lauds alternatives have one ending', () {
    final dead = templates['office-for-dead']!;
    for (final prefix in [
      'officeOfReadings',
      'laudes',
      'sext1',
      'sext2',
      'sext3',
      'vesper',
    ]) {
      for (var n = 1; n <= 3; n++) {
        final options = getLiturgicalAlternatives(
          dead['${prefix}Ps$n'] as String,
          kind: 'psalm',
        );
        expect(options.length, prefix == 'laudes' && n == 3 ? 2 : 1);
        for (final option in options) {
          expectEnding(option.html);
        }
      }
    }
  });

  test('Sunday I: Daniel keeps its own ending; correct psalm stays complete', () {
    final sunday = templates['sunday-week-1']!;
    expectEnding(sunday['laudesPs2'] as String, daniel: true);
    expectEnding(sunday['laudesPs1'] as String);
  });

  test('new bundle supersedes an old local Common without duplicate endings', () async {
    final directory = await Directory.systemTemp.createTemp('doxology-cache-');
    try {
      await HiveService.init(path: directory.path, loadBundle: true);
      await HiveService.content.ensureLoaded(['liturgicalTemplates']);
      final collection = HiveService.content.collection('liturgicalTemplates');
      final stale = Map<String, dynamic>.from(
        collection.get('martyr-one') as Map,
      );
      stale['officeOfReadingsPs1'] =
          (stale['officeOfReadingsPs1'] as String).replaceAll(
            'Хвала Айцу і Сыну',
            'Стары тэкст',
          );
      await collection.applyUpdate(
        {'martyr-one': stale},
        {'martyr-one': documentHash(stale)},
        collection.baselineVersion - 1,
      );
      await Hive.close();
      for (var cycle = 0; cycle < 2; cycle++) {
        await HiveService.init(path: directory.path, loadBundle: true);
        await HiveService.content.ensureLoaded(['liturgicalTemplates']);
        final current = HiveService.content.collection('liturgicalTemplates');
        expectEnding(
          (current.get('martyr-one') as Map)['officeOfReadingsPs1'] as String,
        );
        expect(current.overlayLength, 0);
        await Hive.close();
      }
    } finally {
      await Hive.close();
      await directory.delete(recursive: true);
    }
  });
}
