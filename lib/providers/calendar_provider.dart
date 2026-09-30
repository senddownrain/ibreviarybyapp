import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/models/year_options.dart';
import 'package:mybrev_flutter/utils/computed_year_options.dart';

/// Calendar anchors of a year.
///
/// Year options are computed on the device ([computeYearOptions]), so the
/// calendar is always available synchronously — first launch, offline and
/// for any year — and no screen waits for a `yearOptions` request. The
/// `ensure*` futures are kept for callers that were written against the
/// former network-backed API; they complete immediately.
class CalendarService {
  // ignore: avoid_unused_constructor_parameters
  CalendarService({FirebaseFirestore? db});

  final Map<int, DynamicDates> _dynamicCache = {};

  YearOptions? getYearOptionsCached(int year) => computeYearOptions(year);

  DynamicDates? getDynamicDatesCached(int year) => _dynamicCache.putIfAbsent(
    year,
    () => _computeFromOpts(year, computeYearOptions(year)),
  );

  /// Synchronous views (always available).
  YearOptions? getYearOptions(int year) => getYearOptionsCached(year);

  DynamicDates? getDynamicDates(int year) => getDynamicDatesCached(year);

  Future<YearOptions?> ensureYearOptions(int year) async =>
      getYearOptionsCached(year);

  Future<DynamicDates> ensureDynamicDates(int year) async =>
      getDynamicDatesCached(year)!;

  DynamicDates _computeFromOpts(int year, YearOptions opts) {
    DateTime? parse(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return DateTime(v.year, v.month, v.day);
      if (v is int) {
        final dt = DateTime.fromMillisecondsSinceEpoch(v);
        return DateTime(dt.year, dt.month, dt.day);
      }
      if (v is String) {
        final dt = DateTime.tryParse(v);
        if (dt == null) return null;
        return DateTime(dt.year, dt.month, dt.day);
      }
      return null;
    }

    final easter = parse(opts.data['easterSunday']);
    final pentecost = parse(opts.data['pentecost']);
    final firstAdvent = parse(opts.data['firstAdventSunday']);
    final ash = parse(opts.data['ashWednesday']);

    final dates = <String, DateTime>{};
    if (ash != null) dates['ashWednesday'] = ash;
    if (easter != null) {
      dates['easterSunday'] = easter;
      dates['palmSunday'] = _addDays(easter, -7);
    }
    if (pentecost != null) {
      dates['pentecost'] = pentecost;
      dates['maryMotherChurch'] = _addDays(pentecost, 1);
      final configuredAscension = parse(opts.data['ascension']);
      dates['ascension'] = configuredAscension ?? _addDays(pentecost, -7);
      final holyTrinity = _addDays(pentecost, 7);
      dates['holyTrinity'] = holyTrinity;
      final configuredCorpus = parse(opts.data['corpusChristi']);
      dates['corpusChristi'] = configuredCorpus ?? _addDays(holyTrinity, 4);
      final sacredHeart = _addDays(pentecost, 19);
      dates['sacredHeartOfJesus'] = sacredHeart;
      dates['immaculateHeartOfMary'] = _addDays(sacredHeart, 1);
      dates['christTheHighPriest'] = _addDays(pentecost, 4);
    }
    dates['holyFamily'] = calculateHolyFamilyDate(year);
    dates['baptismOfLord'] = calculateBaptismOfLordDate(year);
    if (firstAdvent != null) {
      dates['christKing'] = _addDays(firstAdvent, -7);
    }
    return dates;
  }
}

/// Civil-day arithmetic: a 24-hour `Duration` lands on the previous day
/// across a daylight-saving change (Palm Sunday 2026 in the EU).
DateTime _addDays(DateTime date, int days) =>
    DateTime(date.year, date.month, date.day + days);

DateTime calculateHolyFamilyDate(int year) {
  final christmas = DateTime(year, 12, 25);
  if (christmas.weekday == DateTime.sunday) {
    return DateTime(year, 12, 30);
  }
  final daysToSunday = DateTime.sunday - christmas.weekday;
  return christmas.add(Duration(days: daysToSunday));
}

DateTime calculateBaptismOfLordDate(int year) {
  final epiphany = DateTime(year, 1, 6);
  if (epiphany.weekday == DateTime.sunday) {
    return epiphany.add(const Duration(days: 7));
  }
  final daysToSunday = DateTime.sunday - epiphany.weekday;
  return epiphany.add(Duration(days: daysToSunday));
}

final calendarServiceProvider = Provider<CalendarService>((ref) {
  return CalendarService();
});

/// Kept for callers that awaited the calendar: it is computed, so it is
/// ready at once.
final calendarReadyProvider = FutureProvider<void>((ref) async {});
