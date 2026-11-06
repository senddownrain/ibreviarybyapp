import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mybrev_flutter/main.dart' show buildAppTheme;
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/models/psalmody_preferences.dart';
import 'package:mybrev_flutter/theme/app_theme.dart';
import 'package:mybrev_flutter/theme/app_theme_controller.dart';
import 'package:mybrev_flutter/theme/app_theme_preference.dart';
import 'package:mybrev_flutter/theme/glass.dart';
import 'package:mybrev_flutter/theme/ib_colors.dart';
import 'package:mybrev_flutter/theme/reader.dart';
import 'package:mybrev_flutter/widgets/reader/reader_scaffold.dart';

ThemeData _theme(AppThemePreference preference, {TargetPlatform? platform}) =>
    buildAppTheme(
      AppPalette.schemesFor(preference).theme,
      preference: preference,
      platform: platform,
    );

double _contrast(Color a, Color b) {
  final x = a.computeLuminance();
  final y = b.computeLuminance();
  return x > y ? (x + .05) / (y + .05) : (y + .05) / (x + .05);
}

void main() {
  group('Hive preference compatibility', () {
    late Directory directory;
    late Box box;
    final containers = <ProviderContainer>[];
    ProviderContainer container() {
      final result = ProviderContainer();
      containers.add(result);
      return result;
    }

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('marian-settings-');
      Hive.init(directory.path);
      box = await Hive.openBox('settings');
    });
    tearDown(() async {
      for (final item in containers) {
        item.dispose();
      }
      containers.clear();
      await Hive.close();
      await directory.delete(recursive: true);
      setActiveThemePreference(AppThemePreference.system);
    });

    for (final preference in AppThemePreference.values) {
      test(
        'reads existing ${preference.name} without rewriting settings',
        () async {
          await box.putAll({
            'themeMode': preference.name,
            'fontSize': 22.4,
            'fontFamily': ReaderFontFamily.system,
            'keepScreenOn': true,
            'favoriteIds': '["one"]',
            'psalmVerseLayout': 'alignedLeft',
            'psalmMarkerBreakMode': 'breakAfterMarker',
            'futureSetting': 'untouched',
          });
          final before = box.toMap();
          final state = container().read(settingsProvider);
          expect(state.themePreference, preference);
          expect(state.themeMode, preference.themeMode);
          expect(appThemePreferenceController.value, preference);
          expect(state.fontSize, 22.4);
          expect(state.fontFamily, ReaderFontFamily.system);
          expect(state.favoriteIds, ['one']);
          expect(state.keepScreenOn, isTrue);
          expect(box.toMap(), before);
        },
      );
    }

    test(
      'all choices update immediately and survive a real close/reopen',
      () async {
        await box.put('unrelated', {'keep': true});
        for (final preference in AppThemePreference.values) {
          final settings = container().read(settingsProvider.notifier);
          final saved = settings.setThemePreference(preference);
          expect(settings.state.themePreference, preference);
          expect(appThemePreferenceController.value, preference);
          await saved;
          await box.close();
          box = await Hive.openBox('settings');
          expect(
            container().read(settingsProvider).themePreference,
            preference,
          );
          expect(box.get('unrelated'), {'keep': true});
        }
      },
    );

    test('unknown, corrupt and missing values safely follow the OS', () async {
      for (final value in [null, 'sepia', 42, true]) {
        await box.put('themeMode', value);
        expect(
          container().read(settingsProvider).themePreference,
          AppThemePreference.system,
        );
      }
    });

    test(
      'saving another setting in a stale container cannot undo Marian',
      () async {
        final stale = container().read(settingsProvider.notifier);
        final active = container().read(settingsProvider.notifier);
        await active.setThemePreference(AppThemePreference.marian);
        await stale.toggleFavorite('one');
        expect(box.get('themeMode'), 'marian');
        expect(container().read(settingsProvider).favoriteIds, ['one']);
      },
    );
    test(
      'all three accepted psalmody modes survive every theme choice',
      () async {
        for (final mode in PsalmodyMode.values) {
          await box.put('psalmodyMode', mode.name);
          final settings = container().read(settingsProvider.notifier);
          for (final preference in AppThemePreference.values) {
            final before = box.toMap();
            await settings.setThemePreference(preference);
            expect(settings.state.psalmodyMode, mode);
            expect(box.toMap(), {...before, 'themeMode': preference.name});
            expect(container().read(settingsProvider).psalmodyMode, mode);
          }
        }
      },
    );
  });

  test('every legacy ColorScheme and IbColors value matches main 7abba85', () {
    final baseline =
        jsonDecode(
              File('test/support/pre_marian_palette.json').readAsStringSync(),
            )
            as Map;
    for (final brightness in Brightness.values) {
      final builder = DiagnosticPropertiesBuilder();
      AppPalette.scheme(brightness).debugFillProperties(builder);
      final actual = {
        for (final property in builder.properties)
          if (property.value is Color)
            property.name!: (property.value as Color).toARGB32(),
      };
      expect(actual, baseline[brightness.name]);
      final c = IbColors.forBrightness(brightness);
      expect(
        [
          c.page,
          c.reader,
          c.surface,
          c.surfaceRaised,
          c.floating,
          c.ink,
          c.inkMuted,
          c.readerMuted,
          c.accent,
          c.onAccent,
          c.rubric,
          c.error,
          c.separator,
          c.outline,
          c.neutralAmbient,
        ].map((color) => color.toARGB32()).toList(),
        baseline['${brightness.name}IbColors'],
      );
    }
  });

  test('Marian maps approved Web roles into Material and Cupertino', () {
    final theme = _theme(
      AppThemePreference.marian,
      platform: TargetPlatform.iOS,
    );
    final cs = theme.colorScheme;
    final colors = theme.extension<IbColors>()!;
    expect(colors, same(IbColors.marian));
    expect(cs.brightness, Brightness.light);
    expect(theme.scaffoldBackgroundColor, const Color(0xFFF4F8FC));
    expect(colors.reader, const Color(0xFFFBFDFF));
    expect(cs.surface, Colors.white);
    expect(cs.surfaceContainerHigh, const Color(0xFFE2EFF9));
    expect(cs.primary, const Color(0xFF244D78));
    expect(cs.secondary, const Color(0xFF477DAA));
    expect(cs.onSurface, const Color(0xFF202D39));
    expect(cs.onSurfaceVariant, const Color(0xFF52687A));
    expect(colors.rubric, IbColors.light.rubric);
    expect(colors.neutralAmbient, const Color(0xFFA8CBE6));
    expect(theme.cupertinoOverrideTheme!.primaryColor, cs.primary);
    expect(theme.cupertinoOverrideTheme!.brightness, Brightness.light);
    expect(theme.extension<GlassDecoration>(), same(GlassDecoration.marian));
    expect(
      theme.appBarTheme.systemOverlayStyle!.statusBarIconBrightness,
      Brightness.dark,
    );
    expect(
      theme.appBarTheme.systemOverlayStyle!.statusBarBrightness,
      Brightness.light,
    );
    expect(
      theme.appBarTheme.systemOverlayStyle!.systemNavigationBarIconBrightness,
      Brightness.dark,
    );
  });

  test('Marian foreground/background pairs pass WCAG AA', () {
    final c = IbColors.marian;
    final cs = AppPalette.marianScheme;
    for (final background in [c.page, c.reader, c.surface, c.floating]) {
      for (final foreground in [c.ink, c.inkMuted, c.rubric, c.accent]) {
        expect(
          _contrast(foreground, background),
          greaterThanOrEqualTo(4.5),
          reason: '$foreground on $background',
        );
      }
    }
    for (final pair in [
      (cs.primary, cs.onPrimary),
      (cs.secondary, cs.onSecondary),
      (cs.error, cs.onError),
      (cs.secondaryContainer, cs.onSecondaryContainer),
    ]) {
      expect(_contrast(pair.$1, pair.$2), greaterThanOrEqualTo(4.5));
    }
  });

  testWidgets('OS brightness controls system but never explicit choices', (
    tester,
  ) async {
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    late IbColors installed;
    late Brightness brightness;
    for (final preference in AppThemePreference.values) {
      final schemes = AppPalette.schemesFor(preference);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(schemes.theme, preference: preference),
          darkTheme: buildAppTheme(schemes.darkTheme, preference: preference),
          themeMode: preference.themeMode,
          themeAnimationDuration: Duration.zero,
          home: Builder(
            builder: (context) {
              installed = IbColors.of(context);
              brightness = Theme.of(context).brightness;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      for (final os in [Brightness.dark, Brightness.light, Brightness.dark]) {
        tester.platformDispatcher.platformBrightnessTestValue = os;
        await tester.pump();
        final expected = switch (preference) {
          AppThemePreference.system => os,
          AppThemePreference.dark => Brightness.dark,
          _ => Brightness.light,
        };
        expect(brightness, expected);
        expect(
          installed,
          same(
            preference == AppThemePreference.marian
                ? IbColors.marian
                : IbColors.forBrightness(expected),
          ),
        );
      }
    }
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('opaque paper and edge protection across scroll, $platform', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      late ReaderTheme reader;
      late GlassTokens tokens;
      await tester.pumpWidget(
        MaterialApp(
          theme: _theme(AppThemePreference.marian, platform: platform),
          home: ReaderTypographyScope(
            useSystemFonts: true,
            child: Builder(
              builder: (context) {
                reader = ReaderTheme.of(context);
                tokens = GlassTokens.of(context);
                return ReaderScaffold(
                  showTextScale: false,
                  showBack: false,
                  scrollController: controller,
                  seasonColor: Colors.green,
                  content: const SizedBox(height: 4000),
                );
              },
            ),
          ),
        ),
      );
      expect(reader.surface, const Color(0xFFFBFDFF));
      expect(reader.ink, IbColors.marian.ink);
      expect(reader.muted, IbColors.marian.inkMuted);
      expect(tokens.ambientStrong, closeTo(.0495, .00001));
      expect(tokens.decoration.backdrop, .06);
      expect(tokens.ambientCard, lessThan(.045));
      for (final fraction in [0.0, .5, 1.0]) {
        controller.jumpTo(controller.position.maxScrollExtent * fraction);
        await tester.pumpAndSettle();
        final paper = tester.widget<ColoredBox>(
          find.byKey(const Key('reader-content-surface')),
        );
        expect(paper.color, reader.surface);
        expect(paper.color.a, 1);
        final fade = tester.widget<DecoratedBox>(
          find.byKey(const Key('reader-top-fade')),
        );
        final gradient =
            (fade.decoration as BoxDecoration).gradient as LinearGradient;
        expect(gradient.colors.first, paper.color);
        expect(gradient.colors.last, paper.color.withValues(alpha: 0));
        expect(tester.takeException(), isNull);
      }
      expect(
        find.byKey(
          Key(
            platform == TargetPlatform.iOS
                ? 'adaptive-chrome-glass'
                : 'adaptive-chrome-ambient',
          ),
        ),
        findsWidgets,
      );
    });
  }

  testWidgets('light/dark decorative intensities remain unchanged', (
    tester,
  ) async {
    for (final preference in [
      AppThemePreference.light,
      AppThemePreference.dark,
    ]) {
      late GlassTokens tokens;
      await tester.pumpWidget(
        MaterialApp(
          theme: _theme(preference),
          themeAnimationDuration: Duration.zero,
          home: Builder(
            builder: (context) {
              tokens = GlassTokens.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      final dark = preference == AppThemePreference.dark;
      expect(tokens.ambientStrong, dark ? .15 : .11);
      expect(tokens.ambientMid, dark ? .06 : .045);
      expect(tokens.ambientSoft, dark ? .07 : .055);
      expect(tokens.ambientPill, dark ? .08 : .065);
      expect(tokens.ambientCard, dark ? .06 : .045);
      expect(tokens.decoration.backdrop, dark ? .11 : .09);
    }
  });
}
