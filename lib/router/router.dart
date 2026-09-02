import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mybrev_flutter/widgets/app_shell.dart';
import 'package:mybrev_flutter/screens/home_screen.dart';
import 'package:mybrev_flutter/screens/liturgical_picker_screen.dart';
import 'package:mybrev_flutter/screens/liturgical_day_options_screen.dart';
import 'package:mybrev_flutter/screens/prayers_screen.dart';
import 'package:mybrev_flutter/screens/prayer_detail_screen.dart';
import 'package:mybrev_flutter/screens/favorites_screen.dart';
import 'package:mybrev_flutter/screens/readings_screen.dart';
import 'package:mybrev_flutter/screens/reading_detail_screen.dart';
import 'package:mybrev_flutter/screens/hora_picker_screen.dart';
import 'package:mybrev_flutter/screens/ora_screen.dart';
import 'package:mybrev_flutter/screens/bible_screen.dart';
import 'package:mybrev_flutter/screens/bible_chapter_screen.dart';
import 'package:mybrev_flutter/screens/settings_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: '/',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: HomeScreen()),
        ),
        GoRoute(
          path: '/picker',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: LiturgicalPickerScreen()),
        ),
        GoRoute(
          path: '/prayers',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: PrayersScreen()),
        ),
        GoRoute(
          path: '/bible',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: BibleScreen()),
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: SettingsScreen()),
        ),
      ],
    ),

    // Full-screen routes (no shell nav)
    GoRoute(
      path: '/picker/options',
      builder: (context, state) {
        final period = state.uri.queryParameters['period'] ?? '';
        final week = int.tryParse(state.uri.queryParameters['week'] ?? '') ?? 0;
        final day = int.tryParse(state.uri.queryParameters['day'] ?? '') ?? 1;
        return LiturgicalDayOptionsScreen(period: period, week: week, day: day);
      },
    ),
    GoRoute(
      path: '/readings/:dateStr',
      builder: (context, state) {
        final dateStr = state.pathParameters['dateStr']!;
        return ReadingsScreen(dateStr: dateStr);
      },
    ),
    GoRoute(
      path: '/readings/liturgical/:period/:week/:day',
      builder: (context, state) {
        final key =
            '${state.pathParameters['period']}/'
            '${state.pathParameters['week']}/'
            '${state.pathParameters['day']}';
        return ReadingsScreen(liturgicalKey: key);
      },
    ),
    GoRoute(
      path: '/reading/:readingId',
      builder: (context, state) {
        final readingId = state.pathParameters['readingId']!;
        return ReadingDetailScreen(readingId: readingId);
      },
    ),
    GoRoute(
      path: '/hora/:dayId',
      builder: (context, state) {
        final dayId = state.pathParameters['dayId']!;
        return HoraPickerScreen(dayId: dayId);
      },
    ),
    GoRoute(
      path: '/ora/:dayId/:type',
      builder: (context, state) {
        final dayId = state.pathParameters['dayId']!;
        final type = state.pathParameters['type']!;
        return OraScreen(dayId: dayId, oraType: type);
      },
    ),
    GoRoute(
      path: '/prayer/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return PrayerDetailScreen(prayerId: id);
      },
    ),
    GoRoute(
      path: '/prayers/favorites',
      builder: (context, state) => const FavoritesScreen(),
    ),
    GoRoute(
      path: '/bible/:version/:book/:chapter',
      builder: (context, state) {
        final version = state.pathParameters['version']!;
        final book = state.pathParameters['book']!;
        final chapter =
            int.tryParse(state.pathParameters['chapter'] ?? '') ?? 1;
        return BibleChapterScreen(
          versionId: version,
          bookId: book,
          chapter: chapter,
        );
      },
    ),
  ],
);
