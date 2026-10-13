import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/models/psalmody_preferences.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/theme/app_theme.dart';
import 'package:mybrev_flutter/widgets/reader/reader_scaffold.dart';

class _PreviewSettings extends SettingsNotifier {
  @override
  SettingsState build() => const SettingsState();
  @override
  Future<void> setPsalmMarkerBreakMode(PsalmMarkerBreakMode value) async {
    state = state.copyWith(psalmMarkerBreakMode: value);
  }

  @override
  Future<void> setPsalmVerseLayout(PsalmVerseLayout value) async {
    state = state.copyWith(psalmVerseLayout: value);
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final fonts =
        '${File(Platform.resolvedExecutable).parent.parent.parent.path}/material_fonts';
    for (final family in ['Roboto', '.AppleSystemUIFont', '.SF UI Text']) {
      await (FontLoader(family)..addFont(
            File(
              '$fonts/roboto-regular.ttf',
            ).readAsBytes().then(ByteData.sublistView),
          ))
          .load();
    }
    for (final (family, asset) in [
      ('PreviewBook', 'assets/google_fonts/Literata-Regular.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
      (
        'packages/phosphor_flutter/PhosphorBold',
        'packages/phosphor_flutter/lib/fonts/Phosphor-Bold.ttf',
      ),
      (
        'packages/phosphor_flutter/PhosphorRegular',
        'packages/phosphor_flutter/lib/fonts/Phosphor.ttf',
      ),
    ]) {
      await (FontLoader(family)..addFont(rootBundle.load(asset))).load();
    }
  });
  final before = Platform.environment['OVERFLOW_VISUAL_STAGE'] == 'before';
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final brightness in Brightness.values) {
      for (final width in [320.0, 360.0, 390.0, 430.0]) {
        for (final scale in [1.0, 1.5, 2.0]) {
          testWidgets('menu ${platform.name} ${brightness.name} $width dp $scale', (
            tester,
          ) async {
            tester.view.physicalSize = Size(width, 760);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            await tester.pumpWidget(
              ProviderScope(
                overrides: [
                  settingsProvider.overrideWith(_PreviewSettings.new),
                ],
                child: RepaintBoundary(
                  key: const Key('menu-preview-capture'),
                  child: MaterialApp(
                    debugShowCheckedModeBanner: false,
                    theme: ThemeData(
                      platform: platform,
                      colorScheme: AppPalette.scheme(brightness),
                    ),
                    builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        textScaler: TextScaler.linear(scale),
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
                        style: TextStyle(
                          fontFamily: 'PreviewBook',
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            Future<void> capture(String state) async {
              final selected =
                  (width == 320 &&
                      brightness == Brightness.dark &&
                      (scale == 1 || scale == 2)) ||
                  (width == 390 && scale == 1);
              if (!selected ||
                  Platform.environment['OVERFLOW_MENU_IMAGES'] != '1') {
                return;
              }
              final boundary = tester.renderObject<RenderRepaintBoundary>(
                find.byKey(const Key('menu-preview-capture')),
              );
              await tester.runAsync(() async {
                final image = await boundary.toImage(pixelRatio: 1);
                final data = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                final directory = Directory(
                  'build/overflow-menu-visual-fix/${before ? 'before' : 'after'}',
                )..createSync(recursive: true);
                File(
                  '${directory.path}/${platform.name}-${brightness.name}-${width.toInt()}-${(scale * 100).round()}-$state.png',
                ).writeAsBytesSync(data!.buffer.asUint8List());
                image.dispose();
              });
            }

            await tester.tap(find.byKey(const Key('app-overflow-open')));
            await tester.pumpAndSettle();
            if (!before) {
              for (final label in [
                'Шрыфт',
                'Перанос пасля * і †',
                'Па левым краі',
                'Налады',
                'Інфармацыя',
              ]) {
                final paragraph = tester.renderObject<RenderParagraph>(
                  find
                      .descendant(
                        of: find.text(label),
                        matching: find.byType(RichText),
                      )
                      .first,
                );
                if (scale == 1) {
                  expect(
                    paragraph.getBoxesForSelection(
                      TextSelection(baseOffset: 0, extentOffset: label.length),
                    ),
                    hasLength(1),
                    reason: '$label should be one line at $width',
                  );
                }
                for (final word in RegExp(r'\S+').allMatches(label)) {
                  expect(
                    paragraph.getBoxesForSelection(
                      TextSelection(
                        baseOffset: word.start,
                        extentOffset: word.end,
                      ),
                    ),
                    hasLength(1),
                    reason: '$label: ${word.group(0)} at $width / $scale',
                  );
                }
              }
              expect(find.byType(Switch), findsNWidgets(2));
              final switches = find.byType(Switch);
              expect(
                tester.getRect(switches.at(0)).right,
                closeTo(tester.getRect(switches.at(1)).right, .01),
              );
            }
            await capture('off-off');
            for (final key in [
              'overflow-psalm-marker-break',
              'overflow-psalm-aligned-left',
            ]) {
              await tester.ensureVisible(find.byKey(Key(key)));
              await tester.tap(find.byKey(Key(key)));
              await tester.pumpAndSettle();
            }
            expect(
              find.byKey(const Key('app-overflow-content')),
              findsOneWidget,
            );
            await tester.ensureVisible(find.text('Шрыфт'));
            await tester.pumpAndSettle();
            await capture('on-on');
            await tester.tap(find.text('Шрыфт'));
            await tester.pumpAndSettle();
            expect(find.byKey(const Key('app-overflow-content')), findsNothing);
            expect(find.byKey(const Key('text-scale-slider')), findsOneWidget);
            if (!before) {
              final title = tester.renderObject<RenderParagraph>(
                find
                    .descendant(
                      of: find.text('Шрыфт'),
                      matching: find.byType(RichText),
                    )
                    .first,
              );
              expect(
                title.getBoxesForSelection(
                  const TextSelection(baseOffset: 0, extentOffset: 5),
                ),
                hasLength(1),
              );
            }
            expect(find.byType(Switch), findsNothing);
            expect(tester.takeException(), isNull);
            await capture('font');
          });
        }
      }
    }
  }
}
