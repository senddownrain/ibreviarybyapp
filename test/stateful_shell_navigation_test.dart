import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('branch switch preserves stacks and active repeat returns root', (
    tester,
  ) async {
    final router = _testRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('A detail'));
    await tester.pumpAndSettle();
    expect(find.text('A child'), findsOneWidget);

    await tester.tap(find.byKey(const Key('branch-b')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('B detail'));
    await tester.pumpAndSettle();
    expect(find.text('B child'), findsOneWidget);

    await tester.tap(find.byKey(const Key('branch-a')));
    await tester.pumpAndSettle();
    expect(find.text('A child'), findsOneWidget, reason: 'A stack restored');

    await tester.tap(find.byKey(const Key('branch-a')));
    await tester.pumpAndSettle();
    expect(
      find.text('A root'),
      findsOneWidget,
      reason: 'active repeat opens root',
    );

    await tester.tap(find.byKey(const Key('branch-b')));
    await tester.pumpAndSettle();
    expect(
      find.text('B child'),
      findsOneWidget,
      reason: 'B stack stayed independent',
    );
  });

  testWidgets('direct link activates its owning branch', (tester) async {
    final router = _testRouter(initialLocation: '/b/detail');
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('B child'), findsOneWidget);
    final selected = tester
        .widget<NavigationBar>(find.byType(NavigationBar))
        .selectedIndex;
    expect(selected, 1);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('B root'), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
      reason: 'Back pops inside the active branch instead of resetting shell',
    );
  });
}

GoRouter _testRouter({String initialLocation = '/a'}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => Scaffold(
        body: shell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: (index) => shell.goBranch(
            index,
            initialLocation: index == shell.currentIndex,
          ),
          destinations: const [
            NavigationDestination(
              key: Key('branch-a'),
              icon: Icon(Icons.audiotrack),
              label: 'A',
            ),
            NavigationDestination(
              key: Key('branch-b'),
              icon: Icon(Icons.book),
              label: 'B',
            ),
          ],
        ),
      ),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/a',
              builder: (context, state) => _Root(label: 'A'),
              routes: [
                GoRoute(
                  path: 'detail',
                  builder: (_, _) => const Center(child: Text('A child')),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/b',
              builder: (context, state) => _Root(label: 'B'),
              routes: [
                GoRoute(
                  path: 'detail',
                  builder: (_, _) => const Center(child: Text('B child')),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);

class _Root extends StatelessWidget {
  const _Root({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label root'),
        TextButton(
          onPressed: () => context.push('/${label.toLowerCase()}/detail'),
          child: Text('$label detail'),
        ),
      ],
    ),
  );
}
