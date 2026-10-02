import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mybrev_flutter/router/router.dart';
import 'package:mybrev_flutter/screens/design_top_chrome_lab_screen.dart';
import 'package:mybrev_flutter/theme/reader.dart';

void main() {
  testWidgets('lab route exists only under its compile-time flag', (
    tester,
  ) async {
    final labRoutes = router.configuration.routes
        .whereType<GoRoute>()
        .where((route) => route.path == topChromeLabRoute)
        .toList();
    expect(labRoutes.length, topChromeLabEnabled ? 1 : 0);
    expect(
      router.routeInformationProvider.value.uri.path,
      isNot(topChromeLabRoute),
    );
  });

  testWidgets('gallery and reader scenarios switch without production data', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app());

    for (final scenario in const [
      TopLabScenario.hoursRoot,
      TopLabScenario.readingsRoot,
      TopLabScenario.prayerbookRoot,
      TopLabScenario.bibleRoot,
      TopLabScenario.oraReader,
      TopLabScenario.prayerReader,
      TopLabScenario.bibleReader,
      TopLabScenario.massReader,
    ]) {
      await _choose(tester, Key('lab-scenario-${scenario.name}'));
      expect(find.byKey(Key('lab-preview-${scenario.name}')), findsOneWidget);
      expect(tester.takeException(), isNull, reason: scenario.name);
    }

    await _choose(tester, const Key('lab-scenario-prayerReader'));
    await _choose(tester, const Key('lab-width-320'));
    await _choose(tester, const Key('lab-scale-200'));
    await _choose(tester, const Key('lab-variant-adaptive'));
    await _choose(tester, const Key('lab-platform-iOS'));
    await _choose(tester, const Key('lab-long-title'));
    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const Key('lab-action-prayerReader-appearance')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('lab-overflow-prayerReader')), findsOneWidget);
    final appearance = find.byKey(
      const Key('lab-action-prayerReader-appearance'),
    );
    await tester.ensureVisible(appearance);
    await tester.tap(appearance);
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const Key('lab-action-feedback'))).data,
      'Выгляд тэксту',
    );
  });

  testWidgets('chrome survives width, scale, platform and variant matrix', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app());
    await _choose(tester, const Key('lab-scenario-bibleReader'));
    await _choose(tester, const Key('lab-long-title'));

    for (final variant in TopLabVariant.values) {
      await _choose(tester, Key('lab-variant-${variant.name}'));
      for (final platform in const ['android', 'iOS']) {
        await _choose(tester, Key('lab-platform-$platform'));
        for (final width in const [320, 360, 390, 700]) {
          await _choose(tester, Key('lab-width-$width'));
          for (final scale in const [100, 150, 200]) {
            await _choose(tester, Key('lab-scale-$scale'));
            expect(
              tester.takeException(),
              isNull,
              reason: '${variant.name} $platform $width $scale%',
            );
            if (variant == TopLabVariant.adaptive &&
                width == 700 &&
                scale == 100) {
              expect(
                find.byKey(const Key('lab-action-bibleReader-language')),
                findsOneWidget,
              );
            }
          }
        }
      }
    }
  });

  testWidgets('700 dp preview scrolls horizontally on a narrow host', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app());
    await _choose(tester, const Key('lab-scenario-hoursRoot'));
    await _choose(tester, const Key('lab-width-700'));
    await tester.ensureVisible(find.byKey(const Key('lab-preview-hoursRoot')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('lab-preview-hoursRoot')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _app() => const ReaderTypographyScope(
  useSystemFonts: true,
  child: MaterialApp(home: TopChromeLabScreen()),
);

Future<void> _choose(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}
