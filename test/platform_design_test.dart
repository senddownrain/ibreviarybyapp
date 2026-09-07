import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/theme/platform_design.dart';
import 'package:mybrev_flutter/widgets/adaptive_segmented_control.dart';
import 'package:mybrev_flutter/widgets/ambient_date_picker.dart';

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
}
