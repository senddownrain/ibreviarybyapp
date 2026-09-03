import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/models/year_options.dart';
import 'package:mybrev_flutter/providers/cache_epoch_provider.dart';
import 'package:mybrev_flutter/providers/calendar_provider.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/services/liturgical_content_service.dart';
import 'package:mybrev_flutter/utils/liturgical_theme.dart';

/// Direction of date slide animation on home (-1 back, 0 none, 1 forward).
final homeNavDirectionProvider = StateProvider<int>((ref) => 0);

/// Currently selected date in the liturgical calendar.
final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

/// Day options for the selected date.
final dayOptionsProvider = Provider<List<DayOption>>((ref) {
  ref.watch(calendarReadyProvider);
  ref.watch(cacheEpochProvider); // rebuild after warmup / sync fills Hive
  final date = ref.watch(selectedDateProvider);
  final calService = ref.watch(calendarServiceProvider);

  final opts = _loadYearOptions(date.year);
  final nextOpts = _loadYearOptions(date.year + 1);
  final dynamicDates = calService.getDynamicDatesCached(date.year);

  final service = LiturgicalContentService();
  return service.getContentForDate(date, opts, nextOpts, dynamicDates);
});

/// Ambient color representing the current liturgical season.
final liturgicalSeasonColorProvider = Provider<Color>((ref) {
  final options = ref.watch(dayOptionsProvider);
  if (options.isEmpty) return const Color(0xFF3A7D44);
  final first = options.first;
  return liturgicalColorForDay(
    first.day,
    fallbackPeriodType: first.contextPeriodType,
  );
});

YearOptions? _loadYearOptions(int year) {
  final box = HiveService.yearOptionsBox;
  final raw = box.get('$year') ?? box.get(year);
  if (raw == null) return null;
  return YearOptions.fromMap(Map<String, dynamic>.from(raw));
}
