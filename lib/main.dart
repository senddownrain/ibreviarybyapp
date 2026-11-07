import 'package:google_fonts/google_fonts.dart';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:mybrev_flutter/analytics/local_analytics.dart';
import 'package:mybrev_flutter/discovery/discovery.dart';
import 'package:mybrev_flutter/discovery/discovery_qa_mode.dart';
import 'package:mybrev_flutter/dev/discovery_qa_flags.dart';
import 'package:mybrev_flutter/firebase_options.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/discovery/p2_navigation.dart';
import 'package:mybrev_flutter/router/discovery_navigation.dart';
import 'package:mybrev_flutter/router/router.dart';
import 'package:mybrev_flutter/services/firebase_bootstrap.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/theme/app_theme.dart';
import 'package:mybrev_flutter/theme/app_theme_preference.dart';
import 'package:mybrev_flutter/theme/glass.dart';
import 'package:mybrev_flutter/theme/app_theme_controller.dart';
import 'package:mybrev_flutter/theme/platform_design.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:mybrev_flutter/widgets/priest_access_lifecycle.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  await ensureFirebaseInitialized(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  if (!kIsWeb) {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
    );
  }
  if (const bool.fromEnvironment('PRIEST_USE_EMULATORS')) {
    const host = String.fromEnvironment('FIREBASE_EMULATOR_HOST');
    if (!kDebugMode || !['localhost', '127.0.0.1', '10.0.2.2'].contains(host)) {
      throw StateError(
        'Firebase emulators require a debug build and a local host',
      );
    }
    FirebaseFirestore.instance.useFirestoreEmulator(
      host,
      const int.fromEnvironment('FIRESTORE_EMULATOR_PORT', defaultValue: 8089),
    );
  }
  await HiveService.init();
  if (!kIsWeb) {
    try {
      await HiveService.sanitizeLegacyFirestoreCache(
        FirebaseFirestore.instance.clearPersistence,
      );
    } catch (_) {
      debugPrint('[PriestAccess] Legacy Firestore cache cleanup will retry.');
    }
  }
  _registerFontLicenses();

  // Both designs are edge-to-edge. Platform chrome floats above the content;
  // only iOS uses blur while Android uses tonal Material surfaces.
  if (!kIsWeb) {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemStatusBarContrastEnforced: false,
        systemNavigationBarContrastEnforced: false,
        statusBarBrightness: Brightness.light,
      ),
    );
  }

  // The hint hosts stay silent until the active storage box is open.
  String? discoveryBoxPath;
  final discoveryStorage = discoveryQaActive
      ? qaDiscoveryStorage()
      : HiveDiscoveryStorage();
  try {
    discoveryBoxPath = (await Hive.openBox<String>(
      discoveryQaActive ? kDiscoveryQaBox : HiveDiscoveryStorage.defaultBoxName,
    )).path;
  } catch (error) {
    debugPrint('[Discovery] hint box unavailable: $error');
  }
  // Test profile only: forget the hint history (the discovery box alone).
  if (discoveryQaResetRequested(discoveryBoxPath)) {
    await discoveryStorage.clear();
  }

  runApp(
    ProviderScope(
      overrides: [
        ...discoveryAppOverrides(),
        discoveryRouteOpenerProvider.overrideWithValue(openDiscoveryRoute),
      ],
      child: const MyBrevApp(),
    ),
  );
  // Test builds only (--dart-define=ANALYTICS_LOCAL=true); decision D-10 = B.
  if (kAnalyticsLocal) unawaited(LocalAnalytics.start(router));
  unawaited(
    HiveService.migrateFormerCache().catchError((Object error) {
      debugPrint('[ContentMigration] $error');
    }),
  );
}

/// The bundled book faces (assets/google_fonts) are under the SIL Open Font
/// License; it is shown in «Інфармацыя пра дадатак» → licences.
void _registerFontLicenses() {
  const families = {
    'cormorantgaramond': 'Cormorant Garamond',
    'literata': 'Literata',
    'sourceserif4': 'Source Serif 4',
    'oldstandardtt': 'Old Standard TT',
    'kurale': 'Kurale',
  };
  LicenseRegistry.addLicense(() async* {
    for (final entry in families.entries) {
      final text = await rootBundle.loadString(
        'assets/google_fonts/OFL-${entry.key}.txt',
      );
      yield LicenseEntryWithLineBreaks([entry.value], text);
    }
  });
}

class MyBrevApp extends ConsumerWidget {
  const MyBrevApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    if (!kIsWeb) {
      WakelockPlus.toggle(enable: settings.keepScreenOn);
    }

    // Content stays consistent with the PWA. Navigation and system controls
    // adapt inside the shared theme and the platform-chrome widgets.
    return ValueListenableBuilder<AppThemePreference>(
      valueListenable: appThemePreferenceController,
      builder: (context, preference, _) {
        final schemes = AppPalette.schemesFor(preference);
        return _buildApp(preference, schemes.theme, schemes.darkTheme);
      },
    );
  }

  Widget _buildApp(
    AppThemePreference preference,
    ColorScheme light,
    ColorScheme dark,
  ) {
    return MaterialApp.router(
      // Keep this boundary stable: rebuilding colors must not dispose readers,
      // branch navigators, open sheets or their scroll/chrome controllers.
      title: 'Mybrev',
      restorationScopeId: 'ibreviary-app',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: Theme.of(context).appBarTheme.systemOverlayStyle!,
        child: PriestAccessLifecycle(child: child ?? const SizedBox.shrink()),
      ),
      themeMode: preference.themeMode,
      themeAnimationDuration: Duration.zero,
      theme: buildAppTheme(light, preference: preference),
      darkTheme: buildAppTheme(dark, preference: preference),
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

/// Shared production theme assembly, also used by isolated visual/test hosts.
ThemeData buildAppTheme(
  ColorScheme cs, {
  required AppThemePreference preference,
  TargetPlatform? platform,
}) {
  final targetPlatform = platform ?? appTargetPlatform();
  final isIOS = targetPlatform == TargetPlatform.iOS;

  // Build from brightness first so textTheme colors match light/dark.
  // GoogleFonts.getTextTheme without a base returns light-mode (dark) ink
  // and makes body/title text unreadable on dark surfaces.
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    brightness: cs.brightness,
    platform: targetPlatform,
    extensions: [
      AppPalette.colorsFor(preference, cs.brightness),
      preference == AppThemePreference.marian
          ? GlassDecoration.marian
          : GlassDecoration.forBrightness(cs.brightness),
    ],
  );
  return base.copyWith(
    platform: targetPlatform,
    splashFactory: isIOS ? NoSplash.splashFactory : InkSparkle.splashFactory,
    highlightColor: isIOS ? Colors.transparent : null,
    cupertinoOverrideTheme: CupertinoThemeData(
      primaryColor: cs.primary,
      brightness: cs.brightness,
      scaffoldBackgroundColor: cs.surfaceContainerLowest,
    ),
    // Application chrome follows the real platform typography. Book faces
    // are applied only inside ReadingScaffold/ReaderTheme.
    textTheme: base.textTheme,
    scaffoldBackgroundColor: cs.surfaceContainerLowest,
    dividerTheme: DividerThemeData(
      color: cs.outlineVariant,
      thickness: 0.7,
      space: 1,
    ),
    cardTheme: CardThemeData(
      color: cs.surface.withValues(alpha: 0.92),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: cs.outlineVariant, width: 0.7),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cs.surface.withValues(alpha: 0.88),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: cs.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: cs.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: cs.primary, width: 1.4),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: Colors.transparent,
      selectedColor: cs.tertiaryContainer,
      side: BorderSide(color: cs.outlineVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      labelStyle: TextStyle(color: cs.onSurfaceVariant),
    ),
    drawerTheme: DrawerThemeData(
      backgroundColor: cs.surface.withValues(alpha: 0.97),
      surfaceTintColor: Colors.transparent,
      width: 320,
      shape: const RoundedRectangleBorder(),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: cs.onSurfaceVariant,
      textColor: cs.onSurface,
      selectedColor: cs.primary,
      selectedTileColor: cs.primary.withValues(alpha: 0.11),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isIOS ? 24 : 18),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isIOS ? 24 : 18),
        ),
        side: BorderSide(color: cs.outlineVariant),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(shape: const StadiumBorder()),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      elevation: 8,
      highlightElevation: 4,
      backgroundColor: cs.surface,
      foregroundColor: cs.primary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isIOS ? 24 : 20),
        side: BorderSide(color: cs.outlineVariant),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: cs.surface.withValues(alpha: 0.98),
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: cs.surface.withValues(alpha: 0.98),
      modalElevation: 16,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: cs.surface.withValues(alpha: 0.98),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(color: cs.outlineVariant),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: cs.inverseSurface,
      contentTextStyle: TextStyle(color: cs.onInverseSurface),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: isIOS,
      // Transparent so BlurAppBar can paint its own background
      backgroundColor: Colors.transparent,
      foregroundColor: cs.onSurface,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        statusBarIconBrightness: cs.brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
        statusBarBrightness: cs.brightness == Brightness.dark
            ? Brightness.dark
            : Brightness.light,
        systemNavigationBarIconBrightness: cs.brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
        systemStatusBarContrastEnforced: false,
        systemNavigationBarContrastEnforced: false,
      ),
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
