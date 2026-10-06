import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:mybrev_flutter/models/mass_ritual.dart';
import 'package:mybrev_flutter/navigation/app_navigation.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/screens/about_screen.dart';
import 'package:mybrev_flutter/screens/bible_search_screen.dart';
import 'package:mybrev_flutter/screens/compendium_node_screen.dart';
import 'package:mybrev_flutter/screens/compendium_reader_screens.dart';
import 'package:mybrev_flutter/screens/compendium_screen.dart';
import 'package:mybrev_flutter/screens/design_bottom_navigation_lab_screen.dart';
import 'package:mybrev_flutter/screens/favorites_screen.dart';
import 'package:mybrev_flutter/screens/home_screen.dart';
import 'package:mybrev_flutter/screens/hora_picker_screen.dart';
import 'package:mybrev_flutter/screens/liturgical_day_options_screen.dart';
import 'package:mybrev_flutter/screens/liturgical_picker_screen.dart';
import 'package:mybrev_flutter/screens/my_prayers_screen.dart';
import 'package:mybrev_flutter/screens/ora_screen.dart';
import 'package:mybrev_flutter/screens/prayer_detail_screen.dart';
import 'package:mybrev_flutter/screens/prayer_form_screen.dart';
import 'package:mybrev_flutter/screens/prayerbook_placeholder_screen.dart';
import 'package:mybrev_flutter/screens/prayers_screen.dart';
import 'package:mybrev_flutter/screens/reading_detail_screen.dart';
import 'package:mybrev_flutter/screens/settings_screen.dart';
import 'package:mybrev_flutter/screens/song_detail_screen.dart';
import 'package:mybrev_flutter/screens/songbook_screen.dart';
import 'package:mybrev_flutter/widgets/app_shell.dart';
import 'package:mybrev_flutter/widgets/branch_hosts.dart';
import 'package:mybrev_flutter/widgets/reader/reader_scaffold.dart';

const bottomNavigationLabRoute = '/design/bottom-navigation-lab';
const bottomNavigationLabEnabled = bool.fromEnvironment(
  'IBREVIARY_BOTTOM_NAV_LAB',
);

const hoursRootRoute = AppRouteDescriptor(
  id: 'hours.root',
  branch: AppBranch.hours,
  defaultChromeMode: ReaderChromeMode.full,
  topChromeOwner: TopChromeOwner.shell,
  isBranchRoot: true,
);
const readingsRootRoute = AppRouteDescriptor(
  id: 'readings.root',
  branch: AppBranch.readings,
  defaultChromeMode: ReaderChromeMode.full,
  topChromeOwner: TopChromeOwner.reader,
  isBranchRoot: true,
);
const prayerbookRootRoute = AppRouteDescriptor(
  id: 'prayerbook.root',
  branch: AppBranch.prayerbook,
  defaultChromeMode: ReaderChromeMode.full,
  topChromeOwner: TopChromeOwner.shell,
  isBranchRoot: true,
);
const bibleRootRoute = AppRouteDescriptor(
  id: 'bible.root',
  branch: AppBranch.bible,
  defaultChromeMode: ReaderChromeMode.full,
  topChromeOwner: TopChromeOwner.reader,
  isBranchRoot: true,
);
const _bibleSearchRoute = AppRouteDescriptor(
  id: 'bible.search',
  branch: AppBranch.bible,
  defaultChromeMode: ReaderChromeMode.full,
  topChromeOwner: TopChromeOwner.legacy,
);
const _bibleSearchResultRoute = AppRouteDescriptor(
  id: 'bible.search.result',
  branch: AppBranch.bible,
  defaultChromeMode: ReaderChromeMode.compact,
  topChromeOwner: TopChromeOwner.reader,
);

const _hoursPickerRoute = AppRouteDescriptor(
  id: 'hours.picker',
  branch: AppBranch.hours,
  defaultChromeMode: ReaderChromeMode.full,
  topChromeOwner: TopChromeOwner.legacy,
);
const _hoursPickerOptionsRoute = AppRouteDescriptor(
  id: 'hours.picker.options',
  branch: AppBranch.hours,
  defaultChromeMode: ReaderChromeMode.full,
  topChromeOwner: TopChromeOwner.legacy,
);
const _horaRoute = AppRouteDescriptor(
  id: 'hours.hora',
  branch: AppBranch.hours,
  defaultChromeMode: ReaderChromeMode.full,
  topChromeOwner: TopChromeOwner.legacy,
);
const _oraRoute = AppRouteDescriptor(
  id: 'hours.ora',
  branch: AppBranch.hours,
  defaultChromeMode: ReaderChromeMode.compact,
  topChromeOwner: TopChromeOwner.reader,
);
const _readingsPickerRoute = AppRouteDescriptor(
  id: 'readings.picker',
  branch: AppBranch.readings,
  defaultChromeMode: ReaderChromeMode.full,
  topChromeOwner: TopChromeOwner.legacy,
);
const _readingsPickerOptionsRoute = AppRouteDescriptor(
  id: 'readings.picker.options',
  branch: AppBranch.readings,
  defaultChromeMode: ReaderChromeMode.full,
  topChromeOwner: TopChromeOwner.legacy,
);
const _readingDetailRoute = AppRouteDescriptor(
  id: 'readings.detail',
  branch: AppBranch.readings,
  defaultChromeMode: ReaderChromeMode.compact,
  topChromeOwner: TopChromeOwner.legacy,
);
const _prayerListRoute = AppRouteDescriptor(
  id: 'prayerbook.list',
  branch: AppBranch.prayerbook,
  defaultChromeMode: ReaderChromeMode.full,
  topChromeOwner: TopChromeOwner.legacy,
);
const _prayerDetailRoute = AppRouteDescriptor(
  id: 'prayerbook.detail',
  branch: AppBranch.prayerbook,
  defaultChromeMode: ReaderChromeMode.compact,
  topChromeOwner: TopChromeOwner.reader,
);

/// Holy Mass reader: its own section/language controls replace the dock.
const massReaderRoute = AppRouteDescriptor(
  id: 'prayerbook.mass',
  branch: AppBranch.prayerbook,
  defaultChromeMode: ReaderChromeMode.compact,
  topChromeOwner: TopChromeOwner.reader,
  showsNavigationDock: false,
);
const _songbookRoute = AppRouteDescriptor(
  id: 'prayerbook.songs',
  branch: AppBranch.prayerbook,
  defaultChromeMode: ReaderChromeMode.full,
  topChromeOwner: TopChromeOwner.legacy,
);
const _songDetailRoute = AppRouteDescriptor(
  id: 'prayerbook.song',
  branch: AppBranch.prayerbook,
  defaultChromeMode: ReaderChromeMode.compact,
  topChromeOwner: TopChromeOwner.reader,
);
const _compendiumRoute = AppRouteDescriptor(
  id: 'prayerbook.compendium',
  branch: AppBranch.prayerbook,
  defaultChromeMode: ReaderChromeMode.full,
  topChromeOwner: TopChromeOwner.legacy,
);
const _compendiumPartRoute = AppRouteDescriptor(
  id: 'prayerbook.compendium.part',
  branch: AppBranch.prayerbook,
  defaultChromeMode: ReaderChromeMode.full,
  topChromeOwner: TopChromeOwner.legacy,
);
const _compendiumNodeRoute = AppRouteDescriptor(
  id: 'prayerbook.compendium.node',
  branch: AppBranch.prayerbook,
  defaultChromeMode: ReaderChromeMode.full,
  topChromeOwner: TopChromeOwner.legacy,
);
const _compendiumReaderRoute = AppRouteDescriptor(
  id: 'prayerbook.compendium.reader',
  branch: AppBranch.prayerbook,
  defaultChromeMode: ReaderChromeMode.compact,
  topChromeOwner: TopChromeOwner.reader,
);
const _prayerbookSectionRoute = AppRouteDescriptor(
  id: 'prayerbook.section',
  branch: AppBranch.prayerbook,
  defaultChromeMode: ReaderChromeMode.full,
  topChromeOwner: TopChromeOwner.legacy,
);
const _prayerFormRoute = AppRouteDescriptor(
  id: 'prayerbook.form',
  branch: AppBranch.prayerbook,
  defaultChromeMode: ReaderChromeMode.full,
  topChromeOwner: TopChromeOwner.legacy,
);

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final hoursNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'hours');
final readingsNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'readings');
final prayerbookNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'prayerbook',
);
final bibleNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'bible');

final appShellState = AppShellState(
  roots: const [
    hoursRootRoute,
    readingsRootRoute,
    prayerbookRootRoute,
    bibleRootRoute,
  ],
);

final router = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: _initialLocation(),
  restorationScopeId: 'ibreviary-router',
  routes: [
    StatefulShellRoute.indexedStack(
      restorationScopeId: 'ibreviary-shell',
      builder: (context, state, navigationShell) => AppShell(
        navigationShell: navigationShell,
        shellState: appShellState,
        activeBranch: AppBranch.values[navigationShell.currentIndex],
      ),
      branches: [
        StatefulShellBranch(
          navigatorKey: hoursNavigatorKey,
          initialLocation: '/hours',
          restorationScopeId: 'hours-branch',
          observers: [
            BranchRouteObserver(appShellState.branches[AppBranch.hours]!),
          ],
          routes: [
            GoRoute(
              path: '/hours',
              pageBuilder: (context, state) => _branchPage(
                state,
                hoursRootRoute,
                const HomeScreen(key: PageStorageKey('hours-root')),
              ),
              routes: [
                GoRoute(
                  path: 'picker',
                  pageBuilder: (context, state) => _branchPage(
                    state,
                    _hoursPickerRoute,
                    const LiturgicalPickerScreen(mode: 'hours'),
                  ),
                  routes: [
                    GoRoute(
                      path: 'options',
                      pageBuilder: (context, state) => _branchPage(
                        state,
                        _hoursPickerOptionsRoute,
                        _pickerOptions(state),
                      ),
                    ),
                  ],
                ),
                GoRoute(
                  path: 'hora/:date/:dayId',
                  pageBuilder: (context, state) => _branchPage(
                    state,
                    _horaRoute,
                    HoursDateContext(
                      date:
                          _parseDate(state.pathParameters['date']) ??
                          DateTime.now(),
                      child: HoraPickerScreen(
                        dayId: state.pathParameters['dayId']!,
                        date:
                            _parseDate(state.pathParameters['date']) ??
                            DateTime.now(),
                      ),
                    ),
                  ),
                ),
                GoRoute(
                  path: 'ora/:date/:dayId/:type',
                  pageBuilder: (context, state) {
                    final date = _parseDate(state.pathParameters['date']);
                    return _branchPage(
                      state,
                      _oraRoute,
                      date == null
                          ? const _InvalidRoute(
                              message: 'Некарэктная дата Ora.',
                            )
                          : HoursDateContext(
                              date: date,
                              child: OraScreen(
                                key: ValueKey('ora-${state.uri.path}'),
                                dayId: state.pathParameters['dayId']!,
                                oraType: state.pathParameters['type']!,
                                date: date,
                              ),
                            ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: readingsNavigatorKey,
          initialLocation: '/readings',
          restorationScopeId: 'readings-branch',
          observers: [
            BranchRouteObserver(appShellState.branches[AppBranch.readings]!),
          ],
          routes: [
            GoRoute(
              path: '/readings',
              pageBuilder: (context, state) =>
                  _branchPage(state, readingsRootRoute, _readingsHost(state)),
              routes: [
                GoRoute(
                  path: 'reading/:readingId',
                  pageBuilder: (context, state) => _branchPage(
                    state,
                    _readingDetailRoute,
                    ReadingDetailScreen(
                      readingId: state.pathParameters['readingId']!,
                    ),
                  ),
                ),
                GoRoute(
                  path: 'picker',
                  pageBuilder: (context, state) => _branchPage(
                    state,
                    _readingsPickerRoute,
                    const LiturgicalPickerScreen(mode: 'readings'),
                  ),
                  routes: [
                    GoRoute(
                      path: 'options',
                      pageBuilder: (context, state) => _branchPage(
                        state,
                        _readingsPickerOptionsRoute,
                        _pickerOptions(state),
                      ),
                    ),
                  ],
                ),
                GoRoute(
                  path: 'liturgical/:period/:week/:day',
                  redirect: (context, state) => _withQuery('/readings', {
                    ...state.uri.queryParameters,
                    'mode': 'liturgical',
                    'period': state.pathParameters['period']!,
                    'week': state.pathParameters['week']!,
                    'day': state.pathParameters['day']!,
                  }),
                ),
                GoRoute(
                  path: ':dateStr',
                  redirect: (context, state) => _withQuery('/readings', {
                    ...state.uri.queryParameters,
                    'date': state.pathParameters['dateStr']!,
                  }),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: prayerbookNavigatorKey,
          initialLocation: '/prayers',
          restorationScopeId: 'prayerbook-branch',
          observers: [
            BranchRouteObserver(appShellState.branches[AppBranch.prayerbook]!),
          ],
          routes: [
            GoRoute(
              path: '/prayers',
              pageBuilder: (context, state) => _branchPage(
                state,
                prayerbookRootRoute,
                const PrayersScreen(key: PageStorageKey('prayerbook-root')),
              ),
              routes: [
                GoRoute(
                  path: 'all',
                  pageBuilder: (context, state) => _branchPage(
                    state,
                    _prayerListRoute,
                    const PrayerCatalogScreen(),
                  ),
                ),
                GoRoute(
                  path: 'search',
                  pageBuilder: (context, state) => _branchPage(
                    state,
                    _prayerListRoute,
                    const PrayerCatalogScreen(searchInitially: true),
                  ),
                ),
                GoRoute(
                  path: 'categories',
                  pageBuilder: (context, state) => _branchPage(
                    state,
                    _prayerListRoute,
                    const PrayerCategoriesScreen(),
                  ),
                ),
                GoRoute(
                  path: 'category/:id',
                  pageBuilder: (context, state) => _branchPage(
                    state,
                    _prayerListRoute,
                    PrayerCategoryScreen(
                      categoryId: state.pathParameters['id']!,
                    ),
                  ),
                ),
                GoRoute(
                  path: 'favorites',
                  pageBuilder: (context, state) => _branchPage(
                    state,
                    _prayerListRoute,
                    const FavoritesScreen(),
                  ),
                ),
                GoRoute(
                  path: 'my',
                  pageBuilder: (context, state) => _branchPage(
                    state,
                    _prayerListRoute,
                    const MyPrayersScreen(),
                  ),
                ),
                GoRoute(
                  path: 'songs',
                  pageBuilder: (context, state) => _branchPage(
                    state,
                    _songbookRoute,
                    const SongbookScreen(),
                  ),
                  routes: [
                    GoRoute(
                      path: ':id',
                      pageBuilder: (context, state) => _branchPage(
                        state,
                        _songDetailRoute,
                        SongDetailScreen(songId: state.pathParameters['id']!),
                      ),
                    ),
                  ],
                ),
                GoRoute(
                  path: 'compendium',
                  pageBuilder: (context, state) => _branchPage(
                    state,
                    _compendiumRoute,
                    const CompendiumScreen(),
                  ),
                  routes: [
                    GoRoute(
                      path: 'part/:partId',
                      pageBuilder: (context, state) => _branchPage(
                        state,
                        _compendiumPartRoute,
                        CompendiumPartScreen(
                          partId: state.pathParameters['partId']!,
                          target: state.uri.queryParameters['target'],
                        ),
                      ),
                    ),
                    // Section and subsection screens.
                    GoRoute(
                      path: 'node/:nodeId',
                      pageBuilder: (context, state) => _branchPage(
                        state,
                        _compendiumNodeRoute,
                        CompendiumNodeScreen(
                          nodeId: state.pathParameters['nodeId']!,
                        ),
                      ),
                    ),
                    GoRoute(
                      path: 'topic/:topicId',
                      pageBuilder: (context, state) => _branchPage(
                        state,
                        _compendiumReaderRoute,
                        CompendiumTopicScreen(
                          topicId: state.pathParameters['topicId']!,
                        ),
                      ),
                    ),
                    GoRoute(
                      path: 'question/:number',
                      pageBuilder: (context, state) => _branchPage(
                        state,
                        _compendiumReaderRoute,
                        CompendiumQuestionScreen(
                          number: state.pathParameters['number']!,
                        ),
                      ),
                    ),
                  ],
                ),
                // The former Катэхізіс placeholder route opens the Compendium.
                GoRoute(
                  path: 'catechism',
                  redirect: (_, _) => '/prayers/compendium',
                ),
                // Stable placeholder; replace the screen, keep the route.
                GoRoute(
                  path: 'sacraments',
                  pageBuilder: (context, state) => _branchPage(
                    state,
                    _prayerbookSectionRoute,
                    const SacramentsPlaceholderScreen(),
                  ),
                ),
                GoRoute(
                  path: 'prayer/add',
                  pageBuilder: (context, state) => _branchPage(
                    state,
                    _prayerFormRoute,
                    const PrayerFormScreen(),
                  ),
                ),
                GoRoute(
                  path: 'prayer/:id/edit',
                  pageBuilder: (context, state) => _branchPage(
                    state,
                    _prayerFormRoute,
                    PrayerFormScreen(prayerId: state.pathParameters['id']!),
                  ),
                ),
                GoRoute(
                  path: 'prayer/:id',
                  pageBuilder: (context, state) => _branchPage(
                    state,
                    prayerDetailDescriptorFor(state.pathParameters['id']!),
                    PrayerDetailScreen(
                      prayerId: state.pathParameters['id']!,
                      massLanguage: state.uri.queryParameters['lang'],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: bibleNavigatorKey,
          initialLocation: '/bible',
          restorationScopeId: 'bible-branch',
          observers: [
            BranchRouteObserver(appShellState.branches[AppBranch.bible]!),
          ],
          routes: [
            GoRoute(
              path: '/bible',
              pageBuilder: (context, state) =>
                  _branchPage(state, bibleRootRoute, _bibleHost(state)),
              routes: [
                GoRoute(
                  path: 'search',
                  pageBuilder: (context, state) => _branchPage(
                    state,
                    _bibleSearchRoute,
                    _bibleSearchHost(state),
                  ),
                  routes: [
                    GoRoute(
                      path: 'result',
                      pageBuilder: (context, state) => _branchPage(
                        state,
                        _bibleSearchResultRoute,
                        _bibleHost(state),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    ),

    if (bottomNavigationLabEnabled)
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: bottomNavigationLabRoute,
        pageBuilder: (context, state) => MaterialPage<void>(
          key: state.pageKey,
          child: const BottomNavigationLabScreen(),
        ),
      ),

    // Compatibility aliases normalize directly to a canonical branch route.
    GoRoute(path: '/', redirect: (_, state) => _withSameQuery('/hours', state)),
    GoRoute(
      path: '/ora/:date/:dayId/:type',
      redirect: (_, state) => _withSameQuery(
        _encodedPath([
          'hours',
          'ora',
          state.pathParameters['date']!,
          state.pathParameters['dayId']!,
          state.pathParameters['type']!,
        ]),
        state,
      ),
    ),
    GoRoute(
      path: '/hora/:date/:dayId',
      redirect: (_, state) => _withSameQuery(
        _encodedPath([
          'hours',
          'hora',
          state.pathParameters['date']!,
          state.pathParameters['dayId']!,
        ]),
        state,
      ),
    ),
    GoRoute(
      path: '/reading/:readingId',
      redirect: (_, state) => _withSameQuery(
        _encodedPath([
          'readings',
          'reading',
          state.pathParameters['readingId']!,
        ]),
        state,
      ),
    ),
    GoRoute(
      path: '/prayer/add',
      redirect: (_, state) => _withSameQuery('/prayers/prayer/add', state),
    ),
    GoRoute(
      path: '/prayer/edit/:id',
      redirect: (_, state) => _withSameQuery(
        _encodedPath([
          'prayers',
          'prayer',
          state.pathParameters['id']!,
          'edit',
        ]),
        state,
      ),
    ),
    GoRoute(
      path: '/prayer/:id',
      redirect: (_, state) => _withSameQuery(
        _encodedPath(['prayers', 'prayer', state.pathParameters['id']!]),
        state,
      ),
    ),
    GoRoute(
      path: '/favorites',
      redirect: (_, state) => _withSameQuery('/prayers/favorites', state),
    ),
    GoRoute(
      path: '/my',
      redirect: (_, state) => _withSameQuery('/prayers/my', state),
    ),
    GoRoute(
      path: '/my-prayers',
      redirect: (_, state) => _withSameQuery('/prayers/my', state),
    ),
    GoRoute(
      path: '/bible/:version/:book/:chapter',
      redirect: (_, state) => _withQuery('/bible', {
        ...state.uri.queryParameters,
        'version': state.pathParameters['version']!,
        'book': state.pathParameters['book']!,
        'chapter': state.pathParameters['chapter']!,
      }),
    ),
    GoRoute(
      path: '/picker',
      redirect: (_, state) => _withSameQuery(
        state.uri.queryParameters['mode'] == 'readings'
            ? '/readings/picker'
            : '/hours/picker',
        state,
      ),
    ),
    GoRoute(
      path: '/picker/options',
      redirect: (_, state) => _withSameQuery(
        state.uri.queryParameters['mode'] == 'readings'
            ? '/readings/picker/options'
            : '/hours/picker/options',
        state,
      ),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/settings',
      pageBuilder: (context, state) => MaterialPage<void>(
        key: state.pageKey,
        restorationId: 'settings',
        child: SecondaryPageScaffold(
          title: 'Налады',
          child: SettingsScreen(
            // `sync` is the former name of the section (old links).
            scrollToData: const {
              'data',
              'sync',
            }.contains(state.uri.queryParameters['section']),
          ),
        ),
      ),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/about',
      pageBuilder: (context, state) => MaterialPage<void>(
        key: state.pageKey,
        restorationId: 'about',
        child: const SecondaryPageScaffold(
          title: 'Інфармацыя',
          child: AboutScreen(),
        ),
      ),
    ),
  ],
);

String _initialLocation() {
  if (bottomNavigationLabEnabled) return bottomNavigationLabRoute;
  try {
    final box = HiveService.settingsBox;
    return startSectionLocation(
      box.get('startSection', defaultValue: 'hours') as String,
      box.get('lastSection', defaultValue: 'hours') as String,
    );
  } catch (_) {
    return '/hours';
  }
}

/// The Mass (any of its language variant ids) opens as the dedicated Mass
/// reader; every other prayer keeps the ordinary prayer reader route.
AppRouteDescriptor prayerDetailDescriptorFor(String prayerId) =>
    kMassRitual.variantForPrayerId(prayerId) != null
    ? massReaderRoute
    : _prayerDetailRoute;

Page<void> _branchPage(
  GoRouterState state,
  AppRouteDescriptor descriptor,
  Widget child,
) {
  final entry = AppRouteEntry(
    id: state.pageKey.value,
    descriptor: descriptor,
    documentKey: state.uri.toString(),
  );
  return _ShellFadePage<void>(
    key: state.pageKey,
    name: state.matchedLocation,
    arguments: entry,
    restorationId: '${descriptor.id}-${state.pageKey.value}',
    child: AppRouteEntryAdapter(
      entry: entry,
      controller: appShellState.branches[descriptor.branch]!,
      child: child,
    ),
  );
}

Widget _readingsHost(GoRouterState state) {
  final query = state.uri.queryParameters;
  if (query['mode'] == 'liturgical') {
    final period = query['period'];
    final week = int.tryParse(query['week'] ?? '');
    final day = int.tryParse(query['day'] ?? '');
    if (period == null || period.isEmpty || week == null || day == null) {
      return const ReadingsBranchHost(
        invalidContext: 'Некарэктны літургічны кантэкст чытанняў.',
      );
    }
    return ReadingsBranchHost(
      liturgicalKey: '$period/$week/$day',
      dayId: query['dayId'],
    );
  }
  final rawDate = query['date'];
  if (rawDate == null) return const ReadingsBranchHost();
  final date = _parseDate(rawDate);
  if (date == null) {
    return const ReadingsBranchHost(
      invalidContext: 'Некарэктная дата чытанняў.',
    );
  }
  return ReadingsBranchHost(date: date, dayId: query['dayId']);
}

Widget _bibleHost(GoRouterState state) {
  final query = state.uri.queryParameters;
  final rawChapter = query['chapter'];
  final chapter = rawChapter == null ? null : int.tryParse(rawChapter);
  if (rawChapter != null && chapter == null) {
    return const BibleBranchHost(
      invalidContext: 'Некарэктны нумар раздзела Бібліі.',
    );
  }
  return BibleBranchHost(
    version: query['version'],
    book: query['book'],
    chapter: chapter,
  );
}

Widget _bibleSearchHost(GoRouterState state) {
  final query = state.uri.queryParameters;
  final version = query['version'];
  final book = query['book'];
  if (version == null || book == null) {
    return const BibleBranchHost(
      invalidContext: 'Некарэктны кантэкст пошуку ў Бібліі.',
    );
  }
  return BibleSearchScreen(versionId: version, bookId: book);
}

Widget _pickerOptions(GoRouterState state) {
  final period = state.uri.queryParameters['period'] ?? '';
  final week = int.tryParse(state.uri.queryParameters['week'] ?? '') ?? 0;
  final day = int.tryParse(state.uri.queryParameters['day'] ?? '') ?? 1;
  return LiturgicalDayOptionsScreen(period: period, week: week, day: day);
}

DateTime? _parseDate(String? value) {
  if (value == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    return null;
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null || _dateKey(parsed) != value) return null;
  return DateUtils.dateOnly(parsed);
}

String _dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

String _encodedPath(List<String> segments) =>
    Uri(pathSegments: ['', ...segments]).path;
String _withSameQuery(String path, GoRouterState state) =>
    _withQuery(path, state.uri.queryParameters);
String _withQuery(String path, Map<String, String> query) =>
    Uri(path: path, queryParameters: query.isEmpty ? null : query).toString();

class _ShellFadePage<T> extends MaterialPage<T> {
  const _ShellFadePage({
    required super.child,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
  });
}

class _InvalidRoute extends StatelessWidget {
  const _InvalidRoute({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text(message)));
}
