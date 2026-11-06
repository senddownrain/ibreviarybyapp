import 'package:mybrev_flutter/theme/app_theme_preference.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mybrev_flutter/main.dart' as app;
import 'package:mybrev_flutter/providers/liturgical_navigation_sync_provider.dart';
import 'package:mybrev_flutter/router/router.dart';
import 'package:mybrev_flutter/screens/home_screen.dart';
import 'package:mybrev_flutter/services/liturgical_content_service.dart';
import 'package:mybrev_flutter/theme/app_theme_controller.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'minimal calendar and October 16 polish',
    (tester) async {
      Future<void> settle() async {
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      Future<void> waitFor(Finder finder) async {
        for (var i = 0; i < 120 && finder.evaluate().isEmpty; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(finder, findsWidgets);
        await settle();
      }

      Future<void> tap(String key) async {
        await tester.ensureVisible(find.byKey(Key(key)));
        await tester.tap(find.byKey(Key(key)));
        await settle();
      }

      final width =
          (tester.view.physicalSize.width / tester.view.devicePixelRatio)
              .round();
      final narrow = kIsWeb && width <= 320;
      Future<void> shot(String name) async {
        expect(tester.takeException(), isNull);
        final prefix = kIsWeb
            ? (narrow ? 'polish-chrome-320' : 'polish-chrome')
            : 'polish-android';
        final fullName = '$prefix-light-$name';
        binding.reportData ??= {};
        final states =
            binding.reportData!.putIfAbsent(
                  'selector_states',
                  () => <String, Object?>{},
                )
                as Map<String, Object?>;
        states[fullName] = {
          'width': width,
          'bottomInset':
              tester.view.viewPadding.bottom / tester.view.devicePixelRatio,
        };
        if (narrow) return; // Record the check without extra screenshots.
        if (kIsWeb) {
          await binding.takeScreenshot(fullName);
        } else {
          debugPrint('SELECTOR_NATIVE_SCREENSHOT_READY:$name');
          for (var i = 0; i < 30; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
        }
      }

      debugPrint(
        'POLISH_BUILD_SHA:${const String.fromEnvironment('POLISH_BUILD_SHA', defaultValue: 'web-working-tree')}',
      );
      app.main();
      await waitFor(find.byKey(const Key('hours-hour-laudes')));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(HomeScreen)),
      );
      final originalTheme = appThemePreferenceController.value;
      try {
        appThemePreferenceController.value = AppThemePreference.light;
        if (narrow) tester.platformDispatcher.textScaleFactorTestValue = 2;
        final date = DateTime(2026, 10, 16);
        final hedwig = LiturgicalContentService()
            .contentForDate(date)
            .options
            .firstWhere((option) => option.title.contains('Ядвіг'));
        final dayId = hedwig.dayId!;
        container
            .read(liturgicalNavigationControllerProvider)
            .openDate(date, dayId: hedwig.dayId);
        router.go(
          '/hours/ordo?date=2026-10-16&dayId=${Uri.encodeQueryComponent(dayId)}',
        );
        await waitFor(find.byKey(const Key('ordo-selected-celebration')));
        expect(
          find.descendant(
            of: find.byKey(const Key('ordo-selected-celebration')),
            matching: find.text(hedwig.title),
          ),
          findsOneWidget,
        );
        if (kIsWeb) await shot('hedwig');
        await tap('ordo-date-action');
        expect(
          tester
              .widget<Text>(find.byKey(const Key('ordo-month-label')))
              .style
              ?.fontSize,
          19,
        );
        if (kIsWeb) await shot('calendar');
        await tester.tap(find.text('Гатова').last);
        await settle();
        await tester.ensureVisible(find.text('XXVIII звычайны тыдзень'));
        await settle();
        expect(find.text('Пятніца', findRichText: true), findsWidgets);
        expect(
          find.byKey(const Key('ordo-reading-references')),
          findsOneWidget,
        );
        if (kIsWeb) await shot('alternatives');
        final list = find.byKey(const Key('ordo-scroll'));
        await tester.drag(list, const Offset(0, -3000));
        await settle();
        final padding = tester.widget<ListView>(list).padding! as EdgeInsets;
        expect(
          padding.bottom,
          greaterThanOrEqualTo(
            24 + tester.view.viewPadding.bottom / tester.view.devicePixelRatio,
          ),
        );
        if (!kIsWeb) await shot('bottom-safe-area');
        expect(tester.takeException(), isNull);
      } finally {
        tester.platformDispatcher.clearTextScaleFactorTestValue();
        appThemePreferenceController.value = originalTheme;
        binding.reportData?['preferences_restored'] = true;
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
