import 'dart:async';

import 'package:mybrev_flutter/discovery/discovery_context.dart';
import 'package:mybrev_flutter/discovery/hints/p0_hints.dart';
import 'package:mybrev_flutter/discovery/p0_facts.dart';
import 'package:mybrev_flutter/discovery/ui/discovery_hint_slot.dart';
import 'package:mybrev_flutter/discovery/ui/discovery_sheet_hint.dart';
import 'package:mybrev_flutter/discovery/ui/discovery_visit.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:mybrev_flutter/widgets/data_loading_notice.dart';
import 'package:mybrev_flutter/widgets/loading/app_load_states.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:mybrev_flutter/models/mass_reading_sets.dart';
import 'package:mybrev_flutter/models/parsed_reading.dart';
import 'package:mybrev_flutter/providers/readings_navigation_provider.dart';
import 'package:mybrev_flutter/widgets/reader/mass_set_selector.dart';
import 'package:mybrev_flutter/models/day.dart';
import 'package:mybrev_flutter/constants/liturgical.dart';
import 'package:mybrev_flutter/providers/readings_loader_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_navigation_sync_provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:mybrev_flutter/widgets/ordo/liturgical_month_calendar.dart';
import 'package:mybrev_flutter/widgets/liturgical_selector_components.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/providers/diocese_provider.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/services/liturgical_content_service.dart';
import 'package:mybrev_flutter/widgets/reading_scaffold.dart';
import 'package:mybrev_flutter/widgets/reader/reader_scaffold.dart';
import 'package:mybrev_flutter/widgets/liturgical_day_header.dart';
import 'package:mybrev_flutter/widgets/liturgical_calendar_disclosure.dart';
import 'package:mybrev_flutter/ordo/reading_references.dart';
import 'package:mybrev_flutter/providers/liturgical_day_presentation_provider.dart';
import 'package:mybrev_flutter/widgets/selection_option_card.dart';
import 'package:mybrev_flutter/navigation/app_navigation.dart';
import 'package:mybrev_flutter/theme/platform_design.dart';
import 'package:mybrev_flutter/theme/reader.dart';
import 'package:mybrev_flutter/theme/liturgical_document.dart';
import 'package:mybrev_flutter/utils/reading_content.dart';
import 'package:mybrev_flutter/utils/reading_groups.dart';
import 'package:mybrev_flutter/utils/readings_selection.dart';
import 'package:mybrev_flutter/utils/readings_cycle_metadata.dart';
import 'package:mybrev_flutter/utils/liturgical_theme.dart';
import 'package:mybrev_flutter/utils/liturgical_titles.dart';
import 'package:mybrev_flutter/utils/liturgical_cycle.dart';
import 'package:mybrev_flutter/utils/liturgical_html.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/utils/system_insets.dart';
import 'package:mybrev_flutter/analytics/local_analytics.dart'
    show analyticsFeature;

const _highlightColors = <String, Color>{
  'amber': Color(0xFFE2AE34),
  'rose': Color(0xFFD37074),
  'sky': Color(0xFF4F9FC1),
  'leaf': Color(0xFF59A46B),
};

const _highlightColorLabels = <String, String>{
  'amber': 'Бурштынавы колер',
  'rose': 'Ружовы колер',
  'sky': 'Блакітны колер',
  'leaf': 'Зялёны колер',
};

class ReadingsScreen extends ConsumerStatefulWidget {
  /// Calendar date string, e.g. "2026-03-21" (date-based loading).
  final String? dateStr;

  /// Liturgical key, e.g. "ordinary/12/6" (period/week/dayOfWeek).
  /// When set, loads readings directly by liturgical period+week+day.
  final String? liturgicalKey;
  final String? dayId;

  /// Mass reading set asked by the route (`?set=`); the set chosen on the
  /// screen (session state) wins over it.
  final String? requestedSetId;

  /// Lectionary cycle asked by the route (`?year=`).
  final String? requestedCycle;

  const ReadingsScreen({
    super.key,
    this.dateStr,
    this.liturgicalKey,
    this.dayId,
    this.requestedSetId,
    this.requestedCycle,
  }) : assert(
         dateStr != null || liturgicalKey != null,
         'Either dateStr or liturgicalKey must be provided',
       );

  @override
  ConsumerState<ReadingsScreen> createState() => _ReadingsScreenState();
}

class _ReadingsScreenState extends ConsumerState<ReadingsScreen> {
  static const double _compactThreshold = 180;
  bool _didRequestCompact = false;

  bool _loading = true;
  String? _error;
  List<ParsedReading> _readings = [];
  List<ReadingCelebrationGroup> _groups = [];
  String? _activeGroupKey;
  String? _automaticGroupKey;
  String _sundayCycle = 'A';
  String _weekdayCycle = '1';
  int _loadGeneration = 0;
  String? _optionId;
  bool _linkDayId = true;
  final ScrollController _scrollController = ScrollController();
  String? _manualCycle;
  // Rebuild the open modal from this reader's state, never a second selection.
  final _optionsRevision = ValueNotifier<int>(0);
  bool _optionsOpen = false;
  bool _optionsRefreshScheduled = false;

  void _refreshOptionsAfterFrame() {
    if (!_optionsOpen || _optionsRefreshScheduled) return;
    _optionsRefreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _optionsRefreshScheduled = false;
      if (mounted && _optionsOpen) _optionsRevision.value++;
    });
  }

  final Map<String, String> _highlights = {};
  String? _highlightReadingId;
  String? _selectedSentenceId;
  final GlobalKey _paletteMeasureKey = GlobalKey();
  double _paletteHeight = 0;

  void _measurePalette() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _selectedSentenceId == null) return;
      final height = _paletteMeasureKey.currentContext?.size?.height;
      if (height != null && height != _paletteHeight) {
        setState(() => _paletteHeight = height);
      }
    });
  }

  AppRouteEntryScope? _routeScope;

  // Contextual Discovery (P0): inert unless the real presenter is installed.
  late final DiscoveryVisit _discovery = DiscoveryVisit(ref, 'readings');
  bool _discoveryScrolling = false;

  Future<void> _discoveryNewVisit() async {
    await _discovery.begin();
    if (mounted) _scheduleDiscovery();
  }

  void _scheduleDiscovery() => _discovery.schedule(_discoverySnapshot);

  /// The shared checks of every hint on this screen. Null = say nothing.
  DiscoveryContext? _discoverySnapshot(int visitId) {
    if (!mounted || widget.dateStr == null || widget.liturgicalKey != null) {
      return null;
    }
    final navigation = AppNavigationScope.maybeOf(context);
    final routeActive =
        (ModalRoute.of(context)?.isCurrent ?? true) &&
        (navigation == null ||
            (navigation.shellState.activeBranch == AppBranch.readings &&
                navigation.shellState.activeController.activeEntryId ==
                    _routeScope?.entry.id));
    final presentation = ref.read(liturgicalDayPresentationProvider);
    final sameDay = DateUtils.isSameDay(presentation.date, _currentDate);
    final ready =
        !_loading && _error == null && _readings.isNotEmpty && sameDay;
    final ui = DiscoveryUiState(
      scrolling: _discoveryScrolling,
      activeReading: _selectedSentenceId != null,
      keyboardVisible: MediaQuery.viewInsetsOf(context).bottom > 0,
      modalOpen: _optionsOpen || !routeActive,
    );
    if (!ready) {
      return DiscoveryContext.loading(
        screenId: 'readings',
        visitId: visitId,
        ui: ui,
      );
    }
    // The anchors are in the header: only reachable at the top of the text.
    final atTop =
        !_scrollController.hasClients || _scrollController.offset <= 24;
    final signals = ref.read(discoverySessionSignalsProvider);
    final celebrations = ref
        .read(hoursLiturgicalSelectionProvider)
        .sortedOptions
        .where(
          (o) =>
              o.ordo != null &&
              !o.disabled &&
              o.source != LiturgicalOptionSource.officeForDead,
        )
        .length;
    return DiscoveryContext(
      screenId: 'readings',
      visitId: visitId,
      status: DiscoveryDataStatus.ready,
      anchors: atTop
          ? _discovery.mounted(const {
              'readings.day_variants.button',
              'readings.cycle.button',
              'calendar.date.button',
            })
          : const {},
      facts: {
        kFactDayVariantCount: celebrations,
        kFactOtherCycleLoaded:
            _selection.cycles.length > 1 && _manualCycle == null,
        kFactCalendarAnchorReady:
            signals.dayArrowTaps >= kDateNavigationArrowTaps &&
            !signals.dateControlUsed,
      },
      ui: ui,
    );
  }

  @override
  void initState() {
    super.initState();
    final cycle = normalizeReadingCycle(widget.requestedCycle);
    if (cycle.isNotEmpty) _manualCycle = cycle;
    _load();
  }

  @override
  void didUpdateWidget(covariant ReadingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dateStr != widget.dateStr ||
        oldWidget.liturgicalKey != widget.liturgicalKey ||
        oldWidget.dayId != widget.dayId) {
      _didRequestCompact = false;
      if (oldWidget.dateStr != widget.dateStr ||
          oldWidget.liturgicalKey != widget.liturgicalKey) {
        _manualCycle = null;
      }
      _activeGroupKey = null;
      _automaticGroupKey = null;
      _clearSentenceSelection();
      ReaderChromeModeScope.maybeControllerOf(context)?.value =
          ReaderChromeMode.full;
      _load();
      _resetDocumentScroll();
    }
  }

  void _applyResult(ReadingsLoadResult result, String? dayId, bool byDate) {
    final selection = resolveDefaultReadings(
      readings: result.readings,
      sundayCycle: result.sundayCycle,
      weekdayCycle: result.weekdayCycle,
      // A memorial opens with the weekday readings (engine order first).
      dayId: result.linkDayId ? dayId : null,
      optionId: result.optionId,
      groupByCelebration: byDate,
    );
    _optionId = result.optionId;
    _linkDayId = result.linkDayId;
    _readings = result.readings;
    _groups = selection.groups;
    _activeGroupKey = selection.activeGroupKey;
    _automaticGroupKey = selection.activeGroupKey;
    final savedChoices = ref.read(readingsMassSetSelectionProvider);
    final savedGroup = savedChoices['$_choiceContext|@group'];
    if (_groups.any((group) => group.key == savedGroup)) {
      _activeGroupKey = savedGroup;
    }
    _manualCycle ??= savedChoices['$_choiceContext|@cycle'];
    _sundayCycle = result.sundayCycle;
    _weekdayCycle = result.weekdayCycle;
    if (_manualCycle != null && !_selection.cycles.contains(_manualCycle)) {
      _manualCycle = null;
    }
    _loading = false;
    _error = null;
  }

  /// Readings are on the device: they are shown in the same frame. Only
  /// at launch, while the content is still being decoded, a quiet
  /// placeholder appears for a moment.
  Future<void> _load() async {
    if (!mounted) return;
    final generation = ++_loadGeneration;
    unawaited(_discoveryNewVisit());
    final requestedDateStr = widget.dateStr;
    final requestedLiturgicalKey = widget.liturgicalKey;
    final requestedDayId = widget.dayId;

    final local = ref.read(readingsLocalLoaderProvider)(
      dateStr: requestedDateStr,
      liturgicalKey: requestedLiturgicalKey,
      dayId: requestedDayId,
    );
    if (local != null) {
      setState(() {
        _applyResult(local, requestedDayId, requestedDateStr != null);
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await ref.read(readingsLoaderProvider)(
        dateStr: requestedDateStr,
        liturgicalKey: requestedLiturgicalKey,
        dayId: requestedDayId,
      );
      // A newer request (another date) owns the screen now.
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _applyResult(result, requestedDayId, requestedDateStr != null);
      });
      _scheduleDiscovery();
    } catch (e) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _routeScope = AppRouteEntryScope.maybeOf(context);
  }

  @override
  void dispose() {
    _discovery.end();
    _routeScope?.showContextualBottomBar(false);
    _scrollController.dispose();
    _optionsRevision.dispose();
    super.dispose();
  }

  String _highlightStorageKey(String readingId) =>
      'readingsHighlight:$readingId';

  void _loadHighlights(String readingId) {
    if (_highlightReadingId == readingId) return;
    _highlightReadingId = readingId;
    _clearSentenceSelection();
    _highlights.clear();
    final raw = HiveService.isSettingsReady
        ? HiveService.settingsBox.get(_highlightStorageKey(readingId))
        : null;
    if (raw is Map) {
      raw.forEach((key, value) {
        final color = value.toString();
        if (_highlightColors.containsKey(color)) {
          _highlights[key.toString()] = color;
        }
      });
    }
  }

  void _toggleSentence(String sentenceId) {
    ScaffoldMessenger.maybeOf(context)?.removeCurrentSnackBar();
    setState(() {
      _selectedSentenceId = _selectedSentenceId == sentenceId
          ? null
          : sentenceId;
    });
    _routeScope?.showContextualBottomBar(_selectedSentenceId != null);
  }

  void _clearSentenceSelection({bool notify = true}) {
    _selectedSentenceId = null;
    if (notify) _routeScope?.showContextualBottomBar(false);
  }

  Future<void> _applySentenceColor(String? color) async {
    final sentenceId = _selectedSentenceId;
    final readingId = _highlightReadingId;
    if (sentenceId == null || readingId == null) return;
    setState(() {
      if (color == null) {
        _highlights.remove(sentenceId);
      } else {
        _highlights[sentenceId] = color;
      }
      _clearSentenceSelection(notify: false);
    });
    _routeScope?.showContextualBottomBar(false);
    if (HiveService.isSettingsReady) {
      await HiveService.settingsBox.put(_highlightStorageKey(readingId), {
        for (final item in _highlights.entries) item.key: item.value,
      });
    }
  }

  List<ParsedReading> _activeGroupDocuments() {
    if (_groups.isEmpty) return _readings;
    final group = _groups.firstWhere(
      (g) => g.key == _activeGroupKey,
      orElse: () => _groups.first,
    );
    return group.documents;
  }

  void _selectCelebrationGroup(String key) {
    if (key == _activeGroupKey) return;
    _clearSentenceSelection();
    setState(() {
      _activeGroupKey = key;
      final group = _groups.where((group) => group.key == key).firstOrNull;
      if (group != null &&
          _manualCycle != null &&
          !_cyclesOfGroup(group).contains(_manualCycle)) {
        _manualCycle = null;
      }
    });
    _rememberChoices();
    // A lectionary set is not a different celebration. Only the shared
    // calendar changes the selected liturgical day and its Office.
    _resetDocumentScroll();
  }

  DefaultReadingsSelection get _selection => resolveDefaultReadings(
    readings: _readings,
    sundayCycle: _sundayCycle,
    weekdayCycle: _weekdayCycle,
    dayId: _linkDayId ? widget.dayId : null,
    optionId: _optionId,
    groupKey: _activeGroupKey,
    manualCycle: _manualCycle,
    requestedSetId: widget.requestedSetId,
    setChoices: _setChoices(),
    groupByCelebration: widget.dateStr != null,
  );

  /// Readings context of the set choices (the date or the liturgical key).
  String get _setContext => widget.dateStr ?? widget.liturgicalKey ?? '';

  String get _choiceContext => '$_setContext|${widget.dayId ?? ''}';

  void _rememberChoices() {
    final notifier = ref.read(readingsMassSetSelectionProvider.notifier);
    final choices = {...notifier.state};
    if (_activeGroupKey != null) {
      choices['$_choiceContext|@group'] = _activeGroupKey!;
    }
    if (_manualCycle == null) {
      choices.remove('$_choiceContext|@cycle');
    } else {
      choices['$_choiceContext|@cycle'] = _manualCycle!;
    }
    notifier.state = choices;
  }

  /// Sets chosen on this screen for the documents of its context.
  Map<String, String> _setChoices() {
    final prefix = '$_setContext|';
    return {
      for (final entry in ref.read(readingsMassSetSelectionProvider).entries)
        if (entry.key.startsWith(prefix))
          entry.key.substring(prefix.length): entry.value,
    };
  }

  /// Another Mass reading set of the same celebration (vigil / day, …).
  /// Kept in the session state: returning to the date shows it again.
  void _selectMassSet(MassSetSelection current, String setId) {
    if (setId == current.set.id) return;
    _clearSentenceSelection();
    final next = current.sets.where((set) => set.id == setId).firstOrNull;
    final notifier = ref.read(readingsMassSetSelectionProvider.notifier);
    setState(() {
      notifier.state = {
        ...notifier.state,
        '$_setContext|${current.document.id}': setId,
      };
      if (_manualCycle != null &&
          next != null &&
          !next.cycles.contains(_manualCycle)) {
        _manualCycle = null;
      }
    });
    _rememberChoices();
    _resetDocumentScroll();
  }

  void _resetDocumentScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          _scrollController.hasClients &&
          _scrollController.position.hasContentDimensions) {
        _scrollController.jumpTo(0);
      }
    });
  }

  void _selectManualCycle(String? cycle) {
    if (_manualCycle == cycle) return;
    _clearSentenceSelection();
    setState(() => _manualCycle = cycle);
    _rememberChoices();
    _resetDocumentScroll();
  }

  Widget? _menuLeading() {
    final navigation = AppNavigationScope.maybeOf(context);
    if (navigation?.shellState.canReturnToOra() ?? false) {
      return IconButton(
        tooltip: 'Вярнуцца да Ora',
        onPressed: navigation!.returnToOra,
        icon: const Icon(Icons.arrow_back_rounded),
      );
    }
    if ((GoRouter.maybeOf(context)?.canPop() ?? false) ||
        !(AppRouteEntryScope.maybeOf(context)?.entry.descriptor.isBranchRoot ??
            true)) {
      return IconButton(
        tooltip: 'Назад',
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => context.pop(),
      );
    }
    return null;
  }

  String _cycleLabel(String cycle) => switch (cycle) {
    '1' => 'I',
    '2' => 'II',
    _ => cycle,
  };

  Color _readingColor() {
    final documents = _activeGroupDocuments();
    if (documents.isEmpty) {
      return Theme.of(context).colorScheme.primary;
    }
    final data = documents.first.toMap();
    if (widget.dayId == 'office-for-dead') {
      data['_kind'] = 'office-for-dead';
    }
    return liturgicalColorForDay(
      LiturgicalDay.fromMap(data),
      fallbackPeriodType: documents.first.periodType ?? 'ordinary',
    );
  }

  /// The date is shown in the page header, as in mybrev/ReadingsView.vue.
  String get _title {
    if (widget.liturgicalKey != null) {
      return _formatLiturgicalKey(widget.liturgicalKey!);
    }
    return 'Чытанні';
  }

  String _formatLiturgicalKey(String key) {
    final parts = key.split('/');
    if (parts.isEmpty) return key;
    final periodType = parts[0];
    final period = periodLabelMap[periodType] ?? periodType;
    if (parts.length < 2) return period;
    final week = int.tryParse(parts[1]);
    if (parts.length < 3 || week == null) return period;
    final day = int.tryParse(parts[2]);
    if (day == null) return period;
    return formatLiturgicalPeriodTitle(
      periodType: periodType,
      periodWeek: week,
      dayOfWeek: day,
      date: DateTime(2000, 2, 2),
      useArabicWeekNumber: false,
    );
  }

  String _contextTitleFor(
    ReadingCelebrationGroup? group,
    ParsedReading? reading,
  ) {
    if (reading != null && (reading.periodType ?? '').isNotEmpty) {
      final periodTitle = formatLiturgicalPeriodTitle(
        periodType: reading.periodType!,
        periodWeek: reading.periodWeekNumber,
        dayOfWeek: reading.dayOfWeek,
        date: DateTime.tryParse(widget.dateStr ?? '') ?? DateTime(2000, 2, 2),
      );
      if (periodTitle.isNotEmpty) return periodTitle;
    }
    return group?.label ?? reading?.title ?? _title;
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.axis == Axis.vertical) {
      if (notification is ScrollEndNotification) {
        if (_discoveryScrolling) {
          _discoveryScrolling = false;
          _scheduleDiscovery();
        }
      } else if (notification is ScrollStartNotification ||
          notification is ScrollUpdateNotification) {
        _discoveryScrolling = true;
        _discovery.interrupt();
      }
    }
    if (!_didRequestCompact &&
        notification.metrics.axis == Axis.vertical &&
        notification.metrics.pixels >= _compactThreshold &&
        notification is ScrollUpdateNotification &&
        notification.dragDetails != null) {
      _didRequestCompact = true;
      ReaderChromeModeScope.maybeControllerOf(context)?.value =
          ReaderChromeMode.compact;
    }
    return false;
  }

  Widget _trackScroll(Widget child) => NotificationListener<ScrollNotification>(
    onNotification: _onScroll,
    child: child,
  );

  DateTime get _currentDate =>
      DateTime.tryParse(widget.dateStr ?? '') ?? DateTime.now();

  void _openRelativeDate(int direction) {
    ref.read(discoverySessionSignalsProvider).dayArrowTaps++;
    AppNavigationScope.maybeOf(context)?.shellState.clearOraReturn();
    ref.read(liturgicalNavigationControllerProvider).moveBy(direction);
  }

  Future<void> _showDateActions() => _showOptions(calendarExpanded: true);

  /// Cycles of a group: of its Mass reading sets, else of its documents.
  List<String> _cyclesOfGroup(ReadingCelebrationGroup group) {
    final sets = group.documents
        .where((reading) => reading.hasMassReadingSets)
        .firstOrNull
        ?.massReadings
        ?.sets;
    if (sets != null) {
      return {for (final set in sets) ...set.cycles}.toList()..sort();
    }
    return availableCyclesForGroup(group.documents);
  }

  bool get _hasOptions {
    final selection = _selection;
    return selection.groups.length > 1 ||
        selection.cycles.length > 1 ||
        (selection.massSet?.sets.length ?? 0) > 1;
  }

  Future<void> _showOptions({bool calendarExpanded = false}) async {
    if (_optionsOpen) return;
    _optionsOpen = true;
    _discovery.interrupt();
    unawaited(_discovery.actedOnPresented());
    if (calendarExpanded) {
      ref.read(discoverySessionSignalsProvider).dateControlUsed = true;
    }
    if (calendarExpanded) analyticsFeature('picker_open');
    final advanced = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) => ValueListenableBuilder<int>(
        valueListenable: _optionsRevision,
        builder: (_, revision, child) {
          final selection = _selection;
          final hours = ref.read(hoursLiturgicalSelectionProvider);
          final selected = hours.selected;
          final content = widget.liturgicalKey == null && selected?.ordo != null
              ? LiturgicalContentService().contentForDate(
                  _currentDate,
                  diocese:
                      hours.diocese ??
                      ref.read(dioceseSelectionProvider).primary,
                )
              : null;
          final refs = content == null
              ? null
              : readingReferencesForDay(
                  content.ordo,
                  ReadingReferenceIndex.current(),
                ).where((r) => r.optionId == selected?.optionId).firstOrNull;
          return _ReadingsOptionsSheet(
            calendarExpanded: calendarExpanded,
            onFindDay: () => Navigator.pop(sheetContext, true),
            loading: _loading,
            readingNote: refs?.status == ReadingReferenceStatus.weekday
                ? 'Чытанні з дня'
                : null,
            date: widget.liturgicalKey == null ? _currentDate : null,
            celebrations: widget.liturgicalKey == null
                ? ref
                      .read(hoursLiturgicalSelectionProvider)
                      .sortedOptions
                      .where(
                        (o) =>
                            o.ordo != null &&
                            !o.disabled &&
                            o.source != LiturgicalOptionSource.officeForDead,
                      )
                      .toList()
                : const [],
            selectedCelebration: ref
                .read(hoursLiturgicalSelectionProvider)
                .selected
                ?.key,
            onCelebrationSelected: (option) {
              if (option.dayId != null) {
                ref
                    .read(liturgicalNavigationControllerProvider)
                    .selectDay(
                      _currentDate,
                      option.dayId!,
                      diocese: option.contextDiocese,
                    );
              }
            },
            onDateSelected: (date) {
              analyticsFeature('date_pick');
              ref.read(liturgicalNavigationControllerProvider).openDate(date);
            },
            massSet: _loading ? null : selection.massSet,
            onSetSelected: (id) {
              if (selection.massSet != null) {
                _selectMassSet(selection.massSet!, id);
              }
            },
            accentColor: _readingColor(),
            groups: _loading ? const [] : selection.groups,
            activeGroupKey: selection.activeGroupKey,
            cycles: _loading ? const [] : selection.cycles,
            automaticCycle: selection.automaticCycle,
            manualCycle: _manualCycle,
            onGroupSelected: (key) {
              _selectCelebrationGroup(key);
            },
            onCycleSelected: (cycle) {
              _selectManualCycle(cycle);
            },
          );
        },
      ),
    );
    _optionsOpen = false;
    // A date picked inside the sheet loaded while it was open: ask again now.
    if (mounted) _scheduleDiscovery();
    if (advanced == true && mounted) {
      await context.push('/readings/picker?mode=readings');
    }
  }

  @override
  Widget build(BuildContext context) {
    _refreshOptionsAfterFrame();
    ref.listen(dioceseSelectionProvider, (previous, next) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    });
    final sharedPresentation = ref.watch(liturgicalDayPresentationProvider);
    final usesCalendar = widget.liturgicalKey == null;
    final seasonColor = usesCalendar
        ? sharedPresentation.accent
        : _readingColor();
    Widget document;
    String contextTitle = _title;
    String? cycleLabel;
    if (_loading) {
      document = const _ReadingsStatus(
        icon: null,
        title: 'Адкрываем чытанні',
        loading: true,
      );
    } else if (_error != null) {
      document = _ReadingsStatus(
        icon: PhosphorIconsLight.warning,
        title: 'Не ўдалося адкрыць чытанні',
        message: _error,
        actionLabel: 'Паўтарыць',
        onAction: _load,
      );
    } else if (_readings.isEmpty) {
      document = _ReadingsStatus(
        icon: PhosphorIconsLight.bookOpen,
        title: 'Чытанні для гэтага дня не знойдзены',
      );
    } else {
      final selection = _selection;
      final reading = selection.reading;
      final activeGroup = selection.groups
          .where((group) => group.key == selection.activeGroupKey)
          .firstOrNull;
      contextTitle = _contextTitleFor(activeGroup, reading);
      final massSet = selection.massSet;
      final cycle = massSet != null
          ? massSet.cycle
          : normalizeReadingCycle(reading?.year);
      if (cycle.isNotEmpty) cycleLabel = _cycleLabel(cycle);
      contextTitle = contextTitle
          .replaceAll(
            RegExp(
              r'\s*[,·:—–-]?\s*[([]?\s*(?:год|цыкл|цикл)\s+[ABCАВСІI12]+\s*[)\]]?\s*\.?$',
              caseSensitive: false,
            ),
            '',
          )
          .trim();
      document = reading == null
          ? const _ReadingsStatus(
              icon: PhosphorIconsLight.bookOpen,
              title: 'Тэкст чытання не знойдзены',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildReadingBody(reading, selection.massSet, seasonColor),
                // Attribution is available in the app's dedicated Sources page.
                const SizedBox(key: Key('readings-document-end')),
              ],
            );
    }

    final manualGroup = _activeGroupKey != _automaticGroupKey;
    final cycleMetadata = readingsCycleMetadata(
      cycle: _manualCycle == null ? cycleLabel : _cycleLabel(_manualCycle!),
      manualGroup: manualGroup,
      manualCycle: _manualCycle != null,
    );
    final hasOraReturn =
        AppNavigationScope.maybeOf(context)?.shellState.canReturnToOra() ??
        false;

    if (_selectedSentenceId != null) {
      _measurePalette();
      document = Padding(
        key: const Key('readings-selection-content-reserve'),
        padding: EdgeInsets.only(
          bottom: Theme.of(context).platform == TargetPlatform.android
              ? floatingOverlayContentReserve(
                  overlayHeight: _paletteHeight,
                  overlayBottom: floatingOverlayBottom(
                    context,
                    gap: floatingPaletteGap(context),
                  ),
                  readerBottomPadding:
                      ReaderContentSurface.bottomSpacing +
                      MediaQuery.paddingOf(context).bottom,
                  contentGap: 24,
                )
              : 80 + systemBottomInset(context),
        ),
        child: document,
      );
    }

    final reader = _trackScroll(
      ReaderScaffold(
        followSwipeDrag: true,
        onSwipePrevious: _currentDate.isAfter(kCalendarFirstDate)
            ? () => _openRelativeDate(-1)
            : null,
        onSwipeNext: _currentDate.isBefore(kCalendarLastDate)
            ? () => _openRelativeDate(1)
            : null,
        scrollController: _scrollController,
        scrollKey: const PageStorageKey('readings-root-scroll'),
        semanticLabel: 'Чытанні дня',
        showScrollToTop: _selectedSentenceId == null,
        seasonColor: seasonColor,
        chromeMode: ReaderChromeMode.full,
        leading: _menuLeading(),
        showBack: false,
        onBack: hasOraReturn
            ? AppNavigationScope.maybeOf(context)?.returnToOra
            : null,
        contextHeader: Padding(
          key: const Key('readings-context-header'),
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (usesCalendar)
                LiturgicalDayHeader(
                  sectionTitle: 'Чытанні дня',
                  keyPrefix: 'readings',
                  presentation: sharedPresentation,
                  onDateTap: _showDateActions,
                  // Proper festal readings can be year-independent and
                  // therefore have no document cycle. The calendar year
                  // remains visible as context even for those readings.
                  metadata: [
                    sharedPresentation.weekday,
                    'Год ${cycleLabel ?? _cycleLabel(getCycleForDate(sharedPresentation.date))}',
                  ].join(' · '),
                  onToday: () => ref
                      .read(liturgicalNavigationControllerProvider)
                      .openDate(DateTime.now()),
                  onVariants: _showOptions,
                  onPrevious: () => _openRelativeDate(-1),
                  onNext: () => _openRelativeDate(1),
                  dateHint: DiscoveryHintSlot(
                    anchorIds: const ['calendar.date.button'],
                    onShow: _showDateActions,
                  ),
                  variantsHint: DiscoveryHintSlot(
                    anchorIds: const [
                      'readings.day_variants.button',
                      'readings.cycle.button',
                    ],
                    onShow: _showOptions,
                  ),
                )
              else ...[
                Text(
                  'Чытанні дня',
                  style: ReaderTheme.of(context).displayTitle(36),
                ),
                const SizedBox(height: 16),
                Text(
                  contextTitle,
                  style: ReaderTheme.of(context).displayTitle(29),
                ),
                TextButton(
                  onPressed: _showDateActions,
                  child: const Text('Выбраць дату'),
                ),
              ],
              if (cycleMetadata != null &&
                  (!usesCalendar || manualGroup || _manualCycle != null)) ...[
                const SizedBox(height: 10),
                Text(
                  cycleMetadata,
                  key: const Key('readings-cycle-metadata'),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (!usesCalendar && !_loading && _error == null && _hasOptions)
                TextButton.icon(
                  key: const Key('readings-options-action'),
                  onPressed: _showOptions,
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: const Text('Іншыя варыянты'),
                ),
            ],
          ),
        ),
        content: document,
      ),
    );
    final content = PopScope<void>(
      canPop: _selectedSentenceId == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _selectedSentenceId != null) {
          setState(() => _clearSentenceSelection());
        }
      },
      child: Stack(
        children: [
          reader,
          if (_selectedSentenceId != null)
            Positioned(
              left: MediaQuery.sizeOf(context).width <= 340 ? 4 : 12,
              right: MediaQuery.sizeOf(context).width <= 340 ? 4 : 12,
              bottom: floatingOverlayBottom(
                context,
                gap: floatingPaletteGap(context),
              ),
              child: KeyedSubtree(
                key: _paletteMeasureKey,
                child: _highlightPalette(),
              ),
            ),
        ],
      ),
    );
    // At a branch root GoRouter has no page to pop. Consume Android Back
    // before its dispatcher so a live selection still gets cancelled.
    if (GoRouter.maybeOf(context) == null) return content;
    return BackButtonListener(
      onBackButtonPressed: () async {
        final navigation = AppNavigationScope.maybeOf(context);
        if (navigation != null &&
            (navigation.shellState.activeBranch != AppBranch.readings ||
                navigation.shellState.activeController.activeEntryId !=
                    _routeScope?.entry.id)) {
          return false;
        }
        if (_selectedSentenceId == null) return false;
        setState(() => _clearSentenceSelection());
        return true;
      },
      child: content,
    );
  }

  Widget _buildReadingBody(
    ParsedReading reading,
    MassSetSelection? massSet,
    Color seasonColor,
  ) {
    _loadHighlights(reading.id);
    final body = _ReadingBody(
      key: ValueKey(
        'reading-document-${reading.id}-'
        '${massSet == null ? '' : '${massSet.set.id}-'}'
        '${_manualCycle ?? 'auto'}',
      ),
      reading: reading,
      massSet: massSet,
      highlights: Map.unmodifiable(_highlights),
      selectedSentenceId: _selectedSentenceId,
      onSentenceTap: _toggleSentence,
    );
    return body;
  }

  Widget _highlightPalette() => AdaptiveChromeSurface(
    key: const Key('readings-highlight-palette'),
    role: ChromeSurfaceRole.group,
    borderRadius: BorderRadius.circular(22),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    child: Material(
      color: Colors.transparent,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final color in _highlightColors.entries)
            Semantics(
              button: true,
              label: _highlightColorLabels[color.key],
              selected: _highlights[_selectedSentenceId] == color.key,
              child: InkWell(
                key: Key('readings-highlight-${color.key}'),
                customBorder: const CircleBorder(),
                onTap: () => _applySentenceColor(color.key),
                child: SizedBox.square(
                  dimension: 48,
                  child: Center(
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.value,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          IconButton(
            key: const Key('readings-highlight-clear'),
            constraints: const BoxConstraints.tightFor(width: 48, height: 48),
            tooltip: 'Прыбраць вылучэнне',
            onPressed: () => _applySentenceColor(null),
            icon: const PhosphorIcon(PhosphorIconsRegular.eraser, size: 20),
          ),
          IconButton(
            key: const Key('readings-highlight-cancel'),
            constraints: const BoxConstraints.tightFor(width: 48, height: 48),
            tooltip: 'Скасаваць выбар',
            onPressed: () {
              setState(() => _clearSentenceSelection(notify: false));
              _routeScope?.showContextualBottomBar(false);
            },
            icon: const PhosphorIcon(PhosphorIconsRegular.x, size: 19),
          ),
        ],
      ),
    ),
  );
}

String _readingsCycleLabel(String cycle) => switch (cycle) {
  '1' => 'I',
  '2' => 'II',
  _ => cycle,
};

class _ReadingsOptionsSheet extends StatefulWidget {
  const _ReadingsOptionsSheet({
    required this.accentColor,
    this.date,
    this.celebrations = const [],
    this.selectedCelebration,
    required this.onCelebrationSelected,
    required this.onDateSelected,
    this.massSet,
    required this.onSetSelected,
    required this.groups,
    required this.activeGroupKey,
    required this.cycles,
    required this.automaticCycle,
    required this.manualCycle,
    required this.onGroupSelected,
    required this.onCycleSelected,
    required this.calendarExpanded,
    required this.onFindDay,
    this.loading = false,
    this.readingNote,
  });

  final DateTime? date;
  final List<DayOption> celebrations;
  final String? selectedCelebration;
  final ValueChanged<DayOption> onCelebrationSelected;
  final ValueChanged<DateTime> onDateSelected;
  final MassSetSelection? massSet;
  final ValueChanged<String> onSetSelected;
  final Color accentColor;
  final List<ReadingCelebrationGroup> groups;
  final String? activeGroupKey;
  final List<String> cycles;
  final String automaticCycle;
  final String? manualCycle;
  final ValueChanged<String> onGroupSelected;
  final ValueChanged<String?> onCycleSelected;
  final bool calendarExpanded;
  final VoidCallback onFindDay;
  final bool loading;
  final String? readingNote;

  @override
  State<_ReadingsOptionsSheet> createState() => _ReadingsOptionsSheetState();
}

class _ReadingsOptionsSheetState extends State<_ReadingsOptionsSheet> {
  late bool _calendarExpanded = widget.calendarExpanded;

  @override
  Widget build(BuildContext context) => LiturgicalSelectorSheet(
    key: const Key('readings-options-sheet'),
    scrollKey: const Key('readings-options-scroll'),
    doneKey: const Key('readings-options-done'),
    children: [
      if (widget.date != null)
        LiturgicalCalendarDisclosure(
          date: widget.date!,
          controlKey: const Key('readings-calendar-disclosure'),
          expanded: _calendarExpanded,
          onChanged: (expanded) => setState(() => _calendarExpanded = expanded),
          calendar: LiturgicalMonthCalendar(
            initialDate: widget.date!,
            onSelected: widget.onDateSelected,
          ),
        ),
      if (widget.date != null && _calendarExpanded)
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            key: const Key('readings-calendar-today'),
            onPressed: () =>
                widget.onDateSelected(DateUtils.dateOnly(DateTime.now())),
            child: const Text('Сёння'),
          ),
        ),
      if (widget.celebrations.isNotEmpty) ...[
        const LiturgicalSelectorHeading('Святкаванне'),
        RadioGroup<String>(
          groupValue: widget.selectedCelebration,
          onChanged: (key) {
            final option = widget.celebrations
                .where((o) => o.key == key)
                .firstOrNull;
            if (option != null) widget.onCelebrationSelected(option);
          },
          child: Column(
            children: [
              for (final option in widget.celebrations)
                LiturgicalCelebrationChoice(
                  key: ValueKey('readings-celebration-${option.key}'),
                  value: option.key,
                  selected: option.key == widget.selectedCelebration,
                  title: option.title,
                  colors: [
                    option.ordo!.color,
                    ...option.ordo!.colorAlternatives,
                  ],
                  subtitle: [
                    liturgicalOptionRank(option),
                    ...option.badges,
                  ].where((s) => s.isNotEmpty).join(' · '),
                ),
            ],
          ),
        ),
      ],
      if (widget.loading) const LinearProgressIndicator(),
      if (!widget.loading && widget.readingNote != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(widget.readingNote!),
        ),
      if (widget.groups.length > 1) ...[
        const SizedBox(height: 18),
        const LiturgicalSelectorHeading('Набор чытанняў'),
        for (final group in widget.groups)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: SelectionOptionCard(
              key: ValueKey('readings-group-${group.key}'),
              dense: true,
              selected: group.key == widget.activeGroupKey,
              title: group.label,
              onTap: () => widget.onGroupSelected(group.key),
            ),
          ),
      ],
      if (widget.massSet != null && widget.massSet!.sets.length > 1) ...[
        const SizedBox(height: 18),
        MassSetSelector(
          sets: widget.massSet!.sets,
          selectedId: widget.massSet!.set.id,
          accentColor: widget.accentColor,
          onSelected: widget.onSetSelected,
        ),
      ],
      if (widget.cycles.length > 1) ...[
        const SizedBox(height: 18),
        const LiturgicalSelectorHeading('Выбар чытанняў'),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final cycle in widget.cycles)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: SelectionOptionCard(
                    key: ValueKey('readings-cycle-$cycle'),
                    compact: true,
                    title: 'Год ${_readingsCycleLabel(cycle)}',
                    selected:
                        cycle == (widget.manualCycle ?? widget.automaticCycle),
                    onTap: () => widget.onCycleSelected(
                      cycle == widget.automaticCycle ? null : cycle,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          widget.manualCycle == null
              ? 'Паводле календара · Год ${_readingsCycleLabel(widget.automaticCycle)}'
              : 'Прагляд іншага года · Год ${_readingsCycleLabel(widget.manualCycle!)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (widget.manualCycle != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('readings-cycle-automatic'),
              onPressed: () => widget.onCycleSelected(null),
              icon: const Icon(Icons.restore, size: 18),
              label: const Text('Паводле календара'),
            ),
          ),
      ],
      if (widget.groups.length < 2 &&
          (widget.massSet?.sets.length ?? 0) < 2 &&
          widget.cycles.length < 2 &&
          widget.celebrations.length < 2)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Text('Для гэтай даты іншых набораў чытанняў няма'),
        ),
      if (widget.date != null) const CalendarSearchHint(),
      if (widget.date != null)
        ListTile(
          key: const Key('readings-calendar-picker'),
          leading: const Icon(Icons.search),
          title: const Text('Знайсці літургічны дзень'),
          subtitle: const Text('Пошук паводле перыяду або свята'),
          onTap: widget.onFindDay,
        ),
    ],
  );
}

class _ReadingsStatus extends StatelessWidget {
  const _ReadingsStatus({
    required this.icon,
    required this.title,
    this.message,
    this.loading = false,
    this.actionLabel,
    this.onAction,
  });
  final PhosphorIconData? icon;
  final String title;
  final String? message;
  final bool loading;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => loading
      // First load only: a still outline of the text that is coming.
      ? const SizedBox(
          height: 360,
          child: DataLoadingNotice(
            label: 'Адкрываем чытанні',
            shape: LoadingShape.text,
          ),
        )
      : SizedBox(
          height: 360,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null)
                  PhosphorIcon(
                    icon!,
                    size: 52,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                const SizedBox(height: 14),
                Text(title, textAlign: TextAlign.center),
                if (message != null) ...[
                  const SizedBox(height: 7),
                  Text(
                    message!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (onAction != null && actionLabel != null) ...[
                  const SizedBox(height: 18),
                  FilledButton(onPressed: onAction, child: Text(actionLabel!)),
                ],
              ],
            ),
          ),
        );
}

// ---------------------------------------------------------------------------

class _ReadingBody extends ConsumerWidget {
  final ParsedReading reading;

  /// The structured Mass reading set to render (else the flat fields).
  final MassSetSelection? massSet;
  final Map<String, String> highlights;
  final String? selectedSentenceId;
  final ValueChanged<String> onSentenceTap;
  const _ReadingBody({
    super.key,
    required this.reading,
    this.massSet,
    required this.highlights,
    required this.selectedSentenceId,
    required this.onSentenceTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reader = ReaderTheme.of(context);
    if (massSet case final selection?) {
      return ReadingScaffold(
        builder: (context, textStyle) => _MassSetContent(
          selection: selection,
          textStyle: textStyle,
          reader: reader,
          highlights: highlights,
          selectedSentenceId: selectedSentenceId,
          onSentenceTap: onSentenceTap,
        ),
      );
    }
    final hasContent = readingHasVisibleContent(reading);

    return ReadingScaffold(
      builder: (context, textStyle) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!reading.hasReadings) ...[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PhosphorIcon(
                    PhosphorIconsRegular.info,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Успамін / апцыянальны памятны дзень. Чытанні звычайнага дня або commune sanctorum.',
                      style: TextStyle(
                        fontSize: (textStyle.fontSize ?? 16) * 0.875,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (!hasContent) ...[
            const SizedBox(height: 24),
            Center(
              child: Column(
                children: [
                  PhosphorIcon(
                    PhosphorIconsLight.bookOpen,
                    size: 48,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Тэкст гэтага чытання адсутнічае',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Паспрабуйце іншы варыянт дня.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (reading.firstReading != null)
            _ReadingSection(
              label: reading.hasTwoReadings ? 'ПЕРШАЕ ЧЫТАННЕ' : 'ЧЫТАННЕ',
              highlightNamespace: 'reading-1',
              section: reading.firstReading!,
              textStyle: textStyle,
              reader: reader,
              highlights: highlights,
              selectedSentenceId: selectedSentenceId,
              onSentenceTap: onSentenceTap,
            ),
          if (reading.psalm != null)
            _PsalmSection(
              psalm: reading.psalm!,
              textStyle: textStyle,
              reader: reader,
            ),
          if (reading.reading2 != null)
            _ReadingSection(
              label: 'ДРУГОЕ ЧЫТАННЕ',
              highlightNamespace: 'reading-2',
              section: reading.reading2!,
              textStyle: textStyle,
              reader: reader,
              highlights: highlights,
              selectedSentenceId: selectedSentenceId,
              onSentenceTap: onSentenceTap,
            ),
          if ((reading.sequence?.text ?? '').trim().isNotEmpty)
            _SequenceSection(
              text: reading.sequence!.text!,
              textStyle: textStyle,
              reader: reader,
            ),
          if (reading.alleluia != null)
            _AlleluiaSection(
              alleluia: reading.alleluia!,
              textStyle: textStyle,
              reader: reader,
            ),
          if (reading.gospel != null)
            _ReadingSection(
              label: 'ЕВАНГЕЛЛЕ',
              highlightNamespace: 'gospel',
              section: reading.gospel!,
              textStyle: textStyle,
              reader: reader,
              highlights: highlights,
              selectedSentenceId: selectedSentenceId,
              onSentenceTap: onSentenceTap,
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Structured Mass reading sets (mybrev ParsedReadingCard `_sections`).

ParsedSection _flatSection(MassReadingSection section) => ParsedSection(
  bible: section.bible,
  comment: section.comment,
  title: section.title,
  text: section.text,
  chorus: section.chorus,
  altChorus: section.altChorus,
  altChorusRef: section.altChorusRef,
  verses: section.verses,
  verse: section.verse,
  acclamation: section.acclamation,
  conclusion: section.conclusion,
  rubrics: section.rubrics,
  alternatives: [for (final item in section.alternatives) _flatSection(item)],
  form: section.form,
  year: section.year,
  passion: section.passion,
);

/// One set in source order: readings, psalms, acclamation, sequence,
/// Gospel (Passion by roles), rubrics; a reference-only set shows its
/// citations only.
class _MassSetContent extends StatelessWidget {
  const _MassSetContent({
    required this.selection,
    required this.textStyle,
    required this.reader,
    required this.highlights,
    required this.selectedSentenceId,
    required this.onSentenceTap,
  });

  final MassSetSelection selection;
  final TextStyle textStyle;
  final ReaderTheme reader;
  final Map<String, String> highlights;
  final String? selectedSentenceId;
  final ValueChanged<String> onSentenceTap;

  @override
  Widget build(BuildContext context) {
    final set = selection.set;
    final base = textStyle.fontSize ?? 16.0;
    final sections = selection.sections;
    return Column(
      key: ValueKey('mass-set-${set.id}-${selection.cycle}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          key: const Key('mass-set-meta'),
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            set.label,
            style: reader
                .serviceHeading(base)
                .copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        if (set.note != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              set.note!,
              key: const Key('mass-set-note'),
              style: reader.metadata(base, italic: true),
            ),
          ),
        if (!set.referenceOnly)
          for (final line in set.preface)
            _RubricText(line, textStyle: textStyle, reader: reader),
        if (set.referenceOnly)
          _ReferenceOnlyCitations(
            citations: set.citations(selection.cycle),
            textStyle: textStyle,
            reader: reader,
          )
        else ...[
          for (final (index, section) in sections.indexed)
            _section(section, '${set.id}-${section.cycle ?? ''}-$index'),
          for (final prayer in set.prayers)
            if ((prayer.text ?? '').isNotEmpty) ...[
              _SectionLabel(
                prayer.displayLabel.toUpperCase(),
                textStyle: textStyle,
                reader: reader,
              ),
              const SizedBox(height: 6),
              _ReadingText(text: prayer.text!, textStyle: textStyle),
            ],
          const SizedBox(height: 32),
        ],
      ],
    );
  }

  Widget _section(MassReadingSection section, String namespace) {
    final label = section.displayLabel;
    switch (section.kind) {
      case 'rubric':
        return _RubricText(
          section.text ?? '',
          textStyle: textStyle,
          reader: reader,
          block: true,
        );
      case 'psalm':
        return _PsalmSection(
          psalm: _flatSection(section),
          textStyle: textStyle,
          reader: reader,
          structured: true,
          label: label,
        );
      case 'acclamation':
        return _AlleluiaSection(
          alleluia: _flatSection(section),
          textStyle: textStyle,
          reader: reader,
          acclamation: section.acclamation,
        );
      case 'sequence':
        return _SequenceSection(
          text: section.text ?? '',
          textStyle: textStyle,
          reader: reader,
        );
      case 'reading':
      case 'gospel':
        return _ReadingSection(
          key: ValueKey('mass-section-$namespace'),
          label: label,
          highlightNamespace: namespace,
          section: _flatSection(section),
          textStyle: textStyle,
          reader: reader,
          highlights: highlights,
          selectedSentenceId: selectedSentenceId,
          onSentenceTap: onSentenceTap,
          gospel: section.kind == 'gospel',
          conclusion: section.conclusion,
          rubrics: section.rubrics,
          alternatives: [
            for (final alternative in section.alternatives)
              _flatSection(alternative),
          ],
          passion: section.passion,
        );
      default:
        final text = section.text ?? '';
        if (text.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: LiturgicalSpacing.sectionBefore),
          child: _ReadingText(text: text, textStyle: textStyle),
        );
    }
  }
}

/// A rubric in rubric style (red/accent, italic): the instructions of the
/// Easter Vigil, Palm Sunday, the legend of the Passion roles.
class _RubricText extends StatelessWidget {
  const _RubricText(
    this.text, {
    required this.textStyle,
    required this.reader,
    this.block = false,
  });

  final String text;
  final TextStyle textStyle;
  final ReaderTheme reader;

  /// A rubric section of its own (spaced as a section).
  final bool block;

  @override
  Widget build(BuildContext context) {
    final base = textStyle.fontSize ?? 16.0;
    final clean = text
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .trim();
    if (clean.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: block ? 18 : 10),
      child: Text(
        clean,
        key: const ValueKey('reading-rubric'),
        style: reader
            .rubricBlock(base, family: textStyle.fontFamily)
            .copyWith(fontStyle: FontStyle.italic),
      ),
    );
  }
}

/// «Або …»: an alternative reading of a section.
class _AlternativeReading extends StatelessWidget {
  const _AlternativeReading({
    super.key,
    required this.section,
    required this.textStyle,
    required this.reader,
    required this.cleanText,
  });

  final ParsedSection section;
  final TextStyle textStyle;
  final ReaderTheme reader;
  final String Function(String text, String? bible) cleanText;

  @override
  Widget build(BuildContext context) {
    final base = textStyle.fontSize ?? 16.0;
    final text = cleanText(section.text ?? '', section.bible).trim();
    final hasAcclamation = RegExp(
      r'Гэта\s+слова\s+(Пана|Бога|Божае)',
      caseSensitive: false,
    ).hasMatch(text);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'Або',
                  style: reader
                      .serviceHeading(base)
                      .copyWith(fontWeight: FontWeight.w800),
                ),
                if (section.bible != null)
                  TextSpan(
                    text: '  ${section.bible}',
                    style: reader.referenceStyle(
                      base,
                      family: textStyle.fontFamily,
                    ),
                  ),
                if (_formLabel(section.form) case final form?)
                  TextSpan(
                    text: '  ·  $form',
                    style: reader.metadata(base, italic: true),
                  ),
              ],
            ),
          ),
          if (section.comment != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                section.comment!,
                style: reader.metadata(base, italic: true),
              ),
            ),
          if (section.title != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 4),
              child: Text(
                section.title!,
                style: textStyle.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          if (text.isNotEmpty) ...[
            const SizedBox(height: 6),
            _ReadingText(text: text, textStyle: textStyle, isProse: true),
            if (!hasAcclamation) ...[
              const SizedBox(height: 12),
              Text(
                'Гэта слова Божае.',
                style: textStyle.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// «карацейшая форма» / «даўжэйшая форма» of a reading offered in two
/// lengths (`form` of the section).
String? _formLabel(String? form) => switch (form) {
  'short' => 'карацейшая форма',
  'long' => 'даўжэйшая форма',
  _ => null,
};

/// Sequence: a first-class section (Easter Sunday, Pentecost).
class _SequenceSection extends StatelessWidget {
  const _SequenceSection({
    required this.text,
    required this.textStyle,
    required this.reader,
  });

  final String text;
  final TextStyle textStyle;
  final ReaderTheme reader;

  @override
  Widget build(BuildContext context) {
    final strophes = text
        .split(RegExp(r'\n[ \t]*\n+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    return Column(
      key: const Key('reading-sequence'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('Секвенцыя', textStyle: textStyle, reader: reader),
        for (final strophe in strophes)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ReadingText(text: strophe, textStyle: textStyle),
          ),
      ],
    );
  }
}

/// The Passion read by roles, as the liturgical books print it: the role
/// marker in rubric colour before each part (Ев. evangelist, Е. Christ,
/// І. one person, Л. several persons), the words of Christ in bold, the
/// words of the crowd in italics; headings and rubrics of the source.
class _PassionView extends StatelessWidget {
  const _PassionView({
    required this.passion,
    required this.textStyle,
    required this.reader,
  });

  final PassionText passion;
  final TextStyle textStyle;
  final ReaderTheme reader;

  static TextStyle runStyle(TextStyle base, PassionRole? role) =>
      switch (role) {
        PassionRole.christ => base.copyWith(fontWeight: FontWeight.w700),
        PassionRole.crowd => base.copyWith(fontStyle: FontStyle.italic),
        _ => base,
      };

  @override
  Widget build(BuildContext context) {
    final base = textStyle.fontSize ?? 16.0;
    final body = textStyle.copyWith(height: ReaderTheme.bodyHeight);
    final marker = body.copyWith(
      color: reader.rubric,
      fontWeight: FontWeight.w800,
      fontStyle: FontStyle.normal,
    );
    return Column(
      key: const Key('passion-by-roles'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final block in passion.blocks)
          switch (block.type) {
            'heading' => Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 6),
              child: Text(
                block.text,
                style: reader
                    .serviceHeading(base, family: textStyle.fontFamily)
                    .copyWith(
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            'rubric' => _RubricText(
              block.text,
              textStyle: textStyle,
              reader: reader,
            ),
            _ => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text.rich(
                TextSpan(
                  children: [
                    for (final run in block.runs) ...[
                      if (run.role != null)
                        TextSpan(
                          text: '${run.role!.marker} ',
                          style: marker,
                          semanticsLabel: '${run.role!.label}: ',
                        ),
                      TextSpan(
                        text: '${run.text} ',
                        style: runStyle(body, run.role),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          },
      ],
    );
  }
}

/// A set without texts: its citations, and that the full text is not
/// loaded yet (the celebration is still shown, never hidden).
class _ReferenceOnlyCitations extends StatelessWidget {
  const _ReferenceOnlyCitations({
    required this.citations,
    required this.textStyle,
    required this.reader,
  });

  final List<MassReadingCitation> citations;
  final TextStyle textStyle;
  final ReaderTheme reader;

  @override
  Widget build(BuildContext context) {
    final base = textStyle.fontSize ?? 16.0;
    return Padding(
      key: const Key('reading-reference-only'),
      padding: const EdgeInsets.only(top: 18, bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Поўны тэкст чытанняў пакуль не загружаны. Цытаты:',
            style: reader.metadata(base, italic: true),
          ),
          const SizedBox(height: 10),
          for (final citation in citations)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    citation.label,
                    style: reader
                        .serviceHeading(base)
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      citation.bible,
                      for (final alternative in citation.alternatives)
                        'або $alternative',
                    ].join(' '),
                    style: textStyle.copyWith(height: ReaderTheme.bodyHeight),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  final String text;
  final TextStyle? textStyle;
  final ReaderTheme? reader;
  const _SectionLabel(this.text, {this.textStyle, this.reader});

  @override
  Widget build(BuildContext context) {
    final base = textStyle?.fontSize ?? 16.0;
    final rubric = reader ?? ReaderTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(
        top: LiturgicalSpacing.sectionBefore,
        bottom: LiturgicalSpacing.sectionTitleToBody,
      ),
      child: Text(_readingLabel(text).toUpperCase(), style: rubric.blockHeading(base)),
    );
  }
}

String _readingLabel(String text) => switch (text.toUpperCase()) {
  'ПЕРШАЕ ЧЫТАННЕ' => 'Першае чытанне',
  'ДРУГОЕ ЧЫТАННЕ' => 'Другое чытанне',
  'ЧЫТАННЕ' => 'Чытанне',
  'ЕВАНГЕЛЛЕ' => 'Евангелле',
  'РЭСПАНСАРЫЙНЫ ПСАЛЬМ' => 'Рэспансарыйны псальм',
  'СПЕЎ ПЕРАД ЕВАНГЕЛЛЕМ' => 'Спеў перад Евангеллем',
  _ => text,
};

class _BibleRef extends StatelessWidget {
  final String text;
  final TextStyle? textStyle;
  final ReaderTheme? reader;
  const _BibleRef(this.text, {this.textStyle, this.reader});

  @override
  Widget build(BuildContext context) {
    final base = textStyle?.fontSize ?? 16.0;
    final theme = reader ?? ReaderTheme.of(context);
    return Text(
      text,
      style: theme
          .referenceStyle(base, family: textStyle?.fontFamily)
          .copyWith(fontSize: theme.metadata(base).fontSize),
    );
  }
}

// ---------------------------------------------------------------------------

class _ReadingText extends ConsumerStatefulWidget {
  final String text;
  final TextStyle textStyle;
  final bool isPsalm;
  final bool isProse;
  final String? highlightNamespace;
  final Map<String, String> highlights;
  final String? selectedSentenceId;
  final ValueChanged<String>? onSentenceTap;

  const _ReadingText({
    required this.text,
    required this.textStyle,
    this.isPsalm = false,
    this.isProse = false,
    this.highlightNamespace,
    this.highlights = const {},
    this.selectedSentenceId,
    this.onSentenceTap,
  });

  @override
  ConsumerState<_ReadingText> createState() => _ReadingTextState();
}

class _ReadingTextState extends ConsumerState<_ReadingText> {
  final Map<String, TapGestureRecognizer> _recognizers = {};

  TapGestureRecognizer _recognizerFor(String sentenceId) =>
      _recognizers.putIfAbsent(
        sentenceId,
        () =>
            TapGestureRecognizer()
              ..onTap = () => widget.onSentenceTap?.call(sentenceId),
      );

  @override
  void dispose() {
    for (final recognizer in _recognizers.values) {
      recognizer.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final alignment = widget.isProse
        ? ref.watch(settingsProvider.select((s) => s.textAlignment))
        : TextAlign.left;
    if (RegExp(r'<[a-z][\s\S]*>', caseSensitive: false).hasMatch(widget.text)) {
      final reader = ReaderTheme.of(context);
      return Html(
        data: widget.isPsalm
            ? formatReadingPsalmHtml(widget.text)
            : formatLiturgicalHtml(widget.text),
        style: {
          ...liturgicalDocumentStyles(reader: reader, body: widget.textStyle),
          if (widget.isProse) ...{
            'body': liturgicalDocumentStyles(reader: reader, body: widget.textStyle)['body']!
              ..textAlign = alignment,
            'p': Style(
              textAlign: alignment,
              margin: Margins.only(bottom: LiturgicalSpacing.paragraphAfter),
            ),
          },
          '.psalm-strophe-even': Style(margin: Margins.only(bottom: 14)),
        },
      );
    }
    final reader = ReaderTheme.of(context);
    final namespace = widget.highlightNamespace;
    final plainText =
        (widget.isPsalm ? formatReadingPsalmText(widget.text) : widget.text)
            .replaceAll(RegExp(r'\r?\n[ \t]*\r?\n+'), '\n');
    final sentences = namespace == null
        ? <_SentencePart>[_SentencePart(plainText, 0)]
        : _splitReadingSentences(plainText);
    return Text.rich(
      TextSpan(
        children: [
          for (final sentence in sentences)
            TextSpan(
              style: _sentenceStyle(context, '$namespace:${sentence.index}'),
              children: [
                for (final piece in sentence.text.split(
                  RegExp(r'(?=[*†])|(?<=[*†])'),
                ))
                  TextSpan(
                    text: piece,
                    recognizer: namespace == null
                        ? null
                        : _recognizerFor('$namespace:${sentence.index}'),
                    style: piece == '*' || piece == '†'
                        ? widget.textStyle.copyWith(
                            height: ReaderTheme.bodyHeight,
                            color: reader.rubric,
                            fontWeight: FontWeight.w600,
                          )
                        : null,
                  ),
              ],
            ),
        ],
      ),
      textAlign: alignment,
    );
  }

  TextStyle _sentenceStyle(BuildContext context, String sentenceId) {
    final color = _highlightColors[widget.highlights[sentenceId]];
    final selected = widget.selectedSentenceId == sentenceId;
    final brightness = Theme.of(context).brightness;
    return widget.textStyle.copyWith(
      height: ReaderTheme.bodyHeight,
      backgroundColor: selected
          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.18)
          : color?.withValues(
              alpha: brightness == Brightness.dark ? 0.32 : 0.30,
            ),
      decoration: selected ? TextDecoration.underline : null,
      decorationColor: selected ? Theme.of(context).colorScheme.primary : null,
      decorationThickness: selected ? 1.5 : null,
    );
  }
}

class _SentencePart {
  const _SentencePart(this.text, this.index);
  final String text;
  final int index;
}

List<_SentencePart> _splitReadingSentences(String text) {
  if (text.isEmpty) return const [];
  final result = <_SentencePart>[];
  final boundary = RegExp(r'[.!?…]+[»”’\)\]]*\s+');
  var start = 0;
  var index = 0;
  for (final match in boundary.allMatches(text)) {
    final before = text.substring(start, match.end).trimRight();
    final lastWord = RegExp(r'([А-ЯЁІЎа-яёіўA-Za-z]+)\.$').firstMatch(before);
    final abbreviation = lastWord?.group(1)?.toLowerCase();
    if (abbreviation != null &&
        (abbreviation.length == 1 ||
            const {'св', 'ст', 'гл', 'пар', 'напр'}.contains(abbreviation))) {
      continue;
    }
    result.add(_SentencePart(text.substring(start, match.end), index++));
    start = match.end;
  }
  if (start < text.length) {
    result.add(_SentencePart(text.substring(start), index));
  }
  return result.isEmpty ? [_SentencePart(text, 0)] : result;
}

// ---------------------------------------------------------------------------

class _ReadingSection extends StatefulWidget {
  final String label;
  final String highlightNamespace;
  final ParsedSection section;
  final TextStyle textStyle;
  final ReaderTheme reader;
  final Map<String, String> highlights;
  final String? selectedSentenceId;
  final ValueChanged<String> onSentenceTap;

  /// Gospel (closing «Гэта слова Пана.»); by default from the label.
  final bool? gospel;

  /// Structured closing acclamation: null = the default one, '' = none.
  final String? conclusion;

  /// Rubrics after the text (e.g. «Не гаворыцца: Гэта слова Божае.»).
  final List<String> rubrics;

  /// «Або …» alternative readings.
  final List<ParsedSection> alternatives;

  /// Passion read by roles (instead of the plain text).
  final PassionText? passion;

  const _ReadingSection({
    super.key,
    required this.label,
    required this.highlightNamespace,
    required this.section,
    required this.textStyle,
    required this.reader,
    required this.highlights,
    required this.selectedSentenceId,
    required this.onSentenceTap,
    this.gospel,
    this.conclusion,
    this.rubrics = const [],
    this.alternatives = const [],
    this.passion,
  });

  @override
  State<_ReadingSection> createState() => _ReadingSectionState();
}

// Closing phrase pattern: "Гэта слова Пана/Бога" variants
final _closingPhraseRe = RegExp(
  r'(Гэта\s+слова\s+(Пана|Бога|Божае|Пана\s+Бога)[^.]*\.?)$',
  caseSensitive: false,
);

class _ReadingSectionState extends State<_ReadingSection> {
  // Strip leading bible reference duplicate from text
  String _cleanText(String text, String? bible) {
    if (bible == null || bible.isEmpty) return text;
    final trimmed = text.trimLeft();
    if (trimmed.startsWith(bible)) {
      return trimmed.substring(bible.length).trimLeft();
    }
    final withoutReference = trimmed.replaceFirst(
      RegExp(
        r'^[А-ЯЁІЎA-Z][а-яёіўa-z]{0,4}\.?\s+\d+[\d\s,.\-–()абвabcABC]*\s*',
      ),
      '',
    );
    if (withoutReference != trimmed) return withoutReference.trimLeft();
    return text;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.section;
    final rawText = s.text ?? '';
    final text = _cleanText(rawText, s.bible);
    final base = widget.textStyle.fontSize ?? 16.0;
    final isHtml = RegExp(
      r'<[a-z][\s\S]*>',
      caseSensitive: false,
    ).hasMatch(text);
    final visibleText = text.replaceAll(RegExp(r'<[^>]+>'), ' ');

    // Split off closing phrase if found
    String bodyText = text;
    String? closingPhrase;
    final match = isHtml ? null : _closingPhraseRe.firstMatch(text);
    if (match != null) {
      closingPhrase = match.group(0)!.trim();
      bodyText = text.substring(0, match.start).trimRight();
    }

    final display = bodyText;
    final isGospel = widget.gospel ?? widget.label == 'ЕВАНГЕЛЛЕ';
    // A flat (legacy) section carries its own conclusion / rubrics /
    // alternatives / Passion exactly like a section of a set.
    final passion = widget.passion ?? s.passion;
    final rubrics = widget.rubrics.isNotEmpty ? widget.rubrics : s.rubrics;
    final alternatives = widget.alternatives.isNotEmpty
        ? widget.alternatives
        : s.alternatives;
    final hasPassion = passion != null && passion.blocks.isNotEmpty;
    final structuredConclusion = widget.conclusion ?? s.conclusion;
    final hasAcclamation = RegExp(
      r'Гэта\s+слова\s+(Пана|Бога|Божае|Пана\s+Бога)',
      caseSensitive: false,
    ).hasMatch(visibleText);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(
          widget.label,
          textStyle: widget.textStyle,
          reader: widget.reader,
        ),
        if (s.bible != null)
          _BibleRef(
            s.bible!,
            textStyle: widget.textStyle,
            reader: widget.reader,
          ),
        if (_formLabel(s.form) case final form?)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              form,
              key: const ValueKey('reading-form'),
              style: widget.reader.metadata(base, italic: true),
            ),
          ),
        if (s.comment != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              s.comment!,
              style: widget.textStyle.copyWith(
                fontSize: widget.reader.psalmSubtitle(base).fontSize,
                color: widget.reader.muted,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        if (s.title != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 4),
            child: Text(
              s.title!,
              style: widget.textStyle.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        if (hasPassion) ...[
          const SizedBox(height: 6),
          _PassionView(
            passion: passion,
            textStyle: widget.textStyle,
            reader: widget.reader,
          ),
        ] else if (display.isNotEmpty) ...[
          const SizedBox(height: 6),
          _ReadingText(
            text: display,
            textStyle: widget.textStyle,
            isProse: true,
            highlightNamespace: widget.highlightNamespace,
            highlights: widget.highlights,
            selectedSentenceId: widget.selectedSentenceId,
            onSentenceTap: widget.onSentenceTap,
          ),
        ],
        for (final rubric in rubrics)
          _RubricText(
            rubric,
            textStyle: widget.textStyle,
            reader: widget.reader,
          ),
        // Closing phrase bold + separated
        if (closingPhrase != null) ...[
          const SizedBox(height: 8),
          Text(
            closingPhrase,
            style: widget.textStyle.copyWith(fontWeight: FontWeight.w700),
          ),
        ] else if (structuredConclusion != null) ...[
          if (structuredConclusion.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              structuredConclusion,
              key: const ValueKey('reading-conclusion'),
              style: widget.textStyle.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ] else if ((display.isNotEmpty || hasPassion) && !hasAcclamation) ...[
          const SizedBox(height: 12),
          Text(
            isGospel ? 'Гэта слова Пана.' : 'Гэта слова Божае.',
            style: widget.textStyle.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
        for (final (index, alternative) in alternatives.indexed)
          _AlternativeReading(
            key: ValueKey('reading-alternative-$index'),
            section: alternative,
            textStyle: widget.textStyle,
            reader: widget.reader,
            cleanText: _cleanText,
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

// Strip "Рэфрэн:" prefix from chorus string — UI adds its own label
String _cleanChorus(String s) {
  final t = s.trim();
  const prefix = 'рэфрэн:';
  if (t.toLowerCase().startsWith(prefix)) {
    return t.substring(prefix.length).trim();
  }
  return t;
}

class _PsalmSection extends StatelessWidget {
  final ParsedSection psalm;
  final TextStyle textStyle;
  final ReaderTheme reader;

  /// Structured set psalm: the alternative refrain follows the opening one
  /// and the last strophe closes with the refrain (as the web).
  final bool structured;
  final String label;
  const _PsalmSection({
    required this.psalm,
    required this.textStyle,
    required this.reader,
    this.structured = false,
    this.label = 'РЭСПАНСАРЫЙНЫ ПСАЛЬМ',
  });

  @override
  Widget build(BuildContext context) {
    final rawChorus = psalm.chorus ?? '';
    final chorus = rawChorus.isNotEmpty ? _cleanChorus(rawChorus) : '';
    final hasChorus = chorus.isNotEmpty;
    final hasVerses = psalm.verses.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(label, textStyle: textStyle, reader: reader),
        if (psalm.bible != null)
          _BibleRef(psalm.bible!, textStyle: textStyle, reader: reader),

        // No structured verses — fallback to raw text block
        if (!hasVerses) ...[
          if (hasChorus) ...[
            const SizedBox(height: 8),
            _ChorusBox(label: 'Рэфрэн', chorus: chorus, textStyle: textStyle),
          ] else if (psalm.altChorus?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            _ChorusBox(
              label: 'Або',
              chorus: psalm.altChorus!,
              textStyle: textStyle,
              alternate: true,
              reference: psalm.altChorusRef,
            ),
          ],
          if (psalm.text?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            _ReadingText(
              text: psalm.text!,
              textStyle: textStyle,
              isPsalm: true,
            ),
          ],
        ],

        // Structured verses: prominent opening refrain, lighter repeats between
        // strophes, then the final (or alternative) refrain.
        if (hasVerses) ...[
          if (hasChorus) ...[
            const SizedBox(height: 10),
            _ChorusBox(label: 'Рэфрэн', chorus: chorus, textStyle: textStyle),
          ],
          if (structured && psalm.altChorus?.isNotEmpty == true)
            _ChorusBox(
              label: 'Або',
              chorus: _cleanChorus(psalm.altChorus!),
              textStyle: textStyle,
              alternate: true,
              reference: psalm.altChorusRef,
            ),
          for (var i = 0; i < psalm.verses.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: _ReadingText(
                text: psalm.verses[i],
                textStyle: textStyle,
                isPsalm: true,
              ),
            ),
            if (hasChorus && i < psalm.verses.length - 1)
              _ChorusBox(
                label: 'Рэфрэн',
                chorus: chorus,
                textStyle: textStyle,
                compact: true,
              ),
          ],
          // After last verse: altChorus or chorus again
          if (hasChorus ||
              (!structured && psalm.altChorus?.isNotEmpty == true)) ...[
            const SizedBox(height: 8),
            if (!structured && psalm.altChorus?.isNotEmpty == true)
              _ChorusBox(
                label: 'Або',
                chorus: psalm.altChorus!,
                textStyle: textStyle,
                alternate: true,
                reference: psalm.altChorusRef,
              )
            else
              _ChorusBox(
                label: 'Рэфрэн',
                chorus: chorus,
                textStyle: textStyle,
                isFinal: true,
              ),
          ],
        ],
      ],
    );
  }
}

/// Quiet shared surface for spoken responses; verses retain the page surface.
class _ReadingResponseSurface extends StatelessWidget {
  const _ReadingResponseSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: ReaderTheme.of(context).rubricSoft,
      borderRadius: BorderRadius.circular(6),
    ),
    child: child,
  );
}

class _ChorusBox extends StatelessWidget {
  final String label;
  final String chorus;
  final TextStyle textStyle;
  final bool compact;
  final bool alternate;
  final bool isFinal;

  /// Citation printed with the refrain («Р.: 9а»).
  final String? reference;

  const _ChorusBox({
    required this.label,
    required this.chorus,
    required this.textStyle,
    this.compact = false,
    this.alternate = false,
    this.isFinal = false,
    this.reference,
  });

  @override
  Widget build(BuildContext context) {
    final reader = ReaderTheme.of(context);
    final accent = alternate ? reader.muted : reader.rubric;
    final base = textStyle.fontSize ?? 16;

    return Container(
      key: ValueKey(
        'psalm-refrain-${alternate
            ? 'alternate'
            : compact
            ? 'repeat'
            : isFinal
            ? 'final'
            : 'opening'}',
      ),
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(0, compact ? 5 : 2, 0, compact ? 9 : 13),
      child: _ReadingResponseSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              (reference ?? '').isEmpty ? label : '$label  $reference',
              style: textStyle.copyWith(
                fontSize: reader.metadata(base).fontSize,
                height: 1.2,
                color: accent,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: compact ? 3 : 5),
            SelectableText(
              chorus,
              style: textStyle.copyWith(
                fontSize: base,
                height: compact ? 1.48 : 1.5,
                color: reader.ink,
                fontWeight: compact ? FontWeight.w600 : FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _AlleluiaSection extends StatelessWidget {
  final ParsedSection alleluia;
  final TextStyle textStyle;
  final ReaderTheme reader;

  /// The acclamation of the source (Lent: «Хвала Табе, Валадар вякоў.»).
  final String? acclamation;
  const _AlleluiaSection({
    required this.alleluia,
    required this.textStyle,
    required this.reader,
    this.acclamation,
  });

  static const _defaultAcclamation = 'Аллелюя, аллелюя, аллелюя.';
  String get _acclamation => acclamation ?? _defaultAcclamation;

  Widget _acclamationLine(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: _ReadingResponseSurface(
        child: SelectableText.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Акламацыя: ',
                style: textStyle.copyWith(fontWeight: FontWeight.w600),
              ),
              TextSpan(text: _acclamation, style: textStyle),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final verse = (alleluia.verse ?? '').trim().isNotEmpty
        ? alleluia.verse!.trim()
        : (alleluia.text ?? '').trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(
          'СПЕЎ ПЕРАД ЕВАНГЕЛЛЕМ',
          textStyle: textStyle,
          reader: reader,
        ),
        if (alleluia.bible != null) ...[
          const SizedBox(height: 4),
          _BibleRef(alleluia.bible!, textStyle: textStyle, reader: reader),
        ],
        const SizedBox(height: 8),
        _acclamationLine(context),
        if (verse.isNotEmpty) ...[
          const SizedBox(height: 4),
          _ReadingText(text: verse, textStyle: textStyle),
        ],
        _acclamationLine(context),
      ],
    );
  }
}
