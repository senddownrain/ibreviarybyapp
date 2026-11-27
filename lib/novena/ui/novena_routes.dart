import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mybrev_flutter/novena/ui/novena_day_screen.dart';
import 'package:mybrev_flutter/novena/ui/novena_list_screen.dart';
import 'package:mybrev_flutter/widgets/branch_hosts.dart';

const novenasLocation = '/novenas';
const novenaDayLocation = '/novenas/day';

/// Root pages above the shell. Their addresses carry no novena or session id
/// (nothing for analytics, crash reports or feedback context to pick up).
List<RouteBase> novenaRoutes(GlobalKey<NavigatorState> navigator) => [
  GoRoute(
    parentNavigatorKey: navigator,
    path: novenasLocation,
    pageBuilder: (context, state) => MaterialPage<void>(
      key: state.pageKey,
      child: const SecondaryPageScaffold(
        title: 'Мае навэнны',
        child: NovenaListScreen(),
      ),
    ),
  ),
  GoRoute(
    parentNavigatorKey: navigator,
    path: novenaDayLocation,
    pageBuilder: (context, state) {
      final extra = state.extra;
      final session = extra is Map ? extra['session'] : null;
      final day = extra is Map ? extra['day'] : null;
      return MaterialPage<void>(
        key: state.pageKey,
        child: session is String
            ? NovenaDayScreen(sessionId: session, day: day is int ? day : 1)
            : const SecondaryPageScaffold(
                title: 'Мае навэнны',
                child: NovenaListScreen(),
              ),
      );
    },
  ),
];
