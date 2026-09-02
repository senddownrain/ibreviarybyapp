import 'package:mybrev_flutter/services/hive_service.dart';

/// Secondary index for readings Hive cache (avoids full-box scans).
class ReadingsIndex {
  static const _datePrefix = 'date:';
  static const _periodPrefix = 'period:';
  static const _feastPrefix = 'feast:';

  static Future<void> indexDoc(String docId, Map<String, dynamic> data) async {
    final box = HiveService.readingsIndexBox;
    for (final key in _keysFor(data)) {
      final existing = (box.get(key) as List?)?.cast<String>() ?? <String>[];
      if (!existing.contains(docId)) {
        await box.put(key, [...existing, docId]);
      }
    }
  }

  static List<String> lookupByDate(String ddmm) =>
      _lookup('$_datePrefix$ddmm');

  static List<String> lookupByPeriod(
    String periodType,
    int week,
    int day,
  ) =>
      _lookup('$_periodPrefix$periodType:$week:$day');

  static List<String> lookupByFeast(String feast) =>
      _lookup('$_feastPrefix$feast');

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

  static Future<void> rebuildFromReadingsBox() async {
    final indexBox = HiveService.readingsIndexBox;
    await indexBox.clear();
    for (final key in HiveService.readingsBox.keys) {
      final raw = HiveService.readingsBox.get(key);
      if (raw == null) continue;
      final data = Map<String, dynamic>.from(raw as Map);
      final id = data['id']?.toString() ?? key.toString();
      await indexDoc(id, data);
    }
    await HiveService.setMetaFlag('readingsIndexBuilt', true);
  }

  static Future<void> ensureBuilt() async {
    if (HiveService.getMetaFlag('readingsIndexBuilt') == true) return;
    if (HiveService.readingsBox.isEmpty) {
      await HiveService.setMetaFlag('readingsIndexBuilt', true);
      return;
    }
    await rebuildFromReadingsBox();
  }

  static List<String> _lookup(String key) {
    final raw = HiveService.readingsIndexBox.get(key);
    if (raw is! List) return const [];
    return raw.cast<String>();
  }

  static Set<String> _keysFor(Map<String, dynamic> data) {
    final keys = <String>{};
    final date = data['_date']?.toString();
    if (date != null && date.isNotEmpty) {
      keys.add('$_datePrefix$date');
    }
    final period = data['_periodType']?.toString();
    final week = _toInt(data['_periodWeekNumber']);
    final day = _toInt(data['_dayOfWeek']);
    if (period != null && week != null && day != null) {
      keys.add('$_periodPrefix$period:$week:$day');
    }
    final feast = data['_feast']?.toString();
    if (feast != null && feast.isNotEmpty) {
      keys.add('$_feastPrefix$feast');
    }
    return keys;
  }

  static int? _toInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    return null;
  }
}
