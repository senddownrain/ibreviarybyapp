// Offline visual harness using production pages and routes, without Firebase.
// flutter run -d chrome -t tool/source_documents_smoke.dart --web-port 5241
// ?theme=dark&scale=2&path=/sources
// ?launchError=true exercises browser failure without opening an external page.
import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/constants/legal_links.dart';
import 'package:mybrev_flutter/router/router.dart';
import 'package:mybrev_flutter/screens/about_screen.dart';
import 'package:mybrev_flutter/screens/source_documents_screen.dart';
import 'package:mybrev_flutter/theme/app_theme.dart';
import 'package:mybrev_flutter/theme/ib_colors.dart';
import 'package:mybrev_flutter/widgets/branch_hosts.dart';

class _Settings extends SettingsNotifier {
  @override
  SettingsState build() => const SettingsState();
}

@JS('sourceSmokeScroll')
external set _scrollBridge(JSFunction callback);
@JS('sourceSmokeSnapshot')
external set _snapshotBridge(JSFunction callback);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  final params = Uri.base.queryParameters;
  router.go(params['path'] ?? '/about');
  runApp(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith(_Settings.new),
        if (params['launchError'] == 'true')
          sourceDocumentLauncherProvider.overrideWithValue(
            (uri, mode) async => false,
          ),
      ],
      child: _SmokeApp(
        dark: params['theme'] == 'dark',
        scale: double.tryParse(params['scale'] ?? '') ?? 1,
      ),
    ),
  );
  _scrollBridge = ((JSString needle) => _scrollToText(needle.toDart).toJS).toJS;
  _snapshotBridge = (() => _snapshot().toJS).toJS;
}

String _text(Widget widget) => switch (widget) {
  Text() => widget.data ?? widget.textSpan?.toPlainText() ?? '',
  _ => '',
};

String _route() {
  final config = router.routerDelegate.currentConfiguration;
  final last = config.last;
  return last is ImperativeRouteMatch ? last.matches.uri.path : config.uri.path;
}

// Inspect widgets without registering inherited-widget dependencies on arbitrary
// Elements. Navigator retains previous pages while another route is displayed.
bool _inactive(Widget widget, String route) {
  if (widget case SecondaryPageScaffold(child: final child)) {
    final path = switch (child) {
      AboutScreen() => '/about',
      SourcesScreen() => '/sources',
      _ => null,
    };
    return path != null && path != route;
  }
  return false;
}

Future<JSBoolean> _scrollToText(String needle) async {
  Element? target;
  var shortest = 1 << 30;
  final route = _route();
  void visit(Element e) {
    if (e.widget case Offstage(offstage: true)) {
      return;
    }
    if (_inactive(e.widget, route)) {
      return;
    }
    final text = _text(e.widget);
    if (text.contains(needle) && text.length < shortest) {
      target = e;
      shortest = text.length;
    }
    e.visitChildElements(visit);
  }

  WidgetsBinding.instance.rootElement?.visitChildElements(visit);
  if (target == null) return false.toJS;
  await Scrollable.ensureVisible(target!, alignment: .12);
  return true.toJS;
}

String _snapshot() {
  final text = <String>[];
  final overflow = <String>[];
  final route = _route();
  final view = WidgetsBinding.instance.platformDispatcher.views.first;
  final screen = view.physicalSize.width / view.devicePixelRatio;
  void visit(Element e) {
    if (e.widget case Offstage(offstage: true)) {
      return;
    }
    if (_inactive(e.widget, route)) {
      return;
    }
    final s = _text(e.widget);
    if (s.isNotEmpty) text.add(s);
    final render = e.renderObject;
    if (render is RenderParagraph && render.attached && render.hasSize) {
      if (render.didExceedMaxLines) {
        overflow.add('Truncated: ${render.text.toPlainText()}');
      }
      final left = render.localToGlobal(Offset.zero).dx;
      if (left < -1 || left + render.size.width > screen + 1) {
        overflow.add(render.text.toPlainText());
      }
    }
    e.visitChildElements(visit);
  }

  WidgetsBinding.instance.rootElement?.visitChildElements(visit);
  return jsonEncode({
    'text': text,
    'overflow': overflow,
    'route': route,
    'links': [
      for (final d in kSourceDocumentLinks) {'label': d.label, 'url': d.url},
    ],
  });
}

class _SmokeApp extends StatelessWidget {
  const _SmokeApp({required this.dark, required this.scale});
  final bool dark;
  final double scale;
  @override
  Widget build(BuildContext context) {
    final brightness = dark ? Brightness.dark : Brightness.light;
    return MaterialApp.router(
      title: 'Local rights and external documents smoke',
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: AppPalette.scheme(brightness),
        extensions: [IbColors.forBrightness(brightness)],
      ),
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
