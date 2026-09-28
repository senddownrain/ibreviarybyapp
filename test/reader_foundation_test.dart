import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/widgets/reader/reader_scaffold.dart';

void main() {
  testWidgets('shell controller drives full compact and hidden chrome', (
    tester,
  ) async {
    final controller = ReaderChromeModeController(ReaderChromeMode.compact);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: ReaderChromeModeScope(
          controller: controller,
          child: const ReaderScaffold(content: Text('Long-form content')),
        ),
      ),
    );

    expect(find.byKey(const Key('reader-chrome-back')), findsOneWidget);
    expect(find.byKey(const Key('reader-top-fade')), findsOneWidget);
    expect(find.byKey(const Key('reader-bottom-fade')), findsOneWidget);
    expect(
      tester
          .widget<IgnorePointer>(
            find.byKey(const Key('reader-edge-protection')),
          )
          .ignoring,
      isTrue,
    );
    expect(find.byKey(const Key('reader-chrome-restore')), findsNothing);

    controller.value = ReaderChromeMode.hidden;
    await tester.pump();
    expect(find.byKey(const Key('reader-top-fade')), findsOneWidget);
    expect(find.byKey(const Key('reader-chrome-back')), findsNothing);
    expect(find.byKey(const Key('reader-chrome-hidden')), findsOneWidget);
    expect(find.byKey(const Key('reader-chrome-restore')), findsNothing);

    await tester.tap(find.byKey(const Key('reader-double-tap-surface')));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(find.byKey(const Key('reader-double-tap-surface')));
    await tester.pump();
    expect(controller.value, ReaderChromeMode.compact);
    expect(find.byKey(const Key('reader-chrome-back')), findsOneWidget);

    await tester.tap(find.byKey(const Key('reader-double-tap-surface')));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(find.byKey(const Key('reader-double-tap-surface')));
    await tester.pump();
    expect(controller.value, ReaderChromeMode.hidden);

    controller.value = ReaderChromeMode.full;
    await tester.pump();
    expect(find.byKey(const Key('reader-chrome-back')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('reader document uses opaque neutral light and dark surfaces', (
    tester,
  ) async {
    Future<Color> surfaceFor(Brightness brightness) async {
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey(brightness),
          theme: ThemeData(brightness: brightness),
          home: const ReaderContentSurface(child: Text('Document')),
        ),
      );
      return tester
          .widget<ColoredBox>(find.byKey(const Key('reader-content-surface')))
          .color;
    }

    expect(await surfaceFor(Brightness.light), const Color(0xFFFCFBF8));
    expect(await surfaceFor(Brightness.dark), const Color(0xFF171A18));
  });

  testWidgets('reader reserves space for floating bottom navigation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          extendBody: true,
          body: const ReaderScaffold(content: Text('Document end')),
          bottomNavigationBar: const SizedBox(height: 94),
        ),
      ),
    );

    final contentPadding = tester.widget<Padding>(
      find
          .descendant(
            of: find.byKey(const Key('reader-content-surface')),
            matching: find.byType(Padding),
          )
          .first,
    );
    expect(contentPadding.padding, const EdgeInsets.fromLTRB(22, 25, 22, 136));
  });

  testWidgets('reader reserves the safe area above floating chrome', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(padding: EdgeInsets.only(top: 24)),
          child: ReaderScaffold(content: Text('Document')),
        ),
      ),
    );

    final inset = tester.widget<SizedBox>(
      find.byKey(const Key('reader-top-inset')),
    );
    expect(inset.height, 100);
  });

  testWidgets('scroll position survives a pushed route and back navigation', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: ReaderScaffold(
          scrollController: scrollController,
          content: const SizedBox(height: 1800, child: Text('Long document')),
        ),
      ),
    );
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();
    final before = scrollController.offset;
    expect(before, greaterThan(0));

    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Next')),
      ),
    );
    await tester.pumpAndSettle();
    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();

    expect(scrollController.offset, closeTo(before, 0.1));
  });

  testWidgets('context actions stay outside the document surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ReaderScaffold(
          contextHeader: ReaderContextHeader(
            title: 'Ютрань',
            subtitle: 'Святкаванне дня',
            actions: [TextButton(onPressed: null, child: Text('Чытанні'))],
          ),
          content: Text('Божа, прыйдзі мне на дапамогу.'),
        ),
      ),
    );

    final contextFinder = find.byKey(const Key('reader-context-header'));
    final surfaceFinder = find.byKey(const Key('reader-content-surface'));
    expect(contextFinder, findsOneWidget);
    expect(surfaceFinder, findsOneWidget);
    expect(
      find.descendant(of: surfaceFinder, matching: contextFinder),
      findsNothing,
    );
  });

  testWidgets('long reader content has no overflow at 180% on iOS and Android', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        await tester.pumpWidget(
          MaterialApp(
            key: ValueKey((platform, brightness)),
            theme: ThemeData(platform: platform, brightness: brightness),
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 640),
                textScaler: TextScaler.linear(1.8),
                padding: EdgeInsets.only(top: 24),
              ),
              child: ReaderScaffold(
                contextHeader: ReaderContextHeader(
                  title: 'Малітва перад поўднем',
                  subtitle:
                      'Доўгая назва літургічнага святкавання для вузкага экрана',
                  onTitleTap: () {},
                  actions: const [
                    TextButton(onPressed: null, child: Text('Чытанні')),
                  ],
                ),
                content: const Text(
                  'Божа, прыйдзі мне на дапамогу. '
                  'Пане, паспяшы да мяне на паратунак.\n\n'
                  'Гэты доўгі фрагмент правярае перанос радкоў і пракрутку.\n\n'
                  'Хвала Айцу і Сыну, і Духу Святому.',
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(CustomScrollView), findsOneWidget);
        expect(
          find.byKey(
            Key(
              platform == TargetPlatform.iOS
                  ? 'adaptive-chrome-glass'
                  : 'adaptive-chrome-ambient',
            ),
          ),
          findsOneWidget,
        );
      }
    }
  });
}
