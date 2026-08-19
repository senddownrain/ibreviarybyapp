import 'package:mybrev_flutter/constants/liturgical.dart';
import 'package:mybrev_flutter/models/day.dart';
import 'package:mybrev_flutter/models/reading.dart';
import 'package:mybrev_flutter/models/year_options.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/utils/liturgical_calendar.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:mybrev_flutter/utils/liturgical_cycle.dart';

/// Strip HTML tags from a string (e.g. "<br>" → " ").
String _stripHtml(String s) =>
    s.replaceAll(RegExp(r'<br\s*/?>'), ' ').replaceAll(RegExp(r'<[^>]+>'), '').trim();

/// A day option combining a day template + reading.
class DayOption {
  final LiturgicalOptionSource source;
  final String title;
  final String? subtitle;
  final LiturgicalDay? day;
  final Reading? reading;
  final int order;
  final bool disabled;
  final String key;

  DayOption({
    required this.source,
    required this.title,
    required this.key,
    this.subtitle,
    this.day,
    this.reading,
    this.order = 0,
    this.disabled = false,
  });

  String? get dayId => day?.id;
  String? get readingId => reading?.id;
  bool get hasLiturgicalDay => day != null;
  bool get hasReadings => reading != null;
}

class LiturgicalContentService {
  /// Get all day options for a given date.
  List<DayOption> getContentForDate(
    DateTime date,
    YearOptions? opts,
    YearOptions? nextYearOpts,
    DynamicDates? dynamicDates,
  ) {
    final context = computeLiturgicalContext(date, opts, nextYearOpts, dynamicDates);
    final options = <DayOption>[];

    // 1. Period-based option
    final periodDay = _findDayByPeriod(
      context.periodType,
      context.periodWeek.toString(),
      context.dayOfWeek.toString(),
    );
    final periodReadings = _findReadingsByPeriod(
      context.periodType,
      context.periodWeek,
      context.dayOfWeek,
      date,
    );

    final periodLabel = periodLabelMap[context.periodType] ?? context.periodType;
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    options.add(DayOption(
      source: LiturgicalOptionSource.period,
      title: context.periodWeek > 0
          ? '$periodLabel, тыдзень ${context.periodWeek}'
          : periodLabel,
      subtitle: weekdayLabelMap[context.dayOfWeek],
      key: 'period:$dateStr',
      day: periodDay,
      reading: periodReadings.isNotEmpty ? periodReadings.first : null,
      order: 1,
    ));
    if (kDebugMode) debugPrint('[LiturgicalContentService] Added DayOption - period: key=period:$dateStr, title=$periodLabel, week=${context.periodWeek}');

    // 2. Dynamic feast option
    final feastCodes = getDynamicFeastCodesForDate(date, dynamicDates);
    for (final feastCode in feastCodes) {
      final feastDay = _findDayByFeast(feastCode);
      final feastReading = _findReadingByFeast(feastCode);
      if (feastDay != null || feastReading != null) {
        options.add(DayOption(
          source: LiturgicalOptionSource.dynamic,
          title: _stripHtml(feastDay?.feastName ?? feastDay?.title ?? feastCode),
          key: 'dynamic:$feastCode:$dateStr',
          day: feastDay,
          reading: feastReading,
          order: 2,
        ));
        if (kDebugMode) debugPrint('[LiturgicalContentService] Added DayOption - dynamic: key=dynamic:$feastCode:$dateStr, title=${_stripHtml(feastDay?.feastName ?? feastDay?.title ?? feastCode)}');
      }
    }

    // 3. Fixed date option — fixed calendar feasts (e.g. saints' days by DD.MM)
    // days._date is stored as D.M (non-padded); readings._date as DD.MM (padded)
    final dateDM   = '${date.day}.${date.month}';
    final dateDDMM = '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}';
    final fixedDay     = _findDayByDate(dateDM);
    final fixedReading = _findReadingByDate(dateDDMM);

    if (fixedDay != null || fixedReading != null) {
      // Skip if this feast is already covered by a dynamic feast option
      final fixedFeast = fixedDay?.feast ?? '';
      final alreadyCovered = fixedFeast.isNotEmpty && feastCodes.contains(fixedFeast);
      if (!alreadyCovered) {
        options.add(DayOption(
          source: LiturgicalOptionSource.fixed,
          title: _stripHtml(fixedDay?.feastName ?? fixedDay?.title ?? 'Фіксаваны дзень'),
          key: 'fixed:$dateStr',
          day: fixedDay,
          reading: fixedReading,
          order: 3,
        ));
        if (kDebugMode) debugPrint('[LiturgicalContentService] Added DayOption - fixed: key=fixed:$dateStr, title=${fixedDay?.feastName ?? fixedDay?.title}');
      }
    }

    options.sort((a, b) => a.order.compareTo(b.order));
    if (kDebugMode) debugPrint('[LiturgicalContentService] getContentForDate: date=$dateStr, total=${options.length} options, keys=${options.map((o) => o.key).join(',')}');
    return options;
  }

  /// Get readings for a date with cycle.
  List<Reading> getReadingsForDate(
    DateTime date,
    YearOptions? opts,
    YearOptions? nextYearOpts,
    DynamicDates? dynamicDates,
  ) {
    final context = computeLiturgicalContext(date, opts, nextYearOpts, dynamicDates);
    final cycle = getCycleForDate(date, dayOfWeek: context.dayOfWeek);

    final results = <String, Reading>{}; // dedupe by id

    // By period
    for (final r in _findReadingsByPeriod(
        context.periodType, context.periodWeek, context.dayOfWeek, date)) {
      results[r.id] = r;
    }

    // By fixed date
    final ddmm =
        '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}';
    for (final r in _findReadingsByDate(ddmm)) {
      results[r.id] = r;
    }

    // By feast
    final feastCodes = getDynamicFeastCodesForDate(date, dynamicDates);
    for (final code in feastCodes) {
      for (final r in _findReadingsByFeast(code)) {
        results[r.id] = r;
      }
    }

    // Filter by cycle if applicable
    final filtered = results.values.where((r) {
      if (r.cycle == null || r.cycle!.isEmpty) return true;
      return r.cycle == cycle;
    }).toList();

    return filtered;
  }

  // --- Hive lookups ---

  LiturgicalDay? _findDayByPeriod(
      String periodType, String weekNum, String dayOfWeek) {
    final box = HiveService.daysBox;
    for (final key in box.keys) {
      final raw = box.get(key);
      if (raw == null) continue;
      final data = Map<String, dynamic>.from(raw);
      final pt = data['_periodType'];
      final wn = data['_periodWeekNumber']?.toString();
      final dw = data['_dayOfWeek']?.toString();
      final feast = data['_feast'];
      // Accept null OR empty string as "no feast"
      final noFeast = feast == null || feast == '';
      if (pt == periodType && wn == weekNum && dw == dayOfWeek && noFeast) {
        return LiturgicalDay.fromMap(data);
      }
    }
    return null;
  }

  LiturgicalDay? _findDayByFeast(String feastCode) {
    final box = HiveService.daysBox;
    for (final key in box.keys) {
      final data = Map<String, dynamic>.from(box.get(key)!);
      if (data['_feast'] == feastCode) {
        return LiturgicalDay.fromMap(data);
      }
    }
    return null;
  }

  LiturgicalDay? _findDayByDate(String dateDM) {
    final box = HiveService.daysBox;
    for (final key in box.keys) {
      final data = Map<String, dynamic>.from(box.get(key)!);
      if (data['_date'] == dateDM) {
        return LiturgicalDay.fromMap(data);
      }
    }
    return null;
  }

  List<Reading> _findReadingsByPeriod(
    String periodType,
    int weekNum,
    int dayOfWeek,
    DateTime date,
  ) {
    final box = HiveService.readingsBox;
    final results = <Reading>[];
    final weekStr = weekNum.toString();
    final dayStr = dayOfWeek.toString();

    for (final key in box.keys) {
      final data = Map<String, dynamic>.from(box.get(key)!);
      if (data['_periodType'] != periodType) continue;
      final rwn = data['_periodWeekNumber']?.toString();
      final rdw = data['_dayOfWeek']?.toString();
      if ((rwn == weekStr || data['_periodWeekNumber'] == weekNum) &&
          (rdw == dayStr || data['_dayOfWeek'] == dayOfWeek)) {
        results.add(Reading.fromMap(data));
      }
    }
    return results;
  }

  Reading? _findReadingByFeast(String feastCode) {
    final readings = _findReadingsByFeast(feastCode);
    return readings.isNotEmpty ? readings.first : null;
  }

  List<Reading> _findReadingsByFeast(String feastCode) {
    final box = HiveService.readingsBox;
    final results = <Reading>[];
    for (final key in box.keys) {
      final data = Map<String, dynamic>.from(box.get(key)!);
      if (data['_feast'] == feastCode) {
        results.add(Reading.fromMap(data));
      }
    }
    return results;
  }

  Reading? _findReadingByDate(String dateDDMM) {
    final readings = _findReadingsByDate(dateDDMM);
    return readings.isNotEmpty ? readings.first : null;
  }

  List<Reading> _findReadingsByDate(String dateDDMM) {
    final box = HiveService.readingsBox;
    final results = <Reading>[];
    for (final key in box.keys) {
      final data = Map<String, dynamic>.from(box.get(key)!);
      if (data['_date'] == dateDDMM) {
        results.add(Reading.fromMap(data));
      }
    }
    return results;
  }
}
