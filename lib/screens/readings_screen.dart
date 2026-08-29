import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/models/parsed_reading.dart';
import 'package:mybrev_flutter/providers/calendar_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/services/parsed_readings_service.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:mybrev_flutter/widgets/ios_app_bar.dart';
import 'package:mybrev_flutter/widgets/reading_scaffold.dart';
import 'package:mybrev_flutter/theme/glass.dart';
import 'package:mybrev_flutter/theme/reader.dart';
import 'package:mybrev_flutter/utils/reading_groups.dart';

class ReadingsScreen extends ConsumerStatefulWidget {
  /// Calendar date string, e.g. "2026-03-21" (date-based loading).
  final String? dateStr;

  /// Liturgical key, e.g. "ordinary/12/6" (period/week/dayOfWeek).
  /// When set, loads readings directly by liturgical period+week+day.
  final String? liturgicalKey;

  const ReadingsScreen({super.key, this.dateStr, this.liturgicalKey})
      : assert(dateStr != null || liturgicalKey != null,
            'Either dateStr or liturgicalKey must be provided');

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
  int _dayOfWeek = 1;
  String _currentCycle = 'A';

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
      String currentCycle = 'A';

      if (widget.liturgicalKey != null) {
        // Liturgical key mode: period/week/dayOfWeek
        final parts = widget.liturgicalKey!.split('/');
        final period = parts[0];
        final week = int.tryParse(parts.length > 1 ? parts[1] : '1') ?? 1;
        final day = int.tryParse(parts.length > 2 ? parts[2] : '1') ?? 1;
        readings = await service.fetchByLiturgicalKey(period, week, day,
            forceRefresh: forceRefresh);
        // Use today's date for cycle detection
        final today = DateTime.now();
        final todayDow = today.weekday == 7 ? 1 : today.weekday + 1;
        currentCycle = ParsedReadingsService.currentCycle(today, dayOfWeek: todayDow);
      } else {
        final date = DateTime.tryParse(widget.dateStr!) ?? DateTime.now();
        final calendar = ref.read(calendarServiceProvider);
        await calendar.ensureYearOptions(date.year);
        await calendar.ensureYearOptions(date.year + 1);
        await calendar.ensureDynamicDates(date.year);
        final opts = calendar.getYearOptionsCached(date.year);
        final nextOpts = calendar.getYearOptionsCached(date.year + 1);
        final dynamicDates = calendar.getDynamicDatesCached(date.year);
        readings = await service.fetchForDate(date, opts, nextOpts, dynamicDates,
            forceRefresh: forceRefresh, includeAlternatives: true);
        final dayOfWeek = date.weekday == 7 ? 1 : date.weekday + 1;
        currentCycle = ParsedReadingsService.currentCycle(date, dayOfWeek: dayOfWeek);
      }

      if (!mounted) return;

      // Detect Sunday (dayOfWeek == 1)
      final int dow;
      if (widget.liturgicalKey != null) {
        final parts = widget.liturgicalKey!.split('/');
        dow = int.tryParse(parts.length > 2 ? parts[2] : '0') ?? 0;
      } else {
        final date = DateTime.tryParse(widget.dateStr!) ?? DateTime.now();
        dow = date.weekday == 7 ? 1 : date.weekday + 1;
      }
      final isSunday = dow == 1;
      final groups = widget.dateStr != null ? groupReadings(readings) : <ReadingCelebrationGroup>[];
      final activeKey = groups.isNotEmpty ? groups.first.key : null;
      final activeDocs = groups.isNotEmpty
          ? groups.first.documents
          : readings;

      _tabController?.dispose();
      final tabState = _buildTabState(
        activeDocs,
        dayOfWeek: dow,
        currentCycle: currentCycle,
        isSunday: isSunday,
      );

      setState(() {
        _readings = readings;
        _groups = groups;
        _activeGroupKey = activeKey;
        _dayOfWeek = dow;
        _currentCycle = currentCycle;
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
      dayOfWeek: _dayOfWeek,
      currentCycle: _currentCycle,
      isSunday: _dayOfWeek == 1,
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
    required int dayOfWeek,
    required String currentCycle,
    required bool isSunday,
  }) {
    TabController? tc;
    List<String> tabs = [];
    bool sundayMode = false;
    Map<String, ParsedReading?> byYear = {};

    final hasYearData = readings.any((r) => r.year != null);
    final isFeastDay =
        readings.any((r) => r.feast != null && r.feast!.isNotEmpty);

    if (isSunday && readings.isNotEmpty && hasYearData && !isFeastDay) {
      for (final r in readings) {
        if (r.year != null) byYear[r.year!] = r;
      }
      tabs = ['A', 'B', 'C'].where((y) => byYear.containsKey(y)).toList();
      if (tabs.length > 1) {
        sundayMode = true;
        tc = TabController(length: tabs.length, vsync: this);
        final idx = tabs.indexOf(currentCycle);
        if (idx >= 0) tc.index = idx;
      }
    } else {
      final hasYears = readings.any((r) => r.year != null);
      if (hasYears) {
        final seen = <String>{};
        tabs = readings
            .map((r) => r.year ?? '')
            .where((y) => y.isNotEmpty && seen.add(y))
            .toList();
      }
      if (tabs.length > 1) {
        tc = TabController(length: tabs.length, vsync: this);
        final idx = tabs.indexOf(currentCycle);
        if (idx >= 0) tc.index = idx;
      }
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
        seasonColor: ref.watch(liturgicalSeasonColorProvider),
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
                                style: reader.body(15).copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              Text(
                                '${group.documents.length} варыянт(аў)',
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
    if (_isSundayMode) return _byYear[year];
    return docs.firstWhere(
      (r) => r.year == year,
      orElse: () => docs.first,
    );
  }

  double get _contentTopInset =>
      MediaQuery.paddingOf(context).top + kToolbarHeight + 8;

  String _formatDate(String dateStr) {
    final date = DateTime.tryParse(dateStr);
    if (date == null) return dateStr;
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
      'снежня'
    ];
    return '${date.day} ${months[date.month]}';
  }

  /// Title for the AppBar — date or liturgical label.
  String get _title {
    if (widget.liturgicalKey != null) {
      return _formatLiturgicalKey(widget.liturgicalKey!);
    }
    return _formatDate(widget.dateStr ?? '');
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
    final seasonColor = ref.watch(liturgicalSeasonColorProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                PhosphorIcon(PhosphorIconsLight.warning,
                    size: 56, color: cs.onSurfaceVariant),
                const SizedBox(height: 12),
                Text('Не атрымалася загрузіць чытанні',
                    style: TextStyle(color: cs.onSurface)),
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
                  icon: const PhosphorIcon(PhosphorIconsRegular.arrowsClockwise, size: 18),
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
              PhosphorIcon(PhosphorIconsLight.bookOpen,
                  size: 56, color: cs.onSurfaceVariant),
              const SizedBox(height: 12),
              Text('Чытанні не знойдзены',
                  style: TextStyle(color: cs.onSurface)),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _load(forceRefresh: true),
                icon: const PhosphorIcon(PhosphorIconsRegular.arrowsClockwise, size: 18),
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
          actions: [_FontSizeButton(ref: ref)],
        ),
        body: Column(
          children: [
            SizedBox(height: _contentTopInset),
            _celebrationPicker(context),
            TabBar(
              controller: _tabController,
              tabs: _tabs.map((y) => Tab(text: y)).toList(),
              labelColor: ReaderTheme.of(context).rubric,
              unselectedLabelColor:
                  Theme.of(context).colorScheme.onSurfaceVariant,
              indicatorColor: ReaderTheme.of(context).rubric,
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
                          PhosphorIcon(PhosphorIconsLight.bookOpen,
                              size: 48, color: cs.onSurfaceVariant),
                          const SizedBox(height: 12),
                          Text('Чытанні для году $y не знойдзены',
                              style: TextStyle(color: cs.onSurface)),
                        ],
                      ),
                    );
                  }
                  return _ReadingBody(
                    reading: reading,
                    dateStr: widget.dateStr,
                    seasonColor: seasonColor,
                    isDark: isDark,
                    compactTop: true,
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      );
    }

    // Single reading
    final single = pickReadingForCycle(
          _activeGroupDocuments(),
          _currentCycle,
        ) ??
        _activeGroupDocuments().first;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: IosGlassAppBar(
        title: Text(title),
        actions: [_FontSizeButton(ref: ref)],
      ),
      body: _ReadingBody(
        reading: single,
        dateStr: widget.dateStr,
        seasonColor: seasonColor,
        isDark: isDark,
        celebrationPicker: _groups.length > 1
            ? _celebrationPicker(context)
            : null,
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

class _ReadingBody extends ConsumerWidget {
  final ParsedReading reading;
  final String? dateStr;
  final Color seasonColor;
  final bool isDark;
  final bool compactTop;
  final Widget? celebrationPicker;
  const _ReadingBody({
    required this.reading,
    this.dateStr,
    required this.seasonColor,
    required this.isDark,
    this.compactTop = false,
    this.celebrationPicker,
  });

  static const _weekdays = {
    1: 'Нядзеля',
    2: 'Панядзелак',
    3: 'Аўторак',
    4: 'Серада',
    5: 'Чацвер',
    6: 'Пятніца',
    7: 'Субота',
  };
  static const _months = [
    '', 'студзеня', 'лютага', 'сакавіка', 'красавіка', 'мая', 'чэрвеня',
    'ліпеня', 'жніўня', 'верасня', 'кастрычніка', 'лістапада', 'снежня',
  ];

  String? _formattedDate() {
    if (dateStr == null) return null;
    final d = DateTime.tryParse(dateStr!);
    if (d == null) return null;
    // Flutter weekday: Mon=1..Sun=7; our map: Sun=1..Sat=7
    final dow = d.weekday == 7 ? 1 : d.weekday + 1;
    final dayName = _weekdays[dow] ?? '';
    final month = _months[d.month];
    return '$dayName - ${d.day} $month ${d.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reader = ReaderTheme.of(context);
    final formattedDate = _formattedDate();
    final topPad = compactTop
        ? 12.0
        : MediaQuery.paddingOf(context).top + kToolbarHeight + 12;

    return ReadingScaffold(
      builder: (context, textStyle) => Stack(
        children: [
          SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, topPad, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (celebrationPicker != null) ...[
              celebrationPicker!,
              const SizedBox(height: 8),
            ],
            // Date header
            if (formattedDate != null) ...[
              Center(
                child: Text(
                  formattedDate,
                  style: reader.referenceStyle(13),
                ),
              ),
              const SizedBox(height: 8),
            ],
            // Commune sanctorum notice
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
                    PhosphorIcon(PhosphorIconsRegular.info,
                        size: 18,
                        color: Theme.of(context).colorScheme.onSecondaryContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Успамін / апцыянальны памятны дзень. Чытанні звычайнага дня або commune sanctorum.',
                        style: TextStyle(
                          fontSize: (textStyle.fontSize ?? 16) * 0.875,
                          color: Theme.of(context).colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (reading.feast != null) _FeastChip(feast: reading.feast!),
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
          ),
          AmbientWash(
            seasonColor: seasonColor,
            height: kToolbarHeight + 120,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _FontSizeButton extends StatelessWidget {
  final WidgetRef ref;
  const _FontSizeButton({required this.ref});

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    return PopupMenuButton<double>(
      icon: const PhosphorIcon(PhosphorIconsRegular.textAa, size: 22),
      tooltip: 'Памер шрыфту',
      onSelected: (size) => ref.read(settingsProvider.notifier).setFontSize(size),
      itemBuilder: (_) => [
        for (final size in [14.0, 16.0, 18.0, 20.0, 24.0])
          PopupMenuItem(
            value: size,
            child: Text(
              '${size.toInt()} pt',
              style: TextStyle(
                fontSize: 14,
                fontWeight: size == settings.fontSize
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          ),
      ],
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
      style: theme.referenceStyle(base * 0.85, family: textStyle?.fontFamily),
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
  bool _expanded = false;
  static const _threshold = 600;

  // Strip leading bible reference duplicate from text
  String _cleanText(String text, String? bible) {
    if (bible == null || bible.isEmpty) return text;
    final trimmed = text.trimLeft();
    if (trimmed.startsWith(bible)) {
      return trimmed.substring(bible.length).trimLeft();
    }
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

    final truncated = bodyText.length > _threshold && !_expanded;
    final display = truncated ? '${bodyText.substring(0, _threshold)}…' : bodyText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(widget.label,
            textStyle: widget.textStyle, reader: widget.reader),
        if (s.bible != null)
          _BibleRef(s.bible!, textStyle: widget.textStyle, reader: widget.reader),
        if (s.comment != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              s.comment!,
              style: widget.reader.rubricStyle(
                base * 0.875,
                family: widget.textStyle.fontFamily,
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
          SelectableText(display, style: widget.textStyle),
          if (bodyText.length > _threshold)
            TextButton(
              style: TextButton.styleFrom(
                textStyle: TextStyle(fontSize: base * 0.9),
              ),
              onPressed: () => setState(() => _expanded = !_expanded),
              child: Text(_expanded ? 'Згарнуць' : 'Паказаць поўны тэкст'),
            ),
        ],
        // Closing phrase bold + separated
        if (closingPhrase != null) ...[
          const SizedBox(height: 8),
          Text(
            closingPhrase,
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
  if (t.toLowerCase().startsWith(prefix)) return t.substring(prefix.length).trim();
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
        _SectionLabel('РЭСПАНСАРЫЙНЫ ПСАЛЬМ',
            textStyle: textStyle, reader: reader),
        if (psalm.bible != null)
          _BibleRef(psalm.bible!, textStyle: textStyle, reader: reader),

        // No structured verses — fallback to raw text block
        if (!hasVerses) ...[
          if (hasChorus) ...[
            const SizedBox(height: 8),
            _ChorusBox(label: 'Рэфрэн', chorus: chorus, cs: cs, textStyle: textStyle),
          ],
          if (psalm.text?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            SelectableText(psalm.text!, style: textStyle),
          ],
        ],

        // Structured verses: chorus → verse → chorus → verse → … → chorus/altChorus
        if (hasVerses) ...[
          for (var i = 0; i < psalm.verses.length; i++) ...[
            // Chorus before each verse
            if (hasChorus) ...[
              const SizedBox(height: 8),
              _ChorusBox(label: 'Рэфрэн', chorus: chorus, cs: cs, textStyle: textStyle),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: SelectableText(psalm.verses[i], style: textStyle),
            ),
            if (i < psalm.verses.length - 1)
              Divider(height: 1, color: cs.outlineVariant),
          ],
          // After last verse: altChorus or chorus again
          if (hasChorus) ...[
            Divider(height: 1, color: cs.outlineVariant),
            const SizedBox(height: 8),
            if (psalm.altChorus?.isNotEmpty == true)
              _ChorusBox(
                label: 'Або',
                chorus: psalm.altChorus!,
                cs: cs,
                textStyle: textStyle,
              )
            else
              _ChorusBox(label: 'Рэфрэн', chorus: chorus, cs: cs, textStyle: textStyle),
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
        TextSpan(children: [
          TextSpan(
            text: '$label: ',
            style: textStyle.copyWith(fontWeight: FontWeight.w700),
          ),
          TextSpan(text: chorus, style: textStyle.copyWith(fontWeight: FontWeight.w600)),
        ]),
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

  static const _acclamation = 'Алілуя, алілуя, алілуя.';

  Widget _acclamationLine(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SelectableText.rich(
        TextSpan(children: [
          TextSpan(
            text: 'Акламацыя: ',
            style: textStyle.copyWith(fontWeight: FontWeight.bold),
          ),
          TextSpan(text: _acclamation, style: textStyle),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('СПЕЎ ПЕРАД ЕВАНГЕЛЛЕМ',
            textStyle: textStyle, reader: reader),
        _acclamationLine(context),
        if (alleluia.bible != null) ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              alleluia.bible!,
              style: textStyle.copyWith(
                fontStyle: FontStyle.italic,
                fontSize: (textStyle.fontSize ?? 16) * 0.85,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
        if (alleluia.verse != null) ...[
          const SizedBox(height: 4),
          SelectableText(alleluia.verse!, style: textStyle),
        ],
        _acclamationLine(context),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _FeastChip extends StatelessWidget {
  final String feast;
  const _FeastChip({required this.feast});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Chip(
        label: Text(feast, style: const TextStyle(fontSize: 12)),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
