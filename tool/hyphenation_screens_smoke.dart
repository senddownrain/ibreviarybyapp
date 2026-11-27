// Real offline bundle + production router and screens (Mass readings, Liturgy
// of Hours). No Firebase initialization, no network, no data writes.
// flutter run -d chrome -t tool/hyphenation_screens_smoke.dart --web-port 5243
// Query: ?path=/readings/2026-11-12&theme=dark&scale=large&align=left
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/hyphenation/hyphenation_service.dart';
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
  await HiveService.init();
  await HiveService.content.ensureLoaded(kLiturgicalCollections);
  await BelarusianHyphenation.ensureLoaded();
  final params = Uri.base.queryParameters;
  final container = ProviderContainer(
    overrides: [
      isOfflineProvider.overrideWithValue(true),
      connectivityProvider.overrideWith((ref) => Stream.value(false)),
    ],
  );
  final settings = container.read(settingsProvider.notifier);
  settings.setThemeMode(
    params['theme'] == 'dark' ? ThemeMode.dark : ThemeMode.light,
  );
  settings.setFontSize(
    params['scale'] == 'large' ? kMaxReaderFontSize : kDefaultReaderFontSize,
  );
  settings.setTextAlignment(
    params['align'] == 'left' ? TextAlign.left : TextAlign.justify,
  );
  router.go(params['path'] ?? '/readings/2026-11-12?diocese=pinsk');
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
      title: 'Hyphenation offline smoke',
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
