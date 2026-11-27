// Offline acceptance stand: real bundled liturgical texts, production router,
// settings and reader. No Firebase initialization or content writes.
// flutter run -d chrome -t tool/psalmody_modes_smoke.dart --web-port 5294
// ?mode=leftBreakIndent&hour=laudes&theme=dark&scale=2&platform=ios
// ?view=settings or ?view=hours (open the calendar to inspect common texts).
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/models/psalmody_preferences.dart';
import 'package:mybrev_flutter/providers/connectivity_provider.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/router/router.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/theme/app_theme.dart';
import 'package:mybrev_flutter/theme/ib_colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  await initializeDateFormatting('be');
  // A harness is not a first launch: no welcome screen over its route.
  await HiveService.init(detectFirstLaunch: false);
  await HiveService.content.ensureLoaded(kLiturgicalCollections);
  final q = Uri.base.queryParameters;
  final container = ProviderContainer(
    overrides: [
      isOfflineProvider.overrideWithValue(true),
      connectivityProvider.overrideWith((ref) => Stream.value(false)),
    ],
  );
  final settings = container.read(settingsProvider.notifier);
  settings.setThemeMode(
    q['theme'] == 'dark' ? ThemeMode.dark : ThemeMode.light,
  );
  if (q.containsKey('mode')) {
    await settings.setPsalmodyMode(resolvePsalmodyMode(storedMode: q['mode']));
  }
  final date = q['date'] ?? '2026-08-27';
  final day = q['dayId'] ?? '27-08-sv-monica';
  router.go(switch (q['view']) {
    'settings' => '/settings',
    'hours' => '/hours?date=$date&dayId=$day',
    _ => '/hours/ora/$date/$day/${q['hour'] ?? 'laudes'}?diocese=minsk-mohilev',
  });
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: _SmokeApp(query: q),
    ),
  );
}

class _SmokeApp extends ConsumerWidget {
  const _SmokeApp({required this.query});
  final Map<String, String> query;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ThemeData theme(Brightness brightness) => ThemeData(
      platform: query['platform'] == 'ios'
          ? TargetPlatform.iOS
          : TargetPlatform.android,
      useMaterial3: true,
      brightness: brightness,
      colorScheme: AppPalette.scheme(brightness),
      extensions: [IbColors.forBrightness(brightness)],
    );
    return MaterialApp.router(
      title: 'Psalmody · bundled offline Flutter',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      themeMode: ref.watch(settingsProvider).themeMode,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('be')],
      locale: const Locale('be'),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(
            double.tryParse(query['scale'] ?? '') ?? 1,
          ),
        ),
        child: child!,
      ),
    );
  }
}
