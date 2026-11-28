import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mybrev_flutter/dev/prayer_categories_harness.dart';
import 'package:mybrev_flutter/novena/novena_providers.dart';
import 'package:mybrev_flutter/novena/novena_schedule.dart';
import 'package:mybrev_flutter/novena/novena_store.dart';
import 'package:mybrev_flutter/novena/ui/novena_day_watcher.dart';
import 'package:mybrev_flutter/novena/ui/novena_routes.dart';
import 'package:mybrev_flutter/providers/admin_songbook_access_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/providers/local_prayers_provider.dart';
import 'package:mybrev_flutter/providers/prayer_categories_provider.dart';
import 'package:mybrev_flutter/providers/prayers_provider.dart';
import 'package:mybrev_flutter/providers/priest_access_provider.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/screens/prayer_detail_screen.dart';
import 'package:mybrev_flutter/screens/prayers_screen.dart';
import 'package:mybrev_flutter/theme/app_theme.dart';
import 'package:mybrev_flutter/theme/reader.dart';

/// The real novena screens over given definitions and public prayers.
/// No Firebase, credentials, network or production reads; progress goes to
/// [box] only.
class NovenaHarness extends StatefulWidget {
  const NovenaHarness({
    super.key,
    required this.content,
    required this.definitions,
    required this.box,
    required this.clock,
    this.initialLocation = '/prayers',
    this.scheme = 'light',
    this.scale = 1,
    this.platform = TargetPlatform.android,
    this.feastDates,
  });

  final PrayerAccessContent content;

  /// `novenaDefinitions` documents.
  final List<Map> definitions;
  final NovenaBox box;
  final DateTime Function() clock;
  final String initialLocation;
  final String scheme;
  final double scale;
  final TargetPlatform platform;
  final NovenaFeastDate? feastDates;

  /// A definition of the reference generator, published as the admin would.
  static Map<String, dynamic> published(Map definition) => {
    ...definition.cast<String, dynamic>(),
    'status': 'published',
    'trackerEnabled': true,
  };

  @override
  State<NovenaHarness> createState() => NovenaHarnessState();
}

class NovenaHarnessState extends State<NovenaHarness> {
  final navigator = GlobalKey<NavigatorState>();
  late final access = CategorySmokeAccess(widget.content);
  late final router = GoRouter(
    navigatorKey: navigator,
    initialLocation: widget.initialLocation,
    routes: [
      GoRoute(
        path: '/prayers',
        builder: (_, _) => const Scaffold(body: PrayersScreen()),
        routes: [
          GoRoute(
            path: 'prayer/:id',
            builder: (_, state) =>
                PrayerDetailScreen(prayerId: state.pathParameters['id']!),
          ),
        ],
      ),
      ...novenaRoutes(navigator),
    ],
  );

  @override
  void dispose() {
    router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [
      novenaBoxProvider.overrideWithValue(widget.box),
      novenaClockProvider.overrideWithValue(widget.clock),
      novenaDocumentsProvider.overrideWithValue(widget.definitions),
      if (widget.feastDates != null)
        novenaFeastDatesProvider.overrideWithValue(widget.feastDates),
      settingsProvider.overrideWith(CategorySmokeSettings.new),
      priestAccessProvider.overrideWith((ref) => access),
      adminSongbookAccessProvider.overrideWith((ref) => Stream.value(false)),
      liturgicalSeasonColorProvider.overrideWithValue(Colors.indigo),
      prayersContentProvider.overrideWith((ref) async {}),
      localPrayersProvider.overrideWith(_NoLocalPrayers.new),
      globalPrayerCategoriesProvider.overrideWith((ref) => Stream.value([])),
      protectedPrayerProvider.overrideWith((ref, id) async => null),
    ],
    child: ReaderTypographyScope(
      useSystemFonts: false,
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        routerConfig: router,
        theme: ThemeData(
          platform: widget.platform,
          colorScheme: switch (widget.scheme) {
            'marian' => AppPalette.marianScheme,
            'dark' => AppPalette.scheme(Brightness.dark),
            _ => AppPalette.scheme(Brightness.light),
          },
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(widget.scale)),
          child: NovenaDayWatcher(child: child!),
        ),
      ),
    ),
  );
}

class _NoLocalPrayers extends LocalPrayersNotifier {
  @override
  List<Never> build() => const [];
}
