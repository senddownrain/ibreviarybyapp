import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:mybrev_flutter/models/psalmody_preferences.dart';
import 'package:mybrev_flutter/providers/connectivity_provider.dart';
import 'package:mybrev_flutter/providers/content_updates_provider.dart';
import 'package:mybrev_flutter/providers/priest_access_provider.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/screens/settings_screen.dart';
import 'package:mybrev_flutter/widgets/data_settings_section.dart';
import 'package:mybrev_flutter/widgets/reader_icon_segments.dart';
import 'package:mybrev_flutter/widgets/settings_reader_controls.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'priest_access_test.dart' show MemoryStorage, SparkGateway;

class _LocalUpdates extends ContentUpdatesNotifier {
  @override
  ContentUpdateState build() => const ContentUpdateState();
}

Finder keyed(String key) => find.byKey(Key(key));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('settings-contract-');
    Hive.init(directory.path);
    await Hive.openBox('settings');
    PackageInfo.setMockInitialValues(
      appName: 'Малітоўнік',
      packageName: 'local.test',
      version: '5.4.3',
      buildNumber: '6',
      buildSignature: '',
    );
  });

  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  testWidgets('Settings V1 structure, choices, collapse and menu routes', (
    tester,
  ) async {
    final gateway = SparkGateway();
    addTearDown(gateway.close);
    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(
          path: '/settings',
          builder: (_, state) => Scaffold(
            body: SettingsScreen(
              scrollToData: const {
                'data',
                'sync',
              }.contains(state.uri.queryParameters['section']),
            ),
          ),
        ),
        for (final path in ['/settings/feedback', '/about'])
          GoRoute(
            path: path,
            builder: (_, _) => Scaffold(body: Text(path)),
          ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          contentUpdatesProvider.overrideWith(_LocalUpdates.new),
          isOfflineProvider.overrideWithValue(false),
          priestAccessProvider.overrideWith(
            (_) => PriestAccessController(gateway, MemoryStorage()),
          ),
          protectedCatalogStorageProvider.overrideWithValue(null),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    final sections = tester.widget<Column>(keyed('settings-sections')).children;
    expect(
      sections
          .where((section) => section.key != null)
          .map((section) => section.key),
      orderedEquals([
        const Key('settings-start'),
        const Key('settings-theme'),
        const Key('settings-text'),
        const Key('settings-calendar'),
        const Key('settings-data'),
        const Key('settings-special-access'),
        const Key('settings-feedback'),
        const Key('settings-about'),
        const Key('settings-version'),
      ]),
    );
    final headingOrder = [
      'Стартовы раздзел',
      'Тэма',
      'Не гасіць экран',
      'Тэкст',
      'Шрыфт',
      'Памер тэксту',
      'Выраўноўванне тэксту',
      'Псальмодыя',
      'Каляровае вылучэнне чытанняў',
      'Літургічны каляндар',
      'Дадзеныя афлайн',
      'Асаблівы доступ',
      'Зваротная сувязь',
      'Інфармацыя',
      'Версія 5.4.3',
    ];
    var previousY = double.negativeInfinity;
    for (final title in headingOrder) {
      final heading = find.text(title);
      expect(heading, findsOneWidget);
      final top = tester.getTopLeft(heading).dy;
      expect(top, greaterThan(previousY), reason: title);
      previousY = top;
    }
    expect(sections, hasLength(15));
    expect(sections.last.key, const Key('settings-version'));
    expect(find.byType(DataSettingsSection), findsOneWidget);
    for (final removed in [
      'Падказкі',
      'Паказваць падказкі',
      'Як карыстацца дадаткам',
      'Скінуць падказкі',
      'Ацаніць дадатак',
      'Не прапаноўваць ацэнку',
      'Адміністрацыйны доступ',
      'Экран',
    ]) {
      expect(find.text(removed, skipOffstage: false), findsNothing);
    }

    final start = tester.widget<DropdownButtonFormField<String>>(
      keyed('settings-start-section'),
    );
    expect(start.initialValue, 'hours');
    expect(
      tester.widget<SwitchListTile>(keyed('settings-keep-screen-on')).value,
      true,
    );
    expect(
      tester.widget<SwitchListTile>(keyed('settings-readings-highlight')).value,
      false,
    );
    final alignment = keyed('settings-text-alignment');
    final psalmody = keyed('settings-psalmody-mode');
    final psalmodySegments = find.descendant(
      of: psalmody,
      matching: find.byType(ReaderIconSegments<PsalmodyMode>),
    );
    expect(tester.widget<ReaderIconSegments<TextAlign>>(alignment).choices, [
      TextAlign.left,
      TextAlign.justify,
    ]);
    expect(
      tester.widget<ReaderIconSegments<PsalmodyMode>>(psalmodySegments).choices,
      PsalmodyMode.values,
    );
    expect(tester.getSize(alignment).height, tester.getSize(psalmody).height);
    final textSection = keyed('settings-text-section');
    for (final member in [
      keyed('settings-reader-font'),
      keyed('settings-font-size'),
      alignment,
      psalmody,
      keyed('settings-readings-highlight'),
      find.byType(SettingsReaderPreview),
    ]) {
      expect(find.descendant(of: textSection, matching: member), findsWidgets);
    }
    expect(find.byType(SettingsReaderPreview), findsNWidgets(2));
    expect(
      tester.getTopLeft(keyed('settings-text-preview')).dy,
      lessThan(tester.getTopLeft(psalmody).dy),
    );
    expect(
      tester.getTopLeft(keyed('settings-psalmody-preview')).dy,
      lessThan(tester.getTopLeft(keyed('settings-readings-highlight')).dy),
    );

    await tester.tap(find.text('Тэкст'));
    await tester.pumpAndSettle();
    expect(psalmody, findsNothing);
    expect(keyed('settings-readings-highlight'), findsNothing);
    expect(find.byType(SettingsReaderPreview), findsNothing);

    for (final (label, destination) in [
      ('Зваротная сувязь', '/settings/feedback'),
      ('Інфармацыя', '/about'),
    ]) {
      final row = find.text(label);
      await tester.ensureVisible(row);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.text(destination), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
    }
    router.go('/settings?section=sync');
    await tester.pumpAndSettle();
    expect(find.text('Дадзеныя афлайн').hitTestable(), findsOneWidget);

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 800);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    router.go('/settings');
    await tester.pumpAndSettle();
    final startField = keyed('settings-start-section');
    await tester.ensureVisible(startField);
    await tester.pumpAndSettle();
    final activeLabel = find.descendant(
      of: startField,
      matching: find.text('Літургія гадзінаў'),
    );
    expect(activeLabel.hitTestable(), findsOneWidget);
    expect(tester.getSize(activeLabel).height, greaterThan(48));
    expect(
      tester.getRect(startField).bottom,
      greaterThan(tester.getRect(activeLabel).bottom),
    );
    expect(
      tester.widget<DropdownButtonFormField<String>>(startField).initialValue,
      'hours',
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test(
    'Hive defaults, stored choices and changes survive a box reopen',
    () async {
      expect(const SettingsState().keepScreenOn, true);
      expect(const SettingsState().readingsHighlightEnabled, false);
      SettingsState load() {
        final container = ProviderContainer();
        try {
          return container.read(settingsProvider);
        } finally {
          container.dispose();
        }
      }

      expect(load().keepScreenOn, true);
      expect(load().readingsHighlightEnabled, false);
      var box = Hive.box('settings');
      await box.putAll({
        'keepScreenOn': false,
        'readingsHighlightEnabled': true,
      });
      expect(load().keepScreenOn, false);
      expect(load().readingsHighlightEnabled, true);

      final container = ProviderContainer();
      final notifier = container.read(settingsProvider.notifier);
      await notifier.setKeepScreenOn(true);
      await notifier.setReadingsHighlightEnabled(false);
      container.dispose();
      await box.close();
      box = await Hive.openBox('settings');
      expect(load().keepScreenOn, true);
      expect(load().readingsHighlightEnabled, false);
      expect(box.get('keepScreenOn'), true);
      expect(box.get('readingsHighlightEnabled'), false);
    },
  );
}
