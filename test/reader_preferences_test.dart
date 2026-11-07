import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mybrev_flutter/models/reader_alignment.dart';
import 'package:mybrev_flutter/models/psalmody_preferences.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/theme/reader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('reader-preferences-');
    Hive.init(directory.path);
    await Hive.openBox('settings');
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });
  test(
    'missing and invalid alignment default safely without writing Hive',
    () async {
      for (final value in [null, 'unknown', 42]) {
        if (value != null) {
          await Hive.box('settings').put('textAlignment', value);
        }
        final container = ProviderContainer();
        expect(
          container.read(settingsProvider).textAlignment,
          ReaderAlignment.start,
        );
        expect(Hive.box('settings').get('textAlignment'), value);
        container.dispose();
      }
    },
  );
  for (final font in kAvailableReaderFonts) {
    test(
      '${font.label} and alignment survive a real Hive close/reopen',
      () async {
        final box = Hive.box('settings');
        await box.putAll({
          'fontFamily': font.id,
          'favoriteIds': '["kept"]',
          'psalmodyMode': 'alternatingStanzas',
        });
        var container = ProviderContainer();
        expect(container.read(settingsProvider).fontFamily, font.id);
        final notifier = container.read(settingsProvider.notifier);
        notifier.setFontFamily(font.id);
        notifier.setFontSize(24);
        await notifier.setTextAlignment(ReaderAlignment.justify);
        await box.flush();
        container.dispose();
        await box.close();
        await Hive.openBox('settings');
        container = ProviderContainer();
        final state = container.read(settingsProvider);
        expect(state.fontFamily, font.id);
        expect(state.fontSize, 24);
        expect(state.textAlignment, ReaderAlignment.justify);
        expect(state.psalmodyMode, PsalmodyMode.alternatingStanzas);
        expect(state.favoriteIds, ['kept']);
        await container
            .read(settingsProvider.notifier)
            .setTextAlignment(ReaderAlignment.start);
        expect(Hive.box('settings').get('textAlignment'), 'start');
        container.dispose();
      },
    );
  }
  test('existing IDs and legacy aliases keep their original appearance', () {
    for (final id in [
      ReaderFontFamily.literata,
      ReaderFontFamily.system,
      ReaderFontFamily.sourceSerif4,
    ]) {
      expect(normalizeReaderFontFamily(id), id);
    }
    expect(normalizeReaderFontFamily('Literata'), ReaderFontFamily.literata);
    expect(
      normalizeReaderFontFamily('Source Serif 4'),
      ReaderFontFamily.sourceSerif4,
    );
    expect(normalizeReaderFontFamily('Сістэмны'), ReaderFontFamily.literata);
    expect(
      normalizeReaderFontFamily('Old Standard TT'),
      ReaderFontFamily.oldStandardTT,
    );
    expect(normalizeReaderFontFamily('Kurale'), ReaderFontFamily.kurale);
    expect(kAvailableReaderFonts.map((f) => f.label), [
      'Literata',
      'Source Serif 4',
      'Old Standard TT',
      'Kurale',
      'Сістэмны',
    ]);
  });
}
