import 'dart:io';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/router/router.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

// Brand seed — used when Material You is unavailable
const _kSeedColor = Color(0xFF3A5FA0);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await HiveService.init();

  // Transparent status bar so blurred AppBar can show beneath it on iOS
  if (Platform.isIOS) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: Brightness.light,
    ));
  }

  runApp(const ProviderScope(child: MyBrevApp()));
}

class MyBrevApp extends ConsumerWidget {
  const MyBrevApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    WakelockPlus.toggle(enable: settings.keepScreenOn);

    // Android uses DynamicColorBuilder (Material You).
    // iOS gets a fixed seed scheme.
    if (Platform.isAndroid) {
      return DynamicColorBuilder(
        builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
          final light = _harmonize(lightDynamic, Brightness.light);
          final dark  = _harmonize(darkDynamic,  Brightness.dark);
          return _buildApp(settings, light, dark);
        },
      );
    }

    final light = ColorScheme.fromSeed(seedColor: _kSeedColor, brightness: Brightness.light);
    final dark  = ColorScheme.fromSeed(seedColor: _kSeedColor, brightness: Brightness.dark);
    return _buildApp(settings, light, dark);
  }

  ColorScheme _harmonize(ColorScheme? dynamic, Brightness brightness) {
    if (dynamic != null) return dynamic.harmonized();
    return ColorScheme.fromSeed(seedColor: _kSeedColor, brightness: brightness);
  }

  Widget _buildApp(SettingsState settings, ColorScheme light, ColorScheme dark) {
    final isIOS = Platform.isIOS;
    final customFont = settings.resolvedFontFamily != null;

    ThemeData makeTheme(ColorScheme cs) {
      // Build from brightness first so textTheme colors match light/dark.
      // GoogleFonts.getTextTheme without a base returns light-mode (dark) ink
      // and makes body/title text unreadable on dark surfaces.
      final base = ThemeData(
        useMaterial3: true,
        colorScheme: cs,
        brightness: cs.brightness,
      );
      final textTheme = customFont
          ? GoogleFonts.getTextTheme(settings.fontFamily, base.textTheme)
          : base.textTheme;

      return base.copyWith(
        textTheme: textTheme,
        appBarTheme: AppBarTheme(
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: isIOS,
          // Transparent so BlurAppBar can paint its own background
          backgroundColor: isIOS ? Colors.transparent : cs.surface,
          foregroundColor: cs.onSurface,
          systemOverlayStyle: cs.brightness == Brightness.dark
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark,
        ),
        pageTransitionsTheme: PageTransitionsTheme(
          builders: {
            TargetPlatform.iOS: const CupertinoPageTransitionsBuilder(),
            TargetPlatform.android: isIOS
                ? const FadeUpwardsPageTransitionsBuilder()
                : const PredictiveBackPageTransitionsBuilder(),
          },
        ),
        // Android: tonal surface elevation (Material You)
        navigationBarTheme: NavigationBarThemeData(
          indicatorColor: cs.secondaryContainer,
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ),
      );
    }

    return MaterialApp.router(
      title: 'Mybrev',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      themeMode: settings.themeMode,
      theme: makeTheme(light),
      darkTheme: makeTheme(dark),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('be'),
        Locale('ru'),
        Locale('pl'),
        Locale('en'),
      ],
      locale: const Locale('be'),
    );
  }
}
