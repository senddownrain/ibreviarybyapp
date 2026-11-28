import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/content/content_store.dart';
import 'package:mybrev_flutter/novena/novena_definition.dart';
import 'package:mybrev_flutter/novena/novena_schedule.dart';
import 'package:mybrev_flutter/novena/novena_session.dart';
import 'package:mybrev_flutter/novena/novena_store.dart';
import 'package:mybrev_flutter/novena/pompeii.dart';
import 'package:mybrev_flutter/ordo/dates.dart';
import 'package:mybrev_flutter/ordo/runtime.dart';
import 'package:mybrev_flutter/providers/cache_epoch_provider.dart';
import 'package:mybrev_flutter/providers/diocese_provider.dart';
import 'package:mybrev_flutter/providers/prayers_provider.dart';

/// Null when storage is not available: the tracker then shows nothing.
final novenaBoxProvider = Provider<NovenaBox?>(
  (ref) => Hive.isBoxOpen(kNovenaBoxName)
      ? HiveNovenaBox(Hive.box<String>(kNovenaBoxName))
      : null,
);

final novenaStoreProvider = Provider<NovenaStore>(
  (ref) => NovenaStore(ref.watch(novenaBoxProvider)),
);

class NovenaController extends Notifier<NovenaState> {
  NovenaStore get _store => ref.read(novenaStoreProvider);

  @override
  NovenaState build() => ref.watch(novenaStoreProvider).read();

  Future<T> _apply<T>(Future<T> action) async {
    try {
      return await action;
    } finally {
      state = _store.read();
    }
  }

  Future<NovenaSession> start(
    NovenaDefinition definition,
    List<List<NovenaBlock>> days,
  ) => _apply(
    _store.start(
      definition,
      days,
      ref.read(novenaTodayProvider.notifier).now(),
    ),
  );

  Future<void> setDay(String sessionId, int day, bool done) => _apply(
    _store.setDay(
      sessionId,
      day,
      done,
      ref.read(novenaTodayProvider.notifier).now(),
    ),
  );

  Future<void> stop(String sessionId) => _apply(
    _store.stop(sessionId, ref.read(novenaTodayProvider.notifier).now()),
  );

  Future<void> setSuggestions(bool enabled) =>
      _apply(_store.setSuggestions(enabled));

  Future<void> dismiss(Iterable<String> novenaIds) =>
      _apply(_store.dismiss(novenaIds, ref.read(novenaTodayProvider)));

  Future<void> setCompact(bool compact) => _apply(_store.setCompact(compact));
}

final novenaProvider = NotifierProvider<NovenaController, NovenaState>(
  NovenaController.new,
);

/// The device clock (replaced in tests).
final novenaClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// The local civil date. Refreshed at start, on return from the background
/// and when the local day changes (`NovenaDayWatcher`).
class NovenaToday extends Notifier<String> {
  @override
  String build() => isoOf(ref.watch(novenaClockProvider)());

  String now() {
    refresh();
    return state;
  }

  void refresh() {
    final today = isoOf(ref.read(novenaClockProvider)());
    if (today != state) state = today;
  }
}

final novenaTodayProvider = NotifierProvider<NovenaToday, String>(
  NovenaToday.new,
);

final _novenaContentProvider = FutureProvider<void>(
  (ref) => ContentStore.instance.ensureLoaded(const [kNovenaCollection]),
);

/// Documents of `novenaDefinitions` (bundle ⊕ updates).
final novenaDocumentsProvider = Provider<List<Map>>((ref) {
  ref.watch(cacheEpochProvider);
  ref.watch(_novenaContentProvider);
  final collection = ContentStore.instance.collection(kNovenaCollection);
  return [
    for (final key in collection.keys)
      if (collection.get(key) case final Map data) data,
  ];
});

/// Published definitions by novena id.
final novenaDefinitionsProvider = Provider<Map<String, NovenaDefinition>>((
  ref,
) {
  final result = <String, NovenaDefinition>{};
  for (final data in ref.watch(novenaDocumentsProvider)) {
    final definition = NovenaDefinition.tryParse(data);
    if (definition != null && definition.isPublished) {
      result[definition.novenaId] = definition;
    }
  }
  return result;
});

/// The prayers anyone may read, under the current access rules. Null while
/// they are not loaded (never mistaken for «withdrawn»).
final novenaPublicPrayersProvider = Provider<Map<String, NovenaPrayer>?>((ref) {
  if (!ref.watch(prayersContentProvider).hasValue) return null;
  final prayers = ref.watch(allPrayersProvider);
  if (prayers.isEmpty) return null;
  return {
    for (final prayer in prayers)
      if (!prayer.priestOnly)
        prayer.id: NovenaPrayer(
          id: prayer.id,
          title: prayer.title,
          text: prayer.displayText,
        ),
  };
});

/// A published novena whose every day can be assembled now.
class SupportedNovena {
  const SupportedNovena(this.definition, this.days);
  final NovenaDefinition definition;
  final List<List<NovenaBlock>> days;
}

final supportedNovenaProvider = Provider.family<SupportedNovena?, String>((
  ref,
  prayerId,
) {
  if (prayerId == kPompeiiNovenaId) {
    final prayers = ref.watch(novenaPublicPrayersProvider);
    if (prayers == null) return null;
    final days = pompeiiDays(prayers);
    return days == null
        ? null
        : SupportedNovena(
            NovenaDefinition.builtIn(
              novenaId: kPompeiiNovenaId,
              title: prayers[kPompeiiNovenaId]!.title,
              durationDays: kPompeiiDays,
            ),
            days,
          );
  }
  final definition = ref.watch(
    novenaDefinitionsProvider.select(
      (all) => all.values
          .where((item) => item.sourcePrayerId == prayerId)
          .firstOrNull,
    ),
  );
  if (definition == null) return null;
  final prayers = ref.watch(novenaPublicPrayersProvider);
  if (prayers == null) return null;
  final days = definition.resolveAll(prayers);
  return days == null ? null : SupportedNovena(definition, days);
});

/// The calendar of the movable celebrations (replaced in tests).
final novenaFeastDatesProvider = Provider<NovenaFeastDate?>((ref) {
  ref.watch(cacheEpochProvider);
  final loaded = ref.watch(_novenaCalendarProvider);
  if (!loaded.hasValue) return null;
  return novenaFeastDates(OrdoRuntime.engine);
});

final _novenaCalendarProvider = FutureProvider<void>(
  (ref) => ContentStore.instance.ensureLoaded(kOrdoCalendarCollections),
);

/// Novenas recommended to start today: one entry per novena.
final novenaSuggestionsProvider = Provider<List<SupportedNovena>>((ref) {
  final state = ref.watch(novenaProvider);
  if (ref.watch(novenaBoxProvider) == null || !state.suggestionsEnabled) {
    return const [];
  }
  final today = ref.watch(novenaTodayProvider);
  final candidates = [
    for (final item in ref.watch(novenaDefinitionsProvider).values)
      if (item.schedule['enabled'] == true &&
          !state.isDismissed(item.novenaId, today) &&
          state.activeFor(item.novenaId) == null &&
          // Started today and already finished or stopped.
          !state.sessions.any(
            (session) =>
                session.novenaId == item.novenaId && session.startDate == today,
          ))
        item,
  ];
  if (candidates.isEmpty) return const [];
  final feasts = candidates.any((item) => item.schedule['type'] == 'liturgical')
      ? ref.watch(novenaFeastDatesProvider)
      : null;
  final dioceses = ref.watch(dioceseSelectionProvider).ordered;
  final starting = [
    for (final item in candidates)
      if (novenaStartsOn(
        item.schedule,
        today,
        dioceses: dioceses,
        // Without the calendar no movable date is guessed.
        feastDate: feasts ?? (_, _, _) => null,
      ))
        item,
  ];
  return [
    for (final item in starting)
      ?ref.watch(supportedNovenaProvider(item.sourcePrayerId)),
  ]..sort((a, b) => a.definition.title.compareTo(b.definition.title));
});
