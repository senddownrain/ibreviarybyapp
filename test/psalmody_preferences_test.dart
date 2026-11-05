import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mybrev_flutter/models/psalmody_preferences.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';

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
        'userCategories': '[{"id":"personal","name":"Маё","tags":[]}]',
        'themeMode': 'dark',
        'selectedDiocese': 'pinsk',
      });
      final before = box.toMap();
      final container = ProviderContainer();
      expect(container.read(settingsProvider).psalmodyMode, expected);
      await box.flush();
      expect(box.get('psalmodyMode'), expected.name);
      // Migration adds exactly one key, without rewriting any other preference.
      expect(box.toMap(), {...before, 'psalmodyMode': expected.name});
      container.dispose();
      await box.close();
      await Hive.openBox('settings');
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
