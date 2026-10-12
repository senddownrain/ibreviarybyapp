import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/providers/priest_access_provider.dart';
import 'package:mybrev_flutter/widgets/priest_access_settings_section.dart';
import 'priest_access_test.dart'
    show MemoryStorage, SparkGateway, validCode, wrongCode;

void main() {
  testWidgets('manual disable requires confirmation; cancel keeps access', (
    tester,
  ) async {
    final gateway = SparkGateway();
    final controller = PriestAccessController(gateway, MemoryStorage());
    await controller.initialize();
    await controller.activate(validCode, 'Phone');
    final container = ProviderContainer(
      overrides: [priestAccessProvider.overrideWith((_) => controller)],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: PriestAccessSettingsSection()),
        ),
      ),
    );
    await tester.tap(find.text('Выключыць доступ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Скасаваць'));
    await tester.pumpAndSettle();
    expect(gateway.active, true);
    await tester.tap(find.text('Выключыць доступ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Выключыць'));
    // Stream cancellation may finish in the real async zone before the UI
    // leaves its busy state; advancing only the fake clock cannot finish it.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(controller.state.busy, false);
    expect(gateway.active, false);
    expect(controller.state.content, null);
    expect(find.byKey(const Key('priest-code')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await gateway.close();
  });
  testWidgets('a failed attempt cannot erase the newly edited code', (
    tester,
  ) async {
    final server = SparkGateway();
    final controller = PriestAccessController(server, MemoryStorage());
    await controller.initialize();
    final container = ProviderContainer(
      overrides: [priestAccessProvider.overrideWith((_) => controller)],
    );
    try {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: PriestAccessSettingsSection()),
            ),
          ),
        ),
      );
      final field = find.byKey(const Key('priest-code'));
      server.pauseActivation = Completer<void>();
      await tester.enterText(field, wrongCode);
      await tester.tap(find.text('Адкрыць доступ'));
      await tester.pump();
      await tester.enterText(field, validCode);
      server.pauseActivation!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Няправільны код актывацыі.'), findsOneWidget);
      expect(tester.widget<TextField>(field).controller!.text, validCode);
      final codeController = tester.widget<TextField>(field).controller!;
      server.pauseActivation = null;
      await tester.tap(find.text('Адкрыць доступ'));
      await tester.pumpAndSettle();
      expect(find.text('Доступ актываваны'), findsOneWidget);
      expect(codeController.text, isEmpty);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await server.close();
    }
  });
}
