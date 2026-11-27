/// On-device storage of novena sessions: its own Hive box of JSON strings.
///
/// ```text
/// s:<sessionId>  session record (small; rewritten on every mark)
/// t:<sessionId>  text snapshot of all days (written once at start)
/// p:...          preferences (suggestions, dismissals, reading mode)
/// ```
///
/// Nothing here is synchronized, measured or logged.
library;

import 'dart:convert';
import 'dart:math';

import 'package:hive/hive.dart';
import 'package:mybrev_flutter/novena/novena_definition.dart';
import 'package:mybrev_flutter/novena/novena_session.dart';

const kNovenaBoxName = 'novenaSessions';

/// The few operations the store needs (Hive in the app, memory elsewhere).
abstract class NovenaBox {
  Iterable<String> get keys;
  String? read(String key);
  Future<void> write(String key, String value);
  Future<void> remove(String key);
}

class HiveNovenaBox implements NovenaBox {
  HiveNovenaBox(this._box);
  final Box<String> _box;

  @override
  Iterable<String> get keys => _box.keys.map((key) => '$key');
  @override
  String? read(String key) => _box.get(key);
  @override
  Future<void> write(String key, String value) async {
    await _box.put(key, value);
    await _box.flush();
  }

  @override
  Future<void> remove(String key) => _box.delete(key);
}

class MemoryNovenaBox implements NovenaBox {
  final Map<String, String> values = {};
  @override
  Iterable<String> get keys => values.keys;
  @override
  String? read(String key) => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> remove(String key) async => values.remove(key);
}

class NovenaState {
  const NovenaState({
    this.sessions = const [],
    this.suggestionsEnabled = true,
    this.dismissedDate,
    this.dismissed = const {},
    this.compact = false,
  });

  /// Newest first.
  final List<NovenaSession> sessions;
  final bool suggestionsEnabled;

  /// «Не цяпер» holds for [dismissedDate] only.
  final String? dismissedDate;
  final Set<String> dismissed;

  /// Reading mode of the day page.
  final bool compact;

  List<NovenaSession> get active => [
    for (final item in sessions)
      if (item.isActive) item,
  ];

  List<NovenaSession> get completed => [
    for (final item in sessions)
      if (item.status == NovenaStatus.completed) item,
  ];

  NovenaSession? activeFor(String novenaId) =>
      active.where((item) => item.novenaId == novenaId).firstOrNull;

  bool hasHistory(String novenaId) =>
      completed.any((item) => item.novenaId == novenaId);

  NovenaSession? session(String id) =>
      sessions.where((item) => item.sessionId == id).firstOrNull;

  /// Number of the quiet indicator.
  int needingAction(String today) =>
      sessions.where((item) => item.needsActionOn(today)).length;

  bool isDismissed(String novenaId, String today) =>
      dismissedDate == today && dismissed.contains(novenaId);
}

/// Reads and writes of one [NovenaBox]. Changes run one after another, so a
/// double tap cannot start two sessions or lose a mark.
class NovenaStore {
  NovenaStore(this.box, {Random? random}) : _random = random ?? Random.secure();

  final NovenaBox? box;
  final Random _random;
  Future<void> _tail = Future<void>.value();

  static const _session = 's:';
  static const _snapshot = 't:';
  static const _suggestions = 'p:suggestions';
  static const _dismissed = 'p:dismissed';
  static const _compact = 'p:compact';

  Map? _decode(String key) {
    final raw = box?.read(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map?;
    } catch (_) {
      return null;
    }
  }

  NovenaState read() {
    final store = box;
    if (store == null) return const NovenaState();
    final sessions = <NovenaSession>[
      for (final key in store.keys)
        if (key.startsWith(_session))
          if (_decode(key) case final data?) ?NovenaSession.tryParse(data),
    ]..sort((a, b) => b.sessionId.compareTo(a.sessionId));
    final dismissed = _decode(_dismissed);
    return NovenaState(
      sessions: List.unmodifiable(sessions),
      suggestionsEnabled: store.read(_suggestions) != 'off',
      dismissedDate: dismissed?['date'] as String?,
      dismissed: {...?(dismissed?['ids'] as List?)?.cast<String>()},
      compact: store.read(_compact) == 'on',
    );
  }

  /// All days as assembled when the session started; null when it is gone.
  List<List<NovenaBlock>>? snapshot(String sessionId) {
    final data = _decode('$_snapshot$sessionId');
    if (data == null) return null;
    try {
      return [
        for (final day in data['days'] as List)
          [for (final block in day as List) NovenaBlock.fromMap(block as Map)],
      ];
    } on TypeError {
      return null;
    }
  }

  Future<T> _serial<T>(Future<T> Function(NovenaBox box) action) {
    final store = box;
    if (store == null) {
      return Future.error(StateError('Novena storage is unavailable'));
    }
    final result = _tail.then((_) => action(store));
    _tail = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  Future<void> _put(NovenaSession session) =>
      box!.write('$_session${session.sessionId}', jsonEncode(session.toMap()));

  /// Starts [definition] today with the text of [days]; an active session of
  /// the same novena is returned instead of a second one.
  Future<NovenaSession> start(
    NovenaDefinition definition,
    List<List<NovenaBlock>> days,
    String today,
  ) => _serial((box) async {
    final running = read().activeFor(definition.novenaId);
    if (running != null) return running;
    // Sortable by creation time; random, never sent anywhere.
    final id =
        '${DateTime.now().microsecondsSinceEpoch.toString().padLeft(18, '0')}'
        '-${_random.nextInt(1 << 30).toRadixString(16)}';
    final session = NovenaSession(
      sessionId: id,
      novenaId: definition.novenaId,
      title: definition.title,
      contentVersion: definition.contentVersion,
      startDate: today,
      durationDays: definition.durationDays,
    );
    // The texts first: a session record never lacks its snapshot.
    await box.write(
      '$_snapshot$id',
      jsonEncode({
        'days': [
          for (final day in days) [for (final block in day) block.toMap()],
        ],
      }),
    );
    await _put(session);
    return session;
  });

  Future<void> setDay(String sessionId, int day, bool done, String today) =>
      _serial((box) async {
        final state = read();
        final session = state.session(sessionId);
        if (session == null) return;
        final next = session.withDay(day, done, today);
        if (identical(next, session)) return;
        // Undoing a finished novena must not create a second active one.
        if (!session.isActive &&
            next.isActive &&
            state.activeFor(session.novenaId) != null) {
          return;
        }
        await _put(next);
      });

  Future<void> stop(String sessionId, String today) => _serial((box) async {
    final session = read().session(sessionId);
    if (session == null || !session.isActive) return;
    await _put(session.stopped(today));
    // A stopped session is not read again.
    await box.remove('$_snapshot$sessionId');
  });

  Future<void> setSuggestions(bool enabled) =>
      _serial((box) => box.write(_suggestions, enabled ? 'on' : 'off'));

  Future<void> dismiss(Iterable<String> novenaIds, String today) =>
      _serial((box) async {
        final state = read();
        await box.write(
          _dismissed,
          jsonEncode({
            'date': today,
            'ids': {
              if (state.dismissedDate == today) ...state.dismissed,
              ...novenaIds,
            }.toList(),
          }),
        );
      });

  Future<void> setCompact(bool compact) =>
      _serial((box) => box.write(_compact, compact ? 'on' : 'off'));

  /// Opens the app's box; the tracker stays hidden when that fails.
  static Future<void> open() => Hive.openBox<String>(kNovenaBoxName);
}
