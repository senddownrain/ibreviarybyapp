import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/navigation/app_navigation.dart';
import 'package:mybrev_flutter/constants/hora_items.dart';
import 'package:mybrev_flutter/providers/connectivity_provider.dart';
import 'package:mybrev_flutter/providers/content_updates_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/router/router.dart';
import 'package:mybrev_flutter/screens/ora_screen.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/widgets/reader/reader_navigation.dart';

class _IdleUpdates extends ContentUpdatesNotifier {
  @override
  ContentUpdateState build() => const ContentUpdateState();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await initializeDateFormatting('be');
    directory = await Directory.systemTemp.createTemp('ora-back-');
    await HiveService.init(path: directory.path, loadBundle: true);
    await HiveService.content.ensureLoaded(kLiturgicalCollections);
    // Complete startup migration on the real async clock. A Hive write begun
    // inside testWidgets' FakeAsync cannot finish during real-I/O teardown.
    final settings = ProviderContainer();
    settings.read(settingsProvider);
    await Hive.box('settings').flush();
    settings.dispose();
  });
  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  for (final contextCase in [
    (
      date: DateTime(2026, 10, 19),
      dayId: '19-10-sv-paul-of-cross--religious',
      diocese: 'minsk-mohilev',
    ),
    (date: DateTime(2026, 10, 20), dayId: 'ordinary-w29-d3', diocese: 'pinsk'),
  ]) {
    for (final scenario in [
      (
        name: 'direct list entry, system Back',
        initial: 'laudes',
        switches: <String>[],
        screenBack: false,
        deepLink: false,
      ),
      (
        name: 'one replacement, system Back',
        initial: 'laudes',
        switches: ['vespers'],
        screenBack: false,
        deepLink: false,
      ),
      (
        name: 'repeated replacements never accumulate hours',
        initial: 'morning',
        switches: ['vespers', 'lectionis', 'laudes', 'vespers'],
        screenBack: false,
        deepLink: false,
      ),
      (
        name: 'screen Back agrees after replacement',
        initial: 'laudes',
        switches: ['vespers'],
        screenBack: true,
        deepLink: false,
      ),
      (
        name: 'direct route without previous visit, system Back',
        initial: 'laudes',
        switches: <String>[],
        screenBack: false,
        deepLink: true,
      ),
      (
        name: 'direct route and repeated replacements, screen Back',
        initial: 'morning',
        switches: ['vespers', 'laudes'],
        screenBack: true,
        deepLink: true,
      ),
    ]) {
      testWidgets(
        '${scenario.name} (${contextCase.diocese}, ${contextCase.dayId})',
        (tester) async {
          tester.view.physicalSize = const Size(1080, 2400);
          tester.view.devicePixelRatio = 2.625;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          bool? frameworkHandlesBack;
          final commonId = contextCase.dayId;
          final date = contextCase.date;
          final diocese = contextCase.diocese;
          final container = ProviderContainer(
            overrides: [
              contentUpdatesProvider.overrideWith(_IdleUpdates.new),
              isOfflineProvider.overrideWithValue(true),
              connectivityProvider.overrideWith((ref) => Stream.value(false)),
            ],
          );
          addTearDown(container.dispose);
          final root = Uri(
            path: '/hours',
            queryParameters: {
              'date': date.toIso8601String().substring(0, 10),
              'dayId': commonId,
              'diocese': diocese,
            },
          ).toString();
          final reader = oraRouteForContext(
            date: date,
            dayId: commonId,
            oraType: scenario.initial,
            diocese: diocese,
            optionId: 'route-context',
          );
          router.go(scenario.deepLink ? reader : root);
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp.router(
                routerConfig: router,
                onNavigationNotification: (notification) {
                  frameworkHandlesBack = notification.canHandlePop;
                  return true;
                },
              ),
            ),
          );
          await tester.pumpAndSettle();
          final originalSettings = container.read(settingsProvider);
          if (!scenario.deepLink) router.push(reader);
          await tester.pumpAndSettle();
          for (final type in scenario.switches) {
            final current = tester.widget<OraScreen>(find.byType(OraScreen));
            final title = kHoraItems
                .singleWhere((h) => h.type == current.oraType)
                .label;
            await tester.tap(find.text(title).first);
            await tester.pumpAndSettle();
            final target = kHoraItems.singleWhere((h) => h.type == type).label;
            await tester.scrollUntilVisible(
              find.text(target),
              250,
              scrollable: find.byType(Scrollable).last,
            );
            await tester.ensureVisible(
              find
                  .ancestor(
                    of: find.text(target),
                    matching: find.byType(ListTile),
                  )
                  .last,
            );
            await tester.pumpAndSettle();
            await tester.tap(find.text(target));
            await tester.pumpAndSettle();
            expect(
              tester.widget<OraScreen>(find.byType(OraScreen)).oraType,
              type,
            );
            expect(
              appShellState.activeController.activeDescriptor.id,
              'hours.ora',
            );
            expect(appShellState.activeController.isAtRoot, isFalse);
            expect(appShellState.activeBranch, AppBranch.hours);
            expect(
              tester.widget<OraScreen>(find.byType(OraScreen)).dayId,
              commonId,
            );
            expect(
              tester.widget<OraScreen>(find.byType(OraScreen)).diocese,
              diocese,
            );
            expect(
              GoRouterState.of(
                tester.element(find.byType(OraScreen)),
              ).uri.queryParameters['option'],
              'route-context',
            );
          }
          expect(
            hoursNavigatorKey.currentState!.widget.pages,
            hasLength(2),
            reason:
                'Exactly the day list and current hour, even after many switches',
          );
          expect(hoursNavigatorKey.currentState!.canPop(), isTrue);
          expect(
            frameworkHandlesBack,
            isTrue,
            reason:
                'Android must forward Back to Flutter, not finish the Activity',
          );
          if (scenario.screenBack) {
            await tester.tap(find.byTooltip('Назад'));
          } else {
            await tester.binding.handlePopRoute();
          }
          await tester.pumpAndSettle();
          expect(find.byType(OraScreen), findsNothing);
          expect(router.routerDelegate.currentConfiguration.uri.path, '/hours');
          expect(container.read(selectedDateProvider), date);
          final selection = container.read(hoursLiturgicalSelectionProvider);
          expect(selection.dayId, commonId);
          if (commonId.endsWith('--religious')) {
            expect(selection.template?.choice, 'religious');
          }
          expect(selection.diocese, diocese);
          expect(
            container.read(settingsProvider).fontSize,
            originalSettings.fontSize,
          );
          expect(
            container.read(settingsProvider).themeMode,
            originalSettings.themeMode,
          );
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
