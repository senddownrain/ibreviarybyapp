import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mybrev_flutter/discovery/discovery.dart';

import 'support.dart';

class _BrokenStorage implements DiscoveryStorage {
  @override
  Future<void> clear() async => throw StateError('down');

  @override
  Future<String?> read() async => throw StateError('down');

  @override
  Future<void> write(String value) async => throw StateError('down');
}

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('discovery_hive');
    Hive.init(dir.path);
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  test('Hive storage persists across a fake restart', () async {
    final clock = FakeDiscoveryClock(t0);
    final first = await openRepo(HiveDiscoveryStorage(), clock);
    await first.dismiss('readings.day_variants');
    await first.flush();
    await Hive.close();

    final second = await openRepo(HiveDiscoveryStorage(), clock);
    expect(second.state.record('readings.day_variants').dismissed, isTrue);
    expect(second.sessionIndex, 2);
  });

  test('it never touches the user settings box or other boxes', () async {
    final settings = await Hive.openBox('settings');
    await settings.put('fontScale', 1.4);
    await settings.put('favorites', ['p1', 'p2']);
    final prayers = await Hive.openBox('localPrayers');
    await prayers.put('mine', {'title': 'x'});

    final repo = await openRepo(HiveDiscoveryStorage(), FakeDiscoveryClock(t0));
    await repo.dismiss('discover.bible');
    await repo.resetHistory();
    await repo.setHintsEnabled(false);
    await repo.flush();

    expect(settings.toMap(), {
      'fontScale': 1.4,
      'favorites': ['p1', 'p2'],
    });
    expect(prayers.toMap(), {
      'mine': {'title': 'x'},
    });
    expect(HiveDiscoveryStorage.defaultBoxName, isNot('settings'));
    expect(Hive.isBoxOpen('discovery_v1'), isTrue);
  });

  test('an unreadable or unwritable store never throws into the UI', () async {
    final repo = await openRepo(_BrokenStorage(), FakeDiscoveryClock(t0));
    await repo.dismiss('discover.bible');
    await repo.flush();
    expect(repo.state.record('discover.bible').dismissed, isTrue);
  });

  test('a state written by a newer build is not overwritten', () async {
    final storage = MemoryDiscoveryStorage()
      ..value = '{"schema":99,"hintsEnabled":false}';
    final repo = await openRepo(storage, FakeDiscoveryClock(t0));
    await repo.dismiss('discover.bible');
    await repo.flush();
    expect(storage.value, '{"schema":99,"hintsEnabled":false}');
  });
}
