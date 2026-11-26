import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/main.dart' show buildAppTheme;
import 'package:mybrev_flutter/screens/welcome_screen.dart';
import 'package:mybrev_flutter/theme/app_theme.dart';
import 'package:mybrev_flutter/theme/app_theme_preference.dart';

const _capture = Key('welcome-capture');

Future<void> _pump(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  AppThemePreference preference = AppThemePreference.light,
  double scale = 1,
  Future<void> Function(String)? onStart,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final schemes = AppPalette.schemesFor(preference);
  final scheme = preference == AppThemePreference.dark
      ? schemes.darkTheme
      : schemes.theme;
  final theme = buildAppTheme(scheme, preference: preference);
  await tester.pumpWidget(
    RepaintBoundary(
      key: _capture,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme.copyWith(
          textTheme: theme.textTheme.apply(fontFamily: 'PreviewText'),
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: WelcomeScreen(onStart: onStart ?? (_) async {}),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

FilledButton _button(WidgetTester tester) =>
    tester.widget(find.byKey(const Key('welcome-start')));

void main() {
  // A real face: the square test font would wrap every line far too early.
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final font = rootBundle.load('assets/google_fonts/Literata-Regular.ttf');
    await (FontLoader('PreviewText')..addFont(font)).load();
  });

  for (final section in kWelcomeSections) {
    testWidgets('starts with the chosen section ${section.id}', (tester) async {
      final started = <String>[];
      await _pump(tester, onStart: (id) async => started.add(id));
      expect(_button(tester).onPressed, isNull);
      await tester.tap(find.text(section.title).last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('welcome-start')));
      await tester.pumpAndSettle();
      expect(started, [section.id]);
    });
  }

  testWidgets('a failed save keeps the screen and allows a retry', (
    tester,
  ) async {
    var calls = 0;
    await _pump(
      tester,
      onStart: (_) async {
        calls++;
        throw StateError('disk full');
      },
    );
    await tester.tap(find.byKey(const Key('welcome-option-bible')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('welcome-start')));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.textContaining('Не ўдалося захаваць'), findsOneWidget);
    expect(_button(tester).onPressed, isNotNull);
  });

  for (final size in const [Size(320, 568), Size(390, 844), Size(834, 1194)]) {
    for (final scale in const [1.0, 2.0]) {
      testWidgets('no overflow, button reachable $size x$scale', (
        tester,
      ) async {
        await _pump(tester, size: size, scale: scale);
        await tester.ensureVisible(find.byKey(const Key('welcome-start')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const Key('welcome-start')).hitTestable(),
          findsOneWidget,
        );
      });
    }
  }

  for (final (size, top, bottom) in const [
    (Size(320, 568), 20.0, 0.0),
    (Size(360, 640), 24.0, 0.0),
    (Size(375, 667), 20.0, 0.0),
    (Size(390, 844), 47.0, 34.0),
  ]) {
    testWidgets('at normal text size everything fits $size', (tester) async {
      tester.view.padding = FakeViewPadding(top: top, bottom: bottom);
      await _pump(tester, size: size);
      final scroll = tester.state<ScrollableState>(find.byType(Scrollable));
      expect(scroll.position.maxScrollExtent, 0);
      expect(
        tester.getSize(find.byKey(const Key('welcome-option-bible'))).height,
        greaterThanOrEqualTo(48),
      );
    });
  }
}
