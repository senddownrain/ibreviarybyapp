import 'package:flutter/material.dart';
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
      .where(
        (r) => [
          '/about',
          sourcesRoute,
          hoursDecreesRoute,
          properCalendarRoute,
        ].contains(r.path),
      )
      .toList(),
);

Widget _app(
  GoRouter router, {
  TargetPlatform platform = TargetPlatform.android,
  Brightness brightness = Brightness.light,
  double scale = 1,
}) => ProviderScope(
  overrides: [settingsProvider.overrideWith(_Settings.new)],
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
    expect(text('hours'), 'Крыніца: lh.catholic.by');
    expect(text('hours'), isNot(contains('©')));
    expect(
      text('readings'),
      contains('© Канферэнцыя Каталіцкіх Біскупаў Беларусі, 2002-2005'),
    );
    expect(text('compendium'), contains('© Libreria Editrice Vaticana, 2005'));
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('hours')),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pumpAndSettle();
    expect(opened.single.toString(), 'https://lh.catholic.by/');
  });

  testWidgets('About → Sources → both documents; jumps do not add Back steps', (
    tester,
  ) async {
    final router = _router('/about');
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(router));
    await _load(tester);
    final link = find.byKey(const Key('about-sources-link'));
    await tester.ensureVisible(link);
    await tester.tap(link);
    await _load(tester);
    expect(_path(router), sourcesRoute);
    expect(find.text('Дэкрэты Літургіі гадзінаў'), findsOneWidget);
    expect(find.textContaining('pending'), findsNothing);
    expect(find.textContaining('пераклад ККББ'), findsNothing);

    final decreeLink = find.text('Дэкрэты Літургіі гадзінаў');
    await tester.ensureVisible(decreeLink);
    await tester.tap(decreeLink);
    await _load(tester);
    expect(_path(router), hoursDecreesRoute);
    for (final roman in ['I', 'II', 'III', 'IV']) {
      final jump = find.widgetWithText(TextButton, 'Том $roman');
      await tester.ensureVisible(jump);
      await tester.tap(jump);
      await tester.pumpAndSettle();
    }
    await tester.binding.handlePopRoute();
    await _load(tester);
    expect(_path(router), sourcesRoute);
    final calendarLink = find.widgetWithText(
      TextButton,
      'Уласны каляндар дыяцэзій на Беларусі',
    );
    await tester.ensureVisible(calendarLink);
    await tester.tap(calendarLink);
    await _load(tester);
    expect(_path(router), properCalendarRoute);
    expect(find.byKey(const Key('calendar-intro')), findsOneWidget);
    expect(find.byType(CalendarDocumentLine), findsNWidgets(477));
    for (final month in [1, 7, 11, 12]) {
      final jump = find.byKey(ValueKey('calendar-jump-$month'));
      await tester.ensureVisible(jump);
      await tester.tap(jump);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await tester.binding.handlePopRoute();
    await _load(tester);
    expect(_path(router), sourcesRoute);
    await tester.tap(find.byTooltip('Закрыць'));
    await _load(tester);
    expect(_path(router), '/about');
    expect(tester.takeException(), isNull);
  });

  for (final path in [hoursDecreesRoute, properCalendarRoute, sourcesRoute]) {
    testWidgets('direct $path has a safe Back destination', (tester) async {
      final router = _router(path);
      addTearDown(router.dispose);
      await tester.pumpWidget(_app(router));
      await _load(tester);
      await tester.binding.handlePopRoute();
      await _load(tester);
      expect(_path(router), path == sourcesRoute ? '/about' : sourcesRoute);
    });
  }

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final brightness in Brightness.values) {
      for (final size in [(320.0, 2.0), (390.0, 1.0)]) {
        testWidgets(
          'offline articles fit $platform $brightness ${size.$1} ${size.$2}',
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
            expect(tester.takeException(), isNull);
            for (final route in [hoursDecreesRoute, properCalendarRoute]) {
              router.go(route);
              await _load(tester);
              expect(tester.takeException(), isNull);
              final scrollable = find.byType(Scrollable).first;
              await tester.drag(scrollable, const Offset(0, -1500));
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
            }
            final runs = tester.widgetList<DocumentRuns>(
              find.byType(DocumentRuns),
            );
            expect(runs.expand((r) => r.runs).any((r) => r.small), isTrue);
            expect(runs.expand((r) => r.runs).any((r) => r.italic), isTrue);
            expect(
              runs.expand((r) => r.runs).any((r) => r.tone == 'red'),
              isTrue,
            );
          },
        );
      }
    }
  }
}
