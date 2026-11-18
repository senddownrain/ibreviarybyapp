import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mybrev_flutter/constants/legal_links.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mybrev_flutter/models/source_documents.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/router/router.dart' as production;
import 'package:mybrev_flutter/screens/source_documents_screen.dart';
import 'package:mybrev_flutter/theme/app_theme.dart';
import 'package:mybrev_flutter/theme/reader.dart';
import 'package:mybrev_flutter/widgets/source_footer.dart';
import 'package:package_info_plus/package_info_plus.dart';

class _Settings extends SettingsNotifier {
  @override
  SettingsState build() => const SettingsState();
}

String _path(GoRouter router) {
  final config = router.routerDelegate.currentConfiguration;
  final last = config.last;
  return last is ImperativeRouteMatch ? last.matches.uri.path : config.uri.path;
}

GoRouter _router(String initialLocation) => GoRouter(
  navigatorKey: production.rootNavigatorKey,
  initialLocation: initialLocation,
  routes: production.router.configuration.routes
      .whereType<GoRoute>()
      .where((r) => ['/about', sourcesRoute].contains(r.path))
      .toList(),
);

Widget _app(
  GoRouter router, {
  TargetPlatform platform = TargetPlatform.android,
  Brightness brightness = Brightness.light,
  double scale = 1,
  Future<bool> Function(Uri, LaunchMode)? launcher,
}) => ProviderScope(
  overrides: [
    settingsProvider.overrideWith(_Settings.new),
    if (launcher != null)
      sourceDocumentLauncherProvider.overrideWithValue(launcher),
  ],
  child: ReaderTypographyScope(
    useSystemFonts: true,
    child: MaterialApp.router(
      routerConfig: router,
      theme: ThemeData(
        platform: platform,
        colorScheme: AppPalette.scheme(brightness),
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          padding: const EdgeInsets.only(bottom: 24),
          viewPadding: const EdgeInsets.only(bottom: 24),
        ),
        child: child!,
      ),
    ),
  ),
);

Future<void> _load(WidgetTester tester) async {
  // Local assets are asynchronous even with no HTTP client/network available.
  await tester.pump();
  for (var i = 0; i < 40; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
  }
  expect(find.byType(CircularProgressIndicator), findsNothing);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await SourceRegistry.load();
    PackageInfo.setMockInitialValues(
      appName: 'MyBrev',
      packageName: 'by.test',
      version: '1.0.0',
      buildNumber: '6',
      buildSignature: '',
    );
  });
  setUp(rootBundle.clear);

  testWidgets('reader footers use verified registry rights and digital URLs', (
    tester,
  ) async {
    final opened = <Uri>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(_Settings.new),
          sourceLinkLauncherProvider.overrideWithValue((uri) async {
            opened.add(uri);
            return true;
          }),
        ],
        child: const ReaderTypographyScope(
          useSystemFonts: true,
          child: MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  SourceFooter(
                    key: Key('hours'),
                    sourceId: 'liturgy-hours-2012-2020',
                  ),
                  SourceFooter(
                    key: Key('readings'),
                    sourceId: 'lectionary-kkbb-2002-2005',
                  ),
                  SourceFooter(
                    key: Key('compendium'),
                    sourceId: 'compendium-kkbb-2010',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await _load(tester);
    String text(String key) => tester
        .widget<Text>(
          find.descendant(
            of: find.byKey(Key(key)),
            matching: find.byType(Text),
          ),
        )
        .textSpan!
        .toPlainText();
    expect(
      text('hours'),
      'Крыніца: lh.catholic.by. © Канферэнцыя Каталіцкіх Біскупаў Беларусі',
    );
    expect(
      text('readings'),
      contains('© Канферэнцыя Каталіцкіх Біскупаў Беларусі, 2002-2005'),
    );
    expect(
      text('compendium'),
      contains('© Канферэнцыя Каталіцкіх Біскупаў Беларусі, 2010'),
    );
    expect(text('compendium'), isNot(contains('Libreria')));
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('hours')),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pumpAndSettle();
    expect(opened.single.toString(), 'https://lh.catholic.by/');
  });

  testWidgets(
    'About → Sources; all documents launch externally without changing the stack',
    (tester) async {
      final router = _router('/about');
      addTearDown(router.dispose);
      final opened = <(Uri, LaunchMode)>[];
      await tester.pumpWidget(
        _app(
          router,
          launcher: (uri, mode) async {
            opened.add((uri, mode));
            return true;
          },
        ),
      );
      await _load(tester);
      final link = find.byKey(const Key('about-sources-link'));
      await tester.ensureVisible(link);
      await tester.tap(link);
      await _load(tester);
      expect(_path(router), sourcesRoute);
      expect(find.text('Касцёльныя крыніцы'), findsOneWidget);
      expect(find.text('Іншыя крыніцы'), findsOneWidget);
      expect(find.text('Малітоўнік «Бог Добры» (Пінск, 2022)'), findsOneWidget);
      expect(
        find.text('Малітоўнік «Каб пазналі Цябе» (Гродна, 2014)'),
        findsOneWidget,
      );
      expect(find.text('«Біблія» (Мінск, 2017)'), findsOneWidget);
      expect(find.text('© Выдавецтва Пінскай дыяцэзіі, 2022'), findsOneWidget);
      expect(find.text('Малітоўнік «Бог Добры» (Пінск, 2018)'), findsNothing);
      expect(
        find.text('«Библия» (Синодальный перевод, на русском языке)'),
        findsOneWidget,
      );
      expect(
        find.text('Стары Запавет - на падставе рукапісаў кс. У. Чарняўскага'),
        findsOneWidget,
      );
      expect(
        find.text('© «Біблійнае таварыства ў Рэспубліцы Беларусь», 2017'),
        findsOneWidget,
      );
      expect(
        find.text('«Рымскі Імшал для дыяцэзій на Беларусі» (Мінск, 2004)'),
        findsOneWidget,
      );
      expect(
        find.text('Спеўнік «Божа, мы Цябе ўслаўляем» (Мінск, 2026)'),
        findsOneWidget,
      );
      expect(
        find.text('© Камісія Божага Культу і Дысцыпліны Сакрамэнтаў, 2022'),
        findsOneWidget,
      );
      expect(find.textContaining('Libreria'), findsNothing);
      for (final document in kSourceDocumentLinks) {
        final button = find.widgetWithText(TextButton, document.label);
        expect(button, findsOneWidget);
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(_path(router), sourcesRoute);
      }
      expect(opened, [
        for (final d in kSourceDocumentLinks)
          (Uri.parse(d.url), LaunchMode.externalApplication),
      ]);
      await tester.binding.handlePopRoute();
      await _load(tester);
      expect(_path(router), '/about');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('direct Sources has a safe Back destination', (tester) async {
    final router = _router(sourcesRoute);
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(router));
    await _load(tester);
    await tester.tap(find.byTooltip('Закрыць'));
    await _load(tester);
    expect(_path(router), '/about');
  });

  for (final throws in [false, true]) {
    testWidgets(
      'external launch ${throws ? 'exception' : 'false'} shows a Belarusian error without fallback',
      (tester) async {
        final router = _router(sourcesRoute);
        addTearDown(router.dispose);
        await tester.pumpWidget(
          _app(
            router,
            launcher: (uri, mode) async {
              if (throws) throw StateError('browser unavailable');
              return false;
            },
          ),
        );
        await _load(tester);
        final button = find.widgetWithText(
          TextButton,
          kSourceDocumentLinks[1].label,
        );
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          find.text('Не ўдалося адкрыць старонку. Праверце інтэрнэт-злучэнне'),
          findsOneWidget,
        );
        expect(_path(router), sourcesRoute);
        expect(find.text('Арыгінал PDF'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  test('document paths have no native Flutter routes', () {
    final routes = production.router.configuration.routes.whereType<GoRoute>();
    for (final doc in kSourceDocumentLinks) {
      expect(routes.where((r) => r.path == Uri.parse(doc.url).path), isEmpty);
    }
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final brightness in Brightness.values) {
      for (final size in [(320.0, 2.0), (390.0, 1.0)]) {
        testWidgets(
          'local rights fit $platform $brightness ${size.$1} ${size.$2}',
          (tester) async {
            tester.view.physicalSize = Size(size.$1, 844);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final router = _router(sourcesRoute);
            addTearDown(router.dispose);
            await tester.pumpWidget(
              _app(
                router,
                platform: platform,
                brightness: brightness,
                scale: size.$2,
              ),
            );
            await _load(tester);
            expect(find.textContaining('Libreria'), findsNothing);
            expect(
              find.text('© Мінска-Магілёўская архідыяцэзія, 2010'),
              findsOneWidget,
            );
            for (final doc in kSourceDocumentLinks) {
              await tester.ensureVisible(
                find.widgetWithText(TextButton, doc.label),
              );
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
            }
          },
        );
      }
    }
  }
}
