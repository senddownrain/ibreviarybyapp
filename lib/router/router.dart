import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:mybrev_flutter/widgets/app_shell.dart';
import 'package:mybrev_flutter/screens/home_screen.dart';
import 'package:mybrev_flutter/screens/liturgical_picker_screen.dart';
import 'package:mybrev_flutter/screens/liturgical_day_options_screen.dart';
import 'package:mybrev_flutter/screens/prayers_screen.dart';
import 'package:mybrev_flutter/screens/prayer_detail_screen.dart';
import 'package:mybrev_flutter/screens/prayer_form_screen.dart';
import 'package:mybrev_flutter/screens/favorites_screen.dart';
import 'package:mybrev_flutter/screens/my_prayers_screen.dart';
import 'package:mybrev_flutter/screens/readings_screen.dart';
import 'package:mybrev_flutter/screens/reading_detail_screen.dart';
import 'package:mybrev_flutter/screens/hora_picker_screen.dart';
import 'package:mybrev_flutter/screens/ora_screen.dart';
import 'package:mybrev_flutter/screens/bible_screen.dart';
import 'package:mybrev_flutter/screens/bible_chapter_screen.dart';
import 'package:mybrev_flutter/screens/settings_screen.dart';

class _ShellFadePage<T> extends CustomTransitionPage<T> {
  _ShellFadePage({required super.child, super.key})
      : super(
          transitionDuration: const Duration(milliseconds: 180),
          reverseTransitionDuration: const Duration(milliseconds: 120),
          transitionsBuilder: (_, animation, _, child) => FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          ),
        );
}

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
              _ShellFadePage(child: const HomeScreen()),
        ),
        GoRoute(
          path: '/picker',
          pageBuilder: (context, state) =>
              _ShellFadePage(child: const LiturgicalPickerScreen()),
        ),
        GoRoute(
          path: '/prayers',
          pageBuilder: (context, state) =>
              _ShellFadePage(child: const PrayersScreen()),
        ),
        GoRoute(
          path: '/bible',
          pageBuilder: (context, state) =>
              _ShellFadePage(child: const BibleScreen()),
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) =>
              _ShellFadePage(child: const SettingsScreen()),
        ),
        GoRoute(
          path: '/my-prayers',
          pageBuilder: (context, state) =>
              _ShellFadePage(child: const MyPrayersScreen()),
        ),
      ],
    ),

    // Full-screen routes (no shell nav)
    GoRoute(
      path: '/picker/options',
      pageBuilder: (context, state) {
        final period = state.uri.queryParameters['period'] ?? '';
        final week = int.tryParse(state.uri.queryParameters['week'] ?? '') ?? 0;
        final day = int.tryParse(state.uri.queryParameters['day'] ?? '') ?? 1;
        return CupertinoPage(
          key: state.pageKey,
          child: LiturgicalDayOptionsScreen(period: period, week: week, day: day),
        );
      },
    ),
    // Specific pattern BEFORE the catch-all /:dateStr
    GoRoute(
      path: '/readings/liturgical/:period/:week/:day',
      pageBuilder: (context, state) {
        final key =
            '${state.pathParameters['period']}/'
            '${state.pathParameters['week']}/'
            '${state.pathParameters['day']}';
        return CupertinoPage(
          key: state.pageKey,
          child: ReadingsScreen(liturgicalKey: key),
        );
      },
    ),
    GoRoute(
      path: '/readings/:dateStr',
      pageBuilder: (context, state) {
        final dateStr = state.pathParameters['dateStr']!;
        return CupertinoPage(
          key: state.pageKey,
          child: ReadingsScreen(
            dateStr: dateStr,
            dayId: state.uri.queryParameters['dayId'],
          ),
        );
      },
    ),
    GoRoute(
      path: '/reading/:readingId',
      pageBuilder: (context, state) {
        final readingId = state.pathParameters['readingId']!;
        return CupertinoPage(
          key: state.pageKey,
          child: ReadingDetailScreen(readingId: readingId),
        );
      },
    ),
    GoRoute(
      path: '/hora/:dateStr/:dayId',
      pageBuilder: (context, state) {
        final dayId = state.pathParameters['dayId']!;
        final date =
            DateTime.tryParse(state.pathParameters['dateStr'] ?? '') ??
            DateTime.now();
        return CupertinoPage(
          key: state.pageKey,
          child: HoraPickerScreen(dayId: dayId, date: date),
        );
      },
    ),
    GoRoute(
      path: '/ora/:dateStr/:dayId/:type',
      pageBuilder: (context, state) {
        final dayId = state.pathParameters['dayId']!;
        final type = state.pathParameters['type']!;
        final date =
            DateTime.tryParse(state.pathParameters['dateStr'] ?? '') ??
            DateTime.now();
        return CupertinoPage(
          key: state.pageKey,
          child: OraScreen(dayId: dayId, oraType: type, date: date),
        );
      },
    ),
    // Specific prayer routes BEFORE the catch-all /prayer/:id
    GoRoute(
      path: '/prayer/add',
      pageBuilder: (context, state) => CupertinoPage(
        key: state.pageKey,
        child: const PrayerFormScreen(),
      ),
    ),
    GoRoute(
      path: '/prayer/edit/:id',
      pageBuilder: (context, state) {
        final id = state.pathParameters['id']!;
        return CupertinoPage(
          key: state.pageKey,
          child: PrayerFormScreen(prayerId: id),
        );
      },
    ),
    GoRoute(
      path: '/prayer/:id',
      pageBuilder: (context, state) {
        final id = state.pathParameters['id']!;
        return CupertinoPage(
          key: state.pageKey,
          child: PrayerDetailScreen(prayerId: id),
        );
      },
    ),
    GoRoute(
      path: '/prayers/favorites',
      pageBuilder: (context, state) => CupertinoPage(
        key: state.pageKey,
        child: const FavoritesScreen(),
      ),
    ),
    GoRoute(
      path: '/bible/:version/:book/:chapter',
      pageBuilder: (context, state) {
        final version = state.pathParameters['version']!;
        final book = state.pathParameters['book']!;
        final chapter =
            int.tryParse(state.pathParameters['chapter'] ?? '') ?? 1;
        return CupertinoPage(
          key: state.pageKey,
          child: BibleChapterScreen(
            versionId: version,
            bookId: book,
            chapter: chapter,
          ),
        );
      },
    ),
  ],
);
