import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:mybrev_flutter/main.dart' show buildAppTheme;
import 'package:mybrev_flutter/providers/connectivity_provider.dart';
import 'package:mybrev_flutter/providers/content_updates_provider.dart';
import 'package:mybrev_flutter/providers/priest_access_provider.dart';
import 'package:mybrev_flutter/screens/about_screen.dart';
import 'package:mybrev_flutter/screens/feedback_screen.dart';
import 'package:mybrev_flutter/screens/settings_screen.dart';
import 'package:mybrev_flutter/services/priest_access_gateway.dart';
import 'package:mybrev_flutter/services/priest_access_storage.dart';
import 'package:mybrev_flutter/theme/app_theme.dart';
import 'package:mybrev_flutter/theme/app_theme_controller.dart';
import 'package:mybrev_flutter/theme/app_theme_preference.dart';
import 'package:mybrev_flutter/widgets/branch_hosts.dart';

/// The production screen and theme with offline fixtures and a local Hive box.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  await Hive.openBox('settings');
  final router = GoRouter(
    initialLocation: '/settings',
    routes: [
      GoRoute(
        path: '/settings',
        builder: (context, state) => SecondaryPageScaffold(
          title: 'Налады',
          child: SettingsScreen(
            scrollToData: const {
              'data',
              'sync',
            }.contains(state.uri.queryParameters['section']),
          ),
        ),
      ),
      GoRoute(
        path: '/settings/feedback',
        builder: (context, state) => const SecondaryPageScaffold(
          title: 'Зваротная сувязь',
          child: FeedbackScreen(),
        ),
      ),
      GoRoute(
        path: '/about',
        builder: (context, state) => const SecondaryPageScaffold(
          title: 'Інфармацыя',
          child: AboutScreen(),
        ),
      ),
    ],
  );
  final scale = double.tryParse(Uri.base.queryParameters['scale'] ?? '') ?? 1;
  runApp(
    ProviderScope(
      overrides: [
        contentUpdatesProvider.overrideWith(_LocalUpdates.new),
        isOfflineProvider.overrideWithValue(false),
        priestAccessProvider.overrideWith(
          (_) => PriestAccessController(_OfflineGateway(), _LocalStorage()),
        ),
        protectedCatalogStorageProvider.overrideWithValue(null),
      ],
      child: ValueListenableBuilder<AppThemePreference>(
        valueListenable: appThemePreferenceController,
        builder: (context, preference, _) {
          final schemes = AppPalette.schemesFor(preference);
          return MaterialApp.router(
            routerConfig: router,
            debugShowCheckedModeBanner: false,
            themeMode: preference.themeMode,
            themeAnimationDuration: Duration.zero,
            theme: buildAppTheme(schemes.theme, preference: preference),
            darkTheme: buildAppTheme(schemes.darkTheme, preference: preference),
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            supportedLocales: const [Locale('be'), Locale('en')],
            locale: const Locale('be'),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
          );
        },
      ),
    ),
  );
}

class _LocalUpdates extends ContentUpdatesNotifier {
  @override
  ContentUpdateState build() => const ContentUpdateState();

  @override
  Future<void> check() async {}
}

class _OfflineGateway implements PriestAccessGateway {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Access requests are disabled in this fixture');
}

class _LocalStorage implements PriestAccessStorage {
  @override
  Future<Map<String, dynamic>> read() async => {};

  @override
  Future<void> write(Map<String, dynamic> data) async {}
}
