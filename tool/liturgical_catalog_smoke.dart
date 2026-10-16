/// Offline Chrome visual smoke of the production picker and router.
/// flutter run -d chrome -t tool/liturgical_catalog_smoke.dart --web-port 5241
/// URL query: ?dark=1&scale=2&width=320&mode=readings
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/content/content_store.dart';
import 'package:mybrev_flutter/providers/content_updates_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/providers/diocese_provider.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/router/router.dart' as production;
import 'package:mybrev_flutter/services/hive_service.dart';

class _Offline extends ContentUpdatesNotifier {
  @override
  ContentUpdateState build() => const ContentUpdateState();
  @override
  Future<void> checkIfDue() async {}
}

class _Settings extends SettingsNotifier {
  @override
  SettingsState build() => const SettingsState();
  @override
  void rememberLastSection(String section) {}
}

class _Dioceses extends DioceseSelectionNotifier {
  @override
  DioceseSelection build() => DioceseSelection.initial;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SemanticsBinding.instance.ensureSemantics();
  GoogleFonts.config.allowRuntimeFetching = false;
  await initializeDateFormatting('be');
  await HiveService.init(path: 'catalog-offline-smoke');
  await ContentStore.instance.ensureLoaded(kLiturgicalCollections);
  final query = Uri.base.queryParameters;
  final mode = query['mode'] == 'readings' ? 'readings' : 'hours';
  final width = double.tryParse(query['width'] ?? '') ?? 390;
  final scale = double.tryParse(query['scale'] ?? '') ?? 1;
  final router = GoRouter(
    navigatorKey: production.rootNavigatorKey,
    initialLocation: '/$mode/picker',
    routes: production.router.configuration.routes,
  );
  runApp(
    ProviderScope(
      overrides: [
        contentUpdatesProvider.overrideWith(_Offline.new),
        settingsProvider.overrideWith(_Settings.new),
        dioceseSelectionProvider.overrideWith(_Dioceses.new),
        selectedDateProvider.overrideWith((ref) => DateTime(2026, 12, 6)),
        liturgicalContentReadyProvider.overrideWith((ref) async {}),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme: ThemeData(
          useMaterial3: true,
          brightness: query['dark'] == '1' ? Brightness.dark : Brightness.light,
        ),
        builder: (context, child) => Center(
          child: SizedBox(
            width: width,
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                size: Size(width, MediaQuery.sizeOf(context).height),
                textScaler: TextScaler.linear(scale),
              ),
              child: child!,
            ),
          ),
        ),
      ),
    ),
  );
}
