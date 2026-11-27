import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mybrev_flutter/novena/novena_definition.dart';
import 'package:mybrev_flutter/novena/novena_session.dart';
import 'package:mybrev_flutter/novena/novena_store.dart';

import 'support.dart';

NovenaDefinition _definition(String id, {int version = 1}) =>
    NovenaDefinition.tryParse({
      ...readyDefinitions().firstWhere((d) => d['novenaId'] == id),
      'status': 'published',
      'trackerEnabled': true,
      'contentVersion': version,
    })!;

const _joseph = 'cn_05b28c5bea797880';
const _spirit = 'Iiufha8NyLABTw92rA5S';

void main() {
  late Map<String, NovenaPrayer> prayers;
  setUpAll(() => prayers = bundledPrayers());

  Future<NovenaSession> start(
    NovenaStore store,
    String id,
    String today, {
    int version = 1,
  }) {
    final definition = _definition(id, version: version);
    return store.start(definition, definition.resolveAll(prayers)!, today);
  }

  test(
    'a double start keeps one session; different novenas run together',
    () async {
      final store = NovenaStore(MemoryNovenaBox());
      final both = await Future.wait([
        start(store, _joseph, '2027-03-10'),
        start(store, _joseph, '2027-03-10'),
      ]);
      expect(both[0].sessionId, both[1].sessionId);
      expect(store.read().active, hasLength(1));
      await start(store, _spirit, '2027-03-11');
      expect(store.read().active, hasLength(2));
    },
  );

  test('days, marks, undo, a missed day and no false completion', () async {
    final store = NovenaStore(MemoryNovenaBox());
    final id = (await start(store, _joseph, '2027-03-10')).sessionId;
    NovenaSession session() => store.read().session(id)!;

    expect(session().calendarDay('2027-03-10'), 1);
    expect(session().needsActionOn('2027-03-10'), isTrue);
    // A future day is for reading only.
    await store.setDay(id, 2, true, '2027-03-10');
    expect(session().completedDays, isEmpty);

    await store.setDay(id, 1, true, '2027-03-10');
    await store.setDay(id, 1, true, '2027-03-10');
    expect(session().completedDays, {1});
    expect(session().needsActionOn('2027-03-10'), isFalse);
    expect(store.read().needingAction('2027-03-10'), 0);
    await store.setDay(id, 1, false, '2027-03-10');
    expect(session().completedDays, isEmpty);
    await store.setDay(id, 1, true, '2027-03-10');

    // Day 2 missed: nothing resets, and it can still be marked.
    expect(session().dayState(2, '2027-03-12'), NovenaDayState.missed);
    expect(session().dayState(3, '2027-03-12'), NovenaDayState.today);
    expect(session().dayState(4, '2027-03-12'), NovenaDayState.upcoming);
    expect(session().dayToPray('2027-03-12'), 3);
    for (var day = 3; day <= 9; day++) {
      await store.setDay(id, day, true, '2027-03-18');
    }

    // Long after the last day: not completed, never wraps to day 9.
    const later = '2027-04-20';
    expect(session().status, NovenaStatus.active);
    expect(session().calendarDay(later), 42);
    expect(session().isOverdue(later), isTrue);
    expect(session().needsActionOn(later), isTrue);
    expect(session().dayToPray(later), 2);
    await store.setDay(id, 2, true, later);
    expect(session().status, NovenaStatus.completed);
    expect(session().finishedDate, later);
    expect(store.read().completed, hasLength(1));
    expect(store.read().needingAction(later), 0);

    // Undo reopens it, unless another session of the novena runs already.
    await store.setDay(id, 2, false, later);
    expect(session().status, NovenaStatus.active);
    await store.setDay(id, 2, true, later);
    final again = await start(store, _joseph, later);
    expect(again.sessionId, isNot(id));
    await store.setDay(id, 2, false, later);
    expect(session().status, NovenaStatus.completed);
    expect(store.read().active.single.sessionId, again.sessionId);
  });

  test('before the start date nothing can be marked', () async {
    final store = NovenaStore(MemoryNovenaBox());
    final session = await start(store, _joseph, '2027-03-10');
    expect(session.needsActionOn('2027-03-09'), isFalse);
    expect(session.canMark(1, '2027-03-09'), isFalse);
    expect(session.dayToPray('2027-03-09'), 1);
  });

  test('civil days across a DST change and a year boundary', () async {
    final store = NovenaStore(MemoryNovenaBox());
    final spring = await start(store, _joseph, '2027-03-27');
    expect(spring.calendarDay('2027-03-29'), 3);
    final winter = await start(store, _spirit, '2027-12-28');
    expect(winter.calendarDay('2028-01-02'), 6);
    expect(winter.dateOfDay(9), '2028-01-05');
  });

  test('stop drops the texts and allows a new start', () async {
    final box = MemoryNovenaBox();
    final store = NovenaStore(box);
    final id = (await start(store, _joseph, '2027-03-10')).sessionId;
    await store.stop(id, '2027-03-11');
    await store.stop(id, '2027-03-11');
    expect(store.read().session(id)!.status, NovenaStatus.stopped);
    expect(store.snapshot(id), isNull);
    expect(store.read().active, isEmpty);
    expect(store.read().completed, isEmpty);
    expect((await start(store, _joseph, '2027-03-11')).sessionId, isNot(id));
  });

  test('Hive: start, restart offline, same progress and texts', () async {
    final directory = await Directory.systemTemp.createTemp('novena-');
    addTearDown(() => directory.delete(recursive: true));
    Hive.init(directory.path);
    await NovenaStore.open();
    var store = NovenaStore(HiveNovenaBox(Hive.box<String>(kNovenaBoxName)));
    final started = await start(store, _joseph, '2027-03-10', version: 3);
    await store.setDay(started.sessionId, 1, true, '2027-03-10');
    await store.dismiss(['a'], '2027-03-10');
    await store.setSuggestions(false);
    await store.setCompact(true);
    await Hive.close();

    // Another process, no content and no network at all.
    Hive.init(directory.path);
    await NovenaStore.open();
    addTearDown(Hive.close);
    store = NovenaStore(HiveNovenaBox(Hive.box<String>(kNovenaBoxName)));
    final state = store.read();
    final session = state.active.single;
    expect(session.sessionId, started.sessionId);
    expect(session.contentVersion, 3);
    expect(session.startDate, '2027-03-10');
    expect(session.completedDays, {1});
    expect(state.suggestionsEnabled, isFalse);
    expect(state.compact, isTrue);
    expect(state.isDismissed('a', '2027-03-10'), isTrue);
    expect(state.isDismissed('a', '2027-03-11'), isFalse);
    final expected = _definition(_joseph).resolveAll(prayers)!;
    final snapshot = store.snapshot(session.sessionId)!;
    expect(
      [
        for (final day in snapshot) [for (final b in day) b.toMap()],
      ],
      [
        for (final day in expected) [for (final b in day) b.toMap()],
      ],
    );
    // A newer publication does not change the running session.
    await start(store, _joseph, '2027-03-12', version: 4);
    expect(store.read().active.single.contentVersion, 3);
  });

  test('unreadable records are skipped, no storage shows nothing', () async {
    final box = MemoryNovenaBox()
      ..values['s:bad'] = 'not json'
      ..values['s:newer'] = '{"status":"paused"}'
      ..values['t:bad'] = '{';
    final store = NovenaStore(box);
    expect(store.read().sessions, isEmpty);
    expect(store.snapshot('bad'), isNull);
    final none = NovenaStore(null);
    expect(none.read().sessions, isEmpty);
    await expectLater(none.setSuggestions(false), throwsStateError);
  });
}
