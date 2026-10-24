// P07: OFFLINE mock of the future client side (consent + local queue + sender).
// TEST ONLY / NO DATA SENT. Mirror of mybrev experiments/analytics-ingest/src/mock-client.mjs
// (same shared scenarios: test/fixtures/analytics/analytics-consent-scenarios.json).
//
// Nothing outside lib/analytics imports this file and it has no dart:io, http,
// socket or SDK use: the "transport" is a function call into an in-memory
// aggregator. A normal build never references it (tree-shaken); the guard test
// in test/analytics/consent_mock_test.dart enforces both facts.
//
// Gate (fail closed): active only if build flag AND server flag (kill switch)
// AND the user's consent are all ON. Consent defaults to OFF and lives only in
// the device-local store, never in a remote profile. Delivery is AT-MOST-ONCE:
// a packet leaves the persisted queue BEFORE it is handed to the transport and
// is never retried, so a crash / 4xx / 5xx / loss under-counts, never double-counts.
import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:mybrev_flutter/analytics/contract.dart';
import 'package:mybrev_flutter/analytics/transport.dart';

const String kConsentKey = 'analytics_mock_consent_v1';
const String kQueueKey = 'analytics_mock_queue_v1';
const int kMaxQueueBytes = 64 * 1024;
const int kMaxQueueDays = maxLocalDays; // 14
const int kDefaultMinCells = 3;
const int _dayMs = 86400000;

/// Device-local store (a Hive box in the future; memory in tests/demo).
abstract class MockKeyValueStore {
  String? get(String key);
  void set(String key, String value);
  void remove(String key);
  bool has(String key);
}

class MemoryKeyValueStore implements MockKeyValueStore {
  MemoryKeyValueStore([Map<String, String>? initial]) : _data = {...?initial};
  final Map<String, String> _data;
  int gets = 0, sets = 0, removes = 0;
  @override
  String? get(String key) {
    gets++;
    return _data[key];
  }

  @override
  void set(String key, String value) {
    sets++;
    _data[key] = value;
  }

  @override
  void remove(String key) {
    removes++;
    _data.remove(key);
  }

  @override
  bool has(String key) => _data.containsKey(key);
  int size(String key) => _data[key]?.length ?? 0;
}

/// Adapter for a Hive `Box<String>` (the box type LocalAnalytics already uses).
class HiveKeyValueStore implements MockKeyValueStore {
  HiveKeyValueStore(this._box);
  final Box<String> _box;
  @override
  String? get(String key) => _box.get(key);
  @override
  void set(String key, String value) => _box.put(key, value);
  @override
  void remove(String key) => _box.delete(key);
  @override
  bool has(String key) => _box.containsKey(key);
}

String _utcDay(int ms) => DateTime.fromMillisecondsSinceEpoch(
  ms,
  isUtc: true,
).toIso8601String().substring(0, 10);
int _dayNumber(String day) =>
    DateTime.parse('${day}T00:00:00Z').millisecondsSinceEpoch ~/ _dayMs;

/// In-process stand-in for the P06 ingest core + in-memory store.
class MockBackend {
  MockBackend({
    required this.now,
    required this.publicIds,
    this.ingestEnabled = true,
    this.lose,
    this.maxDayAgeDays = 2,
  });
  final int Function() now;
  final Set<String> publicIds;
  bool ingestEnabled;
  bool Function()? lose;
  final int maxDayAgeDays;
  int calls = 0;
  int accepted = 0;
  final Map<String, int> counts = {};

  int get totalN => counts.values.fold(0, (a, b) => a + b);

  late final AnalyticsTransport transport = _BackendTransport(this);

  TransportResponse _handle(Map<String, Object?> packet) {
    calls++;
    if (lose?.call() ?? false) throw StateError('simulated loss');
    if (!ingestEnabled) {
      return const TransportResponse(503); // before any parsing
    }
    final errors = validatePacket(packet, publicIds: publicIds);
    if (errors.isNotEmpty) return const TransportResponse(400);
    final age =
        _dayNumber(_utcDay(now())) - _dayNumber(packet['day']! as String);
    if (packet['region'] != 'UNKNOWN' || age < 0 || age > maxDayAgeDays) {
      return const TransportResponse(400);
    }
    for (final raw in packet['cells']! as List) {
      final cell = raw as Map;
      final key = jsonEncode([
        packet['day'],
        packet['platform'],
        packet['app_version'],
        packet['region'],
        cellKey(cell),
      ]);
      counts[key] = (counts[key] ?? 0) + (cell['n'] as int);
    }
    accepted++;
    return const TransportResponse(204);
  }
}

class _BackendTransport implements AnalyticsTransport {
  _BackendTransport(this._backend);
  final MockBackend _backend;
  @override
  Future<TransportResponse> send(Map<String, Object?> packet) async =>
      _backend._handle(packet);
}

class OfferResult {
  const OfferResult(this.accepted, [this.reason]);
  final bool accepted;
  final String? reason;
}

class FlushResult {
  const FlushResult({this.sent = 0, this.lost = 0, this.held = 0});
  final int sent, lost, held;
}

class MockClient {
  MockClient({
    required this.buildFlag,
    required this.serverFlag,
    required this.store,
    required this.transport,
    required this.now,
    required this.publicIds,
    this.minCells = kDefaultMinCells,
    this.maxBytes = kMaxQueueBytes,
    this.ttlDays = kMaxQueueDays,
    this.onPurge,
  });

  final bool buildFlag;
  final bool Function() serverFlag;
  final MockKeyValueStore store;
  final AnalyticsTransport transport;
  final int Function() now;
  final Set<String> publicIds;
  final int minCells, maxBytes, ttlDays;
  final void Function()? onPurge;

  int sent = 0, lost = 0, overflow = 0, rejected = 0, purged = 0;
  bool _flushing = false;

  bool get consent => buildFlag && store.get(kConsentKey) == 'true';
  bool get _active => buildFlag && consent && serverFlag();

  void grantConsent() {
    if (buildFlag) store.set(kConsentKey, 'true');
  }

  /// Stops collecting, wipes the queue and the host buffer, retries nothing.
  void revokeConsent() {
    if (!buildFlag) return;
    store.set(kConsentKey, 'false');
    _purge();
  }

  List<Map<String, Object?>> queue() => buildFlag ? _readQueue() : const [];

  List<Map<String, Object?>> _readQueue() {
    try {
      final parsed = jsonDecode(store.get(kQueueKey) ?? '[]');
      if (parsed is! List) return [];
      return [for (final p in parsed) Map<String, Object?>.from(p as Map)];
    } catch (_) {
      return [];
    }
  }

  void _writeQueue(List<Map<String, Object?>> queue) {
    var list = queue;
    var text = jsonEncode(list);
    while (text.length > maxBytes && list.isNotEmpty) {
      list = list.sublist(1); // oldest day first
      overflow++;
      text = jsonEncode(list);
    }
    if (list.isEmpty) {
      store.remove(kQueueKey);
    } else {
      store.set(kQueueKey, text);
    }
  }

  List<Map<String, Object?>> _expire(List<Map<String, Object?>> queue) {
    final today = _dayNumber(_utcDay(now()));
    return [
      for (final p in queue)
        if (today - _dayNumber(p['day']! as String) <= ttlDays) p,
    ];
  }

  void _purge() {
    final had = store.has(kQueueKey);
    store.remove(kQueueKey);
    onPurge?.call();
    if (had) purged++;
  }

  bool _enforce() {
    if (!buildFlag) return false;
    if (_active) return true;
    _purge();
    return false;
  }

  bool get isActive => _enforce();

  String _gateReason() {
    if (!buildFlag) return 'build_flag_off';
    if (!serverFlag()) return 'kill_switch';
    return 'no_consent';
  }

  OfferResult offer(Map<String, Object?> packet) {
    if (!_enforce()) {
      rejected++;
      return OfferResult(false, _gateReason());
    }
    if (validatePacket(packet, publicIds: publicIds).isNotEmpty) {
      rejected++;
      return const OfferResult(false, 'invalid_packet');
    }
    final copy = jsonDecode(jsonEncode(packet)) as Map<String, Object?>;
    final queue = _expire(_readQueue());
    final same = queue.where(
      (p) =>
          p['day'] == copy['day'] &&
          p['platform'] == copy['platform'] &&
          p['app_version'] == copy['app_version'],
    );
    if (same.isNotEmpty) {
      final cells = same.first['cells']! as List;
      final index = {for (final c in cells) cellKey(c as Map): c};
      for (final raw in copy['cells']! as List) {
        final cell = Map<String, Object?>.from(raw as Map);
        final hit = index[cellKey(cell)];
        if (hit != null) {
          hit['n'] = ((hit['n'] as int) + (cell['n'] as int)).clamp(
            0,
            maxCellCount,
          );
        } else if (cells.length < maxCellsPerPacket) {
          cells.add(cell);
          index[cellKey(cell)] = cell;
        } else {
          overflow++;
        }
      }
    } else {
      queue.add(copy);
    }
    queue.sort((a, b) => (a['day']! as String).compareTo(b['day']! as String));
    _writeQueue(queue);
    return const OfferResult(true);
  }

  /// App resume / daily trigger: each CLOSED day with >= [minCells] cells goes
  /// to the transport once.
  Future<FlushResult> flush() async {
    if (_flushing || !_enforce()) return const FlushResult();
    _flushing = true;
    var s = 0, l = 0, held = 0;
    try {
      var queue = _readQueue();
      final alive = _expire(queue);
      if (alive.length != queue.length) _writeQueue(alive);
      queue = alive;
      final today = _utcDay(now());
      final due = [
        for (final p in queue)
          if ((p['day']! as String).compareTo(today) < 0 &&
              (p['cells']! as List).length >= minCells)
            p,
      ];
      held = queue.length - due.length;
      for (final packet in due) {
        if (!_enforce()) break; // revoked / kill switch flipped mid-flush
        final rest = _readQueue()
            .where(
              (p) =>
                  !(p['day'] == packet['day'] &&
                      p['platform'] == packet['platform'] &&
                      p['app_version'] == packet['app_version']),
            )
            .toList();
        try {
          _writeQueue(rest);
        } catch (_) {
          break; // cannot persist the removal -> do NOT send (no duplicates)
        }
        try {
          final response = await transport.send(packet);
          if (response.status == 204) {
            sent++;
            s++;
          } else {
            lost++;
            l++;
          }
        } catch (_) {
          lost++;
          l++; // no retry: accepted under-count
        }
      }
    } finally {
      _flushing = false;
    }
    return FlushResult(sent: s, lost: l, held: held);
  }
}
