// Local-only analytics collector (contract v1, docs/analytics-contract.md §5-§8).
// Dart port of the web reference `src/utils/analytics/collector.js`.
//
// In-memory state machine: no Flutter, storage, timers or network. The host
// passes a clock and reports lifecycle/scroll facts; the collector turns them
// into aggregated cells. Disabled instances make every call a no-op.
import 'contract.dart';

/// Background of at least this long closes the visit (contract §7).
const int backgroundCloseMs = 5 * 60 * 1000;

/// A re-trigger on the same material within this window is one visit.
const int doubleTriggerMs = 2000;

/// Local cap on distinct cells held in memory; overflow is dropped and counted.
const int maxLocalCells = 2000;

String utcDay(int epochMs) => DateTime.fromMillisecondsSinceEpoch(
  epochMs,
  isUtc: true,
).toIso8601String().substring(0, 10);

/// Coarsens a version such as `1.0.0+6` to `major.minor`; unknown -> `0.0`.
String coarseAppVersion(String? version) {
  final match = RegExp(r'^(\d{1,2})\.(\d{1,2})').firstMatch(version ?? '');
  return match == null ? '0.0' : '${match.group(1)}.${match.group(2)}';
}

class _Visit {
  _Visit({
    required this.section,
    required this.contentId,
    required this.totalChars,
    required this.fits,
    required this.runningSince,
  });

  final String section;
  final String? contentId;
  int? totalChars;
  bool fits;
  double? maxScroll;
  int visibleMs = 0;
  int? runningSince;
}

class _Closed {
  _Closed(this.visit, this.closedAt);
  final _Visit visit;
  final int closedAt;
}

class AnalyticsCollector {
  AnalyticsCollector({
    required this.platform,
    required String appVersion,
    bool enabled = false,
    this.region = 'UNKNOWN',
    Set<String>? publicIds,
    required int Function() now,
  }) : _enabled = enabled,
       _appVersion = coarseAppVersion(appVersion),
       _publicIds = publicIds,
       _now = now;

  final String platform;
  final String region;
  final String _appVersion;
  final Set<String>? _publicIds;
  final int Function() _now;

  bool _enabled;
  // day -> (cellKey -> cell)
  final Map<String, Map<String, Map<String, Object?>>> _days = {};
  int _cellCount = 0;
  _Visit? _visit;
  _Closed? _pending;
  bool _visible = true;
  int? _hiddenAt;

  bool get enabled => _enabled;

  /// Turning off drops all collected state immediately.
  set enabled(bool value) {
    _enabled = value;
    if (!value) clear();
  }

  void _addCell(String day, Map<String, Object?> cell) {
    if (validateCell(cell).isNotEmpty) return;
    final key = cellKey(cell);
    final bucket = _days.putIfAbsent(day, () => {});
    final existing = bucket[key];
    if (existing != null) {
      final sum = (existing['n']! as int) + (cell['n']! as int);
      existing['n'] = sum < maxCellCount ? sum : maxCellCount;
      return;
    }
    // Error cells are exempt from the cap so overflow can be reported; they are
    // bounded by the five error ids per day.
    if (_cellCount >= maxLocalCells && cell['e'] != 'measurement_error') {
      _addError('queue_overflow', day);
      return;
    }
    bucket[key] = Map<String, Object?>.of(cell);
    _cellCount += 1;
  }

  void _addError(String errorId, [String? day]) {
    _addCell(day ?? utcDay(_now()), {
      'e': 'measurement_error',
      'error_id': errorId,
      'n': 1,
    });
  }

  bool _measurable(String section, String? contentId) {
    if (!sections.contains(section)) return false;
    if (!sectionContentKind.containsKey(section)) return contentId == null;
    return _publicIds != null &&
        contentId != null &&
        _publicIds.contains(contentId);
  }

  void _accrue(_Visit? v, int at) {
    if (v == null || v.runningSince == null) return;
    final delta = at - v.runningSince!;
    if (delta < 0) {
      _addError('clock_anomaly');
    } else {
      v.visibleMs += delta;
    }
    v.runningSince = at;
  }

  void _finalize(_Visit v, int endedAt) {
    _accrue(v, endedAt);
    v.runningSince = null;
    final raw = v.visibleMs / 1000;
    final seconds = raw < maxVisitSeconds ? raw : maxVisitSeconds.toDouble();
    if (seconds < minCountedVisitSeconds) return;
    final day = utcDay(endedAt);
    final contentId = v.contentId;
    _addCell(day, {
      'e': 'screen_view',
      'section': v.section,
      'content_id': ?contentId,
      'n': 1,
    });
    if (contentId == null) return;
    _addCell(day, {
      'e': 'text_read',
      'section': v.section,
      'content_id': contentId,
      'metric': 'fv',
      'bucket': bucketVisibleSeconds(seconds),
      'n': 1,
    });
    if (seconds < shortOpenSeconds) return;
    if (!v.fits && v.maxScroll == null) {
      _addError('scroll_unmeasurable', day);
      return;
    }
    final fraction = v.fits ? 1.0 : v.maxScroll!;
    _addCell(day, {
      'e': 'text_read',
      'section': v.section,
      'content_id': contentId,
      'metric': 'sd',
      'bucket': bucketScrollDepth(fraction, fits: v.fits),
      'n': 1,
    });
    final chars = v.totalChars;
    if (chars != null) {
      final er = estimateReadingSeconds(
        visibleSeconds: seconds,
        totalChars: chars,
        maxScrollFraction: fraction,
      );
      if (er != null) {
        _addCell(day, {
          'e': 'text_read',
          'section': v.section,
          'content_id': contentId,
          'metric': 'er',
          'bucket': bucketVisibleSeconds(er),
          'n': 1,
        });
      }
    }
  }

  void _commitPending() {
    final pending = _pending;
    if (pending == null) return;
    _finalize(pending.visit, pending.closedAt);
    _pending = null;
  }

  void _closeActive([int? at]) {
    final visit = _visit;
    if (visit == null) return;
    final when = at ?? _now();
    _accrue(visit, when);
    _pending = _Closed(visit, when);
    _visit = null;
  }

  /// A material or section came on screen. [totalChars] / [fits] describe the text.
  void enterView({
    required String section,
    String? contentId,
    int? totalChars,
    bool fits = false,
  }) {
    if (!_enabled) return;
    final at = _now();
    if (!_measurable(section, contentId)) {
      _closeActive(at);
      _commitPending();
      return;
    }
    final active = _visit;
    if (active != null &&
        active.section == section &&
        active.contentId == contentId) {
      // Same material again while its visit is active (lang/hash change, double
      // trigger): one visit.
      if (totalChars != null) active.totalChars = totalChars;
      if (fits) active.fits = true;
      return;
    }
    _closeActive(at);
    final pending = _pending;
    if (pending != null &&
        pending.visit.section == section &&
        pending.visit.contentId == contentId &&
        at - pending.closedAt <= doubleTriggerMs) {
      // Resume: the earlier close was a double trigger.
      _visit = pending.visit;
      _pending = null;
      _visit!.runningSince = _visible ? at : null;
      return;
    }
    _commitPending();
    _visit = _Visit(
      section: section,
      contentId: contentId,
      totalChars: totalChars,
      fits: fits,
      runningSince: _visible ? at : null,
    );
  }

  void leaveView() {
    if (!_enabled) return;
    _closeActive();
  }

  /// Drop the active visit without recording it (the material did not load).
  void discardView() {
    if (!_enabled) return;
    _visit = null;
  }

  /// Furthest bottom edge of the viewport as a share of scrollable height;
  /// cheap and in-memory, no notifications.
  void reportScroll(double fraction) {
    final visit = _visit;
    if (!_enabled || visit == null || !fraction.isFinite) return;
    final clamped = fraction.clamp(0.0, 1.0);
    if (visit.maxScroll == null || clamped > visit.maxScroll!) {
      visit.maxScroll = clamped;
    }
  }

  /// Foreground visibility. Background time never counts as visible time.
  void setVisible(bool isVisible) {
    if (!_enabled || isVisible == _visible) return;
    final at = _now();
    _visible = isVisible;
    if (!isVisible) {
      _hiddenAt = at;
      final visit = _visit;
      if (visit != null) {
        _accrue(visit, at);
        visit.runningSince = null;
      }
      return;
    }
    var away = _hiddenAt == null ? 0 : at - _hiddenAt!;
    if (away < 0) {
      _addError('clock_anomaly');
      away = 0;
    }
    _hiddenAt = null;
    final visit = _visit;
    if (visit == null) return;
    if (away >= backgroundCloseMs) {
      final section = visit.section;
      final contentId = visit.contentId;
      final totalChars = visit.totalChars;
      final fits = visit.fits;
      _closeActive(at - away);
      _commitPending();
      enterView(
        section: section,
        contentId: contentId,
        totalChars: totalChars,
        fits: fits,
      );
    } else {
      visit.runningSince = at;
    }
  }

  /// Successful user action; once per action, never per scroll/tap tick.
  void featureUse(String featureId, String section) {
    if (!_enabled) return;
    _addCell(utcDay(_now()), {
      'e': 'feature_use',
      'feature_id': featureId,
      'section': section,
      'n': 1,
    });
  }

  void reportError(String errorId) {
    if (!_enabled) return;
    _addError(errorId);
  }

  /// Close the open visit (app paused / detached) so it is not lost.
  void flush() {
    if (!_enabled) return;
    _closeActive();
    _commitPending();
  }

  /// Validated contract packets for all collected days. Does not send.
  List<Map<String, Object?>> snapshot() {
    if (!_enabled) return [];
    final packets = <Map<String, Object?>>[];
    final days = _days.keys.toList()..sort();
    for (final day in days) {
      final cells = _days[day]!.values.toList();
      for (var i = 0; i < cells.length; i += maxCellsPerPacket) {
        final end = i + maxCellsPerPacket < cells.length
            ? i + maxCellsPerPacket
            : cells.length;
        final packet = <String, Object?>{
          'schema_version': schemaVersion,
          'day': day,
          'platform': platform,
          'app_version': _appVersion,
          'region': region,
          'cells': [
            for (final c in cells.sublist(i, end)) Map<String, Object?>.of(c),
          ],
        };
        if (validatePacket(packet, publicIds: _publicIds).isEmpty) {
          packets.add(packet);
        }
      }
    }
    return packets;
  }

  /// Merges previously persisted packets (same platform) back into the counters.
  /// Invalid packets and cells are ignored.
  void importPackets(Iterable<Object?> packets) {
    if (!_enabled) return;
    for (final packet in packets) {
      if (validatePacket(packet, publicIds: _publicIds).isNotEmpty) continue;
      final map = packet! as Map;
      if (map['platform'] != platform) continue;
      for (final cell in map['cells']! as List) {
        _addCell(map['day']! as String, Map<String, Object?>.from(cell as Map));
      }
    }
  }

  void clear() {
    _days.clear();
    _cellCount = 0;
    _visit = null;
    _pending = null;
    _hiddenAt = null;
  }

  /// Drop whole days older than the local retention window (contract §11).
  void pruneOlderThan([int keepDays = maxLocalDays]) {
    final cutoff = utcDay(_now() - keepDays * 86400000);
    for (final day in _days.keys.toList()) {
      if (day.compareTo(cutoff) < 0) {
        _cellCount -= _days[day]!.length;
        _days.remove(day);
      }
    }
  }
}
