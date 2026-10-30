// Offline visual smoke of the D-1 reading choices in the Hour of Readings.
// flutter run -d chrome -t tool/d1_reading_choices_smoke.dart --web-port 5291
// query: ?date=2026-08-27&dayId=27-08-sv-monica&hour=lectionis&theme=dark&scale=large
// No Firebase initialization, remote services or production writes.
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
  await HiveService.init();
  await HiveService.content.ensureLoaded(kLiturgicalCollections);
  final query = Uri.base.queryParameters;
  final container = ProviderContainer(
    overrides: [
      isOfflineProvider.overrideWithValue(true),
      connectivityProvider.overrideWith((ref) => Stream.value(false)),
    ],
  );
  final settings = container.read(settingsProvider.notifier);
  settings.setThemeMode(
    query['theme'] == 'dark' ? ThemeMode.dark : ThemeMode.light,
  );
  settings.setFontSize(
    query['scale'] == 'large' ? kMaxReaderFontSize : kDefaultReaderFontSize,
  );
  final date = query['date'] ?? '2026-08-27';
  final dayId = query['dayId'] ?? '27-08-sv-monica';
  final hour = query['hour'] ?? 'lectionis';
  router.go('/hours/ora/$date/$dayId/$hour?diocese=minsk-mohilev');
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
      title: 'D-1 reading choices offline smoke',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      themeMode: settings.themeMode,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('be')],
      locale: const Locale('be'),
    );
  }
}
