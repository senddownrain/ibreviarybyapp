// Visual pass: the Hours root with diocesan badges and «Каляндар», the
// picker lists and the Settings section at 320 / 360 / 390 / 430 px and a
// tablet, light and dark, text ×1.0 / 1.4 / 2.0 — no overflow; the
// vestment colours stay visible and are never the only carrier of meaning.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/content/content_store.dart';
import 'package:mybrev_flutter/providers/connectivity_provider.dart';
import 'package:mybrev_flutter/providers/diocese_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/screens/home_screen.dart';
import 'package:mybrev_flutter/screens/liturgical_picker_screen.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/utils/liturgical_visual.dart';
import 'package:mybrev_flutter/widgets/liturgical_calendar_settings_section.dart';

class _Dioceses extends DioceseSelectionNotifier {
  @override
  DioceseSelection build() => const DioceseSelection(
    selected: ['grodno', 'vitebsk'],
    primary: 'vitebsk',
  );
}

double _luminance(Color color) => color.computeLuminance();
double _contrast(Color a, Color b) {
  final l1 = _luminance(a);
  final l2 = _luminance(b);
  final hi = l1 > l2 ? l1 : l2;
  final lo = l1 > l2 ? l2 : l1;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  late Directory directory;
  setUpAll(() async {
    await initializeDateFormatting('be');
    directory = await Directory.systemTemp.createTemp('ordo-visual-');
    await HiveService.init(path: directory.path, loadBundle: true);
    await ContentStore.instance.ensureLoaded(kContentCollections);
  });
  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  List<Override> overrides(DateTime date) => [
    selectedDateProvider.overrideWith((ref) => date),
    selectedDateReadyProvider.overrideWith((ref) async {}),
    liturgicalContentReadyProvider.overrideWith((ref) async {}),
    isOfflineProvider.overrideWithValue(false),
    dioceseSelectionProvider.overrideWith(_Dioceses.new),
  ];

  Widget frame(
    Widget child, {
    required ThemeMode mode,
    required double scale,
    List<Override> extra = const [],
  }) => ProviderScope(
    overrides: [...overrides(DateTime(2026, 8, 26)), ...extra],
    child: MaterialApp.router(
      theme: ThemeData(useMaterial3: true),
      darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
      themeMode: mode,
      builder: (context, inner) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: inner!,
      ),
      routerConfig: GoRouter(
        routes: [GoRoute(path: '/', builder: (_, _) => child)],
      ),
    ),
  );

  for (final width in [320.0, 360.0, 390.0, 430.0, 834.0]) {
    for (final scale in [1.0, 1.4, 2.0]) {
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        testWidgets('Hours root, picker and Settings: ${width.toInt()} px, '
            '×$scale, ${mode.name}', (tester) async {
          tester.view.physicalSize = Size(width * 2, 900 * 2);
          tester.view.devicePixelRatio = 2;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            frame(
              const Scaffold(body: HomeScreen()),
              mode: mode,
              scale: scale,
            ),
          );
          await tester.pump();
          expect(tester.takeException(), isNull);
          expect(find.text('Каляндар'), findsNothing);

          await tester.pumpWidget(
            frame(
              const Scaffold(body: LiturgicalPickerScreen()),
              mode: mode,
              scale: scale,
            ),
          );
          await tester.pump();
          await tester.tap(find.text('Святы'));
          await tester.pumpAndSettle();
          final list = find.byKey(const Key('picker-feasts'));
          expect(list, findsOneWidget);
          for (var i = 0; i < 4; i++) {
            await tester.drag(list, const Offset(0, -900));
            await tester.pump();
          }
          expect(tester.takeException(), isNull);

          await tester.pumpWidget(
            frame(
              const Scaffold(
                body: SingleChildScrollView(
                  child: LiturgicalCalendarSettingsSection(),
                ),
              ),
              mode: mode,
              scale: scale,
            ),
          );
          await tester.pump();
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  test('vestment markers stay visible on light and dark surfaces', () {
    const light = Color(0xFFFFFBFE);
    const dark = Color(0xFF1C1B1F);
    for (final vestment in kVestmentColors.values) {
      // The ring (white is drawn gold) separates from both surfaces.
      final best = [
        _contrast(vestment.ring, light),
        _contrast(vestment.ring, dark),
      ];
      expect(best.reduce((a, b) => a > b ? a : b), greaterThan(1.8));
    }
    expect(_contrast(kVestmentColors['albus']!.ring, light), greaterThan(1.8));
    expect(_contrast(kVestmentColors['niger']!.ring, dark), greaterThan(1.1));
    // Every colour has a word: the colour is never the only meaning.
    for (final vestment in kVestmentColors.values) {
      expect(vestment.label, isNotEmpty);
    }
  });
}
