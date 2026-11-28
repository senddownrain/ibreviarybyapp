import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/dev/novena_harness.dart';
import 'package:mybrev_flutter/models/priest_access_content.dart';
import 'package:mybrev_flutter/novena/novena_definition.dart';
import 'package:mybrev_flutter/novena/novena_session.dart';
import 'package:mybrev_flutter/novena/novena_store.dart';
import 'package:mybrev_flutter/novena/pompeii.dart';
import 'package:mybrev_flutter/novena/ui/novena_routes.dart';

import 'support.dart';

const _joseph = 'cn_05b28c5bea797880';
const _page = '/prayers/prayer/$kPompeiiNovenaId';

void main() {
  late PrayerAccessContent content;
  late List<Map> definitions;
  late Map<String, NovenaPrayer> prayers;
  late MemoryNovenaBox box;
  var today = DateTime(2027, 3, 1);

  setUpAll(() {
    content = PrayerAccessContent(
      bundledDocs('prayers'),
      bundledDocs('prayerCategories'),
    ).publicOnly;
    definitions = [
      for (final item in readyDefinitions()) NovenaHarness.published(item),
    ];
    prayers = bundledPrayers();
  });

  setUp(() {
    box = MemoryNovenaBox();
    today = DateTime(2027, 3, 1);
  });

  NovenaDefinition definition() => NovenaDefinition.builtIn(
    novenaId: kPompeiiNovenaId,
    title: 'Пампейская навэнна',
    durationDays: kPompeiiDays,
  );

  Future<NovenaSession> start(String date) =>
      NovenaStore(box).start(definition(), pompeiiDays(prayers)!, date);

  test('54 days: petition to day 27, thanksgiving from day 28', () {
    final days = pompeiiDays(prayers)!;
    expect(days, hasLength(54));
    String text(int day) => days[day - 1].map((b) => b.markdown).join('\n');
    for (final day in [1, 27]) {
      expect(text(day), contains('Памятай, о міласэрная'));
      expect(text(day), isNot(contains('Што ж я магу даць Табе')));
    }
    for (final day in [28, 54]) {
      expect(text(day), contains('Што ж я магу даць Табе'));
      expect(text(day), isNot(contains('Памятай, о міласэрная')));
    }
    final parts = days.first.where((block) => block.kind == 'part').toList();
    expect(parts.map((block) => block.title), [
      'Радасныя таямніцы',
      'Балесныя таямніцы',
      'Хвалебныя таямніцы',
      'Таямніцы святла (паводле жадання)',
    ]);
    for (final part in parts) {
      // Five mysteries, then the prayer of the phase and the invocation.
      expect(
        RegExp(r'^### ', multiLine: true).allMatches(part.markdown).length,
        5,
      );
      expect(part.markdown, contains('Памятай, о міласэрная'));
      expect(
        part.markdown,
        contains('Каралева Ружанца Святога, маліся за нас!'),
      );
    }
    final basics = days.first.where((block) => block.kind == 'prayer').toList();
    expect(basics.map((block) => block.title), [
      'Веру ў Бога',
      'Ойча наш',
      'Вітай, Марыя (3 разы)',
      'Хвала Айцу',
    ]);
    expect(basics[0].markdown, contains('Стварыцеля неба і зямлі'));
    expect(basics[1].markdown, contains('Хлеба нашага штодзённага'));
    expect(basics[2].markdown, contains('поўная ласкі'));
    expect(basics[3].markdown, contains('на векі вечныя'));
    expect(text(1), contains('Гэты Ружанец малюся на Тваю хвалу'));
  });

  test('a missing or closed text means no tracker, nothing substituted', () {
    for (final id in [kPompeiiNovenaId, kPompeiiBasicsId, kPompeiiRosaryId]) {
      expect(pompeiiDays({...prayers}..remove(id)), isNull, reason: id);
    }
  });

  test('the snapshot keeps each phase once and survives a restart', () async {
    final session = await start('2027-03-01');
    final stored = box.values['t:${session.sessionId}']!;
    final one = pompeiiDays(
      prayers,
    )!.first.map((b) => b.markdown).join().length;
    expect(stored.length, lessThan(one * 3));

    final read = NovenaStore(box).snapshot(session.sessionId)!;
    expect(read, hasLength(54));
    expect(read[26].last.toMap(), read[0].last.toMap());
    expect(
      read[27].map((b) => b.markdown).join(),
      contains('Што ж я магу даць Табе'),
    );
  });

  test('marks, undo, a missed day, the end and completion', () async {
    final store = NovenaStore(box);
    final id = (await start('2027-03-01')).sessionId;
    NovenaSession session() => store.read().session(id)!;
    await store.setDay(id, 1, true, '2027-03-01');
    await store.setDay(id, 1, false, '2027-03-01');
    expect(session().completedCount, 0);
    // The phase follows the day, whatever was marked.
    expect(session().calendarDay('2027-03-28'), 28);
    expect(isPompeiiThanksgiving(session().calendarDay('2027-03-28')), isTrue);
    expect(session().dayState(2, '2027-03-05'), NovenaDayState.missed);
    // After day 54 an unfinished novena stays active.
    expect(session().isOverdue('2027-05-01'), isTrue);
    expect(session().status, NovenaStatus.active);
    for (var day = 1; day <= 54; day++) {
      await store.setDay(id, day, true, '2027-05-01');
    }
    expect(session().status, NovenaStatus.completed);
    expect(store.read().completed, hasLength(1));
  });

  Future<void> pump(
    WidgetTester tester, {
    String location = _page,
    double scale = 1,
    String scheme = 'light',
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      NovenaHarness(
        key: UniqueKey(),
        content: content,
        definitions: definitions,
        box: box,
        clock: () => today,
        initialLocation: location,
        scale: scale,
        scheme: scheme,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('start from the prayer page; two groups of 27; pray and mark', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byKey(const Key('novena-pompeii-phases')), findsOneWidget);
    expect(find.byKey(const Key('novena-pompeii-order')), findsOneWidget);
    await tap(tester, find.byKey(const Key('novena-start')));
    expect(find.byKey(const Key('novena-phase-1')), findsOneWidget);
    expect(find.byKey(const Key('novena-phase-28')), findsOneWidget);
    expect(find.byKey(const Key('novena-day-54')), findsOneWidget);

    await tap(tester, find.byKey(const Key('novena-pray')));
    expect(find.textContaining('МАЛІТВА ПРОСЬБЫ'), findsWidgets);
    final reader = find.byKey(const Key('novena-day-reader'));
    expect(reader, findsOneWidget);
    // Below the fold of the reader's sliver, so look offstage too.
    await tap(
      tester,
      find.text('Радасныя таямніцы', skipOffstage: false).first,
    );
    expect(tester.takeException(), isNull);
    // One row of nine on the day page; the grid and day 28 are one tap away.
    Finder dot(int day) => find.descendant(
      of: reader,
      matching: find.byKey(Key('novena-day-$day'), skipOffstage: false),
      skipOffstage: false,
    );
    expect(dot(9), findsOneWidget);
    expect(dot(10), findsNothing);
    await tap(
      tester,
      find.byKey(const Key('novena-all-days'), skipOffstage: false),
    );
    expect(dot(54), findsOneWidget);
    await tap(tester, dot(28));
    expect(find.textContaining('МАЛІТВА ПАДЗЯКІ'), findsWidgets);
    expect(find.byKey(const Key('novena-future-day')), findsOneWidget);
    // Reading marked nothing.
    expect(NovenaStore(box).read().active.single.completedCount, 0);
  });

  testWidgets('beside an ordinary novena: indicator, list and chooser', (
    tester,
  ) async {
    final joseph = NovenaDefinition.tryParse(
      definitions.firstWhere((item) => item['novenaId'] == _joseph),
    )!;
    await NovenaStore(
      box,
    ).start(joseph, joseph.resolveAll(prayers)!, '2027-03-01');
    final session = await start('2027-03-01');
    expect(NovenaStore(box).read().needingAction('2027-03-01'), 2);
    await NovenaStore(box).setDay(session.sessionId, 1, true, '2027-03-01');
    expect(NovenaStore(box).read().needingAction('2027-03-01'), 1);

    await pump(tester, location: novenasLocation);
    expect(find.byKey(const Key('novena-bar')), findsOneWidget);
    expect(find.text('Малітва просьбы'), findsOneWidget);
    // Nine circles of the ordinary one only.
    expect(find.byKey(const Key('novena-day-54')), findsNothing);
    await tap(tester, find.byKey(const Key('novena-start-new')));
    await tester.scrollUntilVisible(
      find.text('Пампейская навэнна').last,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Пампейская навэнна'), findsWidgets);
  });

  testWidgets('narrow screen, large text and every theme do not overflow', (
    tester,
  ) async {
    await start('2027-02-01');
    for (final scheme in ['light', 'dark', 'marian']) {
      for (final location in [_page, novenasLocation]) {
        await pump(
          tester,
          location: location,
          scheme: scheme,
          scale: 2,
          size: const Size(320, 640),
        );
        expect(tester.takeException(), isNull, reason: '$scheme $location');
      }
    }
    await pump(tester, size: const Size(320, 640), scale: 2);
    await tap(tester, find.byKey(const Key('novena-pray')));
    expect(tester.takeException(), isNull);
  });
}
