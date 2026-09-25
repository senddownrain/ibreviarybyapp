import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/providers/readings_navigation_provider.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/router/router.dart';

void main() {
  test('router has four stable restored StatefulShell branches', () {
    final shell = router.configuration.routes
        .whereType<StatefulShellRoute>()
        .single;
    expect(shell.restorationScopeId, 'ibreviary-shell');
    expect(shell.branches, hasLength(4));
    expect(shell.branches.map((branch) => branch.initialLocation), [
      '/hours',
      '/readings',
      '/prayers',
      '/bible',
    ]);
    expect(shell.branches.map((branch) => branch.restorationScopeId), [
      'hours-branch',
      'readings-branch',
      'prayerbook-branch',
      'bible-branch',
    ]);
    expect(
      shell.branches.map((branch) => branch.navigatorKey).toSet(),
      hasLength(4),
    );
  });

  test('reader deep links are descendants of the correct branch', () {
    final shell = router.configuration.routes
        .whereType<StatefulShellRoute>()
        .single;
    final roots = [
      for (final branch in shell.branches) branch.routes.single as GoRoute,
    ];
    expect(roots.map((route) => route.path), [
      '/hours',
      '/readings',
      '/prayers',
      '/bible',
    ]);

    expect(
      _descendantPaths(roots[0]),
      containsAll(['ora/:date/:dayId/:type', 'hora/:date/:dayId']),
    );
    expect(_descendantPaths(roots[1]), contains('reading/:readingId'));
    expect(
      _descendantPaths(roots[2]),
      containsAll({
        'all',
        'search',
        'categories',
        'category/:id',
        'favorites',
        'my',
        'prayer/add',
        'prayer/:id/edit',
        'prayer/:id',
        'songs',
        ':id',
        'catechism',
        'sacraments',
      }),
    );
    expect(
      _descendantPaths(roots[3]),
      containsAll({'search', 'result'}),
      reason: 'Bible chapter remains the root while search keeps its own stack',
    );
  });

  test('canonical direct links match the navigator of their owning branch', () {
    final cases = <(String, GlobalKey<NavigatorState>)>[
      ('/hours/ora/2026-09-09/day-id/lauds', hoursNavigatorKey),
      ('/readings?date=2026-09-09&dayId=day-id', readingsNavigatorKey),
      ('/prayers/prayer/prayer-id', prayerbookNavigatorKey),
      ('/prayers/songs', prayerbookNavigatorKey),
      ('/prayers/songs/song-id', prayerbookNavigatorKey),
      ('/prayers/catechism', prayerbookNavigatorKey),
      ('/prayers/sacraments', prayerbookNavigatorKey),
      ('/bible?version=bel&book=genesis&chapter=1', bibleNavigatorKey),
    ];

    for (final (location, expectedNavigator) in cases) {
      final match = router.configuration.findMatch(Uri.parse(location));
      expect(match.error, isNull, reason: location);
      expect(match.matches, hasLength(1), reason: location);
      final shell = match.matches.single as ShellRouteMatch;
      expect(shell.navigatorKey, same(expectedNavigator), reason: location);
    }
  });

  test('legacy compatibility aliases remain registered', () {
    final paths = router.configuration.routes
        .whereType<GoRoute>()
        .map((route) => route.path)
        .toSet();
    expect(
      paths,
      containsAll({
        '/',
        '/ora/:date/:dayId/:type',
        '/hora/:date/:dayId',
        '/reading/:readingId',
        '/prayer/:id',
        '/prayer/add',
        '/prayer/edit/:id',
        '/favorites',
        '/my',
        '/my-prayers',
        '/bible/:version/:book/:chapter',
        '/picker',
        '/picker/options',
        '/settings',
        '/about',
      }),
    );
  });

  test('Hours and Readings dates are independent branch state', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(selectedDateProvider.notifier).state = DateTime(2026, 9, 8);
    container.read(readingsBranchStateProvider.notifier).state =
        ReadingsBranchState(date: DateTime(2026, 9, 9));

    expect(container.read(selectedDateProvider), DateTime(2026, 9, 8));
    expect(
      container.read(readingsBranchStateProvider).date,
      DateTime(2026, 9, 9),
    );
  });

  test('start section preference resolves only to the four branch roots', () {
    expect(startSectionLocation('hours', 'bible'), '/hours');
    expect(startSectionLocation('readings', 'hours'), '/readings');
    expect(startSectionLocation('prayerbook', 'hours'), '/prayers');
    expect(startSectionLocation('bible', 'hours'), '/bible');
    expect(startSectionLocation('last', 'bible'), '/bible');
    expect(startSectionLocation('invalid', 'invalid'), '/hours');
  });
}

Set<String> _descendantPaths(GoRoute route) {
  final result = <String>{};
  void collect(RouteBase parent) {
    for (final child in parent.routes) {
      if (child is GoRoute) result.add(child.path);
      collect(child);
    }
  }

  collect(route);
  return result;
}
