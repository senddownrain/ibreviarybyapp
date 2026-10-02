import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/models/parsed_reading.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/providers/readings_loader_provider.dart';
import 'package:mybrev_flutter/screens/ora_screen.dart';
import 'package:mybrev_flutter/screens/readings_screen.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/theme/reader.dart';
import 'package:mybrev_flutter/theme/app_theme.dart';
import 'package:mybrev_flutter/utils/liturgical_theme.dart';
import 'package:mybrev_flutter/models/day.dart';
import 'package:mybrev_flutter/widgets/text_scale_control.dart';
import 'package:mybrev_flutter/theme/liturgical_document.dart';
import 'package:mybrev_flutter/widgets/reader/reader_scaffold.dart';

double _fontSize = 16;

class _SmokeSettings extends SettingsNotifier {
  @override
  SettingsState build() => SettingsState(fontSize: _fontSize);
}

void main() {
  late Directory directory;
  final date = DateTime(2028, 8, 1);
  setUpAll(() async {
    await initializeDateFormatting('be');
    directory = await Directory.systemTemp.createTemp('liturgy-smoke-');
    await HiveService.init(path: directory.path);
    final fixture =
        jsonDecode(
              File(
                'test/fixtures/office_assembly_parity.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final apostle = Map<String, dynamic>.from(
      (fixture['templates'] as Map<String, dynamic>)['apostles'] as Map,
    );
    apostle.remove('_schema');
    apostle.remove('_kind');
    const psalmSample =
        '<p style="text-align:center"><span style="color:red">'
        'Псальм 63 (62), 2–9</span></p>'
        '<p><em>Той з Богам, хто адкідае ўчынкі цемры</em></p>'
        '<p>Божа, Ты Бог мой *<br>Цябе шукаю.</p>';
    for (var i = 1; i <= 3; i++) {
      apostle['laudesPs$i'] = psalmSample;
      apostle['sext1Ant$i'] =
          '<p><span style="color:red">$i ант.</span> Хвала Пану.</p>';
      apostle['sext1Ps$i'] = psalmSample;
    }
    apostle['laudesHymn'] = '<p>Спяваем хвалу Пану.</p>';
    final ordinary = Map<String, dynamic>.from(fixture['currentDay'] as Map);
    ordinary['laudesHymn'] = '<p>Спяваем хвалу Пану.</p>';
    for (var i = 1; i <= 3; i++) {
      ordinary['laudesPs$i'] = psalmSample;
    }
    await HiveService.daysBox.put('ordinary-smoke', {
      ...ordinary,
      'id': 'ordinary-smoke',
      '_periodType': 'ordinary',
      '_periodWeekNumber': '17',
      '_dayOfWeek': '3',
    });
    await HiveService.daysBox.put('smoke', {
      ...apostle,
      'id': 'smoke',
      '_periodType': 'ordinary',
      '_periodWeekNumber': '17',
      '_dayOfWeek': '3',
      '_rank': 'festum',
    });
    await HiveService.markDateCached('days', date);
    await HiveService.markDateCached('days', date.add(const Duration(days: 1)));
    await HiveService.invitatoriumsBox.put('one', {
      'title': 'Заклік',
      'invitatoriumPs1': '<p>Прыйдзіце, уславім Пана *</p>',
    });
    for (var day = 1; day <= 7; day++) {
      await HiveService.completoriumsBox.put('ordinary-d$day', {
        'compHymn': '<p>Гімн Камплеты.</p>',
        'compAnt1': '<p>Ант. Пан мой.</p>',
        'compPs1': '<p><em>Псальм 4</em></p><p>Пачуй мяне, Божа *</p>',
        'compR': '<p>Кароткае чытанне 1 П 5, 8</p><p>Будзьце цвярозымі.</p>',
        'compResp':
            '<p>Кароткі рэспансорый<br>К. У рукі Твае * '
            'Н. Аддаю дух мой.</p>',
        'compAntS': '<p>Ант. Збаў нас, Пане.</p>',
        'compPr': '<p>Молімся.</p>',
        'compAntM': '<p>Вітай, Каралева.</p>',
      });
    }
  });
  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  testWidgets('Ora day color reaches context without recoloring Reader or Aa', (
    tester,
  ) async {
    final contexts = <Color>[];
    final schemes = <ColorScheme>[];
    for (final dayId in ['ordinary-smoke', 'smoke']) {
      final day = LiturgicalDay.fromMap(
        Map<String, dynamic>.from(HiveService.daysBox.get(dayId) as Map),
      );
      contexts.add(liturgicalColorForDay(day));
      await tester.pumpWidget(
        ProviderScope(
          key: ValueKey(dayId),
          overrides: [settingsProvider.overrideWith(_SmokeSettings.new)],
          child: MaterialApp(
            key: ValueKey('app-$dayId'),
            theme: ThemeData(colorScheme: AppPalette.scheme(Brightness.light)),
            home: OraScreen(dayId: dayId, oraType: 'laudes', date: date),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final reader = tester.widget<ReaderScaffold>(find.byType(ReaderScaffold));
      expect(reader.seasonColor, contexts.last);
      expect(find.byKey(const Key('text-scale-open')), findsOneWidget);
      schemes.add(
        Theme.of(tester.element(find.byType(TextScaleControl))).colorScheme,
      );
      expect(tester.takeException(), isNull);
    }
    expect(contexts[0], isNot(contexts[1]));
    expect(schemes[0].primary, schemes[1].primary);
    expect(schemes[0].primaryContainer, schemes[1].primaryContainer);
  });

  testWidgets(
    'Ora keeps hour picker above and offers scroll-to-top after reading',
    (tester) async {
      tester.view.physicalSize = const Size(360, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [settingsProvider.overrideWith(_SmokeSettings.new)],
          child: MaterialApp(
            home: OraScreen(dayId: 'smoke', oraType: 'laudes', date: date),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final reader = tester.widget<ReaderScaffold>(find.byType(ReaderScaffold));
      expect(reader.showScrollToTop, isTrue);
      expect(find.byKey(const Key('reader-scroll-to-top')), findsNothing);
      expect(find.byKey(const Key('bible-previous-chapter')), findsNothing);
      expect(find.byKey(const Key('bible-next-chapter')), findsNothing);
      final scroll = reader.scrollController!;
      expect(scroll.position.maxScrollExtent, greaterThan(560));
      scroll.jumpTo(600);
      await tester.pump();
      expect(find.byKey(const Key('reader-scroll-to-top')), findsOneWidget);
      await tester.tap(find.byKey(const Key('reader-scroll-to-top')));
      await tester.pumpAndSettle();
      expect(scroll.offset, 0);
      await tester.tap(find.byKey(const Key('reader-context-title-action')));
      await tester.pumpAndSettle();
      expect(find.text('Літургія гадзінаў'), findsOneWidget);
    },
  );

  final cases = <(String, String, Brightness, double, Size)>[
    ('ordinary-smoke', 'laudes', Brightness.light, 16, const Size(900, 1600)),
    ('smoke', 'laudes', Brightness.light, 16, const Size(900, 1600)),
    ('smoke', 'laudes', Brightness.dark, 24, const Size(900, 1600)),
    ('smoke', 'vespers', Brightness.light, 16, const Size(900, 1600)),
    ('smoke', 'lectionis', Brightness.light, 16, const Size(900, 1600)),
    ('smoke', 'morning', Brightness.light, 16, const Size(900, 1600)),
    ('smoke', 'terz', Brightness.light, 16, const Size(900, 1600)),
    ('smoke', 'sext', Brightness.light, 16, const Size(900, 1600)),
    ('smoke', 'non', Brightness.light, 16, const Size(900, 1600)),
    ('smoke', 'completorium', Brightness.light, 16, const Size(900, 1600)),
    ('smoke', 'completorium', Brightness.dark, 24, const Size(900, 1600)),
    // Phone widths exercise wrapping in both the chrome and long document.
    ('smoke', 'laudes', Brightness.light, 16, const Size(360, 800)),
    ('smoke', 'lectionis', Brightness.light, 16, const Size(360, 800)),
    ('smoke', 'terz', Brightness.light, 16, const Size(360, 800)),
    ('smoke', 'completorium', Brightness.light, 16, const Size(360, 800)),
    ('smoke', 'laudes', Brightness.light, 16, const Size(390, 844)),
    ('smoke', 'lectionis', Brightness.light, 16, const Size(390, 844)),
    ('smoke', 'sext', Brightness.light, 16, const Size(390, 844)),
    ('smoke', 'completorium', Brightness.dark, 24, const Size(390, 844)),
  ];
  for (final (dayId, hour, brightness, size, viewport) in cases) {
    testWidgets('$dayId $hour ${brightness.name} $size '
        '${viewport.width}x${viewport.height} builds document', (tester) async {
      _fontSize = size;
      tester.view.physicalSize = viewport;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        RepaintBoundary(
          key: const Key('smoke-capture'),
          child: ProviderScope(
            overrides: [settingsProvider.overrideWith(_SmokeSettings.new)],
            child: MaterialApp(
              theme: ThemeData(brightness: brightness),
              home: ReaderChromeModeScope(
                controller: ReaderChromeModeController(ReaderChromeMode.full),
                child: OraScreen(dayId: dayId, oraType: hour, date: date),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('reader-content-surface')), findsOneWidget);
      expect(tester.takeException(), isNull);
      final headings = tester
          .widgetList<LiturgicalSectionHeading>(
            find.byType(LiturgicalSectionHeading),
          )
          .toList();
      if (hour == 'lectionis' || hour == 'morning') {
        // The divider owns the first transition; the second reading owns its
        // gap because no divider separates the two readings.
        expect(
          headings
              .singleWhere((heading) => heading.title == 'Першае чытанне')
              .startsSection,
          isFalse,
        );
        expect(
          headings
              .singleWhere((heading) => heading.title == 'Другое чытанне')
              .startsSection,
          isTrue,
        );
      }
      if (const {'laudes', 'vespers', 'morning'}.contains(hour)) {
        expect(
          headings
              .singleWhere((heading) => heading.title == 'Просьбы')
              .startsSection,
          isFalse,
        );
      }
      if (const {
        'laudes',
        'vespers',
        'morning',
        'completorium',
      }.contains(hour)) {
        expect(
          headings
              .singleWhere((heading) => heading.title == 'Малітва')
              .startsSection,
          isTrue,
        );
      }
      if (hour == 'lectionis' || hour == 'morning') {
        // A feast includes Te Deum. It shares HYMN_BODY in both compositions.
        final teDeum = tester
            .widgetList<Html>(find.byType(Html))
            .singleWhere(
              (html) => html.data?.contains('Цябе, Бога, праслаўляем') ?? false,
            );
        expect(teDeum.style['body']?.lineHeight?.size, ReaderTheme.hymnHeight);
        expect(
          teDeum.style['p']?.margin?.bottom?.value,
          LiturgicalSpacing.hymnStropheAfter,
        );
      }
      await _captureIfRequested(
        tester,
        '$dayId-$hour-${brightness.name}-$size-${viewport.width}x${viewport.height}',
      );
      if (const {
        'laudes',
        'vespers',
        'morning',
        'completorium',
      }.contains(hour)) {
        final canticle = find.text('Песня з Евангелля');
        if (canticle.evaluate().isNotEmpty) {
          await tester.ensureVisible(canticle.first);
          await tester.pumpAndSettle();
          await _captureIfRequested(
            tester,
            '$dayId-$hour-${brightness.name}-$size-${viewport.width}x${viewport.height}-canticle',
          );
        }
      }
      if (hour == 'completorium') {
        final marian = find.text(
          'Антыфоны на заканчэнне да Найсвяцейшай Панны Марыі',
        );
        if (marian.evaluate().isNotEmpty) {
          await tester.ensureVisible(marian.first);
          await tester.pumpAndSettle();
          await _captureIfRequested(
            tester,
            '$dayId-$hour-${brightness.name}-$size-${viewport.width}x${viewport.height}-marian',
          );
        }
      }
    });
  }

  for (final (brightness, size, viewport) in [
    (Brightness.light, 16.0, const Size(900, 1600)),
    (Brightness.dark, 24.0, const Size(900, 1600)),
    (Brightness.light, 16.0, const Size(360, 800)),
    (Brightness.dark, 24.0, const Size(390, 844)),
  ]) {
    testWidgets('readings ${brightness.name} $size '
        '${viewport.width}x${viewport.height} builds document', (tester) async {
      _fontSize = size;
      tester.view.physicalSize = viewport;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final reading = ParsedReading(
        id: 'smoke-reading',
        title: 'Свята',
        reading1: const ParsedSection(
          bible: 'Флп 4, 10–23',
          text: 'Браты, я вельмі ўзрадаваўся ў Пану.',
        ),
        psalm: const ParsedSection(
          title: 'Рэспансарыйны псальм',
          chorus: 'Пан пачуў мяне.',
          verses: ['2. Я цвёрда спадзяваўся * і Ён пачуў мяне.'],
        ),
        gospel: const ParsedSection(
          bible: 'Лк 1, 68–79',
          text: 'Благаслаўлёны Пан, Бог Ізраэля.',
        ),
      );
      await tester.pumpWidget(
        RepaintBoundary(
          key: const Key('smoke-capture'),
          child: ProviderScope(
            overrides: [
              settingsProvider.overrideWith(_SmokeSettings.new),
              liturgicalSeasonColorProvider.overrideWithValue(Colors.green),
              readingsLoaderProvider.overrideWithValue(
                ({
                  required dateStr,
                  required liturgicalKey,
                  required dayId,
                  required forceRefresh,
                }) async => ReadingsLoadResult(
                  readings: [reading],
                  sundayCycle: 'B',
                  weekdayCycle: '2',
                ),
              ),
              readingsLocalLoaderProvider.overrideWithValue(
                ({required dateStr, required liturgicalKey, required dayId}) =>
                    ReadingsLoadResult(
                      readings: [reading],
                      sundayCycle: 'B',
                      weekdayCycle: '2',
                    ),
              ),
            ],
            child: MaterialApp(
              theme: ThemeData(brightness: brightness),
              home: const ReadingsScreen(dateStr: '2028-08-01'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('reader-content-surface')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _captureIfRequested(
        tester,
        'readings-${brightness.name}-$size-${viewport.width}x${viewport.height}',
      );
    });
  }
}

Future<void> _captureIfRequested(WidgetTester tester, String name) async {
  if (Platform.environment['LITURGY_SMOKE_IMAGES'] != '1') return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('smoke-capture')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = Directory('build/liturgy_smoke')
      ..createSync(recursive: true);
    File(
      '${directory.path}/$name.png',
    ).writeAsBytesSync(data!.buffer.asUint8List());
    image.dispose();
  });
}
