import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:mybrev_flutter/constants/liturgical.dart';
import 'package:mybrev_flutter/providers/calendar_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/theme/glass.dart';
import 'package:mybrev_flutter/utils/liturgical_calendar.dart' as lit_calendar;

class LiturgicalPickerScreen extends ConsumerStatefulWidget {
  const LiturgicalPickerScreen({super.key, this.mode = 'hours'});

  final String mode;

  bool get isReadingsMode => mode == 'readings';

  @override
  ConsumerState<LiturgicalPickerScreen> createState() =>
      _LiturgicalPickerScreenState();
}

class _LiturgicalPickerScreenState
    extends ConsumerState<LiturgicalPickerScreen> {
  late int _year;

  @override
  void initState() {
    super.initState();
    _year = ref.read(selectedDateProvider).year;
    _ensureCalendarYear();
  }

  Future<void> _ensureCalendarYear() async {
    final calendar = ref.read(calendarServiceProvider);
    await Future.wait([
      calendar.ensureYearOptions(_year),
      calendar.ensureYearOptions(_year + 1),
      calendar.ensureDynamicDates(_year),
    ]);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final seasonColor = ref.watch(liturgicalSeasonColorProvider);
    return DefaultTabController(
      length: 2,
      child: AmbientWash(
        seasonColor: seasonColor,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'ЛІТУРГІЧНЫ КАЛЯНДАР',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: seasonColor,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.3,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    widget.isReadingsMode ? 'Знайсці чытанні' : 'Знайсці дзень',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GlassSurface(
                    style: GlassStyle.soft,
                    borderRadius: BorderRadius.circular(20),
                    padding: const EdgeInsets.fromLTRB(14, 7, 8, 7),
                    child: Row(
                      children: [
                        PhosphorIcon(
                          widget.isReadingsMode
                              ? PhosphorIconsRegular.bookOpenText
                              : PhosphorIconsRegular.handsPraying,
                          color: seasonColor,
                          size: 20,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            widget.isReadingsMode
                                ? 'Рэжым чытанняў'
                                : 'Рэжым літургічных гадзін',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _year,
                            borderRadius: BorderRadius.circular(18),
                            items: [
                              for (var year = 2030; year >= 2019; year--)
                                DropdownMenuItem(
                                  value: year,
                                  child: Text('$year'),
                                ),
                            ],
                            onChanged: (year) {
                              if (year == null || year == _year) return;
                              setState(() => _year = year);
                              _ensureCalendarYear();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
              child: GlassSurface(
                style: GlassStyle.soft,
                borderRadius: BorderRadius.circular(22),
                child: const TabBar(
                  tabs: [
                    Tab(text: 'Перыяды'),
                    Tab(text: 'Святы'),
                  ],
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _PeriodPicker(
                    ref: ref,
                    year: _year,
                    readingsMode: widget.isReadingsMode,
                  ),
                  _FeastsPickerCombined(
                    year: _year,
                    readingsMode: widget.isReadingsMode,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Period picker ─────────────────────────────────────────────────────────────

class _PeriodPicker extends StatelessWidget {
  final WidgetRef ref;
  final int year;
  final bool readingsMode;
  const _PeriodPicker({
    required this.ref,
    required this.year,
    required this.readingsMode,
  });

  static const _maxWeeks = {
    'advent': 3,
    'christmas': 0,
    'lent': 5,
    'holyweek': 1,
    'easter': 7,
    'ordinary': 34,
  };

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: periodLabelMap.entries.map((entry) {
        final color = periodColors[entry.key] ?? Colors.green;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.2),
              child: PhosphorIcon(
                PhosphorIconsRegular.calendarBlank,
                color: color,
                size: 22,
              ),
            ),
            title: Text(entry.value),
            trailing: const PhosphorIcon(
              PhosphorIconsRegular.caretRight,
              size: 18,
            ),
            onTap: () => _showWeekDaySheet(context, entry.key, entry.value),
          ),
        );
      }).toList(),
    );
  }

  void _showWeekDaySheet(
    BuildContext context,
    String period,
    String periodLabel,
  ) {
    final maxWeeks = _maxWeeks[period] ?? 8;
    final startDay = period == 'holyweek' ? 2 : 1;
    final exactDates = _exactDates(period);

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => _WeekDaySheet(
        periodLabel: periodLabel,
        maxWeeks: maxWeeks,
        startDay: startDay,
        exactDates: exactDates,
        exactDatesFirst: period == 'lent',
        onExactDateSelected: (date) {
          Navigator.of(ctx).pop();
          if (readingsMode) {
            context.push('/readings/${_dateKey(date)}');
          } else {
            ref.read(selectedDateProvider.notifier).state = date;
            context.go('/');
          }
        },
        onSelected: (week, day) {
          Navigator.of(ctx).pop();
          if (readingsMode) {
            final calendar = ref.read(calendarServiceProvider);
            final date = lit_calendar.calculateDateForContext(
              year,
              period,
              week,
              day,
              calendar.getYearOptionsCached(year),
              calendar.getYearOptionsCached(year + 1),
            );
            if (date == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Дата для гэтага дня не знойдзена'),
                ),
              );
              return;
            }
            context.push('/readings/${_dateKey(date)}');
          } else {
            ref.read(selectedDateProvider.notifier).state = DateTime(year);
            context.push('/picker/options?period=$period&week=$week&day=$day');
          }
        },
      ),
    );
  }

  static String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  List<DateTime> _exactDates(String period) {
    if (period == 'advent') {
      return [for (var day = 17; day <= 24; day++) DateTime(year, 12, day)];
    }
    if (period == 'christmas') {
      final first = DateTime(year, 12, 25);
      final last = lit_calendar.calculateBaptismOfLordDate(year + 1);
      return [
        for (
          var date = first;
          !date.isAfter(last);
          date = date.add(const Duration(days: 1))
        )
          date,
      ];
    }
    if (period == 'lent') {
      final ash = ref
          .read(calendarServiceProvider)
          .getDynamicDatesCached(year)?['ashWednesday'];
      if (ash != null) {
        return [for (var day = 0; day < 4; day++) ash.add(Duration(days: day))];
      }
    }
    return const [];
  }
}

class _WeekDaySheet extends StatefulWidget {
  final String periodLabel;
  final int maxWeeks;
  final int startDay;
  final List<DateTime> exactDates;
  final bool exactDatesFirst;
  final void Function(int week, int day) onSelected;
  final ValueChanged<DateTime> onExactDateSelected;

  const _WeekDaySheet({
    required this.periodLabel,
    required this.maxWeeks,
    required this.startDay,
    required this.exactDates,
    required this.exactDatesFirst,
    required this.onSelected,
    required this.onExactDateSelected,
  });

  @override
  State<_WeekDaySheet> createState() => _WeekDaySheetState();
}

class _WeekDaySheetState extends State<_WeekDaySheet> {
  int _selectedWeek = 1;

  static const _dayLabels = {
    1: 'Нядз',
    2: 'Пнд',
    3: 'Аўт',
    4: 'Сер',
    5: 'Чцв',
    6: 'Пят',
    7: 'Суб',
  };

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.periodLabel,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          if (widget.exactDatesFirst) ...[
            _ExactDateChoices(
              dates: widget.exactDates,
              onSelected: widget.onExactDateSelected,
            ),
            if (widget.maxWeeks > 0) const Divider(height: 28),
          ],
          if (widget.maxWeeks > 0) ...[
            Text('Тыдзень', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: widget.maxWeeks,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final w = i + 1;
                  final selected = w == _selectedWeek;
                  return ChoiceChip(
                    label: Text('$w'),
                    selected: selected,
                    onSelected: (_) => setState(() => _selectedWeek = w),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            Text('Дзень', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(7 - widget.startDay + 1, (i) {
                final d = widget.startDay + i;
                return FilledButton.tonal(
                  onPressed: () => widget.onSelected(_selectedWeek, d),
                  child: Text(_dayLabels[d] ?? '$d'),
                );
              }),
            ),
          ],
          if (!widget.exactDatesFirst && widget.exactDates.isNotEmpty) ...[
            if (widget.maxWeeks > 0) const Divider(height: 28),
            _ExactDateChoices(
              dates: widget.exactDates,
              onSelected: widget.onExactDateSelected,
            ),
          ],
        ],
      ),
    );
  }
}

class _ExactDateChoices extends StatelessWidget {
  const _ExactDateChoices({required this.dates, required this.onSelected});

  final List<DateTime> dates;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    if (dates.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Каляндарная дата', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 150),
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: dates
                  .map(
                    (date) => OutlinedButton(
                      onPressed: () => onSelected(date),
                      child: Text(DateFormat('d MMM', 'be').format(date)),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Combined feasts picker (dynamic + fixed) ──────────────────────────────────

class _FeastsPickerCombined extends ConsumerStatefulWidget {
  const _FeastsPickerCombined({required this.year, required this.readingsMode});

  final int year;
  final bool readingsMode;

  @override
  ConsumerState<_FeastsPickerCombined> createState() =>
      _FeastsPickerCombinedState();
}

class _FeastsPickerCombinedState extends ConsumerState<_FeastsPickerCombined> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final calSvc = ref.read(calendarServiceProvider);
    final dynamicDates = calSvc.getDynamicDates(widget.year);

    // Build dynamic feasts list
    final dynamicFeasts = _feastLabels.entries.map((entry) {
      final display = dynamicDates?[entry.key];
      return _FeastItem(
        name: entry.value,
        dateLabel: display != null
            ? DateFormat('d MMMM yyyy', 'be').format(display)
            : null,
        date: display,
        isDynamic: true,
      );
    }).toList();

    // Build fixed feasts from Hive days
    final fixedFeasts = _loadFixedFeasts(widget.year);

    // Merge and filter
    final all = [...dynamicFeasts, ...fixedFeasts];
    final filtered = _query.isEmpty
        ? all
        : all.where((f) {
            final q = _query.toLowerCase();
            return f.name.toLowerCase().contains(q) ||
                (f.dateLabel ?? '').toLowerCase().contains(q);
          }).toList();

    // Keep the chosen calendar year in chronological order.
    filtered.sort((a, b) {
      if (a.date == null && b.date == null) return a.name.compareTo(b.name);
      if (a.date == null) return 1;
      if (b.date == null) return -1;
      return a.date!.compareTo(b.date!);
    });

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Пошук свята...',
              prefixIcon: const PhosphorIcon(
                PhosphorIconsRegular.magnifyingGlass,
                size: 20,
              ),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const PhosphorIcon(
                        PhosphorIconsRegular.x,
                        size: 20,
                      ),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      },
                    )
                  : null,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    'Нічога не знойдзена',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final feast = filtered[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: PhosphorIcon(
                          feast.isDynamic
                              ? PhosphorIconsRegular.sparkle
                              : PhosphorIconsRegular.calendarBlank,
                          size: 22,
                          color: feast.isDynamic
                              ? Theme.of(context).colorScheme.tertiary
                              : Theme.of(context).colorScheme.primary,
                        ),
                        title: Text(feast.name),
                        subtitle: feast.dateLabel != null
                            ? Text(feast.dateLabel!)
                            : null,
                        trailing: feast.date != null
                            ? const PhosphorIcon(
                                PhosphorIconsRegular.caretRight,
                                size: 18,
                              )
                            : PhosphorIcon(
                                PhosphorIconsRegular.lock,
                                size: 16,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        onTap: feast.date == null
                            ? () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Дата свята не знойдзена'),
                                  ),
                                );
                              }
                            : () {
                                final date = feast.date!;
                                if (widget.readingsMode) {
                                  context.go('/readings/${_dateKey(date)}');
                                } else {
                                  ref
                                          .read(selectedDateProvider.notifier)
                                          .state =
                                      date;
                                  context.go('/');
                                }
                              },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// Load fixed feasts from Hive days (those with _date field + _feastName).
  List<_FeastItem> _loadFixedFeasts(int year) {
    final box = HiveService.daysBox;
    final seen = <String>{};
    final result = <_FeastItem>[];

    for (final key in box.keys) {
      final raw = box.get(key);
      if (raw == null) continue;
      final data = Map<String, dynamic>.from(raw);
      final dateStr = data['_date'] as String?;
      final feastName = data['_feastName'] as String?;
      if (dateStr == null || feastName == null || feastName.isEmpty) continue;

      // Dedupe by feastName
      if (seen.contains(feastName)) continue;
      seen.add(feastName);

      // Parse "D.M" format
      final parts = dateStr.split('.');
      if (parts.length < 2) continue;
      final day = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      if (day == null || month == null) continue;

      final date = DateTime(year, month, day);

      result.add(
        _FeastItem(
          name: feastName,
          dateLabel: DateFormat('d MMMM', 'be').format(date),
          date: date,
          isDynamic: false,
        ),
      );
    }

    return result;
  }

  static String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static const _feastLabels = {
    'easterSunday': 'Вялікдзень',
    'pentecost': 'Спасланне Святога Духа',
    'ashWednesday': 'Попельная серада',
    'palmSunday': 'Нядзеля Пальмовая',
    'ascension': 'Узнясенне',
    'holyTrinity': 'Найсвяцейшая Тройца',
    'corpusChristi': 'Божае Цела',
    'sacredHeartOfJesus': 'Найсвяцейшае Сэрца Езуса',
    'immaculateHeartOfMary': 'Беззаганнае Сэрца Марыі',
    'christKing': 'Хрыстус Кароль',
    'christTheHighPriest': 'Хрыстус Вялікі Святар',
    'holyFamily': 'Святая Сям\'я',
    'baptismOfLord': 'Хрышчэнне Пана',
  };
}

class _FeastItem {
  final String name;
  final String? dateLabel;
  final DateTime? date;
  final bool isDynamic;

  const _FeastItem({
    required this.name,
    required this.dateLabel,
    required this.date,
    required this.isDynamic,
  });
}
