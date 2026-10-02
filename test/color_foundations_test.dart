import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/navigation/app_navigation.dart';
import 'package:mybrev_flutter/theme/app_theme.dart';
import 'package:mybrev_flutter/theme/glass.dart';
import 'package:mybrev_flutter/theme/ib_colors.dart';
import 'package:mybrev_flutter/theme/reader.dart';
import 'package:mybrev_flutter/widgets/app_navigation_dock.dart';
import 'package:mybrev_flutter/widgets/floating_top_actions.dart';
import 'package:mybrev_flutter/widgets/reader/reader_scaffold.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('semantic colors and ReaderTheme agree in ${brightness.name}', (
      tester,
    ) async {
      final colors = IbColors.forBrightness(brightness);
      final scheme = AppPalette.scheme(brightness);
      late ReaderTheme reader;
      late IbColors installed;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: scheme,
            brightness: brightness,
            extensions: [colors],
          ),
          home: Builder(
            builder: (context) {
              installed = IbColors.of(context);
              reader = ReaderTheme.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(installed.page, scheme.surfaceContainerLowest);
      expect(installed.surface, scheme.surface);
      expect(installed.surfaceRaised, scheme.surfaceBright);
      expect(installed.floating, scheme.surfaceContainerHigh);
      expect(installed.ink, scheme.onSurface);
      expect(installed.inkMuted, scheme.onSurfaceVariant);
      expect(installed.accent, scheme.primary);
      expect(installed.onAccent, scheme.onPrimary);
      expect(installed.error, scheme.error);
      expect(scheme.outline, installed.outline.withValues(alpha: 0.55));
      expect(scheme.outlineVariant, installed.outline.withValues(alpha: 0.22));
      expect(reader.ink, installed.ink);
      expect(reader.muted, installed.readerMuted);
      expect(reader.rubric, installed.rubric);
      expect(reader.surface, installed.reader);
      expect(reader.border, installed.separator);
      expect(installed.neutralAmbient, isNot(installed.page));
      if (brightness == Brightness.light) {
        expect(installed.readerMuted, isNot(installed.inkMuted));
      }
    });
  }

  test('non-liturgical screens do not subscribe to calendar color', () {
    for (final screen in [
      'settings_screen',
      'about_screen',
      'favorites_screen',
      'my_prayers_screen',
    ]) {
      final source = File('lib/screens/$screen.dart').readAsStringSync();
      expect(
        source,
        isNot(contains('liturgicalSeasonColorProvider')),
        reason: '$screen must use neutral page color',
      );
    }
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final brightness in Brightness.values) {
      testWidgets(
        '${platform.name} ${brightness.name} dock, top and reader chrome stay neutral',
        (tester) async {
          Future<List<Color>> capture(Color dayColor) async {
            await tester.pumpWidget(
              MaterialApp(
                key: ValueKey((platform, brightness, dayColor)),
                theme: ThemeData(
                  platform: platform,
                  brightness: brightness,
                  colorScheme: AppPalette.scheme(brightness),
                  extensions: [IbColors.forBrightness(brightness)],
                ),
                home: Scaffold(
                  body: Stack(
                    children: [
                      FloatingTopActions(
                        seasonColor: dayColor,
                        actions: const [
                          IconButton(onPressed: null, icon: Icon(Icons.search)),
                        ],
                      ),
                      ReaderChrome(
                        mode: ReaderChromeMode.full,
                        seasonColor: dayColor,
                        onModeChanged: (_) {},
                      ),
                    ],
                  ),
                  bottomNavigationBar: AppNavigationDock(
                    activeBranch: AppBranch.hours,
                    mode: ReaderChromeMode.full,
                    seasonColor: dayColor,
                    onSelect: (_) {},
                    onExpand: () {},
                  ),
                ),
              ),
            );
            await tester.pump();

            Color surface(Finder root) {
              if (platform == TargetPlatform.iOS) {
                final glass = tester.widget<GlassSurface>(
                  find
                      .descendant(of: root, matching: find.byType(GlassSurface))
                      .first,
                );
                expect(glass.seasonColor, isNull);
                return IbColors.forBrightness(brightness).surface;
              }
              final ambient = find
                  .descendant(
                    of: root,
                    matching: find.byKey(const Key('adaptive-chrome-ambient')),
                  )
                  .first;
              final container = tester.widget<Container>(
                find
                    .descendant(of: ambient, matching: find.byType(Container))
                    .first,
              );
              return (container.decoration! as BoxDecoration).color!;
            }

            return [
              surface(find.byKey(const Key('app-dock-full'))),
              surface(find.byKey(const Key('floating-top-actions-surface'))),
              surface(find.byKey(const Key('reader-chrome-back'))),
            ];
          }

          final ordinary = await capture(const Color(0xFF4D8A5B));
          final lent = await capture(const Color(0xFF6F4A92));
          expect(lent, ordinary);
          expect(
            ordinary[0],
            platform == TargetPlatform.iOS
                ? IbColors.forBrightness(brightness).surface
                : IbColors.forBrightness(brightness).floating,
          );
        },
      );
    }
  }
}
