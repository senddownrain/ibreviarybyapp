import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/models/parsed_reading.dart';
import 'package:mybrev_flutter/providers/calendar_provider.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/services/parsed_readings_service.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:mybrev_flutter/widgets/reading_scaffold.dart';

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
  List<String> _tabs = [];
  bool _isSundayMode = false;
  Map<String, ParsedReading?> _byYear = {};

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
        final opts = calendar.getYearOptions(date.year);
        final nextOpts = calendar.getYearOptions(date.year + 1);
        final dynamicDates = calendar.getDynamicDates(date.year);
        readings = await service.fetchForDate(date, opts, nextOpts, dynamicDates,
            forceRefresh: forceRefresh);
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

      _tabController?.dispose();
      TabController? tc;
      List<String> tabs = [];
      bool sundayMode = false;
      Map<String, ParsedReading?> byYear = {};

      // Show A/B/C tabs on Sundays only when data has year variants
      // and it's NOT a feast day (feasts have their own readings, no A/B/C split)
      final hasYearData = readings.any((r) => r.year != null);
      final isFeastDay = readings.any((r) => r.feast != null && r.feast!.isNotEmpty);
      if (isSunday && readings.isNotEmpty && hasYearData && !isFeastDay) {
        // Sunday: build year map and only show tabs for years with data
        for (final r in readings) {
          if (r.year != null) byYear[r.year!] = r;
        }
        // Only show tabs that actually have readings; preserve A→B→C order
        tabs = ['A', 'B', 'C'].where((y) => byYear.containsKey(y)).toList();
        if (tabs.length > 1) {
          sundayMode = true;
          tc = TabController(length: tabs.length, vsync: this);
          final idx = tabs.indexOf(currentCycle);
          if (idx >= 0) tc.index = idx;
        }
        // If only 1 year has data, sundayMode stays false → renders as single reading
      } else {
        // Weekday: tabs only when data has multiple year variants
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

      setState(() {
        _readings = readings;
        _tabs = tabs;
        _tabController = tc;
        _isSundayMode = sundayMode;
        _byYear = byYear;
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

    // Loading
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
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
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PhosphorIcon(PhosphorIconsLight.warning, size: 56, color: Colors.grey[400]),
                const SizedBox(height: 12),
                const Text('Не атрымалася загрузіць чытанні'),
                const SizedBox(height: 6),
                Text(
                  _error!,
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
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
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PhosphorIcon(PhosphorIconsLight.bookOpen, size: 56, color: Colors.grey[400]),
              const SizedBox(height: 12),
              const Text('Чытанні не знойдзены'),
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

    // Multiple year variants — tabs (always for Sunday, conditional for weekdays)
    if (_tabs.length > 1 && _tabController != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(title),
          actions: [
            _FontSizeButton(ref: ref),
          ],
          bottom: TabBar(
            controller: _tabController,
            tabs: _tabs.map((y) => Tab(text: 'Год $y')).toList(),
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: _tabs.map((y) {
            final reading = _isSundayMode
                ? _byYear[y]
                : _readings.firstWhere(
                    (r) => r.year == y,
                    orElse: () => _readings.first,
                  );
            if (reading == null) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PhosphorIcon(PhosphorIconsLight.bookOpen,
                        size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 12),
                    Text('Чытанні для году $y не знойдзены'),
                  ],
                ),
              );
            }
            return _ReadingBody(reading: reading, dateStr: widget.dateStr);
          }).toList(),
        ),
      );
    }

    // Single reading
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          _FontSizeButton(ref: ref),
        ],
      ),
      body: _ReadingBody(reading: _readings.first, dateStr: widget.dateStr),
    );
  }
}

// ---------------------------------------------------------------------------

class _ReadingBody extends ConsumerWidget {
  final ParsedReading reading;
  final String? dateStr;
  const _ReadingBody({required this.reading, this.dateStr});

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
    final fontSize = ref.watch(settingsProvider).fontSize;
    final textStyle = TextStyle(fontSize: fontSize, height: 1.6);
    final formattedDate = _formattedDate();

    return ReadingScaffold(
      builder: (context, scaffoldStyle) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date header
            if (formattedDate != null) ...[
              Center(
                child: Text(
                  formattedDate,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
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
                          fontSize: (fontSize) * 0.875,
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
                textStyle: textStyle.merge(scaffoldStyle),
              ),
            if (reading.psalm != null)
              _PsalmSection(
                psalm: reading.psalm!,
                textStyle: textStyle.merge(scaffoldStyle),
              ),
            if (reading.reading2 != null)
              _ReadingSection(
                label: 'ДРУГОЕ ЧЫТАННЕ',
                section: reading.reading2!,
                textStyle: textStyle.merge(scaffoldStyle),
              ),
            if (reading.alleluia != null)
              _AlleluiaSection(
                alleluia: reading.alleluia!,
                textStyle: textStyle.merge(scaffoldStyle),
              ),
            if (reading.gospel != null)
              _ReadingSection(
                label: 'ЕВАНГЕЛЛЕ',
                section: reading.gospel!,
                textStyle: textStyle.merge(scaffoldStyle),
              ),
            const SizedBox(height: 32),
          ],
        ),
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
  const _SectionLabel(this.text, {this.textStyle});

  @override
  Widget build(BuildContext context) {
    final base = textStyle?.fontSize ?? 16.0;
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: base * 1.1,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          fontFamily: textStyle?.fontFamily,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _BibleRef extends StatelessWidget {
  final String text;
  final TextStyle? textStyle;
  const _BibleRef(this.text, {this.textStyle});

  @override
  Widget build(BuildContext context) {
    final base = textStyle?.fontSize ?? 16.0;
    return Text(
      text,
      style: TextStyle(
        fontSize: base * 0.8,
        fontFamily: textStyle?.fontFamily,
        fontStyle: FontStyle.italic,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _ReadingSection extends StatefulWidget {
  final String label;
  final ParsedSection section;
  final TextStyle textStyle;
  const _ReadingSection(
      {required this.label,
      required this.section,
      required this.textStyle});

  @override
  State<_ReadingSection> createState() => _ReadingSectionState();
}

class _ReadingSectionState extends State<_ReadingSection> {
  bool _expanded = false;
  static const _threshold = 600;

  @override
  Widget build(BuildContext context) {
    final s = widget.section;
    final text = s.text ?? '';
    final truncated = text.length > _threshold && !_expanded;
    final display = truncated ? '${text.substring(0, _threshold)}…' : text;

    final base = widget.textStyle.fontSize ?? 16.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(widget.label, textStyle: widget.textStyle),
        if (s.bible != null) _BibleRef(s.bible!, textStyle: widget.textStyle),
        if (s.comment != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              s.comment!,
              style: widget.textStyle.copyWith(
                fontStyle: FontStyle.italic,
                fontSize: base * 0.875,
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
        if (text.isNotEmpty) ...[
          const SizedBox(height: 6),
          SelectableText(display, style: widget.textStyle),
          if (text.length > _threshold)
            TextButton(
              style: TextButton.styleFrom(
                textStyle: TextStyle(fontSize: base * 0.9),
              ),
              onPressed: () => setState(() => _expanded = !_expanded),
              child: Text(_expanded ? 'Згарнуць' : 'Паказаць поўны тэкст'),
            ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _PsalmSection extends StatelessWidget {
  final ParsedSection psalm;
  final TextStyle textStyle;
  const _PsalmSection({required this.psalm, required this.textStyle});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('РЭСПАНСАРЫЙНЫ ПСАЛЬМ', textStyle: textStyle),
        if (psalm.bible != null) _BibleRef(psalm.bible!, textStyle: textStyle),
        if (psalm.chorus?.isNotEmpty == true) ...[
          const SizedBox(height: 8),
          _ChorusBox(
            prefix: 'Рэфрэн: ',
            text: psalm.chorus!,
            altChorus: psalm.altChorus,
            color: colorScheme.primaryContainer,
            textStyle: textStyle,
          ),
        ],
        const SizedBox(height: 4),
        for (final verse in psalm.verses) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: SelectableText(verse, style: textStyle),
          ),
          Divider(height: 1, color: colorScheme.outlineVariant),
        ],
      ],
    );
  }
}

class _ChorusBox extends StatelessWidget {
  final String prefix;
  final String text;
  final String? altChorus;
  final Color color;
  final TextStyle textStyle;
  const _ChorusBox(
      {required this.prefix,
      required this.text,
      this.altChorus,
      required this.color,
      required this.textStyle});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SelectableText.rich(
        TextSpan(children: [
          TextSpan(
            text: prefix,
            style: textStyle.copyWith(fontWeight: FontWeight.w700),
          ),
          TextSpan(text: text, style: textStyle),
          if (altChorus?.isNotEmpty == true) ...[
            TextSpan(text: '\n'),
            TextSpan(
              text: 'Або: ',
              style: textStyle.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: (textStyle.fontSize ?? 16) * 0.85,
              ),
            ),
            TextSpan(
              text: altChorus!,
              style: textStyle.copyWith(
                fontSize: (textStyle.fontSize ?? 16) * 0.85,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _AlleluiaSection extends StatelessWidget {
  final ParsedSection alleluia;
  final TextStyle textStyle;
  const _AlleluiaSection({required this.alleluia, required this.textStyle});

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
        _SectionLabel('СПЕЎ ПЕРАД ЕВАНГЕЛЛЕМ', textStyle: textStyle),
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
