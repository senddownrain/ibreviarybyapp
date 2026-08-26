import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/models/year_options.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:hive_flutter/hive_flutter.dart';

class CalendarService {
  /// Returns YearOptions for the given civil year from Hive cache.
  YearOptions? getYearOptions(int year) {
    final Box box = HiveService.yearOptionsBox;
    final raw = box.get('$year') ?? box.get(year);
    if (raw == null) return null;
    return YearOptions.fromMap(Map<String, dynamic>.from(raw));
  }

  /// Returns dynamic feast dates for the given civil year from Hive cache.
  DynamicDates? getDynamicDates(int year) {
    final opts = getYearOptions(year);
    if (opts == null) return null;
    final datesRaw = opts.data['dynamicDates'] as Map?;
    if (datesRaw == null) return null;
    final result = <String, DateTime>{};
    for (final entry in datesRaw.entries) {
      final key = entry.key as String;
      final val = entry.value;
      DateTime? dt;
      if (val is String) {
        dt = DateTime.tryParse(val);
      } else if (val is DateTime) {
        dt = val;
      }
      if (dt != null) result[key] = dt;
    }
    return result.isEmpty ? null : result;
  }
}

final calendarServiceProvider = Provider<CalendarService>((ref) {
  return CalendarService();
});
