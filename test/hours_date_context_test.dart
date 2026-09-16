import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/widgets/branch_hosts.dart';

void main() {
  testWidgets('HoursDateContext defers provider writes out of the build phase',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final first = DateTime(2027, 9, 12);
    final second = DateTime(2027, 9, 13);

    // initState write happens during the first build.
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: HoursDateContext(date: first, child: const SizedBox()),
        ),
      ),
    );
    await tester.pump();

    // didUpdateWidget write happens while the tree is rebuilding.
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: HoursDateContext(date: second, child: const SizedBox()),
        ),
      ),
    );
    await tester.pump();

    expect(container.read(selectedDateProvider), second);
  });
}
