import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/theme/reader.dart';
import 'package:mybrev_flutter/widgets/text_scale_control.dart';
import 'package:mybrev_flutter/widgets/psalmody_mode_selector.dart';

void main() {
  test('reader font preferences are compact and legacy-safe', () {
    expect(kAvailableReaderFonts, hasLength(5));
    expect(normalizeReaderFontFamily('Сістэмны'), ReaderFontFamily.literata);
    expect(
      normalizeReaderFontFamily(ReaderFontFamily.system),
      ReaderFontFamily.system,
    );
    expect(kAvailableReaderFonts.map((option) => option.label).toList(), [
      'Literata',
      'Source Serif 4',
      'Old Standard TT',
      'Kurale',
      'Сістэмны',
    ]);
    expect(
      normalizeReaderFontFamily('Old Standard TT'),
      ReaderFontFamily.oldStandardTt,
    );
    expect(normalizeReaderFontFamily('Kurale'), ReaderFontFamily.kurale);
  });

  test('all five reader font choices work offline', () async {
    for (final asset in [
      'assets/google_fonts/Literata-Regular.ttf',
      'assets/google_fonts/SourceSerif4-Regular.ttf',
      'assets/google_fonts/OldStandardTT-Regular.ttf',
      'assets/google_fonts/OldStandardTT-Italic.ttf',
      'assets/google_fonts/OldStandardTT-Bold.ttf',
      'assets/google_fonts/Kurale-Regular.ttf',
    ]) {
      final fontData = await rootBundle.load(asset);
      expect(fontData.lengthInBytes, greaterThan(100000), reason: asset);
    }
  });

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
    expect(find.byKey(const Key('reader-font-literata')), findsNothing);
    expect(find.byType(PsalmodyModeSelector), findsNothing);
    expect(find.byType(FilterChip), findsNothing);

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

  testWidgets('appearance panel fits 320 px at 200 percent system text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [settingsProvider.overrideWith(_TestSettingsNotifier.new)],
    );
    addTearDown(container.dispose);

    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            key: ValueKey(platform),
            theme: ThemeData(platform: platform),
            home: const MediaQuery(
              data: MediaQueryData(
                size: Size(320, 640),
                textScaler: TextScaler.linear(2),
              ),
              child: Scaffold(body: TextScaleControl()),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('text-scale-open')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('reader-font-literata')), findsNothing);
      expect(tester.takeException(), isNull, reason: platform.name);
      await tester.tap(find.byTooltip('Закрыць'));
      await tester.pumpAndSettle();
    }
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

  @override
  void setFontFamily(String family) {
    state = state.copyWith(fontFamily: normalizeReaderFontFamily(family));
  }

  void _step(int direction) {
    final scale = state.fontSize / kDefaultReaderFontSize;
    final nextScale =
        ((scale / kReaderFontScaleStep).round() + direction) *
        kReaderFontScaleStep;
    setFontSize(kDefaultReaderFontSize * nextScale);
  }
}
