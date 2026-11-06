import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/widgets/reader/reader_scaffold.dart';
import 'package:mybrev_flutter/widgets/source_footer.dart';

class _Settings extends SettingsNotifier {
  @override
  SettingsState build() => const SettingsState(fontSize: 24);
}

void main() {
  for (final inset in [0.0, 24.0, 48.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('footer clears Android dock at inset $inset, scale $scale', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        tester.view.padding = FakeViewPadding(bottom: inset);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPadding);
        final controller = ScrollController();
        addTearDown(controller.dispose);
        final opened = <Uri>[];
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              settingsProvider.overrideWith(_Settings.new),
              sourceLinkLauncherProvider.overrideWithValue((uri) async {
                opened.add(uri);
                return true;
              }),
            ],
            child: MaterialApp(
              theme: ThemeData(platform: TargetPlatform.android),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                extendBody: true,
                bottomNavigationBar: SafeArea(
                  child: SizedBox(
                    key: const Key('dock'),
                    height: 72,
                    child: ColoredBox(color: Colors.white),
                  ),
                ),
                body: ReaderScaffold(
                  scrollController: controller,
                  content: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 1000),
                      Text('Канец Евангелля'),
                      SourceFooter(linkKey: Key('source-link')),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        controller.jumpTo(controller.position.maxScrollExtent);
        await tester.pumpAndSettle();
        final link = find.byKey(const Key('source-link'));
        final footer = tester.getRect(link);
        final dock = tester.getRect(find.byKey(const Key('dock')));
        expect(footer.bottom, lessThanOrEqualTo(dock.top - 20));
        expect(footer.top, greaterThanOrEqualTo(0));
        expect(footer.left, greaterThanOrEqualTo(0));
        expect(footer.right, lessThanOrEqualTo(320));
        expect(
          footer.top - tester.getRect(find.text('Канец Евангелля')).bottom,
          closeTo(32, .01),
        );
        expect(tester.takeException(), isNull);
        final text = tester.widget<Text>(
          find.descendant(of: link, matching: find.byType(Text)),
        );
        expect(text.textSpan!.toPlainText(), 'Крыніца: Catholic.by');
        await tester.tap(link);
        await tester.pump();
        expect(opened.single.toString(), 'https://catholic.by/');
      });
    }
  }
}
