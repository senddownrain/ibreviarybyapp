import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/discovery/discovery.dart';
import 'package:mybrev_flutter/discovery/qa/discovery_qa_harness.dart';
import 'package:mybrev_flutter/discovery/qa/qa_scenarios.dart';

import 'support.dart';

Future<void> pumpHarness(
  WidgetTester tester,
  MemoryDiscoveryStorage storage,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(800, 1600);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    DiscoveryQaApp(storage: storage, clock: FakeDiscoveryClock(t0)),
  );
  await tester.pumpAndSettle();
}

Future<void> choose(WidgetTester tester, QaScenario scenario) async {
  await tester.tap(find.byKey(ValueKey('qa_scenario_${scenario.name}')));
  await tester.pumpAndSettle();
}

String result(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('qa_result'))).data!;

void main() {
  testWidgets('four switches: variants → none → loading/error → disabled', (
    tester,
  ) async {
    await pumpHarness(tester, MemoryDiscoveryStorage());
    expect(result(tester), 'readings.day_variants');

    await choose(tester, QaScenario.noVariants);
    expect(result(tester), 'none');

    await choose(tester, QaScenario.loading);
    expect(result(tester), 'none');
    await choose(tester, QaScenario.error);
    expect(result(tester), 'none');

    await choose(tester, QaScenario.disabled);
    expect(result(tester), 'none');
    expect(find.textContaining('hintsEnabled=false'), findsOneWidget);

    await choose(tester, QaScenario.withVariants);
    expect(result(tester), 'readings.day_variants');
    expect(find.textContaining('hintsEnabled=true'), findsOneWidget);
  });

  testWidgets('every scenario answers its expected hint_id or none', (
    tester,
  ) async {
    await pumpHarness(tester, MemoryDiscoveryStorage());
    for (final scenario in QaScenario.values) {
      await choose(tester, scenario);
      expect(result(tester), scenario.expected, reason: scenario.name);
    }
  });

  testWidgets('show counts after the card is on screen; dismiss survives '
      'a fake restart', (tester) async {
    final storage = MemoryDiscoveryStorage();
    await pumpHarness(tester, storage);

    await tester.tap(find.byKey(const ValueKey('qa_show')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('qa_hint_card')), findsOneWidget);
    expect(find.textContaining('seen=1'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('qa_hint_never')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('qa_hint_card')), findsNothing);
    expect(result(tester), 'none');

    await tester.tap(find.byKey(const ValueKey('qa_restart')));
    await tester.pumpAndSettle();
    expect(find.text('Сесія 2 · перазапускаў: 1'), findsOneWidget);
    expect(result(tester), 'none');
    expect(find.textContaining('dismissed=true'), findsOneWidget);
    expect(find.textContaining('dismissed'), findsWidgets);
  });

  testWidgets('QA reset clears only the hint history and restores the hint', (
    tester,
  ) async {
    await pumpHarness(tester, MemoryDiscoveryStorage());
    await tester.tap(find.byKey(const ValueKey('qa_show')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('qa_hint_never')));
    await tester.pumpAndSettle();
    expect(result(tester), 'none');

    await tester.tap(find.byKey(const ValueKey('qa_reset')));
    await tester.pumpAndSettle();
    expect(result(tester), 'readings.day_variants');
  });

  testWidgets('a second request in the same visit and the 5 minute cooldown '
      'are real, the QA clock can skip them', (tester) async {
    await pumpHarness(tester, MemoryDiscoveryStorage());
    await tester.tap(find.byKey(const ValueKey('qa_show')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('qa_hint_later')));
    await tester.pumpAndSettle();
    // New visit by re-selecting; still inside the cooldown → none.
    await choose(tester, QaScenario.withVariants);
    expect(result(tester), 'none');
    await tester.tap(find.byKey(const ValueKey('qa_plus_6m')));
    await tester.pumpAndSettle();
    await choose(tester, QaScenario.withVariants);
    // First session already used one slot; one more is allowed.
    expect(result(tester), 'readings.day_variants');
  });
}
