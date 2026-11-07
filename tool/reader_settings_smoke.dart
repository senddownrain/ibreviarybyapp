import 'package:mybrev_flutter/providers/liturgical_navigation_sync_provider.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:mybrev_flutter/models/reader_alignment.dart';
import 'package:mybrev_flutter/widgets/text_scale_control.dart';
// Isolated real-bundle/production-app visual audit. Never initializes Firebase.
// flutter run -d chrome -t tool/reader_settings_smoke.dart --web-port 5241
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
import 'package:mybrev_flutter/models/psalmody_preferences.dart';
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
final _textScale = ValueNotifier<double>(1);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugDefaultTargetPlatformOverride =
      Uri.base.queryParameters['platform'] == 'ios'
      ? TargetPlatform.iOS
      : TargetPlatform.android;
  GoogleFonts.config.allowRuntimeFetching = false;
  // Only the isolated Chrome audit: actual Roboto/Noto files supplied locally
  // because this executor cannot fetch Flutter engine fallback fonts from CDN.
  if (const bool.fromEnvironment('READER_AUDIT_LOCAL_FONTS')) {
    for (final entry in {
      'Roboto': 'Roboto.ttf',
      'Noto Sans': 'NotoSans.ttf',
    }.entries) {
      final response = await http.get(
        Uri.parse('${Uri.base.origin}/reader-audit/${entry.value}'),
      );
      if (response.statusCode != 200) {
        throw StateError('Missing local audit font');
      }
      await (FontLoader(entry.key)
            ..addFont(Future.value(ByteData.sublistView(response.bodyBytes))))
          .load();
    }
  }
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
  _textScale.value =
      double.tryParse(Uri.base.queryParameters['scale'] ?? '') ?? 1;
  router.go('/hours?date=2026-02-08&diocese=minsk-mohilev');
  runApp(
    UncontrolledProviderScope(
      container: _container,
      child: Builder(
        builder: (context) => MediaQuery.fromView(
          view: View.of(context),
          child: ValueListenableBuilder<double>(
            valueListenable: _textScale,
            builder: (context, scale, _) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: const MyBrevApp(),
            ),
          ),
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
  if (action == 'scale') {
    _textScale.value = double.parse(value);
  } else if (action == 'platform') {
    debugDefaultTargetPlatformOverride = value == 'ios'
        ? TargetPlatform.iOS
        : TargetPlatform.android;
    final notifier = _container.read(settingsProvider.notifier);
    final theme = _container.read(settingsProvider).themePreference;
    await notifier.setThemePreference(
      theme == AppThemePreference.dark
          ? AppThemePreference.light
          : AppThemePreference.dark,
    );
    await notifier.setThemePreference(theme);
  } else if (action == 'theme') {
    await _container
        .read(settingsProvider.notifier)
        .setThemePreference(AppThemePreference.fromStorage(value));
  } else if (action == 'route') {
    final uri = Uri.parse(value);
    final parts = uri.pathSegments;
    final isOra = parts.length >= 5 && parts[0] == 'hours' && parts[1] == 'ora';
    final date = DateTime.tryParse(
      isOra ? parts[2] : uri.queryParameters['date'] ?? '',
    );
    if (date != null) {
      _container
          .read(liturgicalNavigationControllerProvider)
          .openDate(
            date,
            dayId: isOra ? parts[3] : uri.queryParameters['dayId'],
            diocese: uri.queryParameters['diocese'],
          );
    }
    router.go(value);
  } else if (action == 'psalmody') {
    await _container
        .read(settingsProvider.notifier)
        .setPsalmodyMode(resolvePsalmodyMode(storedMode: value));
  } else if (action == 'family') {
    _container.read(settingsProvider.notifier).setFontFamily(value);
  } else if (action == 'alignment') {
    await _container
        .read(settingsProvider.notifier)
        .setTextAlignment(ReaderAlignment.fromStorage(value));
  } else if (action == 'sheet') {
    unawaited(
      showTextScalePanel(
        rootNavigatorKey.currentContext!,
        showPsalmody: value == 'ora',
      ),
    );
  } else if (action == 'key') {
    _visit((element) {
      if (element.widget.key == ValueKey(value)) {
        final widget = element.widget;
        if (widget is IconButton) widget.onPressed?.call();
      }
    });
  } else if (action == 'expand' || action == 'collapse') {
    _visit((element) {
      if (element.widget is Text && (element.widget as Text).data == 'Тэкст') {
        final controller = ExpansibleController.of(element);
        if (action == 'expand') {
          controller.expand();
        } else {
          controller.collapse();
        }
      }
    });
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
  WidgetsBinding.instance.scheduleFrame();
  await WidgetsBinding.instance.endOfFrame;
  if (action != 'inspect') {
    return 'ok'.toJS;
  }
  var actualRoute = router.routerDelegate.currentConfiguration.uri.toString();
  final surfaces = <String>[];
  final scrolls = <List<double>>[];
  final paragraphs = <Map<String, Object?>>[];
  final bounds = <String, Object?>{};
  final texts = <String>[];
  _visit((element) {
    final widget = element.widget;
    if (element is StatefulElement && element.state is ScrollableState) {
      final position = (element.state as ScrollableState).position;
      if (position.axis == Axis.vertical && position.hasContentDimensions) {
        scrolls.add([position.pixels, position.maxScrollExtent]);
      }
    }
    if (widget is OraScreen) {
      actualRoute = GoRouterState.of(element).uri.toString();
    }
    if (widget is ColoredBox &&
        widget.key == const Key('reader-content-surface')) {
      surfaces.add(widget.color.toARGB32().toRadixString(16));
    }
    if (widget is RichText && widget.text.toPlainText().trim().isNotEmpty) {
      paragraphs.add({
        'text': widget.text.toPlainText().substring(
          0,
          widget.text.toPlainText().length.clamp(0, 90),
        ),
        'align': widget.textAlign.name,
        'family': widget.text.style?.fontFamily,
      });
    }
    for (final key in [
      'settings-reader-font',
      'app-overflow-open',
      'app-overflow-content',
      'text-scale-slider',
    ]) {
      if (widget.key == ValueKey(key)) {
        final box = element.findRenderObject();
        if (box is RenderBox && box.hasSize) {
          final origin = box.localToGlobal(Offset.zero);
          bounds[key] = [origin.dx, origin.dy, box.size.width, box.size.height];
        }
      }
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
    'psalmodyMode': _container.read(settingsProvider).psalmodyMode.name,
    'fontFamily': _container.read(settingsProvider).fontFamily,
    'fontSize': _container.read(settingsProvider).fontSize,
    'scrolls': scrolls,
    'alignment': _container.read(settingsProvider).textAlignment.name,
    'brightness': Theme.of(context).brightness.name,
    'page': colors.page.toARGB32().toRadixString(16),
    'reader': colors.reader.toARGB32().toRadixString(16),
    'readerSurfaces': surfaces,
    'texts': texts,
    'paragraphs': paragraphs,
    'bounds': bounds,
    'scale': _textScale.value,
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
