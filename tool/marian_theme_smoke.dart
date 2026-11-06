// Isolated real-bundle/production-app visual audit. Never initializes Firebase.
// flutter run -d chrome -t tool/marian_theme_smoke.dart --web-port 5241
// Query: ?theme=marian&platform=android|ios&scale=1
import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:mybrev_flutter/screens/ora_screen.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/discovery/discovery.dart';
import 'package:mybrev_flutter/main.dart' show MyBrevApp;
import 'package:mybrev_flutter/providers/connectivity_provider.dart';
import 'package:mybrev_flutter/providers/content_updates_provider.dart';
import 'package:mybrev_flutter/providers/priest_access_provider.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/router/router.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/services/priest_access_gateway.dart';
import 'package:mybrev_flutter/services/priest_access_storage.dart';
import 'package:mybrev_flutter/theme/ib_colors.dart';
import 'package:mybrev_flutter/theme/app_theme_preference.dart';

class _IdleUpdates extends ContentUpdatesNotifier {
  @override
  ContentUpdateState build() => const ContentUpdateState();
}

class _EmptyStorage implements PriestAccessStorage {
  @override
  Future<Map<String, dynamic>> read() async => {};
  @override
  Future<void> write(Map<String, dynamic> data) async {}
}

// These are the only gateway methods reached by an unregistered audit session.
// Any accidental content/network operation fails locally.
class _OfflineGateway implements PriestAccessGateway {
  @override
  Future<String?> restoreSession() async => null;
  @override
  Future<void> clearProtectedMemory() async {}
  @override
  Future<void> close() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError(
    'Network forbidden in Marian audit: ${invocation.memberName}',
  );
}

@JS('marianAuditCommand')
external set _command(JSFunction callback);

late ProviderContainer _container;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugDefaultTargetPlatformOverride =
      Uri.base.queryParameters['platform'] == 'ios'
      ? TargetPlatform.iOS
      : TargetPlatform.android;
  GoogleFonts.config.allowRuntimeFetching = false;
  await initializeDateFormatting('be');
  await HiveService.init();
  await HiveService.content.ensureLoaded(kLiturgicalCollections);
  _container = ProviderContainer(
    overrides: [
      contentUpdatesProvider.overrideWith(_IdleUpdates.new),
      isOfflineProvider.overrideWithValue(true),
      connectivityProvider.overrideWith((ref) => Stream.value(false)),
      priestAccessGatewayProvider.overrideWithValue(_OfflineGateway()),
      priestAccessStorageProvider.overrideWithValue(_EmptyStorage()),
      discoveryStorageProvider.overrideWithValue(MemoryDiscoveryStorage()),
    ],
  );
  await _container
      .read(settingsProvider.notifier)
      .setThemePreference(
        AppThemePreference.fromStorage(
          Uri.base.queryParameters['theme'] ?? 'marian',
        ),
      );
  router.go('/hours?date=2026-02-08&diocese=minsk-mohilev');
  runApp(
    UncontrolledProviderScope(
      container: _container,
      child: Builder(
        builder: (context) => MediaQuery(
          data: MediaQueryData.fromView(View.of(context)).copyWith(
            textScaler: TextScaler.linear(
              double.tryParse(Uri.base.queryParameters['scale'] ?? '') ?? 1,
            ),
          ),
          child: const MyBrevApp(),
        ),
      ),
    ),
  );
  _command = ((JSString action, JSString value) => _handle(
    action.toDart,
    value.toDart,
  ).toJS).toJS;
}

Future<JSString> _handle(String action, String value) async {
  if (action == 'theme') {
    await _container
        .read(settingsProvider.notifier)
        .setThemePreference(AppThemePreference.fromStorage(value));
  } else if (action == 'route') {
    router.go(value);
  } else if (action == 'font') {
    _container.read(settingsProvider.notifier).setFontSize(double.parse(value));
  } else if (action == 'back') {
    router.pop();
  } else if (action == 'scroll') {
    final candidates = <ScrollableState>[];
    _visit((element) {
      if (element is StatefulElement && element.state is ScrollableState) {
        final state = element.state as ScrollableState;
        if (state.position.axis == Axis.vertical &&
            state.position.hasContentDimensions &&
            state.position.maxScrollExtent > 0) {
          candidates.add(state);
        }
      }
    });
    candidates.sort(
      (a, b) =>
          b.position.maxScrollExtent.compareTo(a.position.maxScrollExtent),
    );
    if (candidates.isNotEmpty) {
      final position = candidates.first.position;
      position.jumpTo(position.maxScrollExtent * double.parse(value));
    }
  } else if (action == 'tap' || action == 'text') {
    Element? target;
    _visit((element) {
      final widget = element.widget;
      final text = switch (widget) {
        Text() => widget.data ?? widget.textSpan?.toPlainText() ?? '',
        RichText() => widget.text.toPlainText(),
        _ => '',
      };
      if (text == value) target = element;
    });
    if (target == null) {
      return 'missing: $value'.toJS;
    }
    if (action == 'text') {
      await Scrollable.ensureVisible(target!, alignment: .15);
    } else {
      GestureDetector? gesture;
      InkWell? ink;
      target!.visitAncestorElements((element) {
        if (element.widget case InkWell widget) {
          ink = widget;
          return false;
        }
        if (element.widget case GestureDetector widget) {
          if (widget.onTap != null) {
            gesture = widget;
            return false;
          }
        }
        return true;
      });
      ink?.onTap?.call();
      gesture?.onTap?.call();
    }
  }
  await WidgetsBinding.instance.endOfFrame;
  if (action != 'inspect') {
    return 'ok'.toJS;
  }
  var actualRoute = router.routerDelegate.currentConfiguration.uri.toString();
  final surfaces = <String>[];
  final texts = <String>[];
  _visit((element) {
    final widget = element.widget;
    if (widget is OraScreen) {
      actualRoute = GoRouterState.of(element).uri.toString();
    }
    if (widget is ColoredBox &&
        widget.key == const Key('reader-content-surface')) {
      surfaces.add(widget.color.toARGB32().toRadixString(16));
    }
    if (widget is Text) {
      texts.add(widget.data ?? widget.textSpan?.toPlainText() ?? '');
    }
  });
  final context = rootNavigatorKey.currentContext!;
  if (!context.mounted) return 'unmounted'.toJS;
  final colors = IbColors.of(context);
  return jsonEncode({
    'route': actualRoute,
    'mediaSize': [
      MediaQuery.sizeOf(context).width,
      MediaQuery.sizeOf(context).height,
    ],
    'viewSize': [
      View.of(context).physicalSize.width,
      View.of(context).physicalSize.height,
    ],
    'preference': _container.read(settingsProvider).themePreference.name,
    'brightness': Theme.of(context).brightness.name,
    'page': colors.page.toARGB32().toRadixString(16),
    'reader': colors.reader.toARGB32().toRadixString(16),
    'readerSurfaces': surfaces,
    'texts': texts,
  }).toJS;
}

void _visit(void Function(Element) visitor) {
  void visit(Element element) {
    if (element.widget is Offstage && (element.widget as Offstage).offstage) {
      return;
    }
    visitor(element);
    element.debugVisitOnstageChildren(visit);
  }

  WidgetsBinding.instance.rootElement?.debugVisitOnstageChildren(visit);
}
