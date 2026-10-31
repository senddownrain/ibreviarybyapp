import 'dart:convert';

import 'package:flutter/foundation.dart' show immutable;

const int kDiscoverySchema = 1;

/// Product tour progress. Stage 6 owns the transitions; the engine only
/// stores it and refuses automatic hints while a tour runs.
enum TourStatus {
  notOffered('not_offered'),
  declined('declined'),
  completed('completed'),
  skipped('skipped'),
  inProgress('in_progress');

  const TourStatus(this.wire);

  final String wire;

  static TourStatus parse(Object? value) => TourStatus.values.firstWhere(
    (status) => status.wire == value,
    orElse: () => TourStatus.notOffered,
  );
}

/// Per-hint history. Unknown IDs are kept as they are.
@immutable
class HintRecord {
  const HintRecord({
    this.seenCount = 0,
    this.lastSeenAtMs,
    this.dismissed = false,
    this.completed = false,
    this.hintVersion = 0,
    this.snoozeCount = 0,
    this.snoozedSession,
    this.snoozedVisit,
  });

  final int seenCount;
  final int? lastSeenAtMs;
  final bool dismissed;
  final bool completed;

  /// Version of the hint when it was last shown.
  final int hintVersion;
  final int snoozeCount;

  /// Session and visit of the last «Пазней»; a repeat needs a new visit.
  final int? snoozedSession;
  final int? snoozedVisit;

  HintRecord copyWith({
    int? seenCount,
    int? lastSeenAtMs,
    bool? dismissed,
    bool? completed,
    int? hintVersion,
    int? snoozeCount,
    int? snoozedSession,
    int? snoozedVisit,
  }) => HintRecord(
    seenCount: seenCount ?? this.seenCount,
    lastSeenAtMs: lastSeenAtMs ?? this.lastSeenAtMs,
    dismissed: dismissed ?? this.dismissed,
    completed: completed ?? this.completed,
    hintVersion: hintVersion ?? this.hintVersion,
    snoozeCount: snoozeCount ?? this.snoozeCount,
    snoozedSession: snoozedSession ?? this.snoozedSession,
    snoozedVisit: snoozedVisit ?? this.snoozedVisit,
  );

  Map<String, Object?> toJson() => {
    'seenCount': seenCount,
    'lastSeenAt': lastSeenAtMs,
    'dismissed': dismissed,
    'completed': completed,
    'hintVersion': hintVersion,
    'snoozeCount': snoozeCount,
    'snoozedSession': snoozedSession,
    'snoozedVisit': snoozedVisit,
  };

  /// Returns null for an unusable entry.
  static HintRecord? tryParse(Object? raw) {
    if (raw is! Map) return null;
    int? intOf(String key) {
      final value = raw[key];
      return value is int ? value : null;
    }

    return HintRecord(
      seenCount: (intOf('seenCount') ?? 0).clamp(0, 1000000),
      lastSeenAtMs: intOf('lastSeenAt'),
      dismissed: raw['dismissed'] == true,
      completed: raw['completed'] == true,
      hintVersion: intOf('hintVersion') ?? 0,
      snoozeCount: (intOf('snoozeCount') ?? 0).clamp(0, 1000),
      snoozedSession: intOf('snoozedSession'),
      snoozedVisit: intOf('snoozedVisit'),
    );
  }
}

/// Everything the engine persists. Immutable; mutations return a new state.
@immutable
class DiscoveryState {
  const DiscoveryState({
    this.hintsEnabled = true,
    this.tourStatus = TourStatus.notOffered,
    this.sessionCount = 0,
    this.records = const {},
    this.autoShownAtMs = const [],
    this.fromNewerSchema = false,
  });

  static const empty = DiscoveryState();

  /// Global switch; off silences every automatic hint.
  final bool hintsEnabled;
  final TourStatus tourStatus;

  /// Number of app sessions started on this profile.
  final int sessionCount;
  final Map<String, HintRecord> records;

  /// Epoch milliseconds of automatic displays still inside the window.
  final List<int> autoShownAtMs;

  /// Written by a newer build: read as defaults and never written back.
  final bool fromNewerSchema;

  HintRecord record(String id) => records[id] ?? const HintRecord();

  int? get lastAutoShownAtMs => autoShownAtMs.isEmpty
      ? null
      : autoShownAtMs.reduce((a, b) => a > b ? a : b);

  DiscoveryState copyWith({
    bool? hintsEnabled,
    TourStatus? tourStatus,
    int? sessionCount,
    Map<String, HintRecord>? records,
    List<int>? autoShownAtMs,
  }) => DiscoveryState(
    hintsEnabled: hintsEnabled ?? this.hintsEnabled,
    tourStatus: tourStatus ?? this.tourStatus,
    sessionCount: sessionCount ?? this.sessionCount,
    records: records ?? this.records,
    autoShownAtMs: autoShownAtMs ?? this.autoShownAtMs,
    fromNewerSchema: fromNewerSchema,
  );

  DiscoveryState _withRecord(String id, HintRecord record) =>
      copyWith(records: {...records, id: record});

  static const _window = Duration(days: 7);
  static const _maxStamps = 64;

  /// A hint appeared. A manual display (tour) never touches the quota.
  DiscoveryState shown(
    String id, {
    required int version,
    required DateTime now,
    required bool automatic,
  }) {
    final nowMs = now.millisecondsSinceEpoch;
    final current = record(id);
    final next = _withRecord(
      id,
      current.copyWith(
        seenCount: current.seenCount + 1,
        lastSeenAtMs: nowMs,
        hintVersion: version,
      ),
    );
    if (!automatic) return next;
    final cutoff = nowMs - _window.inMilliseconds;
    final stamps = [
      for (final stamp in autoShownAtMs)
        if (stamp > cutoff) stamp,
      nowMs,
    ];
    return next.copyWith(
      autoShownAtMs: stamps.length > _maxStamps
          ? stamps.sublist(stamps.length - _maxStamps)
          : stamps,
    );
  }

  DiscoveryState dismissedHint(String id) =>
      _withRecord(id, record(id).copyWith(dismissed: true));

  DiscoveryState completedHint(String id) =>
      _withRecord(id, record(id).copyWith(completed: true));

  DiscoveryState snoozedHint(
    String id, {
    required int session,
    required int visit,
  }) {
    final current = record(id);
    return _withRecord(
      id,
      current.copyWith(
        snoozeCount: current.snoozeCount + 1,
        snoozedSession: session,
        snoozedVisit: visit,
      ),
    );
  }

  /// Test-profile reset: hint history only. Settings, the tour status and
  /// the session counter stay.
  DiscoveryState historyReset() =>
      copyWith(records: const {}, autoShownAtMs: const []);

  /// A timestamp far ahead of [now] (clock moved back) is pulled to [now]
  /// so the cooldown starts again instead of blocking for months.
  DiscoveryState clampFuture(DateTime now, {required Duration skew}) {
    final nowMs = now.millisecondsSinceEpoch;
    final limit = nowMs + skew.inMilliseconds;
    bool far(int? stamp) => stamp != null && stamp > limit;
    if (!autoShownAtMs.any(far) &&
        !records.values.any((record) => far(record.lastSeenAtMs))) {
      return this;
    }
    return DiscoveryState(
      hintsEnabled: hintsEnabled,
      tourStatus: tourStatus,
      sessionCount: sessionCount,
      fromNewerSchema: fromNewerSchema,
      autoShownAtMs: [for (final s in autoShownAtMs) far(s) ? nowMs : s],
      records: {
        for (final entry in records.entries)
          entry.key: far(entry.value.lastSeenAtMs)
              ? entry.value.copyWith(lastSeenAtMs: nowMs)
              : entry.value,
      },
    );
  }

  String encode() => jsonEncode({
    'schema': kDiscoverySchema,
    'hintsEnabled': hintsEnabled,
    'tourStatus': tourStatus.wire,
    'sessionCount': sessionCount,
    'autoShownAt': autoShownAtMs,
    'records': {for (final e in records.entries) e.key: e.value.toJson()},
  });

  /// Never throws: a missing, corrupt or newer payload becomes defaults.
  static DiscoveryState decode(String? raw) {
    if (raw == null || raw.isEmpty) return empty;
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return empty;
      final schema = json['schema'];
      if (schema is int && schema > kDiscoverySchema) {
        return const DiscoveryState(fromNewerSchema: true);
      }
      final records = <String, HintRecord>{};
      final rawRecords = json['records'];
      if (rawRecords is Map) {
        for (final entry in rawRecords.entries) {
          final parsed = HintRecord.tryParse(entry.value);
          if (entry.key is String && parsed != null) {
            records[entry.key as String] = parsed;
          }
        }
      }
      final stamps = json['autoShownAt'];
      final sessions = json['sessionCount'];
      return DiscoveryState(
        hintsEnabled: json['hintsEnabled'] != false,
        tourStatus: TourStatus.parse(json['tourStatus']),
        sessionCount: sessions is int ? sessions.clamp(0, 1 << 30) : 0,
        records: records,
        autoShownAtMs: stamps is List ? [...stamps.whereType<int>()] : const [],
      );
    } catch (_) {
      return empty;
    }
  }
}
