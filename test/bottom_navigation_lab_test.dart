import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mybrev_flutter/router/router.dart'
    show bottomNavigationLabEnabled, bottomNavigationLabRoute, router;
import 'package:mybrev_flutter/screens/design_bottom_navigation_lab_screen.dart';
import 'package:mybrev_flutter/theme/app_theme.dart';
import 'package:mybrev_flutter/theme/ib_colors.dart';

Widget _app({TargetPlatform platform = TargetPlatform.android}) => MaterialApp(
  theme: ThemeData(
    useMaterial3: true,
    platform: platform,
    colorScheme: AppPalette.scheme(Brightness.light),
    extensions: const [IbColors.light],
  ),
  home: const BottomNavigationLabScreen(),
);

Future<void> _settings(
  WidgetTester tester, {
  int? width,
  int? scale,
  bool longLabel = false,
}) async {
  await tester.tap(find.byKey(const Key('lab-settings')));
  await tester.pumpAndSettle();
  if (width != null) {
    await tester.tap(find.byKey(Key('lab-width-$width')));
    await tester.pumpAndSettle();
  }
  if (scale != null) {
    await tester.tap(find.byKey(Key('lab-scale-$scale')));
    await tester.pumpAndSettle();
  }
  if (longLabel) {
    await tester.tap(find.byKey(const Key('lab-long-label')));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.byKey(const Key('lab-settings-done')));
  await tester.pumpAndSettle();
}

Future<void> _variant(WidgetTester tester, LabVariant variant) async {
  final target = find.byKey(Key('lab-variant-${variant.name}'));
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  test('lab route exists only in flag builds', () {
    final labRoutes = router.configuration.routes.whereType<GoRoute>().where(
      (route) => route.path == bottomNavigationLabRoute,
    );
    expect(labRoutes.length, bottomNavigationLabEnabled ? 1 : 0);
  });

  testWidgets('A has previous/current/next and outline selection', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('lab-previous')), findsOneWidget);
    expect(find.byKey(const Key('lab-next')), findsOneWidget);
    expect(find.text('Літургія слова'), findsWidgets);

    await tester.tap(find.byKey(const Key('lab-next')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('lab-current-label')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('lab-current-label'))).data,
      'Эўхарыстычная літургія',
    );

    await tester.tap(find.byKey(const Key('lab-current-selector')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('lab-outline-item-0')), findsOneWidget);
    await tester.tap(find.byKey(const Key('lab-outline-item-0')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const Key('lab-current-label'))).data,
      'Уступныя абрады',
    );
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('lab-previous')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('B is selector-first with steps inside outline', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _variant(tester, LabVariant.selectorFirst);
    expect(find.byKey(const Key('lab-previous')), findsNothing);
    expect(find.byKey(const Key('lab-next')), findsNothing);
    await tester.tap(find.byKey(const Key('lab-current-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('lab-outline-next')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const Key('lab-current-label'))).data,
      'Эўхарыстычная літургія',
    );
  });

  testWidgets('C changes to two rows when label does not fit', (tester) async {
    tester.view.physicalSize = const Size(700, 840);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _variant(tester, LabVariant.adaptive);
    final singleRowY = tester
        .getTopLeft(find.byKey(const Key('lab-current-selector')))
        .dy;
    expect(
      tester.getTopLeft(find.byKey(const Key('lab-next'))).dy,
      closeTo(singleRowY, 8),
    );

    await _settings(tester, width: 320, scale: 200, longLabel: true);
    final selectorBottom = tester
        .getBottomLeft(find.byKey(const Key('lab-current-selector')))
        .dy;
    final arrowTop = tester.getTopLeft(find.byKey(const Key('lab-next'))).dy;
    expect(arrowTop, greaterThanOrEqualTo(selectorBottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('width/scale matrix and long labels have no overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(700, 880);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _settings(tester, longLabel: true);
    for (final variant in LabVariant.values) {
      await _variant(tester, variant);
      for (final width in [320, 360, 390, 700]) {
        for (final scale in [100, 150, 200]) {
          await _settings(tester, width: width, scale: scale);
          expect(
            tester.takeException(),
            isNull,
            reason: '${variant.name}, $width px, $scale%',
          );
          expect(
            tester.getSize(find.byKey(const Key('lab-preview-frame'))).width,
            width,
          );
        }
      }
    }
  });

  testWidgets('targets are at least 48 and content clears measured bar', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    for (final key in ['lab-previous', 'lab-current-selector', 'lab-next']) {
      final size = tester.getSize(find.byKey(Key(key)));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
    expect(
      tester.getSize(find.byKey(const Key('lab-content-reserve'))).height,
      greaterThan(0),
    );
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -5000));
    await tester.pumpAndSettle();
    final lastBottom = tester
        .getBottomLeft(find.byKey(const Key('lab-last-paragraph')))
        .dy;
    final barTop = tester
        .getTopLeft(find.byKey(const Key('lab-reader-bar')))
        .dy;
    expect(lastBottom, lessThan(barTop));
  });

  testWidgets('physical 320 px viewport and all scenarios stay interactive', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _settings(tester, width: 320, scale: 200, longLabel: true);
    for (final scenario in LabScenario.values) {
      final target = find.byKey(Key('lab-scenario-${scenario.name}'));
      await tester.ensureVisible(target);
      await tester.tap(target);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: scenario.name);
      await tester.tap(find.byKey(const Key('lab-current-selector')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('lab-outline-item-0')), findsOneWidget);
      await tester.tap(find.byKey(const Key('lab-outline-item-0')));
      await tester.pumpAndSettle();
    }
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('lab uses semantic neutral chrome on ${platform.name}', (
      tester,
    ) async {
      await tester.pumpWidget(_app(platform: platform));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('lab-reader-bar')), findsOneWidget);
      expect(
        find.byKey(
          Key(
            platform == TargetPlatform.iOS
                ? 'adaptive-chrome-glass'
                : 'adaptive-chrome-ambient',
          ),
        ),
        findsWidgets,
      );
      final scaffold = tester.widget<Scaffold>(
        find.byKey(const Key('bottom-navigation-lab')),
      );
      expect(scaffold.backgroundColor, IbColors.light.page);
    });
  }
}
