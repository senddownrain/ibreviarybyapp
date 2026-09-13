import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mybrev_flutter/models/year_options.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/utils/firestore_cache.dart';
import 'package:mybrev_flutter/utils/retry.dart';

class CalendarService {
  final FirebaseFirestore _db;

  CalendarService({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  final Map<int, YearOptions?> _yearCache = {};
  final Map<int, DynamicDates> _dynamicCache = {};

  YearOptions? getYearOptionsCached(int year) {
    if (_yearCache.containsKey(year)) return _yearCache[year];
    final fromHive = _fromHive(year);
    if (fromHive != null) _yearCache[year] = fromHive;
    return fromHive;
  }

  DynamicDates? getDynamicDatesCached(int year) {
    if (_dynamicCache.containsKey(year)) return _dynamicCache[year];
    final opts = getYearOptionsCached(year);
    if (opts == null) return null;
    final dates = _computeFromOpts(year, opts);
    _dynamicCache[year] = dates;
    return dates;
  }

  /// Synchronous views used by screens after [calendarReadyProvider] warmup.
  YearOptions? getYearOptions(int year) => getYearOptionsCached(year);

  DynamicDates? getDynamicDates(int year) => getDynamicDatesCached(year);

  Future<YearOptions?> ensureYearOptions(int year) async {
    final cached = getYearOptionsCached(year);
    if (cached != null) return cached;
    try {
      final snap = await retryFirestore(
        () => _db
            .collection('yearOptions')
            .where('year', isEqualTo: year)
            .limit(1)
            .get(const GetOptions(source: Source.server)),
      );
      if (snap.docs.isEmpty) return null;
      final doc = snap.docs.first;
      final data = {...doc.data(), 'id': doc.id};
      await cacheYearOptionsDoc(doc.id, data);
      final opts = YearOptions.fromMap(data);
      _yearCache[year] = opts;
      return opts;
    } catch (_) {
      return _fromHive(year);
    }
  }

  Future<DynamicDates> ensureDynamicDates(int year) async {
    final cached = getDynamicDatesCached(year);
    if (cached != null && cached.isNotEmpty) return cached;
    await ensureYearOptions(year);
    final opts = getYearOptionsCached(year);
    if (opts == null) return {};
    final dates = _computeFromOpts(year, opts);
    _dynamicCache[year] = dates;
    return dates;
  }

  YearOptions? _fromHive(int year) {
    final Box box = HiveService.yearOptionsBox;
    final raw = box.get('$year') ?? box.get(year);
    if (raw == null) return null;
    return YearOptions.fromMap(Map<String, dynamic>.from(raw));
  }

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
      dates['palmSunday'] = easter.subtract(const Duration(days: 7));
    }
    if (pentecost != null) {
      dates['pentecost'] = pentecost;
      dates['maryMotherChurch'] = pentecost.add(const Duration(days: 1));
      final configuredAscension = parse(opts.data['ascension']);
      dates['ascension'] =
          configuredAscension ?? pentecost.subtract(const Duration(days: 7));
      final holyTrinity = pentecost.add(const Duration(days: 7));
      dates['holyTrinity'] = holyTrinity;
      final configuredCorpus = parse(opts.data['corpusChristi']);
      dates['corpusChristi'] =
          configuredCorpus ?? holyTrinity.add(const Duration(days: 4));
      final sacredHeart = pentecost.add(const Duration(days: 19));
      dates['sacredHeartOfJesus'] = sacredHeart;
      dates['immaculateHeartOfMary'] = sacredHeart.add(const Duration(days: 1));
      dates['christTheHighPriest'] = pentecost.add(const Duration(days: 4));
    }
    dates['holyFamily'] = calculateHolyFamilyDate(year);
    dates['baptismOfLord'] = calculateBaptismOfLordDate(year);
    if (firstAdvent != null) {
      dates['christKing'] = firstAdvent.subtract(const Duration(days: 7));
    }
    return dates;
  }
}

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

/// Preloads year options + dynamic dates for navigation.
final calendarReadyProvider = FutureProvider<void>((ref) async {
  final cal = ref.read(calendarServiceProvider);
  final year = DateTime.now().year;
  await Future.wait([
    cal.ensureYearOptions(year),
    cal.ensureYearOptions(year + 1),
    cal.ensureDynamicDates(year),
    cal.ensureDynamicDates(year + 1),
  ]);
});
