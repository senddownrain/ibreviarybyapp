import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mybrev_flutter/constants/liturgical.dart';
import 'package:mybrev_flutter/discovery/discovery_context.dart';
import 'package:mybrev_flutter/discovery/hints/p0_hints.dart';
import 'package:mybrev_flutter/discovery/p0_facts.dart';
import 'package:mybrev_flutter/discovery/ui/discovery_hint_slot.dart';
import 'package:mybrev_flutter/discovery/ui/discovery_visit.dart';
import 'package:mybrev_flutter/ordo/dates.dart';
import 'package:mybrev_flutter/ordo/day_union.dart';
import 'package:mybrev_flutter/ordo/definitions.dart';
import 'package:mybrev_flutter/ordo/reading_references.dart';
import 'package:mybrev_flutter/ordo/runtime.dart';
import 'package:mybrev_flutter/providers/diocese_provider.dart';
import 'package:mybrev_flutter/providers/cache_epoch_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/services/liturgical_content_service.dart';
import 'package:mybrev_flutter/providers/ordo_provider.dart';
import 'package:mybrev_flutter/utils/hours_liturgical_options.dart';
import 'package:mybrev_flutter/utils/day_options_union.dart';
import 'package:mybrev_flutter/providers/liturgical_navigation_sync_provider.dart';
import 'package:mybrev_flutter/theme/glass.dart';
import 'package:mybrev_flutter/theme/reader.dart';
import 'package:mybrev_flutter/utils/system_insets.dart';
import 'package:mybrev_flutter/widgets/reader/reader_scaffold.dart';
import 'package:mybrev_flutter/utils/liturgical_titles.dart';
import 'package:mybrev_flutter/utils/liturgical_visual.dart';
import 'package:mybrev_flutter/widgets/adaptive_app_bar.dart';
import 'package:mybrev_flutter/widgets/ordo/vestment_marker.dart';
import 'package:mybrev_flutter/widgets/reader/reader_navigation.dart';
import 'package:mybrev_flutter/widgets/liturgical_calendar_sheet.dart';
import 'package:mybrev_flutter/widgets/liturgical_date_navigation_row.dart';
import 'package:mybrev_flutter/widgets/liturgical_heading_text.dart';
import 'package:mybrev_flutter/utils/civil_date.dart';
import 'package:mybrev_flutter/content/content_store.dart';
import 'package:mybrev_flutter/models/mass_reading_sets.dart';
import 'package:url_launcher/url_launcher.dart';

export 'package:mybrev_flutter/providers/ordo_provider.dart';
export 'package:mybrev_flutter/screens/ordo_month_screen.dart';

/// Backwards-compatible day entry; the month has its own route and screen.
class OrdoScreen extends ConsumerStatefulWidget {
  const OrdoScreen({
    super.key,
    required this.initialDate,
    this.dayId,
    this.diocese,
  });
  final DateTime initialDate;
  final String? dayId;
  final String? diocese;

  @override
  ConsumerState<OrdoScreen> createState() => _OrdoScreenState();
}

class _OrdoScreenState extends ConsumerState<OrdoScreen> {
  late DateTime _date = DateUtils.dateOnly(widget.initialDate);
  DioceseSelection get _dioceses => ref.read(dioceseSelectionProvider);
  bool _useInitialRouteContext = true;

  // Contextual Discovery (P0): inert unless the real presenter is installed.
  late final DiscoveryVisit _discovery = DiscoveryVisit(ref, 'ordo');
  DateTime? _discoveryDate;
  bool _dioceseSheetOpen = false;
  bool _discoveryScrolling = false;

  Future<void> _discoveryNewVisit() async {
    await _discovery.begin();
    if (mounted) _discovery.schedule(_discoverySnapshot);
  }

  DiscoveryContext? _discoverySnapshot(int visitId) {
    if (!mounted) return null;
    final ready = ref.read(liturgicalContentReadyProvider).hasValue;
    final ui = DiscoveryUiState(
      scrolling: _discoveryScrolling,
      keyboardVisible: MediaQuery.viewInsetsOf(context).bottom > 0,
      modalOpen:
          _dioceseSheetOpen || !(ModalRoute.of(context)?.isCurrent ?? true),
    );
    if (!ready) {
      return DiscoveryContext.loading(
        screenId: 'ordo',
        visitId: visitId,
        ui: ui,
      );
    }
    final atTop = _scroll.hasClients ? _scroll.offset <= 24 : true;
    return DiscoveryContext(
      screenId: 'ordo',
      visitId: visitId,
      status: DiscoveryDataStatus.ready,
      anchors: atTop
          ? _discovery.mounted(const {'ordo.diocese.button'})
          : const {},
      facts: {
        kFactDioceseDiffers: dioceseOptionsDiffer(_date, OrdoRuntime.engine),
      },
      ui: ui,
    );
  }

  bool _onDiscoveryScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    if (notification is ScrollEndNotification) {
      if (_discoveryScrolling) {
        _discoveryScrolling = false;
        _discovery.schedule(_discoverySnapshot);
      }
    } else if (notification is ScrollStartNotification ||
        notification is ScrollUpdateNotification) {
      _discoveryScrolling = true;
      _discovery.interrupt();
    }
    return false;
  }

  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _discovery.end();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _chooseDioceses() async {
    _dioceseSheetOpen = true;
    _discovery.interrupt();
    unawaited(_discovery.actedOnPresented());
    try {
      await _showDioceseSheet();
    } finally {
      _dioceseSheetOpen = false;
    }
  }

  Future<void> _showDioceseSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => Consumer(
        builder: (context, ref, child) {
          final value = ref.watch(dioceseSelectionProvider);
          final notifier = ref.read(dioceseSelectionProvider.notifier);

          return SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Дыяцэзіі',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  for (final id in kDioceses)
                    CheckboxListTile(
                      key: Key('ordo-diocese-$id'),
                      title: Text(kDioceseNames[id] ?? id),
                      value: value.contains(id),
                      contentPadding: EdgeInsets.zero,
                      onChanged:
                          value.contains(id) && value.selected.length == 1
                          ? null
                          : (_) => notifier.toggle(id),
                    ),
                  TextButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    child: const Text('Гатова'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _syncRouteSelection();
  }

  @override
  void didUpdateWidget(OrdoScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!DateUtils.isSameDay(oldWidget.initialDate, widget.initialDate) ||
        oldWidget.dayId != widget.dayId ||
        oldWidget.diocese != widget.diocese) {
      _date = DateUtils.dateOnly(widget.initialDate);
      _useInitialRouteContext = true;
      _syncRouteSelection();
    }
  }

  void _syncRouteSelection() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(liturgicalContentReadyProvider.future);
      if (!mounted) return;
      final saved = ref.read(hoursLiturgicalOverridesProvider)[isoOf(_date)];
      final routeContext =
          _useInitialRouteContext &&
          DateUtils.isSameDay(_date, widget.initialDate);
      final diocese = routeContext ? widget.diocese : null;
      final id =
          (routeContext ? widget.dayId : null) ??
          saved?.dayId ??
          (diocese == null
              ? null
              : resolveHoursLiturgicalSelection(
                  LiturgicalContentService()
                      .contentForDate(_date, diocese: diocese)
                      .options,
                ).dayId);
      ref
          .read(liturgicalNavigationControllerProvider)
          .openDate(_date, dayId: id, diocese: diocese ?? saved?.diocese);
    });
  }

  void _moveDay(int delta) {
    final date = addCivilDays(_date, delta);
    if (date.isBefore(kCalendarFirstDate) || date.isAfter(kCalendarLastDate)) {
      return;
    }
    _selectDate(date);
  }

  void _selectDate(DateTime date) {
    setState(() => _date = DateUtils.dateOnly(date));
    final content = LiturgicalContentService().contentForDate(
      _date,
      diocese: _dioceses.primary,
    );
    final saved = ref.read(hoursLiturgicalOverridesProvider)[isoOf(_date)];
    ref
        .read(liturgicalNavigationControllerProvider)
        .openDate(
          _date,
          dayId: saved?.diocese == _dioceses.primary
              ? saved?.dayId
              : resolveHoursLiturgicalSelection(content.options).dayId,
          diocese: _dioceses.primary,
        );
  }

  Future<void> _openCalendar() => showCompactLiturgicalCalendar(
    context: context,
    date: _date,
    diocese: _dioceses.primary,
    onSelected: _selectDate,
  );

  void _openMonth() => context.push(
    Uri(
      path: '/hours/ordo/month',
      queryParameters: {'date': isoOf(_date)},
    ).toString(),
  );

  @override
  Widget build(BuildContext context) {
    if (_discoveryDate == null || !DateUtils.isSameDay(_discoveryDate, _date)) {
      _discoveryDate = _date;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_discoveryNewVisit());
      });
    }
    ref.listen(dioceseSelectionProvider, (previous, next) {
      // Explicit links may carry a source, but a subsequent settings change
      // owns the whole calendar view.
      _useInitialRouteContext = false;
    });
    ref.watch(cacheEpochProvider);
    final ready = ref.watch(liturgicalContentReadyProvider);
    final notes = ref.watch(ordoNotesReadyProvider);
    final iso = isoOf(_date);
    final saved = ref.watch(hoursLiturgicalOverridesProvider)[iso];
    final effectiveDayId =
        saved?.dayId ??
        (DateUtils.isSameDay(_date, widget.initialDate) ? widget.dayId : null);
    ref.watch(dioceseSelectionProvider);
    // An explicit link may resolve a saint outside the saved dioceses; it is
    // a route context, never another persisted diocese selection.
    final contextDiocese =
        _useInitialRouteContext &&
            DateUtils.isSameDay(_date, widget.initialDate)
        ? widget.diocese ?? _dioceses.primary
        : _dioceses.primary;
    final union = !ready.hasValue
        ? null
        : buildOrdoDayUnion([
            for (final id in <String>{contextDiocese, ..._dioceses.ordered})
              OrdoRuntime.engine.resolve(iso, diocese: id),
          ]);
    final primary = union?.first.primary;
    final visual = primary == null
        ? null
        : liturgicalVisual(
            color: primary.color,
            category: primary.category,
            rank: primary.rank,
          );
    final accent = visual?.accent ?? Theme.of(context).colorScheme.primary;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AdaptiveAppBar(
        showOverflow: true,
        title: const Text(''),
        actions: [
          IconButton(
            key: const Key('ordo-open-month'),
            tooltip: 'Літургічны каляндар',
            icon: const PhosphorIcon(PhosphorIconsRegular.listBullets),
            onPressed: _openMonth,
          ),
        ],
      ),
      body: Stack(
        children: [
          AmbientWash.hero(seasonColor: accent),
          if (ready.hasError)
            const Center(child: Text('Не ўдалося адкрыць літургічны дзень'))
          else if (union == null)
            const Center(child: CircularProgressIndicator.adaptive())
          else
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.only(
                  top:
                      MediaQuery.paddingOf(context).top +
                      kFloatingAppBarContentInset,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: NotificationListener<ScrollNotification>(
                    onNotification: _onDiscoveryScroll,
                    child: ListView(
                      controller: _scroll,
                      key: const Key('ordo-scroll'),
                      padding: EdgeInsets.fromLTRB(
                        12,
                        0,
                        12,
                        24 + systemBottomInset(context),
                      ),
                      children: [
                        _DayDetail(
                          union: union,
                          marianAccent: visual?.marianAccent ?? false,
                          dayId: effectiveDayId,
                          notesError: notes.hasError,
                          contextDiocese: contextDiocese,
                          onPrevious: _date.isAfter(kCalendarFirstDate)
                              ? () => _moveDay(-1)
                              : null,
                          onNext: _date.isBefore(kCalendarLastDate)
                              ? () => _moveDay(1)
                              : null,
                          onDateTap: _openCalendar,
                          onMonthTap: _openMonth,
                          onToday: () => _selectDate(DateTime.now()),
                          onDioceses: _chooseDioceses,
                          dioceseLabel: _dioceses.ordered
                              .map((id) => kDioceseBadges[id] ?? id)
                              .join(' · '),
                          dioceseHint: DiscoveryHintSlot(
                            anchorIds: const ['ordo.diocese.button'],
                            onShow: _chooseDioceses,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DayDetail extends ConsumerWidget {
  const _DayDetail({
    required this.union,
    required this.marianAccent,
    this.dayId,
    this.notesError = false,
    this.contextDiocese,
    required this.onPrevious,
    required this.onNext,
    required this.onDateTap,
    required this.onMonthTap,
    required this.onToday,
    required this.onDioceses,
    required this.dioceseLabel,
    this.dioceseHint,
  });

  final OrdoDayUnion union;
  final bool marianAccent;
  final String? dayId;
  final bool notesError;
  final String? contextDiocese;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onDateTap;
  final VoidCallback onMonthTap;
  final VoidCallback onToday;
  final VoidCallback onDioceses;
  final String dioceseLabel;

  /// Contextual-discovery slot right below the «Дыяцэзіі» row.
  final Widget? dioceseHint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final day = union.first;
    final date = dateOfIso(day.date);
    final weekday = DateFormat('EEEE', 'be').format(date);
    final officeKind = day.sources.office.officeKind;
    final psalter =
        const {
          'weekday',
          'sunday',
          'memorial',
          'optional-memorial',
        }.contains(officeKind)
        ? toRomanNumeral(day.psalterWeek)
        : '';
    final notesReady = OrdoRuntime.notesReady;
    final engine = OrdoRuntime.engine;
    final notes = <String, (Json, List<String>, Set<String>)>{};
    if (notesReady) {
      for (final ordo in union.days) {
        for (final note in engine.notesOf(ordo)) {
          final variants = note['variants'];
          final variant = variants is List
              ? variants
                    .whereType<Map>()
                    .where((item) => item['diocese'] == ordo.diocese)
                    .firstOrNull
              : null;
          final display = {...note, 'text': variant?['text'] ?? note['text']};
          final text = '${display['text'] ?? display['title'] ?? ''}'.trim();
          if (text.isEmpty) continue;
          final selector = display['selector'];
          final period =
              selector is Map &&
              const ['period', 'period-phase'].contains(selector['type']);
          final id = '${display['category']}|$period|$text';
          final entry = notes[id] ??= (display, <String>[], <String>{});
          if (!entry.$2.contains(ordo.diocese)) entry.$2.add(ordo.diocese);
          final source = _noteSource(display, ordo.diocese);
          if (source.isNotEmpty) entry.$3.add(source);
        }
      }
    }
    // Keep book volumes available in the collapsed additional information.
    final books = notesReady ? _ordoBookFacts(union) : const <_OrdoFact>[];
    final index = ReadingReferenceIndex.current();
    final references = {
      for (final ordo in union.days)
        ordo.diocese: {
          for (final item in readingReferencesForDay(ordo, index))
            item.optionId: item,
        },
    };

    final legal = union.rows
        .where((row) => row.role != 'commemoration')
        .toList();
    // Resolve this detail's date and dioceses, independently of the Hours
    // root retained by the router. Watching the global Hours selection here
    // can notify a hidden detail while HomeScreen is building after navigation.
    final service = LiturgicalContentService();
    final selectedOffice = resolveHoursLiturgicalSelection(
      unionDayOptions([
        for (final item in union.days)
          (
            item.diocese,
            service.contentForDate(date, diocese: item.diocese).options,
          ),
      ], primary: contextDiocese),
      selectedDayId: dayId,
      primaryDiocese: contextDiocese,
    ).selected;
    final chosen = legal.firstWhere(
      (row) =>
          row.option.id == selectedOffice?.optionId &&
          row.dioceses.contains(
            selectedOffice?.contextDiocese ?? contextDiocese,
          ),
      orElse: () => legal.firstWhere(
        (row) =>
            row.role == 'primary' &&
            row.dioceses.contains(day.diocese) &&
            row.option.id == day.primary.id,
      ),
    );
    final chosenDiocese = chosen.dioceses.contains(contextDiocese)
        ? contextDiocese!
        : chosen.dioceses.first;
    final officeContent = LiturgicalContentService().contentForDate(
      date,
      diocese: chosenDiocese,
    );
    final officeSelection = resolveHoursLiturgicalSelection(
      officeContent.options,
      selectedDayId: dayId,
      selectedDiocese: chosenDiocese,
    );
    final primaryRefs = references[chosenDiocese]?[chosen.option.id];
    final year = primaryRefs?.documents
        .map((doc) => doc.year ?? '')
        .where((year) => const {'1', '2', 'A', 'B', 'C'}.contains(year))
        .firstOrNull;
    final structuredCycle =
        primaryRefs?.documents.any(
          (doc) =>
              _massSets(doc.id)?.sets.any(
                (set) => set.cycles.contains(day.readingCycle.sunday),
              ) ??
              false,
        ) ??
        false;
    final cycle = year != null
        ? 'Год ${year == '1'
              ? 'I'
              : year == '2'
              ? 'II'
              : year}'
        : structuredCycle
        ? 'Год ${day.readingCycle.sunday}'
        : '';
    final groups = <String, List<Widget>>{};
    const labels = {
      'liturgical-rule': 'Літургічныя ўказанні',
      'mass': 'Імша',
      'office': 'Літургія гадзін',
      'devotion': 'Набажэнствы',
      'blessing': 'Благаслаўленні',
      'procession': 'Працэсіі',
      'indulgence': 'Адпусты',
      'special-prayer-day': 'Асаблівыя дні малітвы',
      'pastoral-note': 'Дыяцэзіяльныя і душпастырскія заўвагі',
      'announcement': 'Аб’явы',
      'other': 'Іншыя заўвагі',
    };
    for (final (note, dioceses, sources) in notes.values) {
      final selector = note['selector'];
      final periodNote =
          selector is Map &&
          ['period', 'period-phase'].contains(selector['type']);
      final category = '${note['category'] ?? 'other'}';
      final group = periodNote
          ? 'Агульныя ўказанні перыяду'
          : labels[category] ?? 'Іншыя заўвагі';
      groups
          .putIfAbsent(group, () => [])
          .add(
            _NoteRow(
              note: note,
              sources: sources.toList(),
              badges: dioceses.length == union.days.length
                  ? const []
                  : [for (final id in dioceses) kDioceseBadges[id] ?? id],
            ),
          );
    }
    final massNotes = groups.remove('Імша') ?? const <Widget>[];
    final officeNotes = groups.remove('Літургія гадзін') ?? const <Widget>[];
    final directionNotes =
        groups.remove('Літургічныя ўказанні') ?? const <Widget>[];
    final readingGroups =
        <String, (OptionReadingReferences, Set<OrdoUnionRow>, Set<String>)>{};
    for (final row in legal) {
      for (final diocese in row.dioceses) {
        final refs = references[diocese]?[row.option.id];
        if (refs == null) continue;
        // Memorials may keep weekday texts while their own readings are
        // available only as a citation in Ordo. Keep both sets visible.
        if (refs.reference != null &&
            refs.status != ReadingReferenceStatus.referenceOnly) {
          final entry = readingGroups['reference-only|${refs.reference}'] ??= (
            OptionReadingReferences(
              optionId: refs.optionId,
              title: refs.title,
              officeKind: refs.officeKind,
              status: ReadingReferenceStatus.referenceOnly,
              documents: const [],
              alternatives: const [],
              reference: refs.reference,
            ),
            <OrdoUnionRow>{},
            <String>{},
          );
          entry.$2.add(row);
          entry.$3.add(diocese);
        }
        final documents = [...refs.documents, ...refs.alternatives];
        if (documents.isEmpty) {
          final entry = readingGroups['${refs.status}|${refs.reference}'] ??= (
            refs,
            <OrdoUnionRow>{},
            <String>{},
          );
          entry.$2.add(row);
          entry.$3.add(diocese);
        }
        for (final doc in documents) {
          // A weekday shared by memorials appears once. Structured Mass sets
          // retain the document identity so their different contexts survive.
          final raw = ContentStore.instance.collection('readings').get(doc.id);
          final structured = raw is Map && raw['massReadings'] != null;
          final signature = structured || doc.rows.isEmpty
              ? doc.id
              : '${doc.year}|${doc.rows.map((r) => '${r.key}:${r.citation}').join(';')}';
          final entry = readingGroups[signature] ??= (
            OptionReadingReferences(
              optionId: refs.optionId,
              title: refs.title,
              officeKind: refs.officeKind,
              status: refs.status,
              documents: refs.documents.contains(doc) ? [doc] : const [],
              alternatives: refs.alternatives.contains(doc) ? [doc] : const [],
              reference: refs.reference,
            ),
            <OrdoUnionRow>{},
            <String>{},
          );
          entry.$2.add(row);
          entry.$3.add(diocese);
        }
      }
    }
    final directions = _ordoDirections(union);
    final suppressed = <String, (String, List<String>)>{};
    for (final ordo in union.days) {
      for (final option in ordo.suppressed) {
        (suppressed[option.id] ??= (
          option.title,
          <String>[],
        )).$2.add(ordo.diocese);
      }
    }
    final shownReferences = <String>{};
    Widget celebration(OrdoUnionRow row, {bool main = false}) {
      final ordinaryWeekday =
          row.option.isTemporal &&
          row.option.rank == 'feria' &&
          day.period == 'ordinary' &&
          day.week > 0;
      final diocese = row.dioceses.contains(contextDiocese)
          ? contextDiocese!
          : row.dioceses.first;
      final rowReferences = <Widget>[];
      var sharedShown = false;
      for (final entry in readingGroups.entries.where(
        (entry) => entry.value.$2.contains(row),
      )) {
        final refs = entry.value.$1;
        if (!shownReferences.add(entry.key)) {
          if (!sharedShown) {
            rowReferences.add(
              Text(
                references[diocese]?[row.option.id]?.status ==
                        ReadingReferenceStatus.weekday
                    ? 'Чытанні з дня'
                    : 'Чытанні супадаюць з прыведзенымі вышэй',
                key: Key('ordo-shared-readings-${row.option.id}'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }
          sharedShown = true;
        } else {
          if (entry.value.$3.length < union.days.length) {
            rowReferences.add(
              Text(
                entry.value.$3
                    .map((id) => kDioceseBadges[id] ?? id)
                    .join(' · '),
                style: theme.textTheme.bodySmall,
              ),
            );
          }
          rowReferences.add(
            _References(references: refs, cycle: day.readingCycle.sunday),
          );
        }
      }
      final content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (main) Text('Абрана', style: theme.textTheme.labelLarge),
          _CelebrationRow(
            row: row,
            heading: main,
            weekday: main || ordinaryWeekday
                ? '${weekday[0].toUpperCase()}${weekday.substring(1)}'
                : null,
            metadata: main
                ? [
                    if (!row.option.isTemporal &&
                        periodLabelMap[day.period] != null)
                      periodLabelMap[day.period]!,
                    if (cycle.isNotEmpty) cycle,
                    if (psalter.isNotEmpty) '$psalter тыдзень Псалтыра',
                  ].join(' · ')
                : null,
            title: ordinaryWeekday
                ? formatLiturgicalPeriodTitle(
                    periodType: day.period,
                    periodWeek: day.week,
                    dayOfWeek: null,
                    date: date,
                  )
                : main
                ? row.option.title.replaceFirst(
                    RegExp(
                      ',\\s*${RegExp.escape(weekday)}\$',
                      caseSensitive: false,
                    ),
                    '',
                  )
                : null,
          ),
          if (row.role != 'commemoration') ...[
            Wrap(
              spacing: 12,
              children: [
                TextButton.icon(
                  key: Key(
                    main
                        ? 'ordo-open-hours'
                        : 'ordo-hours-${row.option.id}-${row.role}',
                  ),
                  onPressed: () => _openHours(
                    context,
                    ref,
                    date,
                    diocese,
                    optionId: row.option.id,
                    selectedDayId: main ? officeSelection.dayId : null,
                  ),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    textStyle: theme.textTheme.titleSmall?.copyWith(
                      fontSize: 15,
                    ),
                  ),
                  label: const Text('Літургія'),
                  icon: const Icon(Icons.chevron_right, size: 18),
                ),
                TextButton.icon(
                  key: Key(
                    main
                        ? 'ordo-open-readings'
                        : 'ordo-readings-${row.option.id}-${row.role}',
                  ),
                  onPressed: () => _openReadings(
                    context,
                    date,
                    row,
                    selectedDayId: main ? dayId : null,
                    contextDiocese: diocese,
                  ),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    textStyle: theme.textTheme.titleSmall?.copyWith(
                      fontSize: 15,
                    ),
                  ),
                  label: const Text('Чытанні'),
                  icon: const Icon(Icons.chevron_right, size: 18),
                ),
              ],
            ),
            ...rowReferences,
          ],
        ],
      );
      return main
          ? Container(
              key: const Key('ordo-selected-celebration'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: content,
            )
          : Padding(
              key: Key('ordo-alternative-${row.option.id}'),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  content,
                  const SizedBox(height: 8),
                  const Divider(height: 1, thickness: .5),
                ],
              ),
            );
    }

    return Column(
      key: const Key('ordo-day-detail'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LiturgicalHeadingText(
                'Літургічны дзень',
                style: ReaderTheme.of(context).documentTitle(),
              ),
              const SizedBox(height: 12),
              LiturgicalDateNavigationRow(
                date: date,
                keyPrefix: 'ordo',
                onDateTap: onDateTap,
                onPrevious: onPrevious,
                onNext: onNext,
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: TextButton(
                      key: const Key('ordo-dioceses'),
                      style: TextButton.styleFrom(
                        alignment: Alignment.centerLeft,
                        foregroundColor: theme.colorScheme.onSurface,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 10,
                        ),
                      ),
                      onPressed: onDioceses,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Дыяцэзіі · $dioceseLabel',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                          const Icon(Icons.keyboard_arrow_down, size: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  TextButton.icon(
                    key: const Key('ordo-today'),
                    onPressed: onToday,
                    icon: const Icon(Icons.today, size: 18),
                    label: const Text('Сёння'),
                  ),
                ],
              ),
              ?dioceseHint,
              const SizedBox(height: 12),
              celebration(chosen, main: true),
              if (union.days.length > 1 && union.differs) ...[
                const SizedBox(height: 12),
                const _Explain(
                  text:
                      'Выбраныя дыяцэзіі адрозніваюцца ў гэты дзень: святкаванні асобных дыяцэзій пазначаны іх назвамі.',
                ),
              ],
            ],
          ),
        ),
        if (union.rows.any(
          (row) => row != chosen && row.role != 'commemoration',
        ))
          _Section(
            title: 'Іншыя святкаванні дня',
            children: [
              for (final row in union.rows.where(
                (r) => r.role == 'primary' && r != chosen,
              ))
                celebration(row),
              if (union.rows.any(
                (r) => r.role == 'alternative' && r != chosen,
              )) ...[
                const SizedBox(height: 8),
                Text('Можна выбраць замест', style: theme.textTheme.bodyMedium),
                for (final row in union.rows.where(
                  (r) => r.role == 'alternative' && r != chosen,
                ))
                  celebration(row),
              ],
            ],
          ),
        _Section(
          title: 'Літургія гадзінаў',
          collapsed: true,
          storageKey: 'ordo-office-${day.date}',
          children: [
            if (officeSelection.day == null)
              const Text('Тэксты літургіі гадзінаў пакуль недаступныя')
            else
              _FactRow(
                key: union.dayOf(chosenDiocese).sources.split
                    ? const Key('ordo-office-split')
                    : const Key('ordo-office-source'),
                fact: _OrdoFact(
                  label: 'Афіцый',
                  value: union.dayOf(chosenDiocese).sources.split
                      ? union.dayOf(chosenDiocese).sources.office.title
                      : officeSelection.selected?.ordo?.kind == 'temporal'
                      ? 'З дня'
                      : officeSelection.selected!.title,
                  badges: union.differs
                      ? [kDioceseBadges[chosenDiocese] ?? chosenDiocese]
                      : const [],
                ),
              ),
            if (psalter.isNotEmpty)
              _FactRow(
                fact: _OrdoFact(label: 'Псалтыр', value: '$psalter тыдзень'),
              ),
            if ((officeSelection.selected?.templates.length ?? 0) > 1)
              _NoteGroup(
                label: 'Тэксты Літургіі гадзінаў апрача ўласных',
                children: [
                  for (final template in officeSelection.selected!.templates)
                    Padding(
                      key: Key('ordo-template-${template.id}'),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Semantics(
                        selected: template.id == officeSelection.template?.id,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              template.label == 'Перыяд'
                                  ? 'З дня'
                                  : template.label,
                            ),
                            if (template.id == officeSelection.template?.id)
                              Text(
                                'Абрана',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
        if (directions.isNotEmpty || directionNotes.isNotEmpty)
          _Section(
            title: 'Асаблівыя ўказанні',
            collapsed: true,
            storageKey: 'ordo-directions-${day.date}',
            children: [
              for (final fact in directions) _FactRow(fact: fact),
              ...directionNotes,
            ],
          ),
        if (notesError ||
            !notesReady ||
            groups.isNotEmpty ||
            massNotes.isNotEmpty ||
            officeNotes.isNotEmpty ||
            suppressed.isNotEmpty ||
            union.rows.any((row) => row.role == 'commemoration'))
          _Section(
            title: 'Літургічныя заўвагі',
            collapsed: true,
            storageKey: 'ordo-notes-${day.date}',
            children: [
              if (union.rows.any((row) => row.role == 'commemoration')) ...[
                const _GroupHeading('Неабавязковыя ўспаміны'),
                for (final row in union.rows.where(
                  (row) => row.role == 'commemoration',
                ))
                  celebration(row),
              ],
              if (suppressed.isNotEmpty)
                _DetailDisclosure(
                  storageKey: 'ordo-suppressed-${day.date}',
                  label: 'Не адзначаюцца · ${suppressed.length}',
                  children: [
                    for (final (title, dioceses) in suppressed.values)
                      ListTile(
                        title: Text(title),
                        subtitle: dioceses.length == union.days.length
                            ? null
                            : Text(
                                dioceses
                                    .map((id) => kDioceseBadges[id] ?? id)
                                    .join(' · '),
                              ),
                      ),
                  ],
                ),

              if (massNotes.isNotEmpty) ...[
                _NoteGroup(label: 'Імша', children: massNotes),
              ],
              if (officeNotes.isNotEmpty) ...[
                _NoteGroup(label: 'Літургія гадзінаў', children: officeNotes),
              ],
              if (notesError)
                const Text(
                  'Не ўдалося прачытаць літургічныя заўвагі. Паспрабуйце адкрыць дзень яшчэ раз.',
                ),
              if (!notesReady && !notesError)
                const Text('Заўвагі адкрываюцца…')
              else if (notesReady)
                for (final name in [
                  ...labels.values,
                  'Агульныя ўказанні перыяду',
                ])
                  if (groups[name] case final children?)
                    if (name == 'Агульныя ўказанні перыяду')
                      _DetailDisclosure(
                        storageKey: 'ordo-notes-${day.date}-$name',
                        label: name,
                        count: children.length,
                        children: children,
                      )
                    else
                      _NoteGroup(label: name, children: children),
            ],
          ),
        if (books.isNotEmpty)
          _Section(
            title: 'Літургічныя кнігі',
            collapsed: true,
            storageKey: 'ordo-books-${day.date}',
            children: [
              for (final fact in books)
                _FactRow(
                  key: Key('ordo-book-${fact.label}-${fact.value}'),
                  fact: fact,
                ),
            ],
          ),
        const Divider(height: 32),
        ListTile(
          key: const Key('ordo-bottom-month'),
          leading: const Icon(Icons.calendar_month_outlined),
          title: const Text('Літургічны каляндар'),
          trailing: const Icon(Icons.chevron_right),
          onTap: onMonthTap,
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.children,
    this.collapsed = false,
    this.storageKey,
  });
  final String title;
  final List<Widget> children;
  final bool collapsed;
  final String? storageKey;
  @override
  Widget build(BuildContext context) => Padding(
    padding: collapsed
        ? const EdgeInsets.fromLTRB(8, 4, 8, 0)
        : const EdgeInsets.fromLTRB(8, 12, 8, 4),
    child: DefaultTextStyle.merge(
      style: const TextStyle(fontSize: 16, height: 1.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Divider(height: collapsed ? 12 : 24),
          if (collapsed)
            _DetailDisclosure(
              label: title,
              storageKey: storageKey ?? title,
              primary: true,
              childrenPadding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
              children: children,
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ],
      ),
    ),
  );
}

/// Only the parent section owns a hairline. Expanded tiles have no borders.
class _DetailDisclosure extends StatelessWidget {
  const _DetailDisclosure({
    required this.label,
    required this.storageKey,
    required this.children,
    this.count,
    this.primary = false,
    this.childrenPadding = const EdgeInsets.symmetric(vertical: 8),
  });

  final String label;
  final String storageKey;
  final List<Widget> children;
  final int? count;
  final bool primary;
  final EdgeInsets childrenPadding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: PageStorageKey(storageKey),
        shape: const Border(),
        collapsedShape: const Border(),
        maintainState: true,
        tilePadding: EdgeInsets.zero,
        minTileHeight: 48,
        childrenPadding: childrenPadding,
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        expansionAnimationStyle: MediaQuery.disableAnimationsOf(context)
            ? AnimationStyle.noAnimation
            : const AnimationStyle(duration: Duration(milliseconds: 200)),
        title: Text(
          label,
          style: theme.textTheme.titleMedium?.copyWith(
            fontSize: primary ? 17 : 16,
            fontWeight: primary ? FontWeight.w600 : FontWeight.w500,
            color: theme.colorScheme.onSurface,
          ),
        ),
        subtitle: count == null ? null : Text('$count'),
        children: children,
      ),
    );
  }
}

class _OrdoFact {
  const _OrdoFact({
    required this.label,
    required this.value,
    this.context,
    this.badges = const [],
  });
  final String label;
  final String value;
  final String? context;
  final List<String> badges;
}

/// Labels come from domain fields, never from splitting formatted sentences.
List<_OrdoFact> _mergeFacts(
  OrdoDayUnion union,
  Iterable<(String, String, String?, String)> facts,
) {
  final grouped = <(String, String, String?), Set<String>>{};
  for (final (label, value, context, diocese) in facts) {
    if (value.isNotEmpty) {
      (grouped[(label, value, context)] ??= {}).add(diocese);
    }
  }
  return [
    for (final entry in grouped.entries)
      _OrdoFact(
        label: entry.key.$1,
        value: entry.key.$2,
        context: entry.key.$3,
        badges: entry.value.length == union.days.length
            ? const []
            : [for (final id in entry.value) kDioceseBadges[id] ?? id],
      ),
  ];
}

List<_OrdoFact> _ordoDirections(OrdoDayUnion union) => _mergeFacts(union, [
  for (final day in union.days) ...[
    (
      'Нешпары',
      switch (day.evening.vespersType) {
        'first' => 'Першыя · ${day.evening.title}',
        'second' => 'Другія · ${day.evening.title}',
        _ => day.evening.title,
      },
      null,
      day.diocese,
    ),
    if (day.firstVespersCelebratedOnEve)
      ('I Нешпары', 'Напярэдадні святкавання', null, day.diocese),
    ('Камплета', _complineLabel(day.evening.compline), null, day.diocese),
    if (day.evening.omittedFirstVespers != null)
      (
        'Першынство',
        'Першыя нешпары наступнага святкавання саступаюць нешпарам гэтага дня.',
        null,
        day.diocese,
      ),
    for (final option in day.officeOptions)
      if (day.office(option.id) case final office?) ...[
        (
          'Te Deum',
          office.teDeum ? 'Спяваецца' : 'Не спяваецца',
          day.officeOptions.length > 1 ? option.title : null,
          day.diocese,
        ),
        for (final note in office.notes)
          (
            'Літургія гадзінаў',
            note,
            day.officeOptions.length > 1 ? option.title : null,
            day.diocese,
          ),
      ],
  ],
]);

List<_OrdoFact> _ordoBookFacts(OrdoDayUnion union) => _mergeFacts(union, [
  for (final day in union.days)
    if (OrdoRuntime.engine.booksOf(day) case final books?) ...[
      if (books.lectionaryVolume case final volume?)
        ('Лекцыянарый', 'Том $volume', null, day.diocese),
      if (books.hoursVolume case final volume?)
        ('Літургія гадзінаў', 'Том $volume', null, day.diocese),
    ],
]);

class _FactRow extends StatelessWidget {
  const _FactRow({super.key, required this.fact});
  final _OrdoFact fact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = Text(
      fact.label,
      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    );
    final value = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          fact.value,
          style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
        ),
        if (fact.context != null) ...[
          const SizedBox(height: 4),
          Text(
            fact.context!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (fact.badges.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            fact.badges.join(' · '),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns =
              constraints.maxWidth >= 500 &&
              MediaQuery.textScalerOf(context).scale(16) <= 21;
          return columns
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 100, child: label),
                    const SizedBox(width: 16),
                    Expanded(child: value),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [label, const SizedBox(height: 4), value],
                );
        },
      ),
    );
  }
}

class _GroupHeading extends StatelessWidget {
  const _GroupHeading(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 4),
    child: Text(
      label,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

class _NoteGroup extends StatelessWidget {
  const _NoteGroup({required this.label, required this.children});
  final String label;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [_GroupHeading(label), ...children],
  );
}

String _noteSource(Json note, String diocese) {
  if (note['source'] case final String source when source.trim().isNotEmpty) {
    return source.trim();
  }
  final observed = note['observed'];
  if (observed is! List) return '';
  final observations = observed.whereType<Map>();
  final source =
      observations.where((item) => item['diocese'] == diocese).firstOrNull ??
      observations.firstOrNull;
  if (source == null) return '';
  final dates = source['dates'];
  final years = dates is List
      ? dates
            .whereType<String>()
            .where((date) => date.length >= 4)
            .map((date) => date.substring(0, 4))
            .toSet()
            .toList()
      : <String>[];
  years.sort();
  final id = '${source['diocese'] ?? ''}';
  return [
    kDioceseBadges[id] ?? id,
    years.join(', '),
  ].where((part) => part.isNotEmpty).join(' · ');
}

String _complineLabel(String value) => switch (value) {
  'current-weekday' => 'з гэтага дня тыдня',
  'sunday-after-first-vespers' => 'пасля першых нешпараў нядзелі',
  'sunday-after-second-vespers' => 'пасля другіх нешпараў нядзелі',
  'sunday-after-first-or-second-vespers' =>
    'пасля першых або другіх нешпараў нядзелі',
  _ => 'спецыяльны варыянт; апісанне пакуль недаступнае',
};

Future<void> _openReadings(
  BuildContext context,
  DateTime date,
  OrdoUnionRow row, {
  String? selectedDayId,
  String? contextDiocese,
}) async {
  final diocese = contextDiocese ?? row.dioceses.first;
  final option = LiturgicalContentService()
      .contentForDate(date, diocese: diocese)
      .options
      .where((o) => o.optionId == row.option.id)
      .firstOrNull;
  final refs = readingReferencesForDay(
    OrdoRuntime.engine.resolve(isoOf(date), diocese: diocese),
    ReadingReferenceIndex.current(),
  ).where((r) => r.optionId == row.option.id).firstOrNull;
  final sets = [
    for (final doc in refs?.documents ?? <ReadingReferenceDocument>[])
      ...?_massSets(doc.id)?.sets,
  ];
  String? setId;
  if (sets.length > 1) {
    setId = await showReaderChoiceSheet<String>(
      context: context,
      title: 'Набор чытанняў',
      choices: [
        for (final set in sets)
          ReaderChoice(
            key: ValueKey('ordo-reading-set-${set.id}'),
            value: set.id,
            label: set.label,
          ),
      ],
    );
    if (!context.mounted || setId == null) return;
  }
  if (!context.mounted) return;
  final route = Uri.parse(
    readingsRouteForContext(
      date: date,
      dayId:
          option != null &&
              selectedDayId != null &&
              option.ownsDayId(selectedDayId)
          ? selectedDayId
          : option?.dayId,
      diocese: diocese,
      optionId: row.option.id,
    ),
  );
  context.push(
    route
        .replace(queryParameters: {...route.queryParameters, 'set': ?setId})
        .toString(),
  );
}

/// Opens the Hours of [date] (optionally one option in one diocese).
Future<void> _openHours(
  BuildContext context,
  WidgetRef ref,
  DateTime date,
  String? diocese, {
  String? selectedDayId,
  String? optionId,
}) async {
  final contextDiocese = diocese ?? ref.read(dioceseSelectionProvider).primary;
  final content = LiturgicalContentService().contentForDate(
    date,
    diocese: contextDiocese,
  );
  final option = content.options
      .where((o) => o.optionId == optionId)
      .firstOrNull;
  if (option != null && option.templates.length > 1) {
    selectedDayId = await showReaderChoiceSheet<String>(
      context: context,
      title: 'Тэксты Літургіі гадзінаў апрача ўласных',
      selectedValue: selectedDayId ?? option.dayId,
      choices: [
        for (final template in option.templates)
          ReaderChoice(
            key: ValueKey('ordo-hour-template-${template.id}'),
            value: template.id,
            label: template.label == 'Перыяд' ? 'З дня' : template.label,
          ),
      ],
    );
    if (!context.mounted || selectedDayId == null) return;
  } else if (option != null) {
    selectedDayId = option.dayId;
  }
  final selection = resolveHoursLiturgicalSelection(
    content.options,
    selectedDayId: selectedDayId,
    selectedDiocese: contextDiocese,
  );
  if (selection.dayId case final id?) {
    ref
        .read(liturgicalNavigationControllerProvider)
        .openDate(date, dayId: id, diocese: contextDiocese);
    context.go('/hours');
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Тэксты літургіі гадзінаў гэтага святкавання пакуль недаступныя.',
        ),
      ),
    );
  }
}

class _Explain extends StatelessWidget {
  const _Explain({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PhosphorIcon(PhosphorIconsRegular.info, size: 18, color: cs.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
        ),
      ],
    );
  }
}

class _CelebrationRow extends StatelessWidget {
  const _CelebrationRow({
    required this.row,
    this.heading = false,
    this.title,
    this.metadata,
    this.weekday,
  });

  final OrdoUnionRow row;
  final bool heading;
  final String? title;
  final String? metadata;
  final String? weekday;

  @override
  Widget build(BuildContext context) => heading
      ? LayoutBuilder(
          builder: (context, constraints) =>
              _buildContent(context, constraints.maxWidth),
        )
      : _buildContent(context, null);

  Widget _buildContent(BuildContext context, double? headingWidth) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final option = row.option;
    final role = switch (row.role) {
      'primary' => 'Асноўнае',
      'alternative' => 'Па выбары',
      _ => 'Неабавязковы ўспамін',
    };
    final rank = heading && option.officeKind == 'all-souls'
        ? 'Успамін'
        : ordoRankLabel(option);
    final chips = [...row.badges, ...ordoOptionNotes(option)];
    final content = Row(
      crossAxisAlignment: heading
          ? CrossAxisAlignment.stretch
          : CrossAxisAlignment.start,
      children: [
        if (heading)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Semantics(
              label: vestmentColorsLabel(option),
              child: Container(
                width: 4,
                decoration: BoxDecoration(
                  color: kVestmentColors[option.color]?.swatch,
                  border: Border.all(
                    color: kVestmentColors[option.color]?.ring ?? cs.outline,
                    width: .5,
                  ),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        if (heading) const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (heading)
                LiturgicalHeadingText(
                  title ?? option.title,
                  maxWidth: headingWidth! - 16,
                  style: ReaderTheme.of(
                    context,
                  ).displayTitle(29).copyWith(fontWeight: FontWeight.w600),
                )
              else
                Text(
                  title ?? option.title,
                  style:
                      (heading
                              ? ReaderTheme.of(context).displayTitle(29)
                              : theme.textTheme.titleMedium)
                          ?.copyWith(
                            fontSize: heading ? 29 : 16,
                            fontWeight: heading || row.role == 'primary'
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                ),
              if ((!heading ||
                      (option.rank != 'feria' && option.rank != 'dominica')) &&
                  !(option.rank == 'feria' && weekday != null)) ...[
                const SizedBox(height: 3),
                Text(
                  [
                    if (row.role == 'commemoration')
                      role
                    else if (rank.isNotEmpty)
                      rank,
                  ].join(' · '),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 14,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
              if (chips.isNotEmpty) ...[
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [for (final chip in chips) _Badge(chip)],
                ),
              ],
              if (weekday != null || (metadata?.isNotEmpty ?? false)) ...[
                const SizedBox(height: 8),
                Text.rich(
                  TextSpan(
                    children: [
                      if (weekday != null)
                        TextSpan(
                          text: weekday,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: heading ? 18 : 14,
                            color: cs.onSurface,
                          ),
                        ),
                      if (metadata?.isNotEmpty ?? false)
                        TextSpan(
                          text: '${weekday == null ? '' : ' · '}$metadata',
                        ),
                    ],
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (!heading)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 3),
            child: VestmentMarker(
              colors: [option.color, ...option.colorAlternatives],
              size: 16,
            ),
          ),
      ],
    );
    return Padding(
      key: Key('ordo-row-${option.id}-${row.role}'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: heading ? IntrinsicHeight(child: content) : content,
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: cs.onSecondaryContainer),
      ),
    );
  }
}

/// Sources sometimes include the section label in the citation itself.
String _citationText(String label, String citation) {
  final prefix = label.replaceAll(RegExp(r'[:.]+$'), '').trim();
  return citation.replaceFirst(
    RegExp('^${RegExp.escape(prefix)}[.:]?\\s+', caseSensitive: false),
    '',
  );
}

class _References extends StatelessWidget {
  const _References({required this.references, required this.cycle});
  final OptionReadingReferences references;
  final String cycle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final small = theme.textTheme.bodyLarge;
    if (references.status == ReadingReferenceStatus.referenceOnly) {
      return Column(
        key: const Key('ordo-reference-only'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Чытанні: ${references.reference}', style: small),
          Text(
            'Поўны тэкст гэтых чытанняў пакуль недаступны',
            style: small?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      );
    }
    final documents = [...references.documents, ...references.alternatives];
    if (documents.isEmpty) {
      return Text(
        'Тэкст / спасылкі пакуль недаступныя',
        key: const Key('ordo-readings-missing'),
        style: small?.copyWith(color: cs.onSurfaceVariant),
      );
    }
    return Column(
      key: const Key('ordo-reading-references'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final doc in documents) ...[
          const SizedBox(height: 8),
          if (references.alternatives.contains(doc))
            Text(
              'Або ўласныя чытанні святкавання',
              style: small?.copyWith(fontWeight: FontWeight.w700),
            ),
          if (documents.length > 1 && doc.title.isNotEmpty)
            Text(doc.title, style: small),
          if (_massSets(doc.id) case final sets?)
            _MassSetReferences(sets: sets, cycle: cycle)
          else if (doc.rows.isEmpty)
            Text(
              'Тэкст / спасылкі пакуль недаступныя',
              key: const Key('ordo-readings-missing'),
              style: small?.copyWith(color: cs.onSurfaceVariant),
            )
          else
            for (final row in doc.rows)
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${row.label} ',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(text: _citationText(row.label, row.citation)),
                  ],
                ),
                style: small,
              ),
        ],
      ],
    );
  }
}

MassReadings? _massSets(String id) {
  final raw = ContentStore.instance.collection('readings').get(id);
  return raw is Map ? MassReadings.fromMap(raw['massReadings']) : null;
}

class _MassSetReferences extends StatelessWidget {
  const _MassSetReferences({required this.sets, required this.cycle});
  final MassReadings sets;
  final String cycle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final set in sets.sets)
        if (sets.sets.length > 1)
          ExpansionTile(
            key: PageStorageKey('ordo-mass-${set.id}'),
            tilePadding: EdgeInsets.zero,
            expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
            title: Text(
              set.label,
              key: ValueKey('ordo-mass-set-${set.id}'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            children: _contents(set),
          )
        else ...[
          Text(
            set.label,
            key: ValueKey('ordo-mass-set-${set.id}'),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          ..._contents(set),
        ],
    ],
  );

  List<Widget> _contents(MassReadingSet set) => [
    if (set.referenceOnly)
      const Text('Спасылкі; поўны тэкст пакуль недаступны'),
    for (final citation in set.citations(cycle))
      Text(
        '${citation.label}: ${[citation.bible, ...citation.alternatives].map((text) => _citationText(citation.label, text)).join(' або ')}',
      ),
    if (set.citations(cycle).isEmpty) const Text('Спасылкі пакуль недаступныя'),
    if (set.note case final note?) Text(note),
    if (set.sourceUrl ?? sets.sourceUrl case final url?)
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          icon: const Icon(Icons.open_in_new, size: 16),
          label: const Text('Крыніца чытанняў'),
          onPressed: () => _openSource(url),
        ),
      ),
  ];
}

void _openSource(String url) {
  final uri = Uri.tryParse(url);
  if (uri != null && ['https', 'http'].contains(uri.scheme)) launchUrl(uri);
}

class _NoteRow extends StatelessWidget {
  const _NoteRow({
    required this.note,
    required this.badges,
    this.sources = const [],
  });
  final Json note;
  final List<String> badges;
  final List<String> sources;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = '${note['text'] ?? note['title'] ?? ''}'.trim();
    if (text.isEmpty) return const SizedBox.shrink();
    final metadata = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      height: 1.45,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: GoogleFonts.literata(
              textStyle: theme.textTheme.bodyLarge,
              fontSize: 16,
              height: 1.5,
            ),
          ),
          if (badges.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Дыяцэзіі: ${badges.join(' · ')}', style: metadata),
          ],
          if (sources.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Крыніца: ${sources.join('; ')}', style: metadata),
          ],
          if (note['classification'] == 'NEEDS_REVIEW') ...[
            const SizedBox(height: 4),
            Text('Патрабуе праверкі', style: metadata),
          ],
        ],
      ),
    );
  }
}
