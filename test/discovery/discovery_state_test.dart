import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/discovery/discovery.dart';

import 'support.dart';

void main() {
  test('state survives an encode/decode round trip', () {
    var state = DiscoveryState.empty
        .shown('readings.day_variants', version: 1, now: t0, automatic: true)
        .snoozedHint('readings.day_variants', session: 2, visit: 3)
        .completedHint('discover.bible')
        .copyWith(
          hintsEnabled: false,
          tourStatus: TourStatus.skipped,
          sessionCount: 4,
        );
    state = DiscoveryState.decode(state.encode());
    final record = state.record('readings.day_variants');
    expect(record.seenCount, 1);
    expect(record.lastSeenAtMs, t0.millisecondsSinceEpoch);
    expect(record.snoozeCount, 1);
    expect(record.snoozedVisit, 3);
    expect(state.record('discover.bible').completed, isTrue);
    expect(state.hintsEnabled, isFalse);
    expect(state.tourStatus, TourStatus.skipped);
    expect(state.sessionCount, 4);
    expect(state.autoShownAtMs, [t0.millisecondsSinceEpoch]);
  });

  test('corrupt, empty or wrong-typed payloads become defaults', () {
    for (final raw in [null, '', '{not json', '[]', '"x"', '{"records":5}']) {
      final state = DiscoveryState.decode(raw);
      expect(state.hintsEnabled, isTrue, reason: '$raw');
      expect(state.records, isEmpty, reason: '$raw');
    }
  });

  test('a broken record is skipped, the others and unknown IDs survive', () {
    final raw = jsonEncode({
      'schema': 1,
      'records': {
        'readings.day_variants': {'dismissed': true},
        'broken': 'oops',
        'future.hint_from_newer_build': {'seenCount': 2, 'completed': true},
      },
    });
    final state = DiscoveryState.decode(raw);
    expect(state.record('readings.day_variants').dismissed, isTrue);
    expect(state.records.containsKey('broken'), isFalse);
    expect(state.record('future.hint_from_newer_build').seenCount, 2);
    // Unknown IDs do not break the engine and are written back untouched.
    expect(
      DiscoveryState.decode(
        state.encode(),
      ).record('future.hint_from_newer_build').completed,
      isTrue,
    );
    final decision = const HintPolicy().decide(
      catalog: HintCatalog.standard().all,
      context: readings(),
      state: state,
      now: t0,
    );
    expect(decision.label, 'none'); // day_variants dismissed
  });

  test('a payload from a newer schema reads as defaults and is flagged', () {
    final state = DiscoveryState.decode('{"schema":99,"hintsEnabled":false}');
    expect(state.fromNewerSchema, isTrue);
    expect(state.hintsEnabled, isTrue);
  });

  test('manual displays never touch the automatic quota', () {
    final manual = DiscoveryState.empty.shown(
      'tour.step',
      version: 1,
      now: t0,
      automatic: false,
    );
    expect(manual.autoShownAtMs, isEmpty);
    expect(manual.record('tour.step').seenCount, 1);
  });

  test('history reset keeps settings, tour status and session count', () {
    final state = DiscoveryState.empty
        .shown('a', version: 1, now: t0, automatic: true)
        .dismissedHint('a')
        .copyWith(
          hintsEnabled: false,
          tourStatus: TourStatus.completed,
          sessionCount: 5,
        )
        .historyReset();
    expect(state.records, isEmpty);
    expect(state.autoShownAtMs, isEmpty);
    expect(state.hintsEnabled, isFalse);
    expect(state.tourStatus, TourStatus.completed);
    expect(state.sessionCount, 5);
  });
}
