// Isolated offline harness: real assets, engine, providers and production routes.
// flutter run -d chrome -t tool/approved_calendar_smoke.dart --web-port 5242
import 'dart:convert';
import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/ordo/runtime.dart';
import 'package:mybrev_flutter/providers/connectivity_provider.dart';
import 'package:mybrev_flutter/providers/diocese_provider.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_navigation_sync_provider.dart';
import 'package:mybrev_flutter/router/router.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/theme/app_theme.dart';
import 'package:mybrev_flutter/theme/ib_colors.dart';

@JS('approvedNavigate')
external set _navigateBridge(JSFunction callback);
@JS('approvedSnapshot')
external set _snapshotBridge(JSFunction callback);
@JS('approvedScroll')
external set _scrollBridge(JSFunction callback);
late ProviderContainer _container;
String _date = '2026-09-08', _diocese = 'vitebsk';

void _navigate(String date, String diocese, String view) {
  _date = date;
  _diocese = diocese;
  final selection = _container.read(dioceseSelectionProvider.notifier);
  selection.setPrimary(diocese);
  for (final other in [..._container.read(dioceseSelectionProvider).selected]) {
    if (other != diocese) selection.toggle(other);
  }
  _container
      .read(liturgicalNavigationControllerProvider)
      .openDate(DateTime.parse(date));
  router.go(switch (view) {
    'hours' => '/hours?date=$date',
    'readings' => '/readings?date=$date&diocese=$diocese',
    'month' => '/hours/ordo/month?date=$date',
    _ => '/hours/ordo?date=$date&diocese=$diocese',
  });
}

String _snapshot() {
  final text = <String>[];
  void visit(Element e) {
    if (e.widget case Offstage(offstage: true)) return;
    if (e.widget case Text(:final data, :final textSpan)) {
      final value = data ?? textSpan?.toPlainText() ?? '';
      if (value.isNotEmpty) text.add(value);
    }
    e.visitChildElements(visit);
  }

  WidgetsBinding.instance.rootElement?.visitChildElements(visit);
  final day = OrdoRuntime.engine.resolve(_date, diocese: _diocese);
  return jsonEncode({
    'date': _date,
    'diocese': _diocese,
    'primary': day.primary.id,
    'rank': day.primary.rank,
    'alternatives': day.alternatives.map((o) => o.id).toList(),
    'route': router.routeInformationProvider.value.uri.toString(),
    'text': text,
  });
}

Future<bool> _scroll(String needle) async {
  Element? target;
  void visit(Element e) {
    if (e.widget case Offstage(offstage: true)) return;
    if (e.widget case Text(:final data, :final textSpan)) {
      if ((data ?? textSpan?.toPlainText() ?? '').contains(needle)) target = e;
    }
    e.visitChildElements(visit);
  }

  WidgetsBinding.instance.rootElement?.visitChildElements(visit);
  if (target == null) return false;
  await Scrollable.ensureVisible(target!, alignment: .15);
  return true;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  await initializeDateFormatting('be');
  // A harness is not a first launch: no welcome screen over its route.
  await HiveService.init(detectFirstLaunch: false);
  await HiveService.content.ensureLoaded(kContentCollections);
  final params = Uri.base.queryParameters;
  _container = ProviderContainer(
    overrides: [
      isOfflineProvider.overrideWithValue(true),
      connectivityProvider.overrideWith((ref) => Stream.value(false)),
    ],
  );
  _container
      .read(settingsProvider.notifier)
      .setThemeMode(
        params['theme'] == 'dark' ? ThemeMode.dark : ThemeMode.light,
      );
  _navigate(
    params['date'] ?? _date,
    params['diocese'] ?? _diocese,
    params['view'] ?? 'ordo',
  );
  runApp(
    UncontrolledProviderScope(
      container: _container,
      child: _SmokeApp(scale: double.tryParse(params['scale'] ?? '1') ?? 1),
    ),
  );
  _navigateBridge =
      ((JSString date, JSString diocese, JSString view) => _navigate(
        date.toDart,
        diocese.toDart,
        view.toDart,
      )).toJS;
  _snapshotBridge = (() => _snapshot().toJS).toJS;
  _scrollBridge = ((JSString text) => _scroll(text.toDart).toJS).toJS;
}

class _SmokeApp extends ConsumerWidget {
  const _SmokeApp({required this.scale});
  final double scale;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ThemeData theme(Brightness brightness) => ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: AppPalette.scheme(brightness),
      extensions: [IbColors.forBrightness(brightness)],
    );
    return MaterialApp.router(
      routerConfig: router,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      themeMode: ref.watch(settingsProvider).themeMode,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('be')],
      locale: const Locale('be'),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
    );
  }
}
