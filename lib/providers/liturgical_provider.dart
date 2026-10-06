import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/providers/cache_epoch_provider.dart';
import 'package:mybrev_flutter/providers/calendar_provider.dart';
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/content/content_store.dart';
import 'package:mybrev_flutter/services/liturgical_content_service.dart';
import 'package:mybrev_flutter/utils/liturgical_theme.dart';
import 'package:mybrev_flutter/utils/hours_liturgical_options.dart';

/// Direction of date slide animation on home (-1 back, 0 none, 1 forward).
final homeNavDirectionProvider = StateProvider<int>((ref) => 0);

/// Currently selected date in the liturgical calendar.
final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

/// The Liturgy of the Hours and the Readings are on the device (decoded
/// from the bundle once per launch). Every date is then a local lookup:
/// there is nothing to download for a date.
final liturgicalContentReadyProvider = FutureProvider<void>((ref) async {
  await ContentStore.instance.ensureLoaded(kLiturgicalCollections);
});

/// The gate the screens watch: the selected date is ready as soon as the
/// content is decoded (there is no per-date work).
final selectedDateReadyProvider = FutureProvider<void>((ref) async {
  ref.watch(selectedDateProvider);
  await ref.watch(liturgicalContentReadyProvider.future);
});

/// Day options for the selected date.
final dayOptionsProvider = Provider<List<DayOption>>((ref) {
  ref.watch(selectedDateReadyProvider);
  ref.watch(cacheEpochProvider); // rebuild after a content update
  final date = ref.watch(selectedDateProvider);
  final calService = ref.watch(calendarServiceProvider);

  final opts = calService.getYearOptionsCached(date.year);
  final nextOpts = calService.getYearOptionsCached(date.year + 1);
  final dynamicDates = calService.getDynamicDatesCached(date.year);

  final service = LiturgicalContentService();
  return service.getContentForDate(date, opts, nextOpts, dynamicDates);
});

class HoursLiturgicalOverrideNotifier
    extends StateNotifier<Map<String, String>> {
  HoursLiturgicalOverrideNotifier() : super(const {});

  void select(DateTime date, String dayId) {
    state = {...state, _dateKey(date): dayId};
  }

  void clear(DateTime date) {
    final next = Map<String, String>.from(state)..remove(_dateKey(date));
    state = next;
  }
}

/// Session-scoped manual choices, keyed by date so they never leak to another
/// liturgical day. They intentionally are not persisted as user preferences.
final hoursLiturgicalOverridesProvider =
    StateNotifierProvider<HoursLiturgicalOverrideNotifier, Map<String, String>>(
      (ref) => HoursLiturgicalOverrideNotifier(),
    );

final hoursLiturgicalSelectionProvider = Provider<HoursLiturgicalSelection>((
  ref,
) {
  final date = ref.watch(selectedDateProvider);
  final selectedDayId = ref.watch(
    hoursLiturgicalOverridesProvider.select(
      (overrides) => overrides[_dateKey(date)],
    ),
  );
  return resolveHoursLiturgicalSelection(
    ref.watch(dayOptionsProvider),
    selectedDayId: selectedDayId,
  );
});

/// Ambient color representing the current liturgical season.
final liturgicalSeasonColorProvider = Provider<Color>((ref) {
  final selection = ref.watch(hoursLiturgicalSelectionProvider);
  final first = selection.selected;
  if (first == null) return const Color(0xFF3A7D44);
  return liturgicalColorForDay(
    selection.day,
    fallbackPeriodType: first.contextPeriodType,
  );
});

String _dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// Stable date key shared by the synchronized Hours/Readings navigation.
String liturgicalDateKey(DateTime date) => _dateKey(date);
