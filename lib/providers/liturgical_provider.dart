import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/providers/cache_epoch_provider.dart';
import 'package:mybrev_flutter/providers/diocese_provider.dart';
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/content/content_store.dart';
import 'package:mybrev_flutter/services/liturgical_content_service.dart';
import 'package:mybrev_flutter/utils/liturgical_theme.dart';
import 'package:mybrev_flutter/utils/day_options_union.dart';
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

/// Everything the Hours show for the selected date, one entry per selected
/// diocese (primary first).
final dayContentsProvider = Provider<List<LiturgicalDayContent>>((ref) {
  ref.watch(selectedDateReadyProvider);
  ref.watch(cacheEpochProvider); // rebuild after a content update
  final date = ref.watch(selectedDateProvider);
  final dioceses = ref.watch(dioceseSelectionProvider).ordered;
  final service = LiturgicalContentService();
  return [
    for (final diocese in dioceses)
      service.contentForDate(date, diocese: diocese),
  ];
});

/// Day options for the selected date: the legal Offices of every selected
/// diocese, united (shared once, diocesan ones with badges).
final dayOptionsProvider = Provider<List<DayOption>>((ref) {
  final contents = ref.watch(dayContentsProvider);
  final selection = ref.watch(dioceseSelectionProvider);
  return unionDayOptions([
    for (final content in contents) (content.ordo.diocese, content.options),
  ], primary: selection.primary);
});

/// A manual choice on the Hours root: the document (assembly) and the
/// diocese it was chosen in (a temporary route context — Settings never
/// change).
class HoursChoice {
  const HoursChoice(this.dayId, {this.diocese});
  final String dayId;
  final String? diocese;

  @override
  bool operator ==(Object other) =>
      other is HoursChoice && other.dayId == dayId && other.diocese == diocese;

  @override
  int get hashCode => Object.hash(dayId, diocese);
}

class HoursLiturgicalOverrideNotifier
    extends StateNotifier<Map<String, HoursChoice>> {
  HoursLiturgicalOverrideNotifier() : super(const {});

  void select(DateTime date, String dayId, {String? diocese}) {
    state = {...state, _dateKey(date): HoursChoice(dayId, diocese: diocese)};
  }

  void clear(DateTime date) {
    final next = Map<String, HoursChoice>.from(state)..remove(_dateKey(date));
    state = next;
  }
}

/// Session-scoped manual choices, keyed by date so they never leak to another
/// liturgical day. They intentionally are not persisted as user preferences.
final hoursLiturgicalOverridesProvider =
    StateNotifierProvider<
      HoursLiturgicalOverrideNotifier,
      Map<String, HoursChoice>
    >((ref) => HoursLiturgicalOverrideNotifier());

final hoursLiturgicalSelectionProvider = Provider<HoursLiturgicalSelection>((
  ref,
) {
  final date = ref.watch(selectedDateProvider);
  final choice = ref.watch(
    hoursLiturgicalOverridesProvider.select(
      (overrides) => overrides[_dateKey(date)],
    ),
  );
  return resolveHoursLiturgicalSelection(
    ref.watch(dayOptionsProvider),
    selectedDayId: choice?.dayId,
    selectedDiocese: choice?.diocese,
    primaryDiocese: ref.watch(dioceseSelectionProvider).primary,
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
