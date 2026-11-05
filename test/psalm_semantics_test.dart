import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/providers/connectivity_provider.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/providers/content_updates_provider.dart';
import 'package:mybrev_flutter/router/router.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/utils/liturgical_html.dart';
import 'package:mybrev_flutter/widgets/psalm_choir_html.dart';
import 'package:mybrev_flutter/widgets/reader/reader_navigation.dart';

class _IdleUpdates extends ContentUpdatesNotifier {
  @override
  ContentUpdateState build() => const ContentUpdateState();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await initializeDateFormatting('be');
    directory = await Directory.systemTemp.createTemp('psalm-a11y-');
    await HiveService.init(path: directory.path, loadBundle: true);
    await HiveService.content.ensureLoaded(kLiturgicalCollections);
    // Complete startup migration on the real async clock. A Hive write begun
    // inside testWidgets' FakeAsync cannot finish during real-I/O teardown.
    final settings = ProviderContainer();
    settings.read(settingsProvider);
    await Hive.box('settings').flush();
    settings.dispose();
  });
  tearDownAll(() async {
    await HiveService.content.idle();
    await Hive.close();
    await directory.delete(recursive: true);
  });

  testWidgets('psalm bodies are part of the hour text for screen readers', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final handle = tester.ensureSemantics();
    final container = ProviderContainer(
      overrides: [
        contentUpdatesProvider.overrideWith(_IdleUpdates.new),
        isOfflineProvider.overrideWithValue(true),
        connectivityProvider.overrideWith((ref) => Stream.value(false)),
      ],
    );
    addTearDown(container.dispose);
    router.go(
      oraRouteForContext(
        date: DateTime(2026, 10, 19),
        dayId: '19-10-sv-paul-of-cross--religious',
        oraType: 'laudes',
        diocese: 'minsk-mohilev',
      ),
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    try {
      final psalms = tester
          .widgetList<PsalmChoirHtml>(find.byType(PsalmChoirHtml))
          .toList();
      expect(psalms, isNotEmpty);
      final hourText = tester
          .getSemantics(find.byType(PsalmChoirHtml).first)
          .label;
      expect(hourText, startsWith('Тэкст Ora'));
      for (final psalm in psalms) {
        final spoken = psalmPlainText(psalm.html);
        expect(spoken, isNotEmpty);
        for (final line in spoken.split('\n')) {
          expect(
            hourText,
            contains(line),
            reason: 'psalm line missing from the hour text: $line',
          );
        }
      }
    } finally {
      handle.dispose();
    }
  });

  test('psalmPlainText gives one line per strophe, without markup', () {
    expect(
      psalmPlainText(
        '<p class="psalm-strophe">Божа, <span class="psalm-marker">*</span>\n'
        'мой Божа.</p>\n\n<p class="psalm-strophe psalm-strophe-even">Другая.</p>',
      ),
      'Божа, * мой Божа.\nДругая.',
    );
  });
}
