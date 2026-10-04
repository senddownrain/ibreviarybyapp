import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/theme/platform_design.dart';
import 'package:mybrev_flutter/widgets/adaptive_segmented_control.dart';
import 'package:mybrev_flutter/widgets/ambient_date_picker.dart';
import 'package:mybrev_flutter/widgets/floating_top_actions.dart';

void main() {
  testWidgets('chrome uses Liquid Glass only on Apple platforms', (
    tester,
  ) async {
    Future<void> pump(TargetPlatform platform) => tester.pumpWidget(
      MaterialApp(
        key: ValueKey(platform),
        theme: ThemeData(platform: platform),
        home: const Scaffold(
          body: AdaptiveChromeSurface(child: SizedBox.square(dimension: 48)),
        ),
      ),
    );

    await pump(TargetPlatform.iOS);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('adaptive-chrome-glass')), findsOneWidget);
    expect(find.byKey(const Key('adaptive-chrome-ambient')), findsNothing);

    await pump(TargetPlatform.android);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('adaptive-chrome-ambient')), findsOneWidget);
    expect(find.byKey(const Key('adaptive-chrome-glass')), findsNothing);
  });

  testWidgets('date picker is Cupertino on iOS and Material on Android', (
    tester,
  ) async {
    Widget app(TargetPlatform platform) => MaterialApp(
      key: ValueKey(platform),
      theme: ThemeData(platform: platform),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showAmbientDatePicker(
              context: context,
              initialDate: DateTime(2026, 9, 7),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.pumpWidget(app(TargetPlatform.iOS));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoDatePicker), findsOneWidget);
    expect(find.byType(CalendarDatePicker), findsNothing);

    await tester.tap(find.text('Скасаваць'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(app(TargetPlatform.android));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(CalendarDatePicker), findsOneWidget);
    expect(find.byType(CupertinoDatePicker), findsNothing);
  });

  testWidgets('segmented choices follow the target platform', (tester) async {
    Widget app(TargetPlatform platform) => MaterialApp(
      key: ValueKey(platform),
      theme: ThemeData(platform: platform),
      home: Scaffold(
        body: AdaptiveSegmentedControl<bool>(
          value: false,
          segments: const [
            AdaptiveSegment(value: false, label: Text('First')),
            AdaptiveSegment(value: true, label: Text('Second')),
          ],
          onChanged: (_) {},
        ),
      ),
    );

    await tester.pumpWidget(app(TargetPlatform.iOS));
    expect(find.byType(CupertinoSlidingSegmentedControl<bool>), findsOneWidget);
    expect(find.byType(SegmentedButton<bool>), findsNothing);

    await tester.pumpWidget(app(TargetPlatform.android));
    expect(find.byType(SegmentedButton<bool>), findsOneWidget);
    expect(find.byType(CupertinoSlidingSegmentedControl<bool>), findsNothing);
  });

  testWidgets('segmented labels stay on one line on narrow Android screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 800),
            textScaler: TextScaler.linear(1.3),
          ),
          child: Scaffold(
            body: SizedBox(
              width: 320,
              child: AdaptiveSegmentedControl<int>(
                value: 1,
                showSelectedIcon: false,
                segments: const [
                  AdaptiveSegment(
                    value: 0,
                    icon: Icon(Icons.settings),
                    label: Text('Сістэма'),
                  ),
                  AdaptiveSegment(
                    value: 1,
                    icon: Icon(Icons.light_mode),
                    label: Text('Светлая'),
                  ),
                  AdaptiveSegment(
                    value: 2,
                    icon: Icon(Icons.dark_mode),
                    label: Text('Цёмная'),
                  ),
                ],
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(Icon), findsNothing);
    for (final label in ['Сістэма', 'Светлая', 'Цёмная']) {
      final paragraph = find.descendant(
        of: find.text(label),
        matching: find.byType(RichText),
      );
      expect(tester.getSize(paragraph).height, lessThan(30));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('floating back icon follows the target platform', (tester) async {
    Widget app(TargetPlatform platform) => ProviderScope(
      child: MaterialApp(
        key: ValueKey(platform),
        theme: ThemeData(platform: platform),
        home: const Scaffold(
          body: FloatingTopActions(showBack: true, seasonColor: Colors.indigo),
        ),
      ),
    );

    await tester.pumpWidget(app(TargetPlatform.android));
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_ios_new), findsNothing);

    await tester.pumpWidget(app(TargetPlatform.iOS));
    expect(find.byIcon(Icons.arrow_back_ios_new), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
  });

  testWidgets('a single floating top action stays perfectly round', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: FloatingTopActions(
              seasonColor: Colors.indigo,
              actions: [IconButton(onPressed: null, icon: Icon(Icons.search))],
            ),
          ),
        ),
      ),
    );

    final size = tester.getSize(
      find.byKey(const Key('floating-top-actions-surface')),
    );
    expect(size.width, size.height);
    expect(size.width, closeTo(49.6, 0.01));
  });
}
