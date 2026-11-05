// Real offline bundle + production router/OraScreen. No Firebase initialization.
// flutter run -d chrome -t tool/high_priest_daytime_smoke.dart --web-port 5240
// Query: ?hour=terz|sext|none&theme=light|dark&scale=large
import 'dart:js_interop';

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
  final params = Uri.base.queryParameters;
  final hour = const {'terz', 'sext', 'none'}.contains(params['hour'])
      ? params['hour']!
      : 'terz';
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
  final routeHour = hour == 'none' ? 'non' : hour;
  router.go(
    '/ora/2026-05-28/feast-christthehighpriest/$routeHour?diocese=pinsk',
  );
  runApp(
    UncontrolledProviderScope(container: container, child: const _SmokeApp()),
  );
  // ReaderContentSurface merges its accessibility text into one document.
  // This smoke-only bridge finds the real rendered paragraph so the browser
  // can reach it without changing OraScreen or adding production UI controls.
  _scrollBridge = ((JSString needle) => _scrollToText(needle.toDart).toJS).toJS;
}

@JS('highPriestScrollTo')
external set _scrollBridge(JSFunction callback);

Future<JSBoolean> _scrollToText(String needle) async {
  Element? target;
  var shortest = 1 << 30;
  void visit(Element element) {
    final widget = element.widget;
    final text = switch (widget) {
      RichText() => widget.text.toPlainText(),
      Text() => widget.data ?? widget.textSpan?.toPlainText() ?? '',
      _ => '',
    };
    if (text.contains(needle) && text.length < shortest) {
      target = element;
      shortest = text.length;
    }
    element.visitChildElements(visit);
  }

  WidgetsBinding.instance.rootElement?.visitChildElements(visit);
  if (target == null) return false.toJS;
  await Scrollable.ensureVisible(
    target!,
    alignment: 0.15,
    duration: const Duration(milliseconds: 250),
  );
  return true.toJS;
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
      title: 'High Priest daytime offline smoke',
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
