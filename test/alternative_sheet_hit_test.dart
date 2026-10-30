import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/widgets/alternative_text.dart';

/// Real touches rarely land on a tile's centre and always jitter a little:
/// every option of the choice sheet must take a tap anywhere on its row, also
/// when the finger drifts a few points (the sheet is a drag target itself).
void main() {
  const titles = [
    'Святы Іаан Хрызастом: З гамілій на Евангелле паводле Мацвея',
    'Святы Аўгустын: Казанне на ўспамін святых',
    'Пій XII: З пасланні Mediator Dei',
  ];
  final html = [
    for (var i = 0; i < titles.length; i++)
      '<div data-alternative-title="${titles[i]}">Тэкст ${i + 1}</div>',
  ].join();

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (var option = 0; option < titles.length; option++) {
      for (final spot in const <(String, Offset)>[
        ('centre', Offset(0, 0)),
        ('left edge', Offset(-150, 0)),
        ('right edge', Offset(150, 0)),
        ('upper part', Offset(0, -20)),
        ('lower part', Offset(0, 20)),
      ]) {
        for (final jitter in const [0.0, 6.0]) {
          testWidgets(
            '${platform.name}: option ${option + 1} takes a tap at ${spot.$1}'
            '${jitter == 0 ? '' : ' with finger drift'}',
            (tester) async {
              tester.view.physicalSize = const Size(1179, 2556);
              tester.view.devicePixelRatio = 3;
              addTearDown(tester.view.resetPhysicalSize);
              addTearDown(tester.view.resetDevicePixelRatio);
              final controller = ValueNotifier<int>(0);
              await tester.pumpWidget(
                MaterialApp(
                  theme: ThemeData(platform: platform),
                  home: Scaffold(
                    body: AlternativeText(
                      text: html,
                      label: 'Выбар чытання',
                      controller: controller,
                      contentBuilder: (_, value) => Text(value),
                    ),
                  ),
                ),
              );
              await tester.tap(
                find.byKey(const Key('alternative-picker-trigger')),
              );
              await tester.pumpAndSettle();
              final tile = find.byKey(ValueKey('alternative-option-$option'));
              final point = tester.getCenter(tile) + spot.$2;
              expect(tester.getRect(tile).contains(point), isTrue);
              final gesture = await tester.startGesture(point);
              if (jitter > 0) {
                await gesture.moveBy(Offset(0, jitter));
                await gesture.moveBy(Offset(0, -jitter));
              }
              await gesture.up();
              await tester.pumpAndSettle();
              expect(controller.value, option);
              expect(
                find.byKey(ValueKey('alternative-option-$option')),
                findsNothing,
              );
            },
          );
        }
      }
    }
  }
}
