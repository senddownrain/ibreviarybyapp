import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:go_router/go_router.dart';
import 'package:mybrev_flutter/models/parsed_reading.dart';
import 'package:mybrev_flutter/models/day.dart';
import 'package:mybrev_flutter/constants/liturgical.dart';
import 'package:mybrev_flutter/providers/readings_loader_provider.dart';
import 'package:mybrev_flutter/providers/readings_navigation_provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:mybrev_flutter/widgets/navigation_drawer.dart';
import 'package:mybrev_flutter/widgets/reading_scaffold.dart';
import 'package:mybrev_flutter/widgets/text_scale_control.dart';
import 'package:mybrev_flutter/widgets/reader/reader_scaffold.dart';
import 'package:mybrev_flutter/widgets/reader/reader_navigation.dart';
import 'package:mybrev_flutter/widgets/ambient_date_picker.dart';
import 'package:mybrev_flutter/navigation/app_navigation.dart';
import 'package:mybrev_flutter/theme/reader.dart';
import 'package:mybrev_flutter/utils/reading_content.dart';
import 'package:mybrev_flutter/utils/reading_groups.dart';
import 'package:mybrev_flutter/utils/readings_selection.dart';
import 'package:mybrev_flutter/utils/liturgical_theme.dart';
import 'package:mybrev_flutter/utils/liturgical_html.dart';

class ReadingsScreen extends ConsumerStatefulWidget {
  /// Calendar date string, e.g. "2026-03-21" (date-based loading).
  final String? dateStr;

  /// Liturgical key, e.g. "ordinary/12/6" (period/week/dayOfWeek).
  /// When set, loads readings directly by liturgical period+week+day.
  final String? liturgicalKey;
  final String? dayId;

  const ReadingsScreen({
    super.key,
    this.dateStr,
    this.liturgicalKey,
    this.dayId,
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
  final ScrollController _scrollController = ScrollController();
  String? _manualCycle;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ReadingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dateStr != widget.dateStr ||
        oldWidget.liturgicalKey != widget.liturgicalKey ||
        oldWidget.dayId != widget.dayId) {
      _didRequestCompact = false;
      _manualCycle = null;
      _activeGroupKey = null;
      _automaticGroupKey = null;
      ReaderChromeModeScope.maybeControllerOf(context)?.value =
          ReaderChromeMode.full;
      _load();
      _resetDocumentScroll();
    }
  }

  Future<void> _load({bool forceRefresh = false}) async {
    if (!mounted) return;
    final generation = ++_loadGeneration;
    final requestedDateStr = widget.dateStr;
    final requestedLiturgicalKey = widget.liturgicalKey;
    final requestedDayId = widget.dayId;
    setState(() {
      _loading = true;
      _error = null;
    });
    // Yield to event loop so loading spinner renders before fetch
    await Future.delayed(const Duration(milliseconds: 32));
    if (!mounted || generation != _loadGeneration) return;

    try {
      final result = await ref.read(readingsLoaderProvider)(
        dateStr: requestedDateStr,
        liturgicalKey: requestedLiturgicalKey,
        dayId: requestedDayId,
        forceRefresh: forceRefresh,
      );
      final readings = result.readings;
      final sundayCycle = result.sundayCycle;
      final weekdayCycle = result.weekdayCycle;

      if (!mounted || generation != _loadGeneration) return;

      final selection = resolveDefaultReadings(
        readings: readings,
        sundayCycle: sundayCycle,
        weekdayCycle: weekdayCycle,
        dayId: requestedDayId,
        groupByCelebration: requestedDateStr != null,
      );

      setState(() {
        _readings = readings;
        _groups = selection.groups;
        _activeGroupKey = selection.activeGroupKey;
        _automaticGroupKey = selection.activeGroupKey;
        _sundayCycle = sundayCycle;
        _weekdayCycle = weekdayCycle;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
    setState(() {
      _activeGroupKey = key;
      final group = _groups.where((group) => group.key == key).firstOrNull;
      if (group != null &&
          _manualCycle != null &&
          !availableCyclesForGroup(group.documents).contains(_manualCycle)) {
        _manualCycle = null;
      }
    });
    _resetDocumentScroll();
  }

  void _selectAutomatic() {
    setState(() {
      _activeGroupKey = _automaticGroupKey;
      _manualCycle = null;
    });
    _resetDocumentScroll();
  }

  DefaultReadingsSelection get _selection => resolveDefaultReadings(
    readings: _readings,
    sundayCycle: _sundayCycle,
    weekdayCycle: _weekdayCycle,
    dayId: widget.dayId,
    groupKey: _activeGroupKey,
    manualCycle: _manualCycle,
    groupByCelebration: widget.dateStr != null,
  );

  void _resetDocumentScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
    });
  }

  void _selectManualCycle(String? cycle) {
    if (_manualCycle == cycle) return;
    setState(() => _manualCycle = cycle);
    _resetDocumentScroll();
  }

  Widget _menuLeading() {
    final navigation = AppNavigationScope.maybeOf(context);
    if (navigation?.shellState.canReturnToOra() ?? false) {
      return IconButton(
        tooltip: 'Вярнуцца да Ora',
        onPressed: navigation!.returnToOra,
        icon: const Icon(Icons.arrow_back_rounded),
      );
    }
    return IconButton(
      tooltip: 'Меню',
      icon: const PhosphorIcon(PhosphorIconsRegular.list, size: 22),
      onPressed: () => showSecondaryMenu(context),
    );
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

  static const _periodLabels = {
    'ordinary': 'Звычайны перыяд',
    'lent': 'Вялікі пост',
    'holyweek': 'Вялікі тыдзень',
    'easter': 'Велікодны перыяд',
    'advent': 'Адвэнт',
    'christmas': 'Перыяд Нараджэння',
  };

  static const _dayLabels = {
    1: 'Нядзеля',
    2: 'Панядзелак',
    3: 'Аўторак',
    4: 'Серада',
    5: 'Чацвер',
    6: 'Пятніца',
    7: 'Субота',
  };

  String _formatLiturgicalKey(String key) {
    final parts = key.split('/');
    if (parts.isEmpty) return key;
    final period = _periodLabels[parts[0]] ?? parts[0];
    if (parts.length < 2) return period;
    final week = parts[1];
    if (parts.length < 3) return '$period, тыд. $week';
    final day = int.tryParse(parts[2]);
    final dayLabel = day != null ? (_dayLabels[day] ?? parts[2]) : parts[2];
    return '$period, тыд. $week – $dayLabel';
  }

  bool _onScroll(ScrollNotification notification) {
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

  void _openDate(DateTime date) {
    final normalized = DateUtils.dateOnly(date);
    AppNavigationScope.maybeOf(context)?.shellState.clearOraReturn();
    ref.read(readingsBranchStateProvider.notifier).state = ref
        .read(readingsBranchStateProvider)
        .copyWith(date: normalized, clearLiturgicalKey: true, clearDayId: true);
    context.go(readingsRouteForContext(date: normalized));
  }

  Future<void> _showDateActions() async {
    final date = _currentDate;
    final action = await showModalBottomSheet<_ReadingsDateAction>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      builder: (context) => const _ReadingsDateSheet(),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _ReadingsDateAction.today:
        _openDate(DateTime.now());
        return;
      case _ReadingsDateAction.previous:
        final target = date.subtract(const Duration(days: 1));
        if (!target.isBefore(kCalendarFirstDate)) _openDate(target);
        return;
      case _ReadingsDateAction.next:
        final target = date.add(const Duration(days: 1));
        if (!target.isAfter(kCalendarLastDate)) _openDate(target);
        return;
      case _ReadingsDateAction.calendar:
        final picked = await showAmbientDatePicker(
          context: context,
          initialDate: date,
          seasonColor: _readingColor(),
        );
        if (mounted && picked != null) _openDate(picked);
        return;
      case _ReadingsDateAction.advanced:
        context.push('/readings/picker?mode=readings');
        return;
    }
  }

  bool get _hasOptions {
    final selection = _selection;
    return selection.groups.length > 1 ||
        availableCyclesForGroup(selection.documents).length > 1;
  }

  Future<void> _showOptions() async {
    final selection = _selection;
    final cycles = availableCyclesForGroup(selection.documents);
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      builder: (sheetContext) => _ReadingsOptionsSheet(
        groups: selection.groups,
        activeGroupKey: selection.activeGroupKey,
        automaticGroupKey: _automaticGroupKey,
        cycles: cycles,
        automaticCycle: selection.automaticCycle,
        manualCycle: _manualCycle,
        onAutomaticSelected: () {
          Navigator.pop(sheetContext);
          _selectAutomatic();
        },
        onGroupSelected: (key) {
          Navigator.pop(sheetContext);
          _selectCelebrationGroup(key);
        },
        onCycleSelected: (cycle) {
          Navigator.pop(sheetContext);
          _selectManualCycle(cycle);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final seasonColor = _readingColor();
    Widget document;
    String contextTitle = _title;
    if (_loading) {
      document = const _ReadingsStatus(
        icon: null,
        title: 'Загрузка чытанняў...',
        loading: true,
      );
    } else if (_error != null) {
      document = _ReadingsStatus(
        icon: PhosphorIconsLight.warning,
        title: 'Памылка загрузкі чытанняў',
        message: _error,
        actionLabel: 'Паўтарыць',
        onAction: _load,
      );
    } else if (_readings.isEmpty) {
      document = _ReadingsStatus(
        icon: PhosphorIconsLight.bookOpen,
        title: 'Чытанні для гэтага дня не знойдзены',
        message: 'Магчыма, тэкст яшчэ не загружаны на гэтую прыладу.',
        actionLabel: 'Абнавіць',
        onAction: () => _load(forceRefresh: true),
      );
    } else {
      final selection = _selection;
      final reading = selection.reading;
      contextTitle =
          selection.groups
              .where((group) => group.key == selection.activeGroupKey)
              .firstOrNull
              ?.label ??
          reading?.title ??
          _title;
      document = reading == null
          ? const _ReadingsStatus(
              icon: PhosphorIconsLight.bookOpen,
              title: 'Тэкст чытання не знойдзены',
            )
          : _ReadingBody(
              key: ValueKey(
                'reading-document-${reading.id}-${_manualCycle ?? 'auto'}',
              ),
              reading: reading,
              onRefresh: () => _load(forceRefresh: true),
            );
    }

    final manualGroup = _activeGroupKey != _automaticGroupKey;
    final manualLabel = switch ((manualGroup, _manualCycle)) {
      (false, null) => null,
      (true, null) => 'Набор чытанняў · зменены',
      (false, final cycle?) => 'Цыкл ${_cycleLabel(cycle)} · зменены',
      (true, final cycle?) => 'Набор і цыкл ${_cycleLabel(cycle)} · зменены',
    };
    final today = DateUtils.isSameDay(_currentDate, DateTime.now());
    final hasOraReturn =
        AppNavigationScope.maybeOf(context)?.shellState.canReturnToOra() ??
        false;
    return _trackScroll(
      ReaderScaffold(
        scrollController: _scrollController,
        scrollKey: const PageStorageKey('readings-root-scroll'),
        semanticLabel: 'Чытанні дня',
        seasonColor: seasonColor,
        chromeMode: ReaderChromeMode.full,
        leading: _menuLeading(),
        actions: const [TextScaleControl()],
        secondaryActions: [
          ReaderSecondaryAction(
            label: 'Рэжым чытання',
            icon: Icons.fullscreen_rounded,
            onSelected: () =>
                ReaderChromeModeScope.maybeControllerOf(context)?.value =
                    ReaderChromeMode.hidden,
          ),
        ],
        onBack: hasOraReturn
            ? AppNavigationScope.maybeOf(context)?.returnToOra
            : null,
        contextHeader: _ReadingsContextHeader(
          title: contextTitle,
          dateLabel: _formatReadingsDate(widget.dateStr, widget.liturgicalKey),
          seasonColor: seasonColor,
          manualCycleLabel: manualLabel,
          showToday: widget.dateStr != null && !today,
          showOptions: !_loading && _error == null && _hasOptions,
          onDateTap: _showDateActions,
          onToday: () => _openDate(DateTime.now()),
          onOptions: _showOptions,
        ),
        content: document,
      ),
    );
  }
}

enum _ReadingsDateAction { today, previous, next, calendar, advanced }

String _formatReadingsDate(String? dateStr, String? liturgicalKey) {
  if (liturgicalKey != null) return 'Літургічны кантэкст';
  final date = DateTime.tryParse(dateStr ?? '');
  if (date == null) return 'Дата не вызначана';
  const months = [
    '',
    'студзеня',
    'лютага',
    'сакавіка',
    'красавіка',
    'мая',
    'чэрвеня',
    'ліпеня',
    'жніўня',
    'верасня',
    'кастрычніка',
    'лістапада',
    'снежня',
  ];
  return '${date.day} ${months[date.month]} ${date.year}';
}

String _readingsCycleLabel(String cycle) => switch (cycle) {
  '1' => 'I',
  '2' => 'II',
  _ => cycle,
};

class _ReadingsContextHeader extends StatelessWidget {
  const _ReadingsContextHeader({
    required this.title,
    required this.dateLabel,
    required this.seasonColor,
    required this.showToday,
    required this.showOptions,
    required this.onDateTap,
    required this.onToday,
    required this.onOptions,
    this.manualCycleLabel,
  });

  final String title;
  final String dateLabel;
  final Color seasonColor;
  final String? manualCycleLabel;
  final bool showToday;
  final bool showOptions;
  final VoidCallback onDateTap;
  final VoidCallback onToday;
  final VoidCallback onOptions;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Чытанні', style: ReaderTheme.of(context).displayTitle(36)),
          const SizedBox(height: 10),
          Semantics(
            button: true,
            label: 'Змяніць дату: $dateLabel',
            child: InkWell(
              key: const Key('readings-date-action'),
              borderRadius: BorderRadius.circular(12),
              onTap: onDateTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 18,
                      color: seasonColor,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        dateLabel,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: seasonColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.keyboard_arrow_down_rounded, color: seasonColor),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
          if (manualCycleLabel != null) ...[
            const SizedBox(height: 7),
            Text(
              manualCycleLabel!,
              key: const Key('readings-manual-cycle-marker'),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (showToday || showOptions) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (showToday)
                  TextButton.icon(
                    key: const Key('readings-today-action'),
                    onPressed: onToday,
                    icon: const Icon(Icons.today_rounded, size: 18),
                    label: const Text('Сёння'),
                  ),
                if (showOptions)
                  OutlinedButton.icon(
                    key: const Key('readings-options-action'),
                    onPressed: onOptions,
                    icon: const Icon(Icons.tune_rounded, size: 18),
                    label: const Text('Варыянты'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ReadingsDateSheet extends StatelessWidget {
  const _ReadingsDateSheet();

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 620, maxHeight: 620),
    child: ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
      children: const [
        _ReadingsDateTile(
          Icons.today_rounded,
          'Сёння',
          _ReadingsDateAction.today,
        ),
        _ReadingsDateTile(
          Icons.arrow_back_rounded,
          'Папярэдні дзень',
          _ReadingsDateAction.previous,
        ),
        _ReadingsDateTile(
          Icons.arrow_forward_rounded,
          'Наступны дзень',
          _ReadingsDateAction.next,
        ),
        Divider(),
        _ReadingsDateTile(
          Icons.calendar_month_rounded,
          'Выбраць дату',
          _ReadingsDateAction.calendar,
        ),
        _ReadingsDateTile(
          Icons.search_rounded,
          'Знайсці літургічны дзень / свята',
          _ReadingsDateAction.advanced,
        ),
      ],
    ),
  );
}

class _ReadingsDateTile extends StatelessWidget {
  const _ReadingsDateTile(this.icon, this.label, this.action);
  final IconData icon;
  final String label;
  final _ReadingsDateAction action;

  @override
  Widget build(BuildContext context) => ListTile(
    minTileHeight: 52,
    leading: Icon(icon),
    title: Text(label),
    onTap: () => Navigator.pop(context, action),
  );
}

class _ReadingsOptionsSheet extends StatelessWidget {
  const _ReadingsOptionsSheet({
    required this.groups,
    required this.activeGroupKey,
    required this.automaticGroupKey,
    required this.cycles,
    required this.automaticCycle,
    required this.manualCycle,
    required this.onAutomaticSelected,
    required this.onGroupSelected,
    required this.onCycleSelected,
  });

  final List<ReadingCelebrationGroup> groups;
  final String? activeGroupKey;
  final String? automaticGroupKey;
  final List<String> cycles;
  final String automaticCycle;
  final String? manualCycle;
  final VoidCallback onAutomaticSelected;
  final ValueChanged<String> onGroupSelected;
  final ValueChanged<String?> onCycleSelected;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 620, maxHeight: 680),
    child: ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        Text(
          'Варыянты чытанняў',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (activeGroupKey != automaticGroupKey || manualCycle != null) ...[
          const SizedBox(height: 12),
          ListTile(
            key: const Key('readings-selection-auto'),
            selected: false,
            leading: const Icon(Icons.auto_awesome_rounded),
            title: const Text('Па календары'),
            subtitle: const Text('Вярнуць аўтаматычны набор і цыкл'),
            onTap: onAutomaticSelected,
          ),
        ],
        if (groups.length > 1) ...[
          const SizedBox(height: 18),
          const _OptionsHeading('Святкаванне / набор чытанняў'),
          for (final group in groups)
            ListTile(
              selected: group.key == activeGroupKey,
              title: Text(group.label),
              subtitle: Text(_groupCycles(group.documents)),
              trailing: group.key == activeGroupKey
                  ? const Icon(Icons.check_rounded)
                  : null,
              onTap: () => onGroupSelected(group.key),
            ),
        ],
        if (cycles.length > 1) ...[
          const SizedBox(height: 18),
          const _OptionsHeading('Цыкл'),
          ListTile(
            key: const Key('readings-cycle-auto'),
            selected: manualCycle == null,
            title: const Text('Па календары'),
            subtitle: Text('Цыкл ${_readingsCycleLabel(automaticCycle)}'),
            trailing: manualCycle == null
                ? const Icon(Icons.check_rounded)
                : null,
            onTap: () => onCycleSelected(null),
          ),
          for (final cycle in cycles)
            ListTile(
              key: ValueKey('readings-cycle-$cycle'),
              selected: cycle == manualCycle,
              title: Text('Цыкл ${_readingsCycleLabel(cycle)}'),
              trailing: cycle == manualCycle
                  ? const Icon(Icons.check_rounded)
                  : null,
              onTap: () => onCycleSelected(cycle),
            ),
        ],
      ],
    ),
  );

  static String _groupCycles(List<ParsedReading> documents) {
    final cycles = availableCyclesForGroup(documents);
    if (cycles.isEmpty) return 'Уласны набор чытанняў';
    return 'Цыклы ${cycles.map(_readingsCycleLabel).join(', ')}';
  }
}

class _OptionsHeading extends StatelessWidget {
  const _OptionsHeading(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    child: Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: 1.05,
      ),
    ),
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
  Widget build(BuildContext context) => SizedBox(
    height: 360,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading)
            const CircularProgressIndicator()
          else if (icon != null)
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
  final VoidCallback? onRefresh;
  const _ReadingBody({super.key, required this.reading, this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reader = ReaderTheme.of(context);
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
                    'Тэкст чытання пакуль не загружаны',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Паспрабуйце іншы варыянт дня або абнавіце дадзеныя.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                  if (onRefresh != null) ...[
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: onRefresh,
                      icon: const PhosphorIcon(
                        PhosphorIconsRegular.arrowsClockwise,
                        size: 18,
                      ),
                      label: const Text('Абнавіць'),
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (reading.firstReading != null)
            _ReadingSection(
              label: reading.hasTwoReadings ? 'ПЕРШАЕ ЧЫТАННЕ' : 'ЧЫТАННЕ',
              section: reading.firstReading!,
              textStyle: textStyle,
              reader: reader,
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
              section: reading.reading2!,
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
              section: reading.gospel!,
              textStyle: textStyle,
              reader: reader,
            ),
          const SizedBox(height: 32),
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
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(
        _readingLabel(text),
        style: TextStyle(
          fontSize: (base * 0.90).clamp(14, double.infinity),
          fontWeight: FontWeight.w600,
          fontFamily: textStyle?.fontFamily,
          color: rubric.rubric,
        ),
      ),
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
      style: (textStyle ?? theme.body(base)).copyWith(
        fontSize: (base * 0.88).clamp(14, double.infinity),
        color: theme.muted,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.02,
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _ReadingText extends StatelessWidget {
  final String text;
  final TextStyle textStyle;
  final bool isPsalm;
  final double leftInset;

  const _ReadingText({
    required this.text,
    required this.textStyle,
    this.isPsalm = false,
    this.leftInset = 0,
  });

  @override
  Widget build(BuildContext context) {
    if (RegExp(r'<[a-z][\s\S]*>', caseSensitive: false).hasMatch(text)) {
      final reader = ReaderTheme.of(context);
      final base = textStyle.fontSize ?? 16;
      return Padding(
        padding: EdgeInsets.only(left: leftInset),
        child: Html(
          data: isPsalm ? formatPsalmHtml(text) : formatLiturgicalHtml(text),
          style: {
            'body': Style(
              margin: Margins.zero,
              padding: HtmlPaddings.zero,
              color: textStyle.color ?? reader.ink,
              fontFamily: textStyle.fontFamily,
              fontSize: FontSize(base),
              fontWeight: textStyle.fontWeight,
              lineHeight: LineHeight(1.78),
              textAlign: TextAlign.left,
            ),
            'p': Style(margin: Margins.only(bottom: 14)),
            '.liturgical-subheading': Style(
              fontSize: FontSize((base * 0.88).clamp(14, double.infinity)),
              lineHeight: LineHeight(1.45),
              color: reader.muted,
              margin: Margins.only(bottom: 7),
            ),
            '.liturgical-heading': Style(
              fontSize: FontSize((base * 0.98).clamp(15, double.infinity)),
              lineHeight: LineHeight(1.3),
              color: reader.rubric,
              fontWeight: FontWeight.w700,
            ),
            '.psalm-strophe-even': Style(
              margin: Margins.only(left: 16, bottom: 14),
            ),
            '.psalm-marker': Style(
              color: reader.rubric,
              fontWeight: FontWeight.w600,
            ),
            '.liturgical-rubric-inline': Style(color: reader.rubric),
          },
        ),
      );
    }
    final reader = ReaderTheme.of(context);
    final pieces = text.split(RegExp(r'(?=[*†])|(?<=[*†])'));
    return Padding(
      padding: EdgeInsets.only(left: leftInset),
      child: SelectableText.rich(
        TextSpan(
          children: [
            for (final piece in pieces)
              TextSpan(
                text: piece,
                style: piece == '*' || piece == '†'
                    ? textStyle.copyWith(
                        height: 1.78,
                        color: reader.rubric,
                        fontWeight: FontWeight.w600,
                      )
                    : textStyle.copyWith(height: 1.78),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _ReadingSection extends StatefulWidget {
  final String label;
  final ParsedSection section;
  final TextStyle textStyle;
  final ReaderTheme reader;
  const _ReadingSection({
    required this.label,
    required this.section,
    required this.textStyle,
    required this.reader,
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
    final isGospel = widget.label == 'ЕВАНГЕЛЛЕ';
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
        if (s.comment != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              s.comment!,
              style: widget.textStyle.copyWith(
                fontSize: base * 0.875,
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
        if (display.isNotEmpty) ...[
          const SizedBox(height: 6),
          _ReadingText(text: display, textStyle: widget.textStyle),
        ],
        // Closing phrase bold + separated
        if (closingPhrase != null) ...[
          const SizedBox(height: 8),
          Text(
            closingPhrase,
            style: widget.textStyle.copyWith(fontWeight: FontWeight.w700),
          ),
        ] else if (display.isNotEmpty && !hasAcclamation) ...[
          const SizedBox(height: 12),
          Text(
            isGospel ? 'Гэта Слова Пана.' : 'Гэта Слова Божае.',
            style: widget.textStyle.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
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
  const _PsalmSection({
    required this.psalm,
    required this.textStyle,
    required this.reader,
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
        _SectionLabel(
          'РЭСПАНСАРЫЙНЫ ПСАЛЬМ',
          textStyle: textStyle,
          reader: reader,
        ),
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
          for (var i = 0; i < psalm.verses.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: _ReadingText(
                text: psalm.verses[i],
                textStyle: textStyle,
                isPsalm: true,
                leftInset: i.isOdd ? 16 : 0,
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
          if (hasChorus || psalm.altChorus?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            if (psalm.altChorus?.isNotEmpty == true)
              _ChorusBox(
                label: 'Або',
                chorus: psalm.altChorus!,
                textStyle: textStyle,
                alternate: true,
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

class _ChorusBox extends StatelessWidget {
  final String label;
  final String chorus;
  final TextStyle textStyle;
  final bool compact;
  final bool alternate;
  final bool isFinal;

  const _ChorusBox({
    required this.label,
    required this.chorus,
    required this.textStyle,
    this.compact = false,
    this.alternate = false,
    this.isFinal = false,
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
      padding: EdgeInsets.only(left: compact ? 12 : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: textStyle.copyWith(
              fontSize: (base * .88).clamp(14, double.infinity),
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
    );
  }
}

// ---------------------------------------------------------------------------

class _AlleluiaSection extends StatelessWidget {
  final ParsedSection alleluia;
  final TextStyle textStyle;
  final ReaderTheme reader;
  const _AlleluiaSection({
    required this.alleluia,
    required this.textStyle,
    required this.reader,
  });

  static const _acclamation = 'Аллелюя, аллелюя, аллелюя.';

  Widget _acclamationLine(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SelectableText.rich(
        TextSpan(
          children: [
            TextSpan(
              text: 'Акламацыя: ',
              style: textStyle.copyWith(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: _acclamation, style: textStyle),
          ],
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
