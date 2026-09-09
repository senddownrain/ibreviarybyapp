import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/navigation/app_navigation.dart';
import 'package:mybrev_flutter/widgets/app_navigation_dock.dart';
import 'package:mybrev_flutter/widgets/reader/reader_scaffold.dart';

void main() {
  Widget app(TargetPlatform platform, ReaderChromeMode mode) => MaterialApp(
    key: ValueKey((platform, mode)),
    theme: ThemeData(useMaterial3: true, platform: platform),
    home: MediaQuery(
      data: const MediaQueryData(
        size: Size(320, 640),
        textScaler: TextScaler.linear(2),
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
      for (final label in ['Гадзіны', 'Чытанні', 'Малітоўнік', 'Біблія']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
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
    expect(expanded, isTrue);
    expect(selected, isFalse);
  });

  testWidgets('Hidden removes the primary dock', (tester) async {
    await tester.pumpWidget(
      app(TargetPlatform.android, ReaderChromeMode.hidden),
    );
    expect(find.byKey(const Key('app-dock-hidden')), findsOneWidget);
    expect(find.text('Гадзіны'), findsNothing);
  });
}
