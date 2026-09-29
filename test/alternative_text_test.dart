import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/widgets/alternative_text.dart';

void main() {
  testWidgets('shared controller synchronizes repeated antiphons', (
    tester,
  ) async {
    final controller = ValueNotifier<int>(0);
    const html =
        '<div data-alternative-title="Першы">Антыфона 1</div>'
        '<div data-alternative-title="Другі">Антыфона 2</div>';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                AlternativeText(
                  text: html,
                  label: 'Выбар антыфоны',
                  controller: controller,
                  contentBuilder: (_, value) => Text(value),
                ),
                AlternativeText(
                  text: html,
                  controller: controller,
                  showPicker: false,
                  contentBuilder: (_, value) => Text(value),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('Антыфона 1'), findsNWidgets(2));
    expect(find.text('Варыянт · 1 з 2'), findsOneWidget);
    expect(find.text('Другі'), findsNothing);
    final trigger = find.byKey(const Key('alternative-picker-trigger'));
    await tester.ensureVisible(trigger);
    await tester.tap(trigger);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Другі'));
    await tester.pumpAndSettle();

    expect(controller.value, 1);
    expect(find.textContaining('Антыфона 2'), findsNWidgets(2));
  });

  testWidgets('seven long alternatives fit a narrow 200 percent sheet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final html = List.generate(
      7,
      (index) =>
          '<div data-alternative-title="Вельмі доўгая беларуская назва ${index + 1}">Тэкст ${index + 1}</div>',
    ).join();

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: MaterialApp(
          home: Scaffold(
            body: AlternativeText(
              text: html,
              contentBuilder: (_, value) => Text(value),
            ),
          ),
        ),
      ),
    );
    final narrowTrigger = find.byKey(const Key('alternative-picker-trigger'));
    tester.widget<TextButton>(narrowTrigger).onPressed!();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('alternative-option-0')), findsOneWidget);
  });
}
