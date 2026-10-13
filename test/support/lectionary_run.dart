import 'package:mybrev_flutter/models/mass_reading_sets.dart';
import 'package:mybrev_flutter/providers/calendar_provider.dart';
import 'package:mybrev_flutter/providers/readings_loader_provider.dart';
import 'package:mybrev_flutter/services/liturgical_content_service.dart';
import 'package:mybrev_flutter/services/parsed_readings_service.dart';
import 'package:mybrev_flutter/utils/reading_view.dart';
import 'package:mybrev_flutter/utils/readings_selection.dart';

/// What the Flutter Readings screen shows, in the shape of the web fixture
/// (`scripts/lectionary/build_parity_fixture.mjs`).
class FlutterScreen {
  FlutterScreen({
    required this.groups,
    required this.active,
    required this.setDoc,
    required this.sets,
    required this.activeSet,
    required this.cycles,
    required this.cycle,
    required this.view,
    required this.dayId,
    required this.linkDayId,
  });

  /// `[key, [doc ids]]`, in the order of the screen.
  final List<(String, List<String>)> groups;
  final int active;
  final String? setDoc;

  /// `[id, label, context, default, referenceOnly, cycles]`.
  final List<List<Object>> sets;
  final String? activeSet;
  final String cycles;
  final String cycle;
  final ReadingView? view;

  /// The Hours day id the route carried (null: none).
  final String? dayId;
  final bool linkDayId;
}

final _service = ParsedReadingsService();
final _calendar = CalendarService();
final _content = LiturgicalContentService();

/// The Hours day id the selection of [optionId] puts in the Readings route
/// (`openPickedDate` / `selectDay`): null when the option has no day.
String? routeDayIdOf(DateTime date, String diocese, String? optionId) {
  if (optionId == null) return null;
  return _content
      .contentForDate(date, diocese: diocese)
      .options
      .where((option) => option.ordo?.optionId == optionId)
      .firstOrNull
      ?.dayId;
}

/// The screen for [date] in [diocese] opened for [optionId] (null: opened
/// without a chosen celebration, as the Readings root does).
FlutterScreen? flutterScreenFor(
  DateTime date,
  String diocese,
  String? optionId, {
  String? dayId,
  bool useRouteDayId = true,
  String? setId,
  String? cycle,
}) {
  final routeDayId = useRouteDayId
      ? (dayId ?? routeDayIdOf(date, diocese, optionId))
      : null;
  // `dayId == ''` is the route of an option without an Hours day.
  final loaded = loadReadingsForDate(
    service: _service,
    calendar: _calendar,
    date: date,
    dayId: routeDayId,
    diocese: diocese,
  );
  if (loaded == null) return null;
  final selection = resolveDefaultReadings(
    readings: loaded.readings,
    sundayCycle: loaded.sundayCycle,
    weekdayCycle: loaded.weekdayCycle,
    dayId: loaded.linkDayId ? routeDayId : null,
    optionId: loaded.optionId,
    groupByCelebration: true,
    requestedSetId: setId,
    manualCycle: cycle,
  );
  final massSet = selection.massSet;
  final sets = massSet == null
      ? const <List<Object>>[]
      : [
          for (final set in massSet.sets)
            [
              set.id,
              set.label,
              set.context ?? '',
              set.isDefault ? 1 : 0,
              set.referenceOnly ? 1 : 0,
              set.cycles.join(),
            ],
        ];
  final view = readingViewOf(selection);
  return FlutterScreen(
    groups: [
      for (final group in selection.groups)
        (group.key, [for (final doc in group.documents) doc.id]),
    ],
    active: selection.groups.indexWhere(
      (group) => group.key == selection.activeGroupKey,
    ),
    setDoc: massSet?.document.id,
    sets: sets,
    activeSet: massSet?.set.id,
    cycles: selection.cycles.join(),
    cycle: view?.cycle ?? '',
    view: view,
    dayId: routeDayId,
    linkDayId: loaded.linkDayId,
  );
}

/// Section list of a set for one cycle (tests of the model).
List<MassReadingSection> sectionsOf(MassReadingSet set, String? cycle) =>
    set.sectionsForCycle(cycle);
