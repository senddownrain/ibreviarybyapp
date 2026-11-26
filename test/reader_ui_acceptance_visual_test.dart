import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mybrev_flutter/main.dart' show buildAppTheme;
import 'package:mybrev_flutter/models/psalmody_preferences.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/theme/app_theme.dart';
import 'package:mybrev_flutter/theme/app_theme_preference.dart';
import 'package:mybrev_flutter/theme/ib_colors.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/screens/settings_screen.dart';
import 'package:mybrev_flutter/widgets/app_overflow_menu.dart';
import 'package:mybrev_flutter/widgets/reader/reader_scaffold.dart';

class _DarkVisualSettings extends _VisualSettings {
  @override
  SettingsState build() =>
      const SettingsState(themePreference: AppThemePreference.dark);
}

class _VisualSettings extends SettingsNotifier {
  @override
  SettingsState build() =>
      const SettingsState(themePreference: AppThemePreference.marian);

  @override
  void setFontSize(double size) {
    state = state.copyWith(fontSize: normalizeReaderFontSize(size));
  }

  @override
  Future<void> setPsalmodyMode(PsalmodyMode value) async {
    state = state.copyWith(psalmodyMode: value);
  }
}

Future<void> _capture(WidgetTester tester, String name) async {
  if (Platform.environment['READER_UI_ACCEPTANCE_IMAGES'] != '1') return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('reader-acceptance-capture')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = Directory('build/ui_acceptance')
      ..createSync(recursive: true);
    File(
      '${directory.path}/$name.png',
    ).writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final hiveDir = await Directory.systemTemp.createTemp('reader-ui-visual-');
    await HiveService.init(path: hiveDir.path, loadBundle: false);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity_status'),
      (call) async => null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      (call) async => <String>['wifi'],
    );
    GoogleFonts.config.allowRuntimeFetching = false;
    // Widget tests otherwise substitute Ahem squares for Android's Roboto:
    // load a real installed sans font so Belarusian chrome can be reviewed.
    if (Platform.isLinux) {
      const candidates = [
        '/usr/share/fonts/truetype/roboto/unhinted/RobotoTTF/Roboto-Regular.ttf',
        '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
        '/usr/share/fonts/truetype/liberation2/LiberationSans-Regular.ttf',
      ];
      final path = candidates.firstWhere(
        (candidate) => File(candidate).existsSync(),
        orElse: () => '',
      );
      if (path.isEmpty) {
        throw StateError('No installed Cyrillic sans font for visual QA');
      }
      await (FontLoader('Roboto')..addFont(
            Future.value(File(path).readAsBytesSync().buffer.asByteData()),
          ))
          .load();
    }
    for (final (family, asset) in [
      ('VisualPreview', 'assets/google_fonts/Literata-Regular.ttf'),
      (
        GoogleFonts.literata().fontFamily!,
        'assets/google_fonts/Literata-Regular.ttf',
      ),
      (
        GoogleFonts.cormorantGaramond(fontWeight: FontWeight.w700).fontFamily!,
        'assets/google_fonts/CormorantGaramond-Bold.ttf',
      ),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
      (
        'packages/phosphor_flutter/PhosphorRegular',
        'packages/phosphor_flutter/lib/fonts/Phosphor.ttf',
      ),
    ]) {
      await (FontLoader(family)..addFont(rootBundle.load(asset))).load();
    }
  });

  testWidgets('settings typography and live psalm example match Web', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      RepaintBoundary(
        key: const Key('reader-acceptance-capture'),
        child: ProviderScope(
          overrides: [settingsProvider.overrideWith(_DarkVisualSettings.new)],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: (() {
              final theme = buildAppTheme(
                AppPalette.scheme(Brightness.dark),
                preference: AppThemePreference.dark,
              );
              return theme.copyWith(
                textTheme: theme.textTheme.apply(fontFamily: 'Roboto'),
              );
            })(),
            home: Scaffold(
              appBar: AppBar(title: const Text('Налады')),
              body: const SettingsScreen(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('settings-reader-font')), findsOneWidget);
    expect(find.byKey(const Key('settings-text-preview')), findsOneWidget);
    expect(find.byTooltip('Па левым краі'), findsOneWidget);
    expect(find.byTooltip('Па шырыні'), findsOneWidget);
    expect(find.text('Прыклад'), findsNothing);
    // Top-level sections share the same production chrome typography.
    final sectionSize = tester.widget<Text>(find.text('Тэкст')).style?.fontSize;
    expect(
      tester.widget<Text>(find.text('Псальмодыя')).style?.fontSize,
      tester.widget<Text>(find.text('Выраўноўванне тэксту')).style?.fontSize,
    );
    expect(
      tester.widget<Text>(find.text('Стартовы раздзел')).style?.fontSize,
      sectionSize,
    );
    await Scrollable.ensureVisible(
      tester.element(find.text('Тэкст')),
      alignment: 0.06,
    );
    await tester.pumpAndSettle();
    await _capture(tester, '01-text-settings');
    tester.view.physicalSize = const Size(320, 800);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('settings-text-alignment')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _capture(tester, '01b-text-settings-320');
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(
      tester.element(find.text('Псальмодыя')),
      alignment: 0.12,
    );
    await tester.pumpAndSettle();
    expect(find.text('Псальмодыя'), findsOneWidget);
    final psalmTitle = find.text('Псальмодыя');
    final psalmSelector = find.byKey(const Key('settings-psalmody-mode'));
    expect(psalmSelector, findsOneWidget);
    expect(
      (tester.getCenter(psalmTitle).dy - tester.getCenter(psalmSelector).dy)
          .abs(),
      lessThan(5),
    );
    expect(
      tester.getTopRight(psalmTitle).dx,
      lessThan(tester.getTopLeft(psalmSelector).dx),
    );
    await _capture(tester, '02-psalmody-example');

    tester.view.physicalSize = const Size(320, 800);
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(
      tester.element(psalmSelector),
      alignment: 0.12,
    );
    await tester.pumpAndSettle();
    expect(
      (tester.getCenter(psalmTitle).dy - tester.getCenter(psalmSelector).dy)
          .abs(),
      lessThan(5),
    );
    expect(tester.takeException(), isNull);
    await _capture(tester, '02b-psalmody-320');
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('roomy reading and prayer menus', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> draw(ReaderScaffold reader) async {
      await tester.pumpWidget(
        RepaintBoundary(
          key: const Key('reader-acceptance-capture'),
          child: ProviderScope(
            overrides: [settingsProvider.overrideWith(_VisualSettings.new)],
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                useMaterial3: true,
                colorScheme: AppPalette.marianScheme,
                extensions: const [IbColors.marian],
                fontFamily: 'VisualPreview',
              ),
              home: reader,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('app-overflow-open')));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byKey(const Key('app-overflow-content'))).width,
        inInclusiveRange(280, 360),
      );
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
      expect(find.text('Катэгорыі'), findsNothing);
    }

    await draw(
      const ReaderScaffold(
        contextHeader: ReaderContextHeader(
          eyebrow: 'ЧЫТАННІ',
          title: 'Евангелле паводле Лукі',
        ),
        content: Text(
          'У той час Езус сказаў: Хто з вас, маючы слугу, '
          'які арэ або пасвіць, скажа яму, калі ён вернецца з поля?',
        ),
      ),
    );
    await _capture(tester, '04-readings-menu');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    await draw(
      ReaderScaffold(
        contextHeader: const ReaderContextHeader(
          eyebrow: 'МАЛІТВА',
          title: 'Крыжовы шлях',
        ),
        content: const Text(
          'Кланяемся Табе, Пане Езу Хрыстэ! '
          'Бо праз крыж і муку сваю свет адкупіў Ты!',
        ),
        secondaryActions: [
          ReaderSecondaryAction(
            label: 'Памылка',
            icon: Icons.flag_outlined,
            onSelected: () {},
          ),
        ],
      ),
    );
    expect(find.text('Памылка'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Памылка')).dy,
      greaterThan(tester.getTopLeft(find.text('Інфармацыя')).dy),
    );
    await _capture(tester, '05-prayer-menu');
    expect(tester.takeException(), isNull);
  });
}
