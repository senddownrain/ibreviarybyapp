import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mybrev_flutter/navigation/app_navigation.dart';
import 'package:mybrev_flutter/providers/data_bootstrap_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_navigation_sync_provider.dart';
import 'package:mybrev_flutter/providers/readings_navigation_provider.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/widgets/app_shell.dart';
import 'package:mybrev_flutter/widgets/reader/reader_scaffold.dart';

class _IdleBootstrap extends DataBootstrapNotifier {
  @override
  DataBootstrapState build() => const DataBootstrapState(initialComplete: true);
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
  testWidgets(
    'shell starts and restores the shared date without build writes',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith(_MemorySettings.new),
          dataBootstrapProvider.overrideWith(_IdleBootstrap.new),
          liturgicalSeasonColorProvider.overrideWithValue(Colors.green),
          // Date restoration is tested independently of remote liturgical data.
          liturgicalNavigationSyncProvider.overrideWith((ref) {}),
        ],
      );
      addTearDown(container.dispose);
      final shellState = AppShellState(
        roots: [
          for (final branch in AppBranch.values)
            AppRouteDescriptor(
              id: branch.name,
              branch: branch,
              defaultChromeMode: ReaderChromeMode.full,
              topChromeOwner: TopChromeOwner.shell,
              isBranchRoot: true,
            ),
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
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
