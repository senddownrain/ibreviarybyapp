import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/analytics/collector.dart';
import 'package:mybrev_flutter/analytics/contract.dart';

const _prayer = 'prayer:AbCdEfGhIjKlMnOpQrSt';
const _closed = 'prayer:ZZZZZZZZZZZZZZZZZZZZ';
final _publicIds = {_prayer, 'hour:laudes'};

class _Setup {
  _Setup({
    bool enabled = true,
    Set<String>? publicIds,
    String appVersion = '1.0.0+6',
    int? startMs,
  }) : _t = startMs ?? DateTime.utc(2026, 10, 15, 10).millisecondsSinceEpoch {
    collector = AnalyticsCollector(
      platform: 'android',
      appVersion: appVersion,
      enabled: enabled,
      publicIds: publicIds ?? _publicIds,
      now: () => _t,
    );
  }

  late final AnalyticsCollector collector;
  int _t;

  void tick(double seconds) => _t += (seconds * 1000).round();
  void set(int ms) => _t = ms;
  int get time => _t;

  List<Map<String, Object?>> get cells => [
    for (final p in collector.snapshot())
      ...(p['cells']! as List).cast<Map<String, Object?>>(),
  ];
}

Map<String, Object?>? _find(
  List<Map<String, Object?>> cells,
  bool Function(Map<String, Object?>) test,
) {
  for (final c in cells) {
    if (test(c)) return c;
  }
  return null;
}

void main() {
  test('disabled by default: nothing is collected', () {
    final s = _Setup(enabled: false);
    s.collector.enterView(section: 'prayers', contentId: _prayer);
    s.collector.featureUse('back_to_top', 'prayers');
    s.collector.flush();
    expect(s.collector.snapshot(), isEmpty);
    expect(s.collector.enabled, isFalse);
  });

  test(
    'a read visit yields screen_view plus fv, sd and er in a valid packet',
    () {
      final s = _Setup();
      s.collector.enterView(
        section: 'prayers',
        contentId: _prayer,
        totalChars: 1200,
      );
      s.tick(30);
      s.collector.reportScroll(0.6);
      s.collector.reportScroll(0.4);
      s.collector.leaveView();
      s.collector.flush();
      final packets = s.collector.snapshot();
      expect(packets.length, 1);
      expect(validatePacket(packets.first, publicIds: _publicIds), isEmpty);
      expect(packets.first['app_version'], '1.0');
      expect(packets.first['platform'], 'android');
      expect(packets.first['region'], 'UNKNOWN');
      final cells = s.cells;
      expect(
        _find(
          cells,
          (c) => c['e'] == 'screen_view' && c['content_id'] == _prayer,
        ),
        isNotNull,
      );
      expect(_find(cells, (c) => c['metric'] == 'fv')!['bucket'], '15_60s');
      expect(_find(cells, (c) => c['metric'] == 'sd')!['bucket'], 'p50_75');
      expect(_find(cells, (c) => c['metric'] == 'er')!['bucket'], '15_60s');
    },
  );

  test('short opens give fv=lt5s only; under 1 s is discarded', () {
    final s = _Setup();
    s.collector.enterView(
      section: 'prayers',
      contentId: _prayer,
      totalChars: 500,
    );
    s.tick(3);
    s.collector.leaveView();
    s.collector.enterView(section: 'hours', contentId: 'hour:laudes');
    s.tick(0.5);
    s.collector.flush();
    final cells = s.cells;
    expect(cells.where((c) => c['e'] == 'screen_view').length, 1);
    expect(
      [
        for (final c in cells.where((c) => c['e'] == 'text_read'))
          '${c['metric']}:${c['bucket']}',
      ],
      ['fv:lt5s'],
    );
  });

  test('closed or unknown material is never measured (fail closed)', () {
    final s = _Setup();
    s.collector.enterView(section: 'prayers', contentId: _closed);
    s.tick(20);
    s.collector.flush();
    expect(s.collector.snapshot(), isEmpty);
    final noInventory = AnalyticsCollector(
      platform: 'ios',
      appVersion: '1.0',
      enabled: true,
      now: () => 0,
    );
    noInventory.enterView(section: 'prayers', contentId: _prayer);
    noInventory.flush();
    expect(noInventory.snapshot(), isEmpty);
  });

  test(
    'background time is not visible time; 5+ minutes in background starts a new visit',
    () {
      final s = _Setup();
      s.collector.enterView(
        section: 'prayers',
        contentId: _prayer,
        totalChars: 600,
      );
      s.tick(10);
      s.collector.setVisible(false);
      s.tick(60);
      s.collector.setVisible(true);
      s.tick(10);
      s.collector.leaveView();
      s.collector.flush();
      var cells = s.cells;
      expect(_find(cells, (c) => c['e'] == 'screen_view')!['n'], 1);
      expect(_find(cells, (c) => c['metric'] == 'fv')!['bucket'], '15_60s');

      final second = _Setup();
      second.collector.enterView(section: 'prayers', contentId: _prayer);
      second.tick(10);
      second.collector.setVisible(false);
      second.tick(backgroundCloseMs / 1000);
      second.collector.setVisible(true);
      second.tick(10);
      second.collector.flush();
      cells = second.cells;
      expect(_find(cells, (c) => c['e'] == 'screen_view')!['n'], 2);
    },
  );

  test(
    'same-material double trigger within 2 s and re-entry are one visit',
    () {
      final s = _Setup();
      s.collector.enterView(section: 'prayers', contentId: _prayer);
      s.tick(10);
      s.collector.enterView(section: 'prayers', contentId: _prayer);
      s.collector.leaveView();
      s.tick(1);
      s.collector.enterView(section: 'prayers', contentId: _prayer);
      s.tick(10);
      s.collector.flush();
      final cells = s.cells;
      expect(_find(cells, (c) => c['e'] == 'screen_view')!['n'], 1);
      expect(_find(cells, (c) => c['metric'] == 'fv')!['bucket'], '15_60s');
    },
  );

  test(
    'back navigation to the same material after more than 2 s is a new visit',
    () {
      final s = _Setup();
      s.collector.enterView(section: 'prayers', contentId: _prayer);
      s.tick(6);
      s.collector.leaveView();
      s.tick(3);
      s.collector.enterView(section: 'prayers', contentId: _prayer);
      s.tick(6);
      s.collector.flush();
      expect(_find(s.cells, (c) => c['e'] == 'screen_view')!['n'], 2);
    },
  );

  test(
    'sections without content ids count views only; text that fits reports fit',
    () {
      final s = _Setup();
      s.collector.enterView(section: 'settings');
      s.tick(4);
      s.collector.leaveView();
      s.collector.enterView(
        section: 'prayers',
        contentId: _prayer,
        totalChars: 300,
        fits: true,
      );
      s.tick(8);
      s.collector.flush();
      final cells = s.cells;
      expect(
        _find(
          cells,
          (c) =>
              c['e'] == 'screen_view' &&
              c['section'] == 'settings' &&
              !c.containsKey('content_id'),
        ),
        isNotNull,
      );
      expect(_find(cells, (c) => c['metric'] == 'sd')!['bucket'], 'fit');
      expect(
        cells
            .where((c) => c['section'] == 'settings' && c['e'] == 'text_read')
            .length,
        0,
      );
    },
  );

  test('unmeasurable scroll is counted as an error, not guessed', () {
    final s = _Setup();
    s.collector.enterView(
      section: 'prayers',
      contentId: _prayer,
      totalChars: 900,
    );
    s.tick(20);
    s.collector.flush();
    final cells = s.cells;
    expect(
      _find(cells, (c) => c['error_id'] == 'scroll_unmeasurable'),
      isNotNull,
    );
    expect(_find(cells, (c) => c['metric'] == 'sd'), isNull);
  });

  test('clock going backwards is a measurement error, not negative time', () {
    final s = _Setup();
    s.collector.enterView(section: 'prayers', contentId: _prayer);
    s.tick(10);
    s.collector.setVisible(false);
    s.set(s.time - 5000);
    s.collector.setVisible(true);
    s.tick(6);
    s.collector.flush();
    expect(_find(s.cells, (c) => c['error_id'] == 'clock_anomaly'), isNotNull);
  });

  test(
    'feature_use validates ids; unknown features and sections are dropped',
    () {
      final s = _Setup();
      s.collector.featureUse('theme_change', 'settings');
      s.collector.featureUse('theme_change', 'settings');
      s.collector.featureUse('not_a_feature', 'settings');
      s.collector.featureUse('theme_change', 'admin');
      final cells = s.cells;
      expect(cells.length, 1);
      expect(cells.first['n'], 2);
    },
  );

  test('local queue is bounded and overflow is counted', () {
    final s = _Setup(startMs: DateTime.utc(2020, 1, 1).millisecondsSinceEpoch);
    for (var d = 0; d < 400; d++) {
      for (final f in [
        'theme_change',
        'back_to_top',
        'share_use',
        'copy_use',
        'date_pick',
        'search_open',
      ]) {
        s.collector.featureUse(f, 'settings');
      }
      s.tick(86400);
    }
    final cells = s.cells;
    expect(
      cells.where((c) => c['e'] == 'feature_use').length <= maxLocalCells,
      isTrue,
    );
    expect(_find(cells, (c) => c['error_id'] == 'queue_overflow'), isNotNull);
  });

  test('pruneOlderThan drops stale days; disabling clears everything', () {
    final s = _Setup(startMs: DateTime.utc(2026, 9, 1).millisecondsSinceEpoch);
    s.collector.featureUse('theme_change', 'settings');
    s.set(DateTime.utc(2026, 10, 15).millisecondsSinceEpoch);
    s.collector.featureUse('theme_change', 'settings');
    s.collector.pruneOlderThan(14);
    expect([for (final p in s.collector.snapshot()) p['day']], ['2026-10-15']);
    s.collector.enabled = false;
    expect(s.collector.snapshot(), isEmpty);
  });

  test('discardView drops the active visit without recording it', () {
    final s = _Setup();
    s.collector.enterView(section: 'prayers', contentId: _prayer);
    s.tick(20);
    s.collector.discardView();
    s.collector.flush();
    expect(s.collector.snapshot(), isEmpty);
  });

  test(
    'importPackets restores persisted counters and ignores invalid or foreign packets',
    () {
      final s = _Setup();
      s.collector.featureUse('theme_change', 'settings');
      final saved = s.collector.snapshot();
      final fresh = _Setup();
      fresh.collector.importPackets([
        ...saved,
        {'junk': true},
        {...saved.first, 'platform': 'ios'},
      ]);
      expect(fresh.cells.length, 1);
      expect(fresh.cells.first['n'], 1);
      fresh.collector.importPackets(saved);
      expect(fresh.cells.first['n'], 2);
    },
  );

  test('app version is coarsened to major.minor', () {
    expect(coarseAppVersion('1.0.0+6'), '1.0');
    expect(coarseAppVersion('4.5.2'), '4.5');
    expect(coarseAppVersion('garbage'), '0.0');
    expect(coarseAppVersion(null), '0.0');
  });
}
