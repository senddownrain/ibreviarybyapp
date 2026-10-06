// Settings «Літургічны каляндар» section (no storage: the box is closed).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/providers/diocese_provider.dart';
import 'package:mybrev_flutter/widgets/liturgical_calendar_settings_section.dart';

void main() {
  testWidgets('the section lists four dioceses and keeps one', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: LiturgicalCalendarSettingsSection(),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Літургічны каляндар'), findsOneWidget);
    for (final name in kDioceseShortNames.values) {
      expect(find.text(name), findsOneWidget);
    }
    await tester.tap(find.byKey(const Key('settings-diocese-minsk-mohilev')));
    await tester.pump();
    expect(find.text('Патрэбна хоць адна дыяцэзія.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('settings-diocese-vitebsk')));
    await tester.pump();
    expect(
      find.byKey(const Key('settings-diocese-primary-vitebsk')),
      findsOneWidget,
    );
  });
}
