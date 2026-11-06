import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:mybrev_flutter/widgets/psalmody_mode_selector.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/widgets/reader/reader_scaffold.dart';

class _PreviewSettings extends SettingsNotifier {
  @override
  SettingsState build() => const SettingsState();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    for (final (family, asset) in [
      ('PreviewText', 'assets/google_fonts/Literata-Regular.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
      (
        'packages/phosphor_flutter/PhosphorRegular',
        'packages/phosphor_flutter/lib/fonts/Phosphor.ttf',
      ),
    ]) {
      await (FontLoader(family)..addFont(rootBundle.load(asset))).load();
    }
  });
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final brightness in Brightness.values) {
      testWidgets('menu preview ${platform.name} ${brightness.name} 320 dp 200%', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [settingsProvider.overrideWith(_PreviewSettings.new)],
            child: RepaintBoundary(
              key: const Key('menu-preview-capture'),
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: ThemeData(
                  platform: platform,
                  brightness: brightness,
                  fontFamily: 'PreviewText',
                ),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: const TextScaler.linear(2),
                    padding: const EdgeInsets.only(top: 44, bottom: 34),
                    viewPadding: const EdgeInsets.only(top: 44, bottom: 34),
                  ),
                  child: child!,
                ),
                home: const ReaderScaffold(
                  showPsalmody: true,
                  contextHeader: ReaderContextHeader(
                    eyebrow: 'ЛІТУРГІЯ ГАДЗІНАЎ',
                    title: 'Ютрань',
                  ),
                  content: Text(
                    'Пане, пачуй маю малітву *\nі няхай мой кліч дойдзе да Цябе.\n\nБо Ты — мая надзея †\nі мая абарона.',
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.byKey(const Key('app-overflow-open')));
        await tester.pumpAndSettle();
        expect(find.text('Шрыфт'), findsOneWidget);
        expect(find.byType(FilterChip), findsNothing);
        expect(tester.takeException(), isNull);
        Future<void> capture(String suffix) async {
          if (Platform.environment['OVERFLOW_MENU_IMAGES'] != '1') return;
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const Key('menu-preview-capture')),
          );
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 1);
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            final directory = Directory('build/overflow-menu-preview')
              ..createSync(recursive: true);
            File(
              '${directory.path}/${platform.name}-${brightness.name}-320-200-$suffix.png',
            ).writeAsBytesSync(data!.buffer.asUint8List());
            image.dispose();
          });
        }

        await capture('open');
        await tester.tap(find.text('Шрыфт'));
        await tester.pumpAndSettle();
        expect(find.byType(PsalmodyModeSelector), findsOneWidget);
        expect(tester.takeException(), isNull);
        await capture('font-sheet');
      });
    }
  }
}
