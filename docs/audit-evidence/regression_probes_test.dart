// Audit-only characterization probes: asserts CURRENT behavior, not desired fixes.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_navigation_sync_provider.dart';
import 'package:mybrev_flutter/providers/readings_navigation_provider.dart';
import 'package:mybrev_flutter/widgets/reader/reader_scaffold.dart';

void main() {
  test('AUDIT: a Readings date update overwrites the Hours context', () {
    final container = ProviderContainer(
      overrides: [
        dayOptionsProvider.overrideWithValue([]),
        selectedDateProvider.overrideWith((ref) => DateTime(2026, 9, 13)),
        readingsBranchStateProvider.overrideWith(
          (ref) => ReadingsBranchState(date: DateTime(2026, 9, 13)),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(liturgicalNavigationSyncProvider);
    container.read(readingsBranchStateProvider.notifier).state =
        ReadingsBranchState(date: DateTime(2026, 9, 14));
    expect(container.read(selectedDateProvider), DateTime(2026, 9, 14));
  });

  testWidgets('AUDIT: double tapping a child action also hides reader chrome', (
    tester,
  ) async {
    final chrome = ReaderChromeModeController(ReaderChromeMode.compact);
    addTearDown(chrome.dispose);
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ReaderChromeModeScope(
          controller: chrome,
          child: ReaderScaffold(
            content: TextButton(
              onPressed: () => taps++,
              child: const Text('Child action'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Child action'));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(find.text('Child action'));
    await tester.pump();
    expect(taps, 2);
    expect(chrome.value, ReaderChromeMode.hidden);
    expect(find.byKey(const Key('reader-chrome-restore')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'AUDIT: stable GoRouter retains route state across MaterialApp theme keys',
    (tester) async {
      final mode = ValueNotifier(ThemeMode.light);
      addTearDown(mode.dispose);
      final router = GoRouter(
        routes: [GoRoute(path: '/', builder: (_, _) => const _Counter())],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ValueListenableBuilder<ThemeMode>(
          valueListenable: mode,
          builder: (_, themeMode, _) => MaterialApp.router(
            key: ValueKey(themeMode),
            themeMode: themeMode,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Count 0'));
      await tester.pump();
      expect(find.text('Count 1'), findsOneWidget);
      mode.value = ThemeMode.dark;
      await tester.pumpAndSettle();
      expect(find.text('Count 1'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

class _Counter extends StatefulWidget {
  const _Counter();
  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int count = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: TextButton(
      onPressed: () => setState(() => count++),
      child: Text('Count $count'),
    ),
  );
}
