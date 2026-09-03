import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:mybrev_flutter/models/parsed_reading.dart';
import 'package:mybrev_flutter/models/day.dart';
import 'package:mybrev_flutter/providers/calendar_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/services/parsed_readings_service.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:mybrev_flutter/widgets/ios_app_bar.dart';
import 'package:mybrev_flutter/widgets/reading_scaffold.dart';
import 'package:mybrev_flutter/widgets/text_scale_control.dart';
import 'package:mybrev_flutter/theme/glass.dart';
import 'package:mybrev_flutter/theme/reader.dart';
import 'package:mybrev_flutter/utils/reading_content.dart';
import 'package:mybrev_flutter/utils/reading_groups.dart';
import 'package:mybrev_flutter/utils/liturgical_cycle.dart';
import 'package:mybrev_flutter/utils/liturgical_theme.dart';

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

class _ReadingsScreenState extends ConsumerState<ReadingsScreen>
    with TickerProviderStateMixin {
  TabController? _tabController;

  bool _loading = true;
  String? _error;
  List<ParsedReading> _readings = [];
  List<ReadingCelebrationGroup> _groups = [];
  String? _activeGroupKey;
  List<String> _tabs = [];
  bool _isSundayMode = false;
  Map<String, ParsedReading?> _byYear = {};
  String _sundayCycle = 'A';
  String _weekdayCycle = '1';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    // Yield to event loop so loading spinner renders before fetch
    await Future.delayed(const Duration(milliseconds: 32));
    if (!mounted) return;

    try {
      final service = ParsedReadingsService();
      final List<ParsedReading> readings;
      String sundayCycle = 'A';
      String weekdayCycle = '1';

      if (widget.liturgicalKey != null) {
        // Liturgical key mode: period/week/dayOfWeek
        final parts = widget.liturgicalKey!.split('/');
        final period = parts[0];
        final week = int.tryParse(parts.length > 1 ? parts[1] : '1') ?? 1;
        final day = int.tryParse(parts.length > 2 ? parts[2] : '1') ?? 1;
        readings = await service.fetchByLiturgicalKey(
          period,
          week,
          day,
          forceRefresh: forceRefresh,
        );
        // Use today's date for cycle detection
        final today = DateTime.now();
        sundayCycle = getCycleForDate(today, dayOfWeek: 1);
        weekdayCycle = getWeekdayCycleForDate(today);
      } else {
        final date = DateTime.tryParse(widget.dateStr!) ?? DateTime.now();
        final calendar = ref.read(calendarServiceProvider);
        await calendar.ensureYearOptions(date.year);
        await calendar.ensureYearOptions(date.year + 1);
        await calendar.ensureDynamicDates(date.year);
        final opts = calendar.getYearOptionsCached(date.year);
        final nextOpts = calendar.getYearOptionsCached(date.year + 1);
        final dynamicDates = calendar.getDynamicDatesCached(date.year);
        readings = await service.fetchForDate(
          date,
          opts,
          nextOpts,
          dynamicDates,
          forceRefresh: forceRefresh,
          includeAlternatives: true,
          dayId: widget.dayId,
        );
        sundayCycle = getCycleForDate(date, dayOfWeek: 1);
        weekdayCycle = getWeekdayCycleForDate(date);
      }

      if (!mounted) return;

      var groups = widget.dateStr != null
          ? groupReadings(readings)
          : <ReadingCelebrationGroup>[];
      final groupsWithContent = groups
          .where((g) => g.documents.any(readingHasVisibleContent))
          .toList();
      if (groupsWithContent.isNotEmpty) groups = groupsWithContent;
      final linkedGroup = widget.dayId == null
          ? null
          : groups.where((group) {
              return group.documents.any(
                (reading) =>
                    reading.dayId == widget.dayId ||
                    reading.dayIds.contains(widget.dayId),
              );
            }).firstOrNull;
      final activeKey =
          linkedGroup?.key ?? (groups.isNotEmpty ? groups.first.key : null);
      final activeDocs =
          linkedGroup?.documents ??
          (groups.isNotEmpty ? groups.first.documents : readings);

      _tabController?.dispose();
      final tabState = _buildTabState(
        activeDocs,
        sundayCycle: sundayCycle,
        weekdayCycle: weekdayCycle,
      );

      setState(() {
        _readings = readings;
        _groups = groups;
        _activeGroupKey = activeKey;
        _sundayCycle = sundayCycle;
        _weekdayCycle = weekdayCycle;
        _tabs = tabState.tabs;
        _tabController = tabState.controller;
        _isSundayMode = tabState.sundayMode;
        _byYear = tabState.byYear;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
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
    final group = _groups.firstWhere((g) => g.key == key);
    _tabController?.dispose();
    final tabState = _buildTabState(
      group.documents,
      sundayCycle: _sundayCycle,
      weekdayCycle: _weekdayCycle,
    );
    setState(() {
      _activeGroupKey = key;
      _tabs = tabState.tabs;
      _tabController = tabState.controller;
      _isSundayMode = tabState.sundayMode;
      _byYear = tabState.byYear;
    });
  }

  _TabState _buildTabState(
    List<ParsedReading> readings, {
    required String sundayCycle,
    required String weekdayCycle,
  }) {
    TabController? tc;
    List<String> tabs = [];
    bool sundayMode = false;
    Map<String, ParsedReading?> byYear = {};

    tabs = availableCyclesForGroup(readings);
    for (final reading in readings) {
      final cycle = normalizeReadingCycle(reading.year);
      if (cycle.isNotEmpty) byYear[cycle] = reading;
    }
    sundayMode = tabs.any(const {'A', 'B', 'C'}.contains);
    if (tabs.length > 1) {
      tc = TabController(length: tabs.length, vsync: this);
      final desired = sundayMode ? sundayCycle : weekdayCycle;
      final idx = tabs.indexOf(desired);
      if (idx >= 0) tc.index = idx;
    }

    return _TabState(
      tabs: tabs,
      controller: tc,
      sundayMode: sundayMode,
      byYear: byYear,
    );
  }

  Widget _celebrationPicker(BuildContext context) {
    if (_groups.length <= 1) return const SizedBox.shrink();
    final active = _groups.firstWhere(
      (g) => g.key == _activeGroupKey,
      orElse: () => _groups.first,
    );
    final reader = ReaderTheme.of(context);
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: GlassSurface(
        style: GlassStyle.soft,
        seasonColor: _readingColor(),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'НА ГЭТЫ ДЗЕНЬ',
              style: reader.referenceStyle(11).copyWith(letterSpacing: 1.1),
            ),
            const SizedBox(height: 8),
            for (final group in _groups)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _selectCelebrationGroup(group.key),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: group.key == active.key
                          ? reader.rubricSoft
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                group.label,
                                style: reader
                                    .body(15)
                                    .copyWith(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                _groupMeta(group),
                                style: reader.referenceStyle(12),
                              ),
                            ],
                          ),
                        ),
                        if (group.key == active.key)
                          PhosphorIcon(
                            PhosphorIconsFill.checkCircle,
                            size: 20,
                            color: reader.rubric,
                          )
                        else
                          PhosphorIcon(
                            PhosphorIconsRegular.caretRight,
                            size: 18,
                            color: cs.outline,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  ParsedReading? _readingForTab(String year) {
    final docs = _activeGroupDocuments();
    if (_isSundayMode) {
      final reading = _byYear[year];
      if (reading != null && readingHasVisibleContent(reading)) return reading;
    }
    final forYear = docs
        .where((r) => normalizeReadingCycle(r.year) == year)
        .toList();
    return pickReadingForCycle(forYear.isNotEmpty ? forYear : docs, year);
  }

  ParsedReading _displayReading() {
    final docs = _activeGroupDocuments();
    final cycles = availableCyclesForGroup(docs);
    final desired = cycles.any(const {'A', 'B', 'C'}.contains)
        ? _sundayCycle
        : _weekdayCycle;
    return pickReadingForCycle(docs, desired) ??
        docs.firstWhere(readingHasVisibleContent, orElse: () => docs.first);
  }

  String _cycleLabel(String cycle) => switch (cycle) {
    '1' => 'I',
    '2' => 'II',
    _ => cycle,
  };

  String _groupMeta(ReadingCelebrationGroup group) {
    final cycles = availableCyclesForGroup(group.documents);
    if (cycles.isNotEmpty) {
      return 'Цыклы ${cycles.map(_cycleLabel).join(', ')}';
    }
    final reading = group.documents.first;
    if ((reading.date ?? '').isNotEmpty) {
      return 'Уласныя чытанні святкавання';
    }
    if ((reading.feast ?? '').isNotEmpty) return 'Уласныя чытанні свята';
    return 'Чытанні літургічнага перыяду';
  }

  Widget _readingsBackdrop({required Widget child}) {
    final seasonColor = _readingColor();
    return Stack(
      children: [
        AmbientWash.hero(seasonColor: seasonColor),
        child,
      ],
    );
  }

  Color _readingColor() {
    final documents = _activeGroupDocuments();
    if (documents.isEmpty) {
      return ref.watch(liturgicalSeasonColorProvider);
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

  double get _contentTopInset =>
      MediaQuery.paddingOf(context).top + kToolbarHeight + 8;

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

  @override
  Widget build(BuildContext context) {
    final title = _title;
    final seasonColor = _readingColor();

    // Loading
    if (_loading) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: IosGlassAppBar.text(title),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Загрузка чытанняў...'),
            ],
          ),
        ),
      );
    }

    // Error
    if (_error != null) {
      final cs = Theme.of(context).colorScheme;
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: IosGlassAppBar.text(title),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PhosphorIcon(
                  PhosphorIconsLight.warning,
                  size: 56,
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(height: 12),
                Text(
                  'Памылка загрузкі чытанняў',
                  style: TextStyle(color: cs.onSurface),
                ),
                const SizedBox(height: 6),
                Text(
                  _error!,
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _load,
                  icon: const PhosphorIcon(
                    PhosphorIconsRegular.arrowsClockwise,
                    size: 18,
                  ),
                  label: const Text('Паўтарыць'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // No readings
    if (_readings.isEmpty) {
      final cs = Theme.of(context).colorScheme;
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: IosGlassAppBar.text(title),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PhosphorIcon(
                PhosphorIconsLight.bookOpen,
                size: 56,
                color: cs.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Text(
                'Чытанні для гэтага дня не знойдзены',
                style: TextStyle(color: cs.onSurface),
              ),
              const SizedBox(height: 6),
              Text(
                'Магчыма, яны яшчэ не дададзены ў базу даных',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _load(forceRefresh: true),
                icon: const PhosphorIcon(
                  PhosphorIconsRegular.arrowsClockwise,
                  size: 18,
                ),
                label: const Text('Абнавіць'),
              ),
            ],
          ),
        ),
      );
    }

    // Multiple year variants — tabs
    if (_tabs.length > 1 && _tabController != null) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: IosGlassAppBar(
          title: Text(title),
          actions: const [TextScaleControl()],
        ),
        body: _readingsBackdrop(
          child: Column(
            children: [
              SizedBox(height: _contentTopInset),
              _ReadingsPageHeading(
                dateStr: widget.dateStr,
                seasonColor: seasonColor,
              ),
              _celebrationPicker(context),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: GlassSurface(
                  style: GlassStyle.soft,
                  seasonColor: seasonColor,
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ЛІТУРГІЧНЫ ЦЫКЛ',
                        style: ReaderTheme.of(
                          context,
                        ).referenceStyle(11).copyWith(letterSpacing: 1.1),
                      ),
                      Text(
                        'Актуальны на гэту дату адкрыты аўтаматычна',
                        style: ReaderTheme.of(context).referenceStyle(12),
                      ),
                      TabBar(
                        controller: _tabController,
                        tabs: _tabs
                            .map((cycle) => Tab(text: _cycleLabel(cycle)))
                            .toList(),
                        labelColor: ReaderTheme.of(context).rubric,
                        unselectedLabelColor: Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant,
                        indicatorColor: ReaderTheme.of(context).rubric,
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: _tabs.map((y) {
                    final reading = _readingForTab(y);
                    if (reading == null) {
                      final cs = Theme.of(context).colorScheme;
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            PhosphorIcon(
                              PhosphorIconsLight.bookOpen,
                              size: 48,
                              color: cs.onSurfaceVariant,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Чытанні для году $y не знойдзены',
                              style: TextStyle(color: cs.onSurface),
                            ),
                          ],
                        ),
                      );
                    }
                    return _ReadingBody(
                      reading: reading,
                      dateStr: widget.dateStr,
                      seasonColor: seasonColor,
                      compactTop: true,
                      onRefresh: () => _load(forceRefresh: true),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Single reading
    final single = _displayReading();
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: IosGlassAppBar(
        title: Text(title),
        actions: const [TextScaleControl()],
      ),
      body: _readingsBackdrop(
        child: _ReadingBody(
          reading: single,
          dateStr: widget.dateStr,
          seasonColor: seasonColor,
          onRefresh: () => _load(forceRefresh: true),
          celebrationPicker: _groups.length > 1
              ? _celebrationPicker(context)
              : null,
        ),
      ),
    );
  }
}

class _TabState {
  final List<String> tabs;
  final TabController? controller;
  final bool sundayMode;
  final Map<String, ParsedReading?> byYear;

  const _TabState({
    required this.tabs,
    required this.controller,
    required this.sundayMode,
    required this.byYear,
  });
}

// ---------------------------------------------------------------------------

class _ReadingsPageHeading extends StatelessWidget {
  final String? dateStr;
  final Color seasonColor;

  const _ReadingsPageHeading({
    required this.dateStr,
    required this.seasonColor,
  });

  static const _weekdays = {
    1: 'нядзеля',
    2: 'панядзелак',
    3: 'аўторак',
    4: 'серада',
    5: 'чацвер',
    6: 'пятніца',
    7: 'субота',
  };
  static const _months = [
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

  String? get formattedDate {
    final date = DateTime.tryParse(dateStr ?? '');
    if (date == null) return null;
    final dayOfWeek = date.weekday == DateTime.sunday ? 1 : date.weekday + 1;
    final prefix = DateUtils.isSameDay(date, DateTime.now()) ? 'Сёння, ' : '';
    return '$prefix${_weekdays[dayOfWeek]}, '
        '${date.day} ${_months[date.month]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final reader = ReaderTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Чытанні', style: reader.displayTitle(36)),
          if (formattedDate case final date?) ...[
            const SizedBox(height: 9),
            Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: seasonColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    date,
                    style: reader
                        .referenceStyle(14)
                        .copyWith(
                          color: seasonColor,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _ReadingBody extends ConsumerWidget {
  final ParsedReading reading;
  final String? dateStr;
  final Color seasonColor;
  final bool compactTop;
  final Widget? celebrationPicker;
  final VoidCallback? onRefresh;
  const _ReadingBody({
    required this.reading,
    this.dateStr,
    required this.seasonColor,
    this.compactTop = false,
    this.celebrationPicker,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reader = ReaderTheme.of(context);
    final topPad = compactTop
        ? 12.0
        : MediaQuery.paddingOf(context).top + kToolbarHeight + 12;
    final hasContent = readingHasVisibleContent(reading);

    return ReadingScaffold(
      builder: (context, textStyle) => LayoutBuilder(
        builder: (context, constraints) => Stack(
          children: [
            AmbientWash.hero(seasonColor: seasonColor),
            SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, topPad, 16, 40),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!compactTop)
                      _ReadingsPageHeading(
                        dateStr: dateStr,
                        seasonColor: seasonColor,
                      ),
                    if (celebrationPicker != null) ...[
                      celebrationPicker!,
                      const SizedBox(height: 8),
                    ],
                    GlassSurface(
                      style: GlassStyle.card,
                      seasonColor: seasonColor,
                      borderRadius: BorderRadius.circular(28),
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if ((reading.title ?? '').trim().isNotEmpty) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.fromLTRB(0, 4, 0, 20),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: reader.border),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ЛІТУРГІЯ СЛОВА',
                                    style: reader
                                        .referenceStyle(11)
                                        .copyWith(letterSpacing: 1.2),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    reading.title!,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          fontFamily: textStyle.fontFamily,
                                          fontWeight: FontWeight.w700,
                                          height: 1.28,
                                        ),
                                  ),
                                  if ((reading.year ?? '').isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 9,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: reader.rubricSoft,
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        'Цыкл ${reading.year == '1'
                                            ? 'I'
                                            : reading.year == '2'
                                            ? 'II'
                                            : reading.year}',
                                        style: reader
                                            .referenceStyle(11)
                                            .copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                          if (!reading.hasReadings) ...[
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  PhosphorIcon(
                                    PhosphorIconsRegular.info,
                                    size: 18,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSecondaryContainer,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Успамін / апцыянальны памятны дзень. Чытанні звычайнага дня або commune sanctorum.',
                                      style: TextStyle(
                                        fontSize:
                                            (textStyle.fontSize ?? 16) * 0.875,
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
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Тэкст чытання пакуль не загружаны',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Паспрабуйце іншы варыянт дня або абнавіце дадзеныя.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
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
                              label: reading.hasTwoReadings
                                  ? 'ПЕРШАЕ ЧЫТАННЕ'
                                  : 'ЧЫТАННЕ',
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
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
        text.toUpperCase(),
        style: TextStyle(
          fontSize: base * 0.80,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
          fontFamily: textStyle?.fontFamily,
          color: rubric.rubric,
        ),
      ),
    );
  }
}

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
        fontSize: base * 0.85,
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

  const _ReadingText({required this.text, required this.textStyle});

  @override
  Widget build(BuildContext context) {
    if (RegExp(r'<[a-z][\s\S]*>', caseSensitive: false).hasMatch(text)) {
      return Html(
        data: text,
        style: {
          'body': Style(
            margin: Margins.zero,
            padding: HtmlPaddings.zero,
            color: textStyle.color ?? ReaderTheme.of(context).ink,
            fontFamily: textStyle.fontFamily,
            fontSize: FontSize(textStyle.fontSize ?? 16),
            fontWeight: textStyle.fontWeight,
            lineHeight: LineHeight(1.78),
            textAlign: TextAlign.left,
          ),
          'p': Style(margin: Margins.only(bottom: 14)),
        },
      );
    }
    return SelectableText(text, style: textStyle.copyWith(height: 1.78));
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

    // Split off closing phrase if found
    String bodyText = text;
    String? closingPhrase;
    final match = _closingPhraseRe.firstMatch(text);
    if (match != null) {
      closingPhrase = match.group(0)!.trim();
      bodyText = text.substring(0, match.start).trimRight();
    }

    final display = bodyText;
    final isGospel = widget.label == 'ЕВАНГЕЛЛЕ';
    final hasAcclamation = RegExp(
      r'Гэта\s+слова\s+(Пана|Бога|Божае|Пана\s+Бога)',
      caseSensitive: false,
    ).hasMatch(text);

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
    final cs = Theme.of(context).colorScheme;
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
            _ChorusBox(
              label: 'Рэфрэн',
              chorus: chorus,
              cs: cs,
              textStyle: textStyle,
            ),
          ],
          if (psalm.text?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            _ReadingText(text: psalm.text!, textStyle: textStyle),
          ],
        ],

        // Structured verses: chorus → verse → chorus → verse → … → chorus/altChorus
        if (hasVerses) ...[
          for (var i = 0; i < psalm.verses.length; i++) ...[
            // Chorus before each verse
            if (hasChorus) ...[
              const SizedBox(height: 8),
              _ChorusBox(
                label: 'Рэфрэн',
                chorus: chorus,
                cs: cs,
                textStyle: textStyle,
              ),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: _ReadingText(text: psalm.verses[i], textStyle: textStyle),
            ),
          ],
          // After last verse: altChorus or chorus again
          if (hasChorus) ...[
            const SizedBox(height: 8),
            if (psalm.altChorus?.isNotEmpty == true)
              _ChorusBox(
                label: 'Або',
                chorus: psalm.altChorus!,
                cs: cs,
                textStyle: textStyle,
              )
            else
              _ChorusBox(
                label: 'Рэфрэн',
                chorus: chorus,
                cs: cs,
                textStyle: textStyle,
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
  final ColorScheme cs;
  final TextStyle textStyle;

  const _ChorusBox({
    required this.label,
    required this.chorus,
    required this.cs,
    required this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.30),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(4),
          bottomRight: Radius.circular(4),
        ),
        border: Border(
          left: BorderSide(color: cs.primary.withValues(alpha: 0.45), width: 3),
        ),
      ),
      child: SelectableText.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: textStyle.copyWith(fontWeight: FontWeight.w700),
            ),
            TextSpan(
              text: chorus,
              style: textStyle.copyWith(fontWeight: FontWeight.w600),
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
        if (alleluia.verse != null) ...[
          const SizedBox(height: 4),
          _ReadingText(text: alleluia.verse!, textStyle: textStyle),
        ],
        _acclamationLine(context),
      ],
    );
  }
}
