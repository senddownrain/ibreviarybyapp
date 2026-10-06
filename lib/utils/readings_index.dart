import 'package:mybrev_flutter/services/hive_service.dart';

/// In-memory secondary index of the `readings` documents: date, period day,
/// feast and linked day id → document ids. Rebuilt lazily after any change
/// of the collection (bundle loaded, update applied).
class ReadingsIndex {
  ReadingsIndex._();

  static int _builtAt = -1;
  static final Map<String, List<String>> _index = {};

  static const _datePrefix = 'date:';
  static const _periodPrefix = 'period:';
  static const _feastPrefix = 'feast:';
  static const _dayIdPrefix = 'dayId:';

  static List<String> lookupByDate(String ddmm) => _lookup('$_datePrefix$ddmm');

  static List<String> lookupByPeriod(String periodType, int week, int day) =>
      _lookup('$_periodPrefix$periodType:$week:$day');

  static List<String> lookupByFeast(String feast) =>
      _lookup('$_feastPrefix$feast');

  static List<String> lookupByDayId(String dayId) =>
      _lookup('$_dayIdPrefix$dayId');

  static List<String> lookupForDateContext({
    required String periodType,
    required int periodWeek,
    required int dayOfWeek,
    required String ddmm,
    required Set<String> feastVariants,
  }) {
    final ids = <String>{};
    ids.addAll(lookupByDate(ddmm));
    ids.addAll(lookupByPeriod(periodType, periodWeek, dayOfWeek));
    for (final feast in feastVariants) {
      ids.addAll(lookupByFeast(feast));
    }
    return ids.toList();
  }

  static List<String> _lookup(String key) {
    _ensure();
    return _index[key] ?? const [];
  }

  static void _ensure() {
    final box = HiveService.readingsBox;
    if (_builtAt == box.changeCount) return;
    _index.clear();
    for (final key in box.keys) {
      final raw = box.get(key);
      if (raw is! Map) continue;
      final id = raw['id']?.toString() ?? key;
      for (final indexKey in _keysFor(raw)) {
        (_index[indexKey] ??= []).add(id);
      }
    }
    _builtAt = box.changeCount;
  }

  static Set<String> _keysFor(Map data) {
    final keys = <String>{};
    final date = data['_date']?.toString();
    if (date != null && date.isNotEmpty) {
      keys.add('$_datePrefix$date');
    }
    final period = data['_periodType']?.toString();
    // A week-less document (the days after Ash Wednesday) is week 0, as the
    // former `_periodWeekNumber == null` query for week 0.
    final week = data.containsKey('_periodWeekNumber')
        ? _toInt(data['_periodWeekNumber']) ?? 0
        : null;
    final day = _toInt(data['_dayOfWeek']);
    if (period != null && week != null && day != null) {
      keys.add('$_periodPrefix$period:$week:$day');
    }
    final feast = data['_feast']?.toString();
    if (feast != null && feast.isNotEmpty) {
      keys.add('$_feastPrefix$feast');
    }
    final linked = data['_dayId']?.toString();
    if (linked != null && linked.isNotEmpty) keys.add('$_dayIdPrefix$linked');
    final many = data['_dayIds'];
    if (many is List) {
      for (final id in many) {
        if (id != null && id.toString().isNotEmpty) {
          keys.add('$_dayIdPrefix$id');
        }
      }
    }
    return keys;
  }

  static int? _toInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    return null;
  }
}
