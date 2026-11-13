import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mybrev_flutter/feedback/feedback_models.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/widgets/app_overflow_menu.dart';

class _Settings extends SettingsNotifier {
  @override
  SettingsState build() => const SettingsState();
}

/// The report entry must follow the page the reader SEES, also for a page
/// opened with `context.push` (an imperative match).
void main() {
  Future<GoRouter> pumpApp(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/hours',
      routes: [
        GoRoute(
          path: '/hours',
          builder: (context, state) => Scaffold(
            body: Column(
              children: [
                const AppOverflowMenu(),
                TextButton(
                  onPressed: () =>
                      context.push('/hours/ora/2026-11-13/day-1/laudes'),
                  child: const Text('open hour'),
                ),
              ],
            ),
          ),
        ),
        GoRoute(
          path: '/hours/ora/:date/:dayId/:type',
          builder: (context, state) =>
              const Scaffold(body: AppOverflowMenu(showTextScale: true)),
        ),
        GoRoute(
          path: '/settings/feedback',
          builder: (context, state) =>
              Scaffold(body: Text('form ${state.uri.queryParameters}')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsProvider.overrideWith(_Settings.new)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('app-overflow-open')));
    await tester.pumpAndSettle();
  }

  testWidgets('no report entry on a list screen', (tester) async {
    await pumpApp(tester);
    await openMenu(tester);
    expect(find.text(kReportErrorLabel), findsNothing);
  });

  testWidgets('a pushed Hours page offers the entry with its context', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text('open hour'));
    await tester.pumpAndSettle();
    await openMenu(tester);
    expect(find.text(kReportErrorLabel), findsOneWidget);
    await tester.tap(find.text(kReportErrorLabel));
    await tester.pumpAndSettle();
    expect(find.textContaining("ctx_kind: hour"), findsOneWidget);
    expect(find.textContaining("ctx_hour: lauds"), findsOneWidget);
    expect(find.textContaining("ctx_date: 2026-11-13"), findsOneWidget);
  });
}
