import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/navigation/app_navigation.dart';
import 'package:mybrev_flutter/widgets/app_navigation_dock.dart';
import 'package:mybrev_flutter/widgets/reader/reader_scaffold.dart';

void main() {
  Widget app(
    TargetPlatform platform,
    ReaderChromeMode mode, {
    double width = 320,
    double textScale = 2,
  }) => MaterialApp(
    key: ValueKey((platform, mode)),
    theme: ThemeData(useMaterial3: true, platform: platform),
    home: MediaQuery(
      data: MediaQueryData(
        size: Size(width, 640),
        textScaler: TextScaler.linear(textScale),
        viewPadding: EdgeInsets.only(bottom: 24),
      ),
      child: Scaffold(
        bottomNavigationBar: AppNavigationDock(
          activeBranch: AppBranch.readings,
          mode: mode,
          seasonColor: Colors.green,
          onSelect: (_) {},
          onExpand: () {},
        ),
      ),
    ),
  );

  testWidgets('Full dock renders four destinations on iOS and Android', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      await tester.pumpWidget(app(platform, ReaderChromeMode.full));
      await tester.pump();
      expect(find.byKey(const Key('app-dock-full')), findsOneWidget);
      expect(
        find.byKey(
          Key(
            platform == TargetPlatform.iOS
                ? 'app-dock-ios'
                : 'app-dock-android',
          ),
        ),
        findsOneWidget,
      );
      for (final label in ['Літургія', 'Чытанні', 'Малітоўнік', 'Біблія']) {
        expect(find.text(label), findsOneWidget);
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(
            of: find.text(label),
            matching: find.byType(RichText),
          ),
        );
        expect(paragraph.didExceedMaxLines, isFalse, reason: label);
        final destination = tester.getSize(
          find.byKey(Key('app-destination-$label')),
        );
        expect(destination.width, greaterThanOrEqualTo(48));
        expect(destination.height, greaterThanOrEqualTo(48));
      }
      expect(
        tester
            .getSize(find.byKey(const Key('app-dock-system-navigation-strip')))
            .height,
        24,
      );
      final strip = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byKey(const Key('app-dock-system-navigation-strip')),
          matching: find.byType(ColoredBox),
        ),
      );
      expect(strip.color.a, closeTo(0.72, 0.01));
      final backing = tester.widget<Container>(
        find.byKey(
          Key(
            platform == TargetPlatform.iOS
                ? 'app-dock-ios'
                : 'app-dock-android',
          ),
        ),
      );
      final gradient =
          (backing.decoration! as BoxDecoration).gradient! as LinearGradient;
      expect(gradient.colors.first.a, 0);
      expect(gradient.colors[1].a, greaterThan(0));
      expect(
        tester
            .getSize(
              find.byKey(
                Key(
                  platform == TargetPlatform.iOS
                      ? 'app-dock-ios'
                      : 'app-dock-android',
                ),
              ),
            )
            .height,
        160,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('dock labels stay complete across widths and text scales', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      for (final width in [320.0, 360.0, 390.0, 430.0, 700.0]) {
        for (final scale in [1.0, 1.5, 2.0]) {
          tester.view.physicalSize = Size(width, 640);
          await tester.pumpWidget(
            app(
              platform,
              ReaderChromeMode.full,
              width: width,
              textScale: scale,
            ),
          );
          await tester.pump();
          for (final label in ['Літургія', 'Чытанні', 'Малітоўнік', 'Біблія']) {
            final paragraph = tester.renderObject<RenderParagraph>(
              find.descendant(
                of: find.text(label),
                matching: find.byType(RichText),
              ),
            );
            expect(
              paragraph.didExceedMaxLines,
              isFalse,
              reason: '$platform $width/$scale $label',
            );
          }
          expect(
            tester.takeException(),
            isNull,
            reason: '$platform $width/$scale',
          );
        }
      }
    }
  });

  testWidgets('Compact expands without acting as a repeated tab', (
    tester,
  ) async {
    var expanded = false;
    var selected = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: AppNavigationDock(
            activeBranch: AppBranch.bible,
            mode: ReaderChromeMode.compact,
            seasonColor: Colors.green,
            onSelect: (_) => selected = true,
            onExpand: () => expanded = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('app-dock-compact')));
    expect(find.byKey(const Key('app-dock-android')), findsOneWidget);
    expect(expanded, isTrue);
    expect(selected, isFalse);
  });

  testWidgets('Hidden removes the primary dock', (tester) async {
    await tester.pumpWidget(
      app(TargetPlatform.android, ReaderChromeMode.hidden),
    );
    expect(find.byKey(const Key('app-dock-hidden')), findsOneWidget);
    expect(find.text('Літургія'), findsNothing);
    expect(find.byKey(const Key('app-dock-android')), findsNothing);
  });
}
