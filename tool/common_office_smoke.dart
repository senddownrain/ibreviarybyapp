// Offline visual smoke of the existing picker and Hours screens.
// flutter run -d chrome -t tool/common_office_smoke.dart --web-port 5238
// No Firebase initialization, remote services or synthetic production writes.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mybrev_flutter/content/content_bundle.dart';
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
  final container = ProviderContainer(
    overrides: [
      isOfflineProvider.overrideWithValue(true),
      connectivityProvider.overrideWith((ref) => Stream.value(false)),
    ],
  );
  final settings = container.read(settingsProvider.notifier);
  settings.setThemeMode(
    Uri.base.queryParameters['theme'] == 'dark'
        ? ThemeMode.dark
        : ThemeMode.light,
  );
  settings.setFontSize(
    Uri.base.queryParameters['scale'] == 'large'
        ? kMaxReaderFontSize
        : kDefaultReaderFontSize,
  );
  router.go(
    '/hours?date=2026-10-19&dayId=19-10-sv-paul-of-cross&diocese=minsk-mohilev',
  );
  runApp(
    UncontrolledProviderScope(container: container, child: const _SmokeApp()),
  );
}

class _SmokeApp extends ConsumerWidget {
  const _SmokeApp();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    ThemeData theme(Brightness brightness) => ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: AppPalette.scheme(brightness),
      extensions: [IbColors.forBrightness(brightness)],
    );
    return MaterialApp.router(
      title: 'Common office offline smoke',
      routerConfig: router,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      themeMode: settings.themeMode,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('be')],
      locale: const Locale('be'),
    );
  }
}
