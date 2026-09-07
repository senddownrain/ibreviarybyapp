import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/widgets/text_scale_control.dart';

void main() {
  testWidgets('opens the slider panel and respects reader-size limits', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [settingsProvider.overrideWith(_TestSettingsNotifier.new)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topRight,
              child: TextScaleControl(),
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('text-scale-open')), findsOneWidget);
    expect(find.byKey(const Key('text-scale-slider')), findsNothing);

    await tester.tap(find.byKey(const Key('text-scale-open')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('text-scale-slider')), findsOneWidget);
    expect(find.byKey(const Key('text-scale-value')), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);

    await tester.tap(find.byKey(const Key('text-scale-increase')));
    await tester.pump();
    expect(find.text('110%'), findsOneWidget);
    expect(
      container.read(settingsProvider).fontSize,
      closeTo(kDefaultReaderFontSize * 1.1, 0.001),
    );

    container.read(settingsProvider.notifier).setFontSize(kMaxReaderFontSize);
    await tester.pump();
    final increaseButton = tester.widget<IconButton>(
      find.descendant(
        of: find.byKey(const Key('text-scale-increase')),
        matching: find.byType(IconButton),
      ),
    );
    expect(increaseButton.onPressed, isNull);

    container.read(settingsProvider.notifier).setFontSize(kMinReaderFontSize);
    await tester.pump();
    final decreaseButton = tester.widget<IconButton>(
      find.descendant(
        of: find.byKey(const Key('text-scale-decrease')),
        matching: find.byType(IconButton),
      ),
    );
    expect(decreaseButton.onPressed, isNull);
  });
}

class _TestSettingsNotifier extends SettingsNotifier {
  @override
  SettingsState build() => const SettingsState();

  @override
  void setFontSize(double size) {
    state = state.copyWith(fontSize: normalizeReaderFontSize(size));
  }

  @override
  void increaseFontSize() => _step(1);

  @override
  void decreaseFontSize() => _step(-1);

  void _step(int direction) {
    final scale = state.fontSize / kDefaultReaderFontSize;
    final nextScale =
        ((scale / kReaderFontScaleStep).round() + direction) *
        kReaderFontScaleStep;
    setFontSize(kDefaultReaderFontSize * nextScale);
  }
}
