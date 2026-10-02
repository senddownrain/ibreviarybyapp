import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/screens/reader_consistency_lab_screen.dart';
import 'package:mybrev_flutter/theme/reader.dart';

Future<void> pumpLab(
  WidgetTester tester, {
  required double width,
  required double aa,
  required double system,
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = Size(width, 840);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 840),
          textScaler: TextScaler.linear(system),
        ),
        child: ReaderTypographyScope(
          useSystemFonts: true,
          child: ReaderConsistencyLabScreen(readerScale: aa),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> selectChip(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('six mock domains retain their distinct content', (tester) async {
    await pumpLab(tester, width: 390, aa: 1, system: 1);
    await selectChip(tester, 'lab-aa-180');
    expect(
      tester.widget<ChoiceChip>(find.byKey(const Key('lab-aa-180'))).selected,
      isTrue,
    );
    for (final scenario in ReaderLabScenario.values) {
      await selectChip(tester, 'lab-scenario-${scenario.name}');
      expect(find.byKey(const Key('lab-title')), findsOneWidget);
      expect(find.byKey(const Key('lab-first-section')), findsOneWidget);
      expect(find.byKey(const Key('lab-end')), findsOneWidget);
      expect(tester.takeException(), isNull, reason: scenario.name);
    }
  });

  testWidgets('normalized page narrows while retaining source and end', (
    tester,
  ) async {
    await pumpLab(tester, width: 700, aa: 1, system: 1);
    await selectChip(tester, 'lab-scenario-compendium');
    final currentWidth = tester
        .getSize(find.byKey(const Key('lab-page')))
        .width;
    await selectChip(tester, 'lab-version-normalized');
    final normalizedWidth = tester
        .getSize(find.byKey(const Key('lab-page')))
        .width;
    expect(currentWidth, 700);
    expect(normalizedWidth, 660);
    expect(find.byKey(const Key('lab-source')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('lab-end')));
    final pageBottom = tester
        .getBottomRight(find.byKey(const Key('lab-page')))
        .dy;
    final endBottom = tester
        .getBottomRight(find.byKey(const Key('lab-end')))
        .dy;
    expect(pageBottom - endBottom, 32);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'width, Aa, system scale and themes have no layout exception',
    (tester) async {
      for (final width in [320.0, 360.0, 390.0, 700.0]) {
        for (final aa in [0.7, 1.0, 1.8]) {
          for (final system in [1.0, 1.5, 2.0]) {
            for (final brightness in [Brightness.light, Brightness.dark]) {
              await pumpLab(
                tester,
                width: width,
                aa: aa,
                system: system,
                brightness: brightness,
              );
              for (final scenario in ReaderLabScenario.values) {
                await selectChip(tester, 'lab-scenario-${scenario.name}');
                await selectChip(tester, 'lab-version-normalized');
                await tester.ensureVisible(find.byKey(const Key('lab-end')));
                expect(
                  tester.takeException(),
                  isNull,
                  reason:
                      '$width ${aa * 100}% ${system * 100}% '
                      '${brightness.name} ${scenario.name}',
                );
                await selectChip(tester, 'lab-version-current');
              }
            }
          }
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
