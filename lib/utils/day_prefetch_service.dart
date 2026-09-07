import 'package:mybrev_flutter/services/cache_warmup_service.dart';
import 'package:mybrev_flutter/services/liturgical_content_service.dart';
import 'package:mybrev_flutter/services/liturgical_day_service.dart';

/// Prefetch liturgical data for one calendar date before navigation.
class DayPrefetchService {
  final CacheWarmupService _warmup;
  final LiturgicalDayService _days;

  DayPrefetchService({CacheWarmupService? warmup, LiturgicalDayService? days})
    : _warmup = warmup ?? CacheWarmupService(),
      _days = days ?? LiturgicalDayService();

  Future<void> prefetch(DateTime date, DayOption option) async {
    await _warmup.warmupDate(date);
    if (option.day != null) {
      await _days.getDayById(option.day!.id);
    }
  }
}
