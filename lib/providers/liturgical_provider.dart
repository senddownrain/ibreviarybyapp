import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/models/year_options.dart';
import 'package:mybrev_flutter/providers/calendar_provider.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/constants/liturgical.dart';
import 'package:mybrev_flutter/services/liturgical_content_service.dart';

/// Currently selected date in the liturgical calendar.
final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

/// Day options for the selected date.
final dayOptionsProvider = Provider<List<DayOption>>((ref) {
  final date = ref.watch(selectedDateProvider);
  final calService = ref.watch(calendarServiceProvider);

  final opts = _loadYearOptions(date.year);
  final nextOpts = _loadYearOptions(date.year + 1);
  final dynamicDates = calService.getDynamicDates(date.year);

  final service = LiturgicalContentService();
  return service.getContentForDate(date, opts, nextOpts, dynamicDates);
});

/// Ambient color representing the current liturgical season.
final liturgicalSeasonColorProvider = Provider<Color>((ref) {
  final options = ref.watch(dayOptionsProvider);
  if (options.isEmpty) return const Color(0xFF3A7D44);
  final first = options.first;
  switch (first.source) {
    case LiturgicalOptionSource.dynamic:
      return const Color(0xFFE8A030); // feast — gold
    case LiturgicalOptionSource.fixed:
      return const Color(0xFF5B8DD9); // fixed feast — blue
    case LiturgicalOptionSource.period:
      return _seasonColor(first.title);
  }
});

Color _seasonColor(String title) {
  if (title.contains('пост') || title.contains('Адвэнт')) return const Color(0xFF7C5CBF);
  if (title.contains('Велікодны') || title.contains('Вялікдзень')) return const Color(0xFFD4A017);
  if (title.contains('Вялікі тыдзень')) return const Color(0xFF8B0000);
  if (title.contains('Нараджэнн')) return const Color(0xFF1565C0);
  if (title.contains('Пяцідзесятніц')) return const Color(0xFFB71C1C);
  return const Color(0xFF3A7D44); // Ordinary time — green
}

YearOptions? _loadYearOptions(int year) {
  final box = HiveService.yearOptionsBox;
  final raw = box.get('$year') ?? box.get(year);
  if (raw == null) return null;
  return YearOptions.fromMap(Map<String, dynamic>.from(raw));
}
