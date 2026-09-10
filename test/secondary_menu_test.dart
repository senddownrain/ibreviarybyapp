import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/widgets/navigation_drawer.dart';

void main() {
  testWidgets('secondary menu contains only product-level destinations', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AppNavigationDrawer())),
    );

    expect(find.text('Налады'), findsOneWidget);
    expect(find.text('Сінхранізацыя'), findsOneWidget);
    expect(find.text('Інфармацыя'), findsOneWidget);
    expect(find.text('Святая Імша'), findsNothing);
    expect(find.text('Абраныя малітвы'), findsNothing);
    expect(find.text('Мае малітвы'), findsNothing);
  });
}
