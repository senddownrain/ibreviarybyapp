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
    await tester.tap(find.text('Другі'));
    await tester.pumpAndSettle();

    expect(controller.value, 1);
    expect(find.textContaining('Антыфона 2'), findsNWidgets(2));
  });
}
