import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/widgets/navigation_drawer.dart';

class _RecordingNavigatorObserver extends NavigatorObserver {
  final List<Route<dynamic>> pushedRoutes = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushedRoutes.add(route);
    super.didPush(route, previousRoute);
  }
}

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

  testWidgets('secondary bottom sheet stays above system navigation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(400, 800),
            viewPadding: EdgeInsets.only(bottom: 32),
          ),
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => showSecondaryMenu(context),
                  child: const Text('Адкрыць меню'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Адкрыць меню'));
    await tester.pumpAndSettle();

    final informationBottom = tester.getBottomLeft(find.text('Інфармацыя')).dy;
    expect(informationBottom, lessThan(800 - 32));
  });

  testWidgets('secondary menu is shown above the app navigation dock', (
    tester,
  ) async {
    final rootObserver = _RecordingNavigatorObserver();
    final branchObserver = _RecordingNavigatorObserver();

    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [rootObserver],
        home: Scaffold(
          body: Navigator(
            observers: [branchObserver],
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (branchContext) => Center(
                child: FilledButton(
                  onPressed: () => showSecondaryMenu(branchContext),
                  child: const Text('Адкрыць укладзенае меню'),
                ),
              ),
            ),
          ),
          bottomNavigationBar: const SizedBox(
            key: Key('app-navigation-dock-placeholder'),
            height: 80,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Адкрыць укладзенае меню'));
    await tester.pumpAndSettle();

    expect(rootObserver.pushedRoutes, hasLength(2));
    expect(branchObserver.pushedRoutes, hasLength(1));
    expect(find.text('Інфармацыя'), findsOneWidget);
  });
}
