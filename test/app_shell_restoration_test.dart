import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mybrev_flutter/navigation/app_navigation.dart';
import 'package:mybrev_flutter/providers/content_updates_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_navigation_sync_provider.dart';
import 'package:mybrev_flutter/providers/readings_navigation_provider.dart';
import 'package:mybrev_flutter/providers/readings_loader_provider.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/router/router.dart';
import 'package:mybrev_flutter/widgets/app_shell.dart';
import 'package:mybrev_flutter/widgets/branch_hosts.dart';
import 'package:mybrev_flutter/widgets/reader/reader_scaffold.dart';

class _IdleBootstrap extends ContentUpdatesNotifier {
  @override
  ContentUpdateState build() => const ContentUpdateState();
}

class _MemorySettings extends SettingsNotifier {
  @override
  SettingsState build() => const SettingsState();

  @override
  void rememberLastSection(String section) {
    if (state.lastSection != section) {
      state = state.copyWith(lastSection: section);
    }
  }
}

void main() {
  test('Bible selection temporarily owns the bottom slot', () {
    const entry = AppRouteEntry(id: 'bible', descriptor: bibleRootRoute);
    final controller = BranchShellController(AppBranch.bible, bibleRootRoute)
      ..activate(entry);
    expect(bibleRootRoute.defaultChromeMode.name, 'full');
    expect(controller.navigationDockSuppressed, isFalse);
    controller.requestContextualBottomSlot(entry.id, visible: true);
    expect(controller.navigationDockSuppressed, isTrue);
    controller.requestContextualBottomSlot(entry.id, visible: false);
    expect(controller.navigationDockSuppressed, isFalse);
    controller.dispose();
  });

  testWidgets(
    'shell starts and restores the shared date without build writes',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith(_MemorySettings.new),
          contentUpdatesProvider.overrideWith(_IdleBootstrap.new),
          liturgicalSeasonColorProvider.overrideWithValue(Colors.green),
          // Date restoration is tested independently of remote liturgical data.
          liturgicalNavigationSyncProvider.overrideWith((ref) {}),
        ],
      );
      addTearDown(container.dispose);
      final shellState = AppShellState(
        roots: const [
          hoursRootRoute,
          readingsRootRoute,
          prayerbookRootRoute,
          bibleRootRoute,
        ],
      );
      addTearDown(shellState.dispose);
      final router = GoRouter(
        restorationScopeId: 'test-router',
        initialLocation: '/hours',
        routes: [
          StatefulShellRoute.indexedStack(
            restorationScopeId: 'test-shell',
            builder: (context, state, shell) => AppShell(
              navigationShell: shell,
              shellState: shellState,
              activeBranch: AppBranch.values[shell.currentIndex],
            ),
            branches: [
              for (final branch in AppBranch.values)
                StatefulShellBranch(
                  restorationScopeId: '${branch.name}-branch',
                  observers: [
                    BranchRouteObserver(shellState.branches[branch]!),
                  ],
                  routes: [
                    GoRoute(
                      path: '/${branch.name}',
                      pageBuilder: (context, state) => MaterialPage<void>(
                        key: state.pageKey,
                        arguments: AppRouteEntry(
                          id: state.pageKey.value,
                          descriptor:
                              shellState.branches[branch]!.rootDescriptor,
                        ),
                        child: Consumer(
                          builder: (context, ref, child) {
                            ref.watch(selectedDateProvider);
                            ref.watch(readingsBranchStateProvider);
                            ref.watch(settingsProvider);
                            return Text(branch.name);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      final date = DateTime(2026, 8, 15);
      container.read(selectedDateProvider.notifier).state = date;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            restorationScopeId: 'test-app',
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      expect(container.read(selectedDateProvider), date);
      expect(container.read(readingsBranchStateProvider).date, date);

      router.go('/readings');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(container.read(settingsProvider).lastSection, 'readings');
      expect(shellState.activeController.activeEntryId, isNotNull);

      router.go('/bible');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('app-dock-full')), findsOneWidget);
      for (final (branch, label) in [
        (AppBranch.hours, 'Літургія'),
        (AppBranch.readings, 'Чытанні'),
        (AppBranch.prayerbook, 'Малітоўнік'),
      ]) {
        await tester.tap(find.byKey(Key('app-destination-$label')));
        await tester.pumpAndSettle();
        expect(find.text(branch.name), findsOneWidget);
        router.go('/bible');
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('app-dock-full')), findsOneWidget);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'opening Readings with an explicit date updates after route build',
    (tester) async {
      final requestedDate = DateTime(2028, 8, 1);
      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith(_MemorySettings.new),
          contentUpdatesProvider.overrideWith(_IdleBootstrap.new),
          liturgicalSeasonColorProvider.overrideWithValue(Colors.green),
          dayOptionsProvider.overrideWithValue(const []),
          readingsLoaderProvider.overrideWithValue(
            ({
              required dateStr,
              required liturgicalKey,
              required dayId,
            }) async => const ReadingsLoadResult(
              readings: [],
              sundayCycle: 'A',
              weekdayCycle: '1',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final shellState = AppShellState(
        roots: const [
          hoursRootRoute,
          readingsRootRoute,
          prayerbookRootRoute,
          bibleRootRoute,
        ],
      );
      addTearDown(shellState.dispose);
      final chrome = ReaderChromeModeController(ReaderChromeMode.full);
      addTearDown(chrome.dispose);
      final router = GoRouter(
        initialLocation: '/hours',
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, shell) => AppShell(
              navigationShell: shell,
              shellState: shellState,
              activeBranch: AppBranch.values[shell.currentIndex],
            ),
            branches: [
              for (final branch in AppBranch.values)
                StatefulShellBranch(
                  observers: [
                    BranchRouteObserver(shellState.branches[branch]!),
                  ],
                  routes: [
                    GoRoute(
                      path: '/${branch.name}',
                      pageBuilder: (context, state) => MaterialPage<void>(
                        key: state.pageKey,
                        arguments: AppRouteEntry(
                          id: state.pageKey.value,
                          descriptor:
                              shellState.branches[branch]!.rootDescriptor,
                        ),
                        child: branch == AppBranch.readings
                            ? ReaderChromeModeScope(
                                controller: chrome,
                                child: ReadingsBranchHost(date: requestedDate),
                              )
                            : Text(branch.name),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      router.go('/readings');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(container.read(selectedDateProvider), requestedDate);
      expect(container.read(readingsBranchStateProvider).date, requestedDate);
    },
  );
}
