// Device run of the Stage 2 QA harness (iOS Simulator / Android emulator).
//
//   flutter test -d <device> test/discovery/device/discovery_qa_device_run.dart
//
// Not named *_test.dart on purpose: `flutter test test/discovery` on the host
// does not pick it up. It uses an isolated Hive directory (never the app's
// data). Each state prints `QA_SHOT::<name>` and holds the frame so an
// outside script can take a real screenshot (simctl / adb screencap).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mybrev_flutter/discovery/discovery.dart';
import 'package:mybrev_flutter/discovery/qa/discovery_qa_harness.dart';
import 'package:mybrev_flutter/discovery/qa/qa_scenarios.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('QA harness: 4 switches, dismiss survives fake restart', (
    tester,
  ) async {
    await Hive.initFlutter('discovery_qa_device');
    final storage = HiveDiscoveryStorage(boxName: 'discovery_qa_device_v1');
    await storage.clear(); // isolated QA box only

    Future<void> hold(String name) async {
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      debugPrint('QA_SHOT::$name');
      await Future<void>.delayed(const Duration(seconds: 4));
      await tester.pump();
    }

    String result() =>
        tester.widget<Text>(find.byKey(const ValueKey('qa_result'))).data!;

    Future<void> choose(QaScenario scenario) async {
      await tester.tap(find.byKey(ValueKey('qa_scenario_${scenario.name}')));
      await tester.pumpAndSettle();
    }

    await tester.pumpWidget(DiscoveryQaApp(storage: storage));
    await tester.pumpAndSettle();
    expect(result(), 'readings.day_variants');
    await hold('01_ready_with_alternatives');

    await choose(QaScenario.noVariants);
    expect(result(), 'none');
    await hold('02_no_alternatives');

    await choose(QaScenario.loading);
    expect(result(), 'none');
    await hold('03_loading');
    await choose(QaScenario.error);
    expect(result(), 'none');
    await hold('04_error');

    await choose(QaScenario.disabled);
    expect(result(), 'none');
    await hold('05_disabled');

    await choose(QaScenario.withVariants);
    expect(result(), 'readings.day_variants');
    await tester.tap(find.byKey(const ValueKey('qa_show')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('qa_hint_card')), findsOneWidget);
    await hold('06_hint_shown');

    await tester.tap(find.byKey(const ValueKey('qa_hint_never')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('qa_restart')));
    await tester.pumpAndSettle();
    expect(result(), 'none');
    expect(find.textContaining('dismissed=true'), findsOneWidget);
    await hold('07_after_restart_dismiss_kept');

    await tester.tap(find.byKey(const ValueKey('qa_reset')));
    await tester.pumpAndSettle();
    expect(result(), 'readings.day_variants');
    await hold('08_after_qa_reset');
    await Hive.close();
  });
}
