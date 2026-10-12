import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mybrev_flutter/content/content_store.dart';
import 'package:mybrev_flutter/providers/priest_access_provider.dart';
import 'package:mybrev_flutter/services/hive_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'public snapshot removes private records, compacts old frames and keeps user data',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'priest-public-cache-',
      );
      try {
        await HiveService.init(path: temp.path, loadBundle: false);
        await HiveService.prayerCategoriesBox.put('closed', {
          'priestOnly': true,
          'tags': ['closed'],
        });
        await HiveService.prayersBox.put('closed', {
          'title': 'Closed',
          'text': 'PRIVATE-TEXT-SENTINEL',
          'tags': ['closed'],
        });
        await HiveService.prayersBox.put('public', {
          'title': 'Public',
          'text': 'Before',
          'tags': ['public'],
        });
        await HiveService.settingsBox.put('favoriteIds', ['closed', 'public']);
        await HiveService.localPrayersBox.put('local', {'text': 'Personal'});
        var sdkClears = 0;
        Future<void> clearSdk() async {
          sdkClears++;
        }

        await HiveService.sanitizeLegacyFirestoreCache(clearSdk);
        await HiveService.sanitizeLegacyFirestoreCache(clearSdk);
        expect(sdkClears, 1);
        final snapshot = PrayerAccessContent(
          {
            'public': {
              'id': 'public',
              'title': 'Public',
              'text': 'After',
              'tags': ['public'],
            },
          },
          {
            'public': {
              'id': 'public',
              'tags': ['public'],
            },
          },
        );
        await persistPublicPrayerContent(snapshot);
        expect(HiveService.prayersBox.get('closed'), null);
        expect(HiveService.prayersBox.get('public')['text'], 'After');
        expect(HiveService.settingsBox.get('favoriteIds'), [
          'closed',
          'public',
        ]);
        expect(HiveService.localPrayersBox.get('local')['text'], 'Personal');
        await Hive.close();
        for (final file in temp.listSync().whereType<File>().where(
          (f) => f.path.endsWith('.hive'),
        )) {
          expect(
            latin1.decode(file.readAsBytesSync()),
            isNot(contains('PRIVATE-TEXT-SENTINEL')),
          );
        }
        await HiveService.init(path: temp.path, loadBundle: false);
        expect(ContentStore.instance.collection('prayers').get('closed'), null);
        expect(HiveService.settingsBox.get('favoriteIds'), [
          'closed',
          'public',
        ]);
      } finally {
        await Hive.close();
        await temp.delete(recursive: true);
      }
    },
  );
  test('a protected snapshot is rejected before any disk write', () async {
    final temp = await Directory.systemTemp.createTemp(
      'priest-rejected-cache-',
    );
    try {
      await HiveService.init(path: temp.path, loadBundle: false);
      await expectLater(
        persistPublicPrayerContent(
          const PrayerAccessContent({
            'closed': {'priestOnly': true, 'text': 'Private'},
          }, {}),
        ),
        throwsFormatException,
      );
      expect(HiveService.prayersBox.keys, isEmpty);
    } finally {
      await Hive.close();
      await temp.delete(recursive: true);
    }
  });
}
