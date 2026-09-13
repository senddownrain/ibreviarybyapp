// Audit characterization of a linked celebration in the actual branch host.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mybrev_flutter/constants/liturgical.dart';
import 'package:mybrev_flutter/models/day.dart';
import 'package:mybrev_flutter/models/parsed_reading.dart';
import 'package:mybrev_flutter/models/prayer.dart';
import 'package:mybrev_flutter/navigation/app_navigation.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_navigation_sync_provider.dart';
import 'package:mybrev_flutter/providers/prayers_provider.dart';
import 'package:mybrev_flutter/providers/readings_loader_provider.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/services/liturgical_content_service.dart';
import 'package:mybrev_flutter/widgets/branch_hosts.dart';
import 'package:mybrev_flutter/widgets/reader/reader_scaffold.dart';

class _MemorySettings extends SettingsNotifier {
  @override
  SettingsState build() => const SettingsState();
}

void main() {
  test(
    'AUDIT: visible Markdown phrase is not found across bold boundaries',
    () {
      const prayer = Prayer(
        id: 'audit',
        title: 'Probe',
        body: '**Ойча** наш',
        textFormat: 'mybrev-markdown',
      );
      expect(
        filterAndSortPrayers(
          [prayer],
          const PrayersFilter(searchQuery: 'Ойча'),
          [],
        ),
        hasLength(1),
      );
      expect(
        filterAndSortPrayers(
          [prayer],
          const PrayersFilter(searchQuery: 'Ойча наш'),
          [],
        ),
        isEmpty,
      );
    },
  );

  testWidgets(
    'AUDIT: selecting a linked celebration loses its manual marker after host rekey',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith(_MemorySettings.new),
          selectedDateProvider.overrideWith((ref) => DateTime(2026, 9, 13)),
          liturgicalSeasonColorProvider.overrideWithValue(Colors.green),
          dayOptionsProvider.overrideWithValue([
            for (final id in ['ordinary', 'feast'])
              DayOption(
                source: LiturgicalOptionSource.period,
                title: id,
                key: id,
                contextPeriodType: 'ordinary',
                day: LiturgicalDay(id: id),
              ),
          ]),
          readingsLoaderProvider.overrideWithValue(
            ({
              required dateStr,
              required liturgicalKey,
              required dayId,
              required forceRefresh,
            }) async => ReadingsLoadResult(
              readings: [
                for (final id in ['ordinary', 'feast'])
                  ParsedReading(
                    id: id,
                    dayId: id,
                    title: id == 'ordinary' ? 'Звычайны дзень' : 'Свята AUDIT',
                    reading1: ParsedSection(
                      text: 'Body for $id',
                      bible: 'Ян 1',
                    ),
                  ),
              ],
              sundayCycle: 'A',
              weekdayCycle: '2',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(liturgicalNavigationSyncProvider);
      final state = AppShellState(
        roots: [
          for (final branch in AppBranch.values)
            AppRouteDescriptor(
              id: branch.name,
              branch: branch,
              defaultChromeMode: ReaderChromeMode.full,
              topChromeOwner: TopChromeOwner.reader,
              isBranchRoot: true,
            ),
        ],
      );
      addTearDown(state.dispose);
      final chrome = ReaderChromeModeController();
      addTearDown(chrome.dispose);
      final router = GoRouter(
        initialLocation: '/readings',
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (_, _, shell) => AppNavigationScope(
              shell: shell,
              shellState: state,
              child: ReaderChromeModeScope(controller: chrome, child: shell),
            ),
            branches: [
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/readings',
                    builder: (_, _) => const ReadingsBranchHost(),
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
      expect(find.textContaining('Body for ordinary'), findsWidgets);
      await tester.tap(find.byKey(const Key('readings-options-action')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Свята AUDIT').last);
      await tester.pumpAndSettle();
      expect(container.read(hoursLiturgicalSelectionProvider).dayId, 'feast');
      expect(find.textContaining('Body for feast'), findsWidgets);
      expect(
        find.byKey(const Key('readings-manual-cycle-marker')),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}
