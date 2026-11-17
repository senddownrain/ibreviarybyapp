import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/models/day.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/screens/ora_screen.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/services/liturgical_content_service.dart';
import 'package:mybrev_flutter/utils/liturgical_titles.dart';
import 'package:mybrev_flutter/utils/hours_liturgical_options.dart';
import 'package:mybrev_flutter/utils/triduum_compline.dart';

LiturgicalDay litDay(int weekday, String officeKind, {int? complineDay}) =>
    LiturgicalDay.fromMap({
      'id': 'day',
      '_periodType': 'holyweek',
      '_dayOfWeek': weekday,
      '_ordoOfficeKind': officeKind,
      '_ordoComplineSolemnityPrayer': officeKind == 'triduum',
      '_ordoComplineDay': ?complineDay,
    });

class _SmokeSettings extends SettingsNotifier {
  @override
  SettingsState build() => const SettingsState(fontSize: 24);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  final service = LiturgicalContentService();
  const dioceses = ['minsk-mohilev', 'grodno', 'pinsk', 'vitebsk'];

  setUpAll(() async {
    await initializeDateFormatting('be');
    directory = await Directory.systemTemp.createTemp('triduum-compline-');
    await HiveService.init(path: directory.path, loadBundle: true);
    await HiveService.content.ensureLoaded(kContentCollections);
  });

  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  LiturgicalDay open(DateTime date, String id, String diocese) =>
      service.resolveDayLocal(
        date,
        id,
        null,
        null,
        null,
        diocese: diocese,
        forCompline: true,
      )!;

  test('three different Triduum antiphons match the printed breviary', () {
    final a = triduumAntiphon(litDay(5, 'triduum'));
    final b = triduumAntiphon(litDay(6, 'triduum'));
    final c = triduumAntiphon(litDay(7, 'triduum'));
    expect({a, b, c}.length, 3);
    expect(a, contains('ажно да смерці'));
    expect(b, contains('смерці крыжовай'));
    expect(c, contains('Таму Бог узвысіў Яго'));
    expect(triduumAntiphon(litDay(4, 'weekday')), isEmpty);
  });

  test('Vespers and Compline rubrics occur only on their own days', () {
    expect(triduumVespersNotice(litDay(5, 'triduum')), contains('Вячэры Пана'));
    expect(
      triduumVespersNotice(litDay(6, 'triduum')),
      contains('Літургіі Мукі Пана'),
    );
    expect(
      triduumComplineNotice(litDay(7, 'triduum')),
      contains('Пасхальнай вігіліі'),
    );
    expect(
      goodFridayIntercessionsRubric(litDay(6, 'triduum')),
      contains('Імшале'),
    );
    expect(goodFridayIntercessionsRubric(litDay(5, 'triduum')), isEmpty);
  });

  test('Ordo Compline template weekday is preserved through the local day', () {
    expect(
      completoriumRecordIdForDay(litDay(6, 'triduum', complineDay: 1)),
      'lent-d1',
    );
    final eveOfSolemnity = LiturgicalDay.fromMap({
      'id': 'eve',
      '_periodType': 'ordinary',
      '_dayOfWeek': 3,
      '_ordoComplineDay': 7,
    });
    expect(completoriumRecordIdForDay(eveOfSolemnity), 'ordinary-d7');
  });

  test('non-Sunday solemnities and Triduum use prayer number two', () {
    expect(
      specialComplinePrayer(litDay(6, 'triduum')),
      contains('наведай гэты дом'),
    );
    final solemnity = LiturgicalDay.fromMap({
      'id': 'solemnity',
      '_periodType': 'ordinary',
      '_dayOfWeek': 3,
      '_ordoOfficeKind': 'solemnity',
      '_ordoComplineSolemnityPrayer': true,
    });
    expect(specialComplinePrayer(solemnity), contains('наведай гэты дом'));
    expect(specialComplinePrayer(litDay(1, 'sunday')), isEmpty);
  });

  test(
    'both evenings of weekday solemnities load prayer 2 after cache restore',
    () async {
      await Hive.close();
      await HiveService.init(path: directory.path, loadBundle: true);
      await HiveService.content.ensureLoaded(kContentCollections);
      for (final diocese in dioceses) {
        for (final (iso, id) in [
          ('2026-12-31', 'christmas-d7'),
          ('2027-01-01', 'christmas-d1'),
          ('2027-12-07', 'advent-d7'),
          ('2027-12-08', 'advent-d1'),
        ]) {
          final date = DateTime.parse(iso);
          final content = service.contentForDate(date, diocese: diocese);
          for (final dayId in [content.options.first.dayId!, 'legacy-copy']) {
            final day = open(date, dayId, diocese);
            expect(
              completoriumRecordIdForDay(day),
              id,
              reason: '$iso $diocese $dayId',
            );
            expect(specialComplinePrayer(day), contains('наведай гэты дом'));
          }
        }
        for (final iso in ['2027-01-23', '2027-01-24', '2027-05-20']) {
          final day = open(DateTime.parse(iso), 'legacy-copy', diocese);
          expect(specialComplinePrayer(day), isEmpty);
        }
      }
    },
  );

  test('Triduum, octave and Word of God Sunday in all dioceses, 2026–2032', () {
    final sundays = [25, 24, 23, 21, 27, 26, 25];
    final easters = [
      (4, 5),
      (3, 28),
      (4, 16),
      (4, 1),
      (4, 21),
      (4, 13),
      (3, 28),
    ];
    for (final diocese in dioceses) {
      for (var year = 2026; year <= 2032; year++) {
        final sunday = DateTime(year, 1, sundays[year - 2026]);
        final content = service.contentForDate(sunday, diocese: diocese);
        expect(content.ordo.primary.title, contains('Нядзеля Божага Слова'));
        expect(content.options.first.title, contains('Нядзеля Божага Слова'));
        final day = open(sunday, content.options.first.dayId!, diocese);
        expect(
          liturgicalDayDisplayTitle(day, sunday),
          contains('Нядзеля Божага Слова'),
        );
        final following = sunday.add(const Duration(days: 7));
        expect(
          service
              .contentForDate(following, diocese: diocese)
              .ordo
              .primary
              .title,
          isNot(contains('Нядзеля Божага Слова')),
        );
        final (month, date) = easters[year - 2026];
        for (var i = -3; i <= 8; i++) {
          final civilDate = DateTime(year, month, date + i);
          final selected = open(civilDate, 'old-route', diocese);
          if (i < 0) {
            expect(completoriumRecordIdForDay(selected), 'lent-d1');
            expect(
              specialComplinePrayer(selected),
              contains('наведай гэты дом'),
            );
            expect(
              specialComplineResponsory(selected),
              contains('Хрыстус стаў'),
            );
          } else if (i <= 7) {
            expect(completoriumRecordIdForDay(selected), 'easter-d1');
            expect(
              completoriumRecordIdForDay(selected, firstVespers: true),
              'easter-d7',
            );
            expect(specialComplinePrayer(selected), isEmpty);
            expect(specialComplineResponsory(selected), contains('Вось дзень'));
          } else {
            expect(selected.field('_ordoComplineChoice'), 'false');
          }
        }
      }
    }
  });

  testWidgets('octave selector swaps the psalmody and prayer together', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsProvider.overrideWith(_SmokeSettings.new)],
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: OraScreen(
            dayId: 'legacy-copy',
            oraType: 'completorium',
            date: DateTime(2027, 3, 29),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Iterable<String> html() => tester
        .widgetList<Html>(find.byType(Html))
        .map((widget) => widget.data ?? '');
    int occurrences(String value) =>
        html().where((source) => source.contains(value)).length;

    expect(occurrences('пакорна просім Цябе напрыканцы'), 1);
    expect(occurrences('Вось дзень, які Пан учыніў'), 1);
    expect(occurrences('аддаю я дух мой'), 0);
    final secondPsalmody = html()
        .where((source) => source.contains('Псальм'))
        .toList();

    final selector = find.byKey(const Key('compline-formula-picker'));
    await tester.ensureVisible(selector);
    await tester.tap(selector);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Пасля I Нешпараў нядзелі'));
    await tester.pumpAndSettle();

    expect(occurrences('Пане, будзь з намі ў гэтую ноч'), 1);
    expect(occurrences('пакорна просім Цябе напрыканцы'), 0);
    expect(occurrences('Вось дзень, які Пан учыніў'), 1);
    expect(
      html().where((source) => source.contains('Псальм')).toList(),
      isNot(equals(secondPsalmody)),
    );
    expect(tester.takeException(), isNull);
  });
}
