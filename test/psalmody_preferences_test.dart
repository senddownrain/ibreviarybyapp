import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mybrev_flutter/models/psalmody_preferences.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/services/hive_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('psalmody-migration-');
    Hive.init(directory.path);
    await Hive.openBox('settings');
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  final cases = [
    (null, null, PsalmodyMode.leftBreak),
    ('alignedLeft', 'inline', PsalmodyMode.leftBreak),
    ('alignedLeft', 'breakAfterMarker', PsalmodyMode.leftBreakIndent),
    ('alternatingIndent', 'inline', PsalmodyMode.alternatingStanzas),
    ('alternatingIndent', 'breakAfterMarker', PsalmodyMode.alternatingStanzas),
    ('alignedLeft', null, PsalmodyMode.leftBreak),
    (null, 'breakAfterMarker', PsalmodyMode.alternatingStanzas),
    ('unknown', 'unknown', PsalmodyMode.alternatingStanzas),
  ];
  for (final (layout, breaks, expected) in cases) {
    test('migrates $layout / $breaks and persists on real Hive reopen', () async {
      final box = Hive.box('settings');
      if (layout != null) await box.put('psalmVerseLayout', layout);
      if (breaks != null) await box.put('psalmMarkerBreakMode', breaks);
      await box.putAll({
        'fontSize': 20.0,
        'favoriteIds': '["favorite"]',
        'userCategories':
            '[{"id":"personal","name":"Маё","tags":[],"iconKey":"prayer"}]',
        'themeMode': 'dark',
        'selectedDiocese': 'pinsk',
      });
      final before = box.toMap();
      // An installed old version is fully closed before the updated app opens.
      await box.close();
      await HiveService.init(path: directory.path, loadBundle: false);
      final migrated = Hive.box('settings');
      expect(migrated.toMap(), {...before, 'psalmodyMode': expected.name});
      final container = ProviderContainer();
      expect(container.read(settingsProvider).psalmodyMode, expected);
      expect(migrated.get('psalmodyMode'), expected.name);
      // Migration adds exactly one key, without rewriting any other preference.
      expect(migrated.toMap(), {...before, 'psalmodyMode': expected.name});
      container.dispose();
      await Hive.close();
      await HiveService.init(path: directory.path, loadBundle: false);
      final reloaded = ProviderContainer();
      addTearDown(reloaded.dispose);
      final state = reloaded.read(settingsProvider);
      expect(state.psalmodyMode, expected);
      expect(state.fontSize, 20);
      expect(state.favoriteIds, ['favorite']);
      expect(state.userCategories.single.id, 'personal');
    });
  }

  for (final mode in PsalmodyMode.values) {
    test(
      '${mode.name} wins over legacy values and survives selection/restart',
      () async {
        final box = Hive.box('settings');
        await box.putAll({
          'psalmodyMode': mode.name,
          'psalmVerseLayout': 'alternatingIndent',
          'psalmMarkerBreakMode': 'breakAfterMarker',
        });
        await HiveService.init(path: directory.path, loadBundle: false);
        final container = ProviderContainer();
        expect(container.read(settingsProvider).psalmodyMode, mode);
        for (final next in PsalmodyMode.values) {
          await container.read(settingsProvider.notifier).setPsalmodyMode(next);
          expect(container.read(settingsProvider).psalmodyMode, next);
          await box.flush();
          final other = ProviderContainer();
          expect(other.read(settingsProvider).psalmodyMode, next);
          other.dispose();
        }
        container.dispose();
        await box.close();
        await Hive.openBox('settings');
        final restarted = ProviderContainer();
        expect(
          restarted.read(settingsProvider).psalmodyMode,
          PsalmodyMode.alternatingStanzas,
        );
        restarted.dispose();
      },
    );
  }
  test('provider reads never write or leave migration work at close', () async {
    final box = Hive.box('settings');
    await box.putAll({
      'psalmVerseLayout': 'alignedLeft',
      'psalmMarkerBreakMode': 'breakAfterMarker',
      'favoriteIds': '["keep"]',
    });
    final before = box.toMap();
    final changes = <BoxEvent>[];
    final subscription = box.watch().listen(changes.add);
    for (var i = 0; i < 5; i++) {
      final container = ProviderContainer();
      expect(
        container.read(settingsProvider).psalmodyMode,
        PsalmodyMode.leftBreakIndent,
      );
      container.dispose();
    }
    await box.close();
    await subscription.cancel();
    expect(changes, isEmpty);
    final reopened = await Hive.openBox('settings');
    expect(reopened.toMap(), before);
  });

  test(
    'startup completes migration before an immediate close and restart',
    () async {
      final old = Hive.box('settings');
      await old.putAll({
        'psalmVerseLayout': 'alignedLeft',
        'psalmMarkerBreakMode': 'breakAfterMarker',
        'favoriteIds': '["keep"]',
        'prayerCategoryMap': '{"keep":["personal"]}',
        'hiddenGlobalPrayerCategoryIds': '["hidden"]',
        'fontFamily': 'system',
        'fontSize': 22.0,
        'themeMode': 'dark',
        'bibleVersionId': 'ru',
        'dioceseSelection': {'primary': 'pinsk'},
      });
      final before = old.toMap();
      await Hive.close();
      await HiveService.init(path: directory.path, loadBundle: false);
      // No ProviderContainer, extra pump, flush or delay before closing.
      await Hive.close();
      final reopened = await Hive.openBox('settings');
      expect(reopened.toMap(), {...before, 'psalmodyMode': 'leftBreakIndent'});
    },
  );

  test(
    'unrelated saves from an older container cannot overwrite a new mode',
    () async {
      await HiveService.init(path: directory.path, loadBundle: false);
      final first = ProviderContainer();
      final second = ProviderContainer();
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      first.read(settingsProvider);
      second.read(settingsProvider);
      final notifier = first.read(settingsProvider.notifier);
      // Run the old container's full settings save and the explicit mode write
      // concurrently; only the mode setter owns this key after initialization.
      await Future.wait([
        second.read(settingsProvider.notifier).toggleFavorite('keep'),
        notifier.setPsalmodyMode(PsalmodyMode.alternatingStanzas),
      ]);
      await Hive.close();
      final reopened = await Hive.openBox('settings');
      expect(reopened.get('psalmodyMode'), 'alternatingStanzas');
      expect(reopened.get('favoriteIds'), '["keep"]');
    },
  );

  test(
    'reinitialization is idempotent and never resets a selected mode',
    () async {
      await HiveService.init(path: directory.path, loadBundle: false);
      final container = ProviderContainer();
      await container
          .read(settingsProvider.notifier)
          .setPsalmodyMode(PsalmodyMode.leftBreakIndent);
      container.dispose();
      final box = Hive.box('settings');
      final before = box.toMap();
      final changes = <BoxEvent>[];
      final subscription = box.watch().listen(changes.add);
      await HiveService.init(path: directory.path, loadBundle: false);
      for (var i = 0; i < 5; i++) {
        final next = ProviderContainer();
        expect(
          next.read(settingsProvider).psalmodyMode,
          PsalmodyMode.leftBreakIndent,
        );
        next.dispose();
      }
      await subscription.cancel();
      expect(changes, isEmpty);
      expect(box.toMap(), before);
    },
  );

  test('unknown new value still migrates valid legacy preferences', () {
    expect(
      resolvePsalmodyMode(
        storedMode: 'future',
        legacyLayout: 'alignedLeft',
        legacyBreakMode: 'breakAfterMarker',
      ),
      PsalmodyMode.leftBreakIndent,
    );
  });
}
