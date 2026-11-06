import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/discovery/discovery.dart';
import 'package:mybrev_flutter/main.dart' show MyBrevApp;
import 'package:mybrev_flutter/providers/connectivity_provider.dart';
import 'package:mybrev_flutter/providers/content_updates_provider.dart';
import 'package:mybrev_flutter/providers/priest_access_provider.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/router/router.dart';
import 'package:mybrev_flutter/screens/ora_screen.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/theme/app_theme_preference.dart';
import 'package:mybrev_flutter/theme/ib_colors.dart';
import 'package:mybrev_flutter/widgets/reader/reader_scaffold.dart';
import 'priest_access_test.dart' show MemoryStorage, SparkGateway;

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
    directory = await Directory.systemTemp.createTemp('marian-navigation-');
    await HiveService.init(path: directory.path, loadBundle: true);
    await HiveService.content.ensureLoaded(kLiturgicalCollections);
  });
  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  testWidgets(
    'production app retains route, reader state, scroll and open sheet across all themes',
    (tester) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMessageHandler(
        'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
        (_) async => const StandardMessageCodec().encodeMessage([null]),
      );
      messenger.setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/connectivity'),
        (_) async => ['none'],
      );
      messenger.setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/connectivity_status'),
        (_) async => null,
      );
      final gateway = SparkGateway();
      final container = ProviderContainer(
        overrides: [
          contentUpdatesProvider.overrideWith(_IdleUpdates.new),
          isOfflineProvider.overrideWithValue(true),
          connectivityProvider.overrideWith((ref) => Stream.value(false)),
          priestAccessGatewayProvider.overrideWithValue(gateway),
          priestAccessStorageProvider.overrideWithValue(MemoryStorage()),
          discoveryStorageProvider.overrideWithValue(MemoryDiscoveryStorage()),
        ],
      );
      router.go(
        '/hours/ora/2026-02-08/ordinary-w5-d1/laudes?diocese=minsk-mohilev',
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MyBrevApp(),
        ),
      );
      await tester.pumpAndSettle();
      final ora = find.byType(OraScreen);
      expect(ora, findsOneWidget);
      final originalState = tester.state(ora);
      final route = router.routerDelegate.currentConfiguration.uri;
      final reader = tester.widget<ReaderScaffold>(find.byType(ReaderScaffold));
      final scroll = reader.scrollController!;
      scroll.jumpTo(650);
      await tester.pumpAndSettle();
      final offset = scroll.offset;
      final sheet = showReaderChoiceSheet<int>(
        context: tester.element(ora),
        title: 'Тэма — захаванне стану',
        choices: const [ReaderChoice(value: 1, label: 'Засталося адкрытым')],
      );
      await tester.pumpAndSettle();
      for (final preference in AppThemePreference.values) {
        // Hive flush uses the real async zone, while the theme signal is immediate.
        await tester.runAsync(
          () => container
              .read(settingsProvider.notifier)
              .setThemePreference(preference),
        );
        await tester.pumpAndSettle();
        expect(tester.state(ora), same(originalState));
        expect(router.routerDelegate.currentConfiguration.uri, route);
        expect(scroll.offset, offset);
        expect(find.text('Засталося адкрытым'), findsOneWidget);
        if (preference == AppThemePreference.marian) {
          expect(IbColors.of(tester.element(ora)), same(IbColors.marian));
        }
        final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
        expect(app.key, isNull);
        expect(tester.takeException(), isNull);
      }
      rootNavigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      await sheet;
      expect(tester.state(ora), same(originalState));
      expect(scroll.offset, offset);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() => Hive.box('settings').flush());
      container.dispose();
      await gateway.close();
    },
  );
}
