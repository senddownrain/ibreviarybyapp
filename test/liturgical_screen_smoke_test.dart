import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
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

  final cases = <(String, String, Brightness, double)>[
    ('ordinary-smoke', 'laudes', Brightness.light, 16),
    ('smoke', 'laudes', Brightness.light, 16),
    ('smoke', 'laudes', Brightness.dark, 24),
    ('smoke', 'vespers', Brightness.light, 16),
    ('smoke', 'lectionis', Brightness.light, 16),
    ('smoke', 'morning', Brightness.light, 16),
    ('smoke', 'terz', Brightness.light, 16),
    ('smoke', 'sext', Brightness.light, 16),
    ('smoke', 'non', Brightness.light, 16),
    ('smoke', 'completorium', Brightness.light, 16),
    ('smoke', 'completorium', Brightness.dark, 24),
  ];
  for (final (dayId, hour, brightness, size) in cases) {
    testWidgets('$dayId $hour ${brightness.name} $size builds document', (
      tester,
    ) async {
      _fontSize = size;
      tester.view.physicalSize = const Size(900, 1600);
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
      await _captureIfRequested(
        tester,
        '$dayId-$hour-${brightness.name}-$size',
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
            '$dayId-$hour-${brightness.name}-$size-canticle',
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
            '$dayId-$hour-${brightness.name}-$size-marian',
          );
        }
      }
    });
  }

  for (final (brightness, size) in [
    (Brightness.light, 16.0),
    (Brightness.dark, 24.0),
  ]) {
    testWidgets('readings ${brightness.name} $size builds document', (
      tester,
    ) async {
      _fontSize = size;
      tester.view.physicalSize = const Size(900, 1600);
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
      await _captureIfRequested(tester, 'readings-${brightness.name}-$size');
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
