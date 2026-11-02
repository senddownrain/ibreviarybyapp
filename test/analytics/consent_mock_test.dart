// P07: offline consent / queue / mock-transport tests (synthetic data, no network).
// The scenarios file is shared byte-for-byte with mybrev
// (tests/fixtures/analytics-consent-scenarios.json).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mybrev_flutter/analytics/consent_mock.dart';
import 'package:mybrev_flutter/analytics/public_inventory.dart';

Map<String, dynamic> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

final _contract = _json('test/fixtures/analytics/analytics-contract-v2.json');
final _scenarios = _json(
  'test/fixtures/analytics/analytics-consent-scenarios.json',
);
final int _t0 = DateTime.utc(2026, 10, 17, 12).millisecondsSinceEpoch;
const int _day = 86400000;

String _dayOf(String token, int now) {
  final offset = token == 'D0' ? 0 : int.parse(token.substring(1));
  return DateTime.fromMillisecondsSinceEpoch(
    now + offset * _day,
    isUtc: true,
  ).toIso8601String().substring(0, 10);
}

Map<String, Object?> _packet(String day, int cells) {
  final p =
      jsonDecode(jsonEncode(_contract['validPacket'])) as Map<String, Object?>;
  p['day'] = day;
  p['cells'] = (p['cells']! as List).take(cells).toList();
  return p;
}

class _World {
  _World({
    this.build = true,
    bool server = true,
    int minCells = kDefaultMinCells,
    int maxBytes = kMaxQueueBytes,
    MemoryKeyValueStore? kv,
  }) : server = server,
       kv = kv ?? MemoryKeyValueStore(),
       _minCells = minCells,
       _maxBytes = maxBytes {
    backend = MockBackend(
      now: () => now,
      publicIds: kAnalyticsPublicIds,
      lose: () {
        final v = loseNext;
        loseNext = false;
        return v;
      },
    );
    client = _make();
  }
  final bool build;
  bool server;
  final MemoryKeyValueStore kv;
  final int _minCells, _maxBytes;
  int now = _t0;
  bool loseNext = false;
  int purged = 0;
  late final MockBackend backend;
  late MockClient client;
  MockClient _make() => MockClient(
    buildFlag: build,
    serverFlag: () => server,
    store: kv,
    transport: backend.transport,
    now: () => now,
    publicIds: kAnalyticsPublicIds,
    minCells: _minCells,
    maxBytes: _maxBytes,
    onPurge: () => purged++,
  );
  void relaunch() => client = _make();
  OfferResult offer(String day, int cells) => client.offer(_packet(day, cells));
}

void main() {
  final config = _scenarios['config'] as Map<String, dynamic>;

  for (final sc in (_scenarios['scenarios'] as List).cast<Map>()) {
    test('scenario: ${sc['name']}', () async {
      final w = _World(
        build: sc['build'] as bool,
        server: sc['server'] as bool,
        minCells: config['minCells'] as int,
      );
      OfferResult? offered;
      FlushResult? flushed;
      final steps = (sc['steps'] as List).cast<Map>();
      for (var i = 0; i < steps.length; i++) {
        final step = steps[i];
        switch (step['op']) {
          case 'grant':
            w.client.grantConsent();
          case 'revoke':
            w.client.revokeConsent();
          case 'offer':
            offered = w.offer(
              _dayOf(step['day'] as String, w.now),
              step['cells'] as int,
            );
          case 'flush':
            flushed = await w.client.flush();
          case 'setServer':
            w.server = step['value'] as bool;
          case 'setBackend':
            w.backend.ingestEnabled = step['value'] as bool;
          case 'loseNext':
            w.loseNext = true;
          case 'relaunch':
            w.relaunch();
          case 'advanceDays':
            w.now += (step['days'] as int) * _day;
          default:
            fail('unknown op ${step['op']}');
        }
        final e = (step['expect'] as Map?) ?? const {};
        final at = '${sc['name']} / step $i (${step['op']})';
        if (e.containsKey('accepted') && step['op'] == 'offer') {
          expect(offered!.accepted, e['accepted'], reason: '$at: accepted');
        }
        if (e.containsKey('reason')) {
          expect(offered!.reason, e['reason'], reason: at);
        }
        if (e.containsKey('sent')) {
          expect(flushed!.sent, e['sent'], reason: '$at: sent');
        }
        if (e.containsKey('lost')) {
          expect(flushed!.lost, e['lost'], reason: '$at: lost');
        }
        if (e.containsKey('held')) {
          expect(flushed!.held, e['held'], reason: '$at: held');
        }
        if (e.containsKey('accepted') && step['op'] == 'flush') {
          expect(w.backend.accepted, e['accepted'], reason: '$at: backend');
        }
        if (e.containsKey('aggregateN')) {
          expect(w.backend.totalN, e['aggregateN'], reason: '$at: aggregate');
        }
        if (e.containsKey('queueDays')) {
          expect(
            [for (final p in w.client.queue()) p['day']],
            [
              for (final d in e['queueDays'] as List)
                _dayOf(d as String, w.now),
            ],
            reason: '$at: queue',
          );
        }
        if (e.containsKey('queueKeyPresent')) {
          expect(
            w.kv.has(kQueueKey),
            e['queueKeyPresent'],
            reason: '$at: queue key',
          );
        }
        if (e.containsKey('consent')) {
          expect(w.client.consent, e['consent'], reason: at);
        }
        if (e.containsKey('hostBufferPurged')) {
          expect(w.purged > 0, isTrue, reason: at);
        }
      }
    });
  }

  test(
    'gate matrix OFF/OFF, ON/OFF, OFF/ON, ON/ON: only ON/ON processes a packet',
    () async {
      for (final g in (_scenarios['gates'] as List).cast<Map>()) {
        final w = _World(
          build: g['build'] as bool,
          server: g['server'] as bool,
        );
        w.backend.ingestEnabled = g['server'] as bool;
        w.client.grantConsent();
        final processes = g['processes'] as bool;
        final offered = w.offer(_dayOf('D-1', _t0), 9);
        final flushed = await w.client.flush();
        expect(offered.accepted, processes, reason: '${g['name']}');
        expect(flushed.sent, processes ? 1 : 0, reason: '${g['name']}');
        expect(w.backend.calls, processes ? 1 : 0, reason: '${g['name']}');
        expect(w.backend.totalN, processes ? 28 : 0, reason: '${g['name']}');
        if (!(g['build'] as bool)) {
          expect(
            [w.kv.gets, w.kv.sets, w.kv.removes],
            [0, 0, 0],
            reason: 'build flag OFF must not touch storage',
          );
        }
      }
    },
  );

  test('default is OFF: fresh install and non-literal consent values', () {
    expect(_World().client.consent, isFalse);
    for (final bad in ['', 'TRUE', '1', 'yes', '{"a":1}', 'true ']) {
      final w = _World(kv: MemoryKeyValueStore({kConsentKey: bad}));
      expect(w.client.consent, isFalse, reason: bad);
      expect(w.offer(_dayOf('D-1', _t0), 9).accepted, isFalse);
    }
  });

  test('consent=false never writes anything', () {
    final w = _World();
    for (var i = 0; i < 50; i++) {
      w.offer(_dayOf('D0', _t0), 9);
    }
    expect(w.kv.has(kQueueKey), isFalse);
    expect(w.kv.sets, 0);
  });

  test('invalid packets are refused even with consent', () {
    final w = _World()..client.grantConsent();
    final bad = _packet(_dayOf('D-1', _t0), 9);
    ((bad['cells']! as List).first as Map)['content_id'] =
        'prayer:notInInventory';
    expect(w.client.offer(bad).reason, 'invalid_packet');
    final extra = _packet(_dayOf('D-1', _t0), 9)..['user_id'] = 'x';
    expect(w.client.offer(extra).accepted, isFalse);
    expect(w.kv.has(kQueueKey), isFalse);
  });

  test('queue: same day merged, byte cap, 14 days', () {
    final w = _World(maxBytes: 2500)..client.grantConsent();
    w.offer(_dayOf('D-1', _t0), 9);
    w.offer(_dayOf('D-1', _t0), 9);
    final q = w.client.queue();
    expect(q.length, 1);
    expect(
      (q.first['cells']! as List).fold<int>(
        0,
        (s, c) => s + ((c as Map)['n'] as int),
      ),
      56,
    );
    for (var d = 2; d <= 13; d++) {
      w.offer(_dayOf('D-$d', _t0), 9);
    }
    expect(w.kv.size(kQueueKey) <= 2500, isTrue);
    expect(w.client.overflow > 0, isTrue);
    expect(kMaxQueueBytes, 64 * 1024);
    final w2 = _World()..client.grantConsent();
    w2.offer(_dayOf('D-1', _t0), 9);
    w2.now += 15 * _day;
    w2.offer(_dayOf('D0', w2.now), 9);
    expect(
      [for (final p in w2.client.queue()) p['day']],
      [_dayOf('D0', w2.now)],
    );
  });

  test('non-204 and exceptions are counted lost and never retried', () async {
    final w = _World()..client.grantConsent();
    w.offer(
      _dayOf('D-5', _t0),
      9,
    ); // outside the server late-delivery window -> 400
    final r = await w.client.flush();
    expect([r.sent, r.lost], [0, 1]);
    expect(w.backend.totalN, 0);
    expect((await w.client.flush()).lost, 0);
  });

  test(
    'Hive adapter: queue lives in a Box<String>, revoke removes the key',
    () async {
      final dir = Directory.systemTemp.createTempSync('p07_hive');
      addTearDown(() async {
        await Hive.close();
        dir.deleteSync(recursive: true);
      });
      Hive.init(dir.path);
      final box = await Hive.openBox<String>('analytics_mock_test');
      final backend = MockBackend(
        now: () => _t0,
        publicIds: kAnalyticsPublicIds,
      );
      final client = MockClient(
        buildFlag: true,
        serverFlag: () => true,
        store: HiveKeyValueStore(box),
        transport: backend.transport,
        now: () => _t0,
        publicIds: kAnalyticsPublicIds,
      )..grantConsent();
      expect(client.offer(_packet(_dayOf('D-1', _t0), 9)).accepted, isTrue);
      expect(box.containsKey(kQueueKey), isTrue);
      client.revokeConsent();
      expect(box.containsKey(kQueueKey), isFalse);
      expect(box.get(kConsentKey), 'false');
    },
  );

  test(
    'isolation: nothing outside lib/analytics imports the mock; it has no network API',
    () {
      final src = File('lib/analytics/consent_mock.dart').readAsStringSync();
      final code = src
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      for (final word in [
        'dart:io',
        'dart:html',
        'package:http',
        'dio',
        'Socket',
        'HttpClient',
        'Uri.parse',
        'https://',
        'http://',
        'firebase',
        'sentry',
        'package_info',
      ]) {
        expect(code.contains(word), isFalse, reason: word);
      }
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (entity.path.replaceAll('\\', '/').startsWith('lib/analytics/')) {
          continue;
        }
        expect(
          entity.readAsStringSync().contains('consent_mock'),
          isFalse,
          reason: entity.path,
        );
      }
    },
  );
}
