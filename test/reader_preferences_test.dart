import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mybrev_flutter/models/reader_preferences.dart';
import 'package:mybrev_flutter/models/psalmody_preferences.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/theme/reader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('reader-settings-');
    Hive.init(directory.path);
    await Hive.openBox('settings');
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test(
    'alignment has safe defaults, typed values and respects fixed line breaks',
    () {
      for (final unknown in [null, '', 'left', 'future', 3]) {
        expect(
          ReaderTextAlignment.fromStorage(unknown),
          ReaderTextAlignment.start,
        );
      }
      expect(
        readerProseAlignment(
          ReaderTextAlignment.justify,
          'Абзац.\n\nДругі абзац.',
        ),
        TextAlign.justify,
      );
      expect(
        readerProseAlignment(ReaderTextAlignment.justify, 'Страфа\nПрацяг'),
        TextAlign.start,
      );
      expect(
        readerProseAlignment(ReaderTextAlignment.start, 'Абзац.'),
        TextAlign.start,
      );
    },
  );

  test('text group expansion defaults to collapsed and survives restart', () async {
    final first = ProviderContainer();
    expect(first.read(settingsProvider).textSettingsExpanded, isFalse);
    await first.read(settingsProvider.notifier).setTextSettingsExpanded(true);
    expect(Hive.box('settings').get('textSettingsExpanded'), isTrue);
    first.dispose();
    await Hive.close();
    await Hive.openBox('settings');
    final restarted = ProviderContainer();
    expect(restarted.read(settingsProvider).textSettingsExpanded, isTrue);
    await restarted.read(settingsProvider.notifier).setTextSettingsExpanded(false);
    expect(Hive.box('settings').get('textSettingsExpanded'), isFalse);
    restarted.dispose();
  });

  test('loading old preferences performs no writes or resets', () async {
    final box = Hive.box('settings');
    for (final family in [
      ReaderFontFamily.literata,
      ReaderFontFamily.system,
      ReaderFontFamily.sourceSerif4,
    ]) {
      await box.putAll({
        'fontFamily': family,
        'fontSize': 22.4,
        'psalmodyMode': 'leftBreakIndent',
        'favoriteIds': '["keep"]',
      });
      final before = box.toMap();
      final container = ProviderContainer();
      final settings = container.read(settingsProvider);
      expect(settings.fontFamily, family);
      expect(settings.textAlignment, ReaderTextAlignment.start);
      expect(settings.textSettingsExpanded, isFalse);
      expect(settings.psalmodyMode, PsalmodyMode.leftBreakIndent);
      expect(settings.fontSize, 22.4);
      expect(settings.favoriteIds, ['keep']);
      container.dispose();
      expect(box.toMap(), before);
    }
  });

  test(
    'both alignments and all five fonts survive a real Hive close/reopen',
    () async {
      for (final family in kAvailableReaderFonts) {
        for (final alignment in ReaderTextAlignment.values) {
          final container = ProviderContainer();
          final notifier = container.read(settingsProvider.notifier);
          notifier.setFontFamily(family.id);
          notifier.setFontSize(24);
          await notifier.setTextAlignment(alignment);
          await notifier.setPsalmodyMode(PsalmodyMode.alternatingStanzas);
          // An awaited existing settings save drains the two legacy void setters.
          await notifier.toggleFavorite('keep');
          await Hive.box('settings').flush();
          container.dispose();
          await Hive.close();
          await Hive.openBox('settings');
          final restarted = ProviderContainer();
          final settings = restarted.read(settingsProvider);
          expect(settings.fontFamily, family.id);
          expect(
            settings.resolvedFontFamily,
            family.id == ReaderFontFamily.system ? null : family.label,
          );
          expect(settings.textAlignment, alignment);
          expect(settings.fontSize, 24);
          expect(settings.psalmodyMode, PsalmodyMode.alternatingStanzas);
          restarted.dispose();
        }
      }
    },
  );

  test(
    'unrelated save cannot overwrite explicit alignment from another container',
    () async {
      final first = ProviderContainer();
      final second = ProviderContainer();
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      first.read(settingsProvider);
      second.read(settingsProvider);
      await Future.wait([
        first
            .read(settingsProvider.notifier)
            .setTextAlignment(ReaderTextAlignment.justify),
        second.read(settingsProvider.notifier).toggleFavorite('keep'),
      ]);
      expect(Hive.box('settings').get('textAlignment'), 'justify');
      expect(Hive.box('settings').get('favoriteIds'), '["keep"]');
    },
  );
}
