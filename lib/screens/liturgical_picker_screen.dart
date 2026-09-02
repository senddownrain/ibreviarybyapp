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

class LiturgicalPickerScreen extends ConsumerWidget {
  const LiturgicalPickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seasonColor = ref.watch(liturgicalSeasonColorProvider);
    return DefaultTabController(
      length: 2,
      child: AmbientWash(
        seasonColor: seasonColor,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
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
                  _PeriodPicker(ref: ref),
                  const _FeastsPickerCombined(),
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
  const _PeriodPicker({required this.ref});

  static const _maxWeeks = {
    'advent': 4,
    'christmas': 2,
    'lent': 6,
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
        onSelected: (week, day) {
          Navigator.of(ctx).pop();
          context.push('/picker/options?period=$period&week=$week&day=$day');
        },
      ),
    );
  }
}

class _WeekDaySheet extends StatefulWidget {
  final String periodLabel;
  final int maxWeeks;
  final int startDay;
  final void Function(int week, int day) onSelected;

  const _WeekDaySheet({
    required this.periodLabel,
    required this.maxWeeks,
    required this.startDay,
    required this.onSelected,
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
      ),
    );
  }
}

// ─── Combined feasts picker (dynamic + fixed) ──────────────────────────────────

class _FeastsPickerCombined extends ConsumerStatefulWidget {
  const _FeastsPickerCombined();

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
    final now = DateTime.now();
    final dynamicDates = calSvc.getDynamicDates(now.year);
    final nextDynamicDates = calSvc.getDynamicDates(now.year + 1);

    // Build dynamic feasts list
    final dynamicFeasts = _feastLabels.entries.map((entry) {
      DateTime? date = dynamicDates?[entry.key];
      DateTime? nextDate = nextDynamicDates?[entry.key];
      final display = _chooseDate(date, nextDate, now);
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
    final fixedFeasts = _loadFixedFeasts(now);

    // Merge and filter
    final all = [...dynamicFeasts, ...fixedFeasts];
    final filtered = _query.isEmpty
        ? all
        : all.where((f) {
            final q = _query.toLowerCase();
            return f.name.toLowerCase().contains(q) ||
                (f.dateLabel ?? '').toLowerCase().contains(q);
          }).toList();

    // Sort: upcoming first, then by date
    filtered.sort((a, b) {
      final today = DateTime(now.year, now.month, now.day);
      final aUpcoming =
          a.date != null &&
          !DateTime(a.date!.year, a.date!.month, a.date!.day).isBefore(today);
      final bUpcoming =
          b.date != null &&
          !DateTime(b.date!.year, b.date!.month, b.date!.day).isBefore(today);
      if (aUpcoming != bUpcoming) return aUpcoming ? -1 : 1;
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
                                ref.read(selectedDateProvider.notifier).state =
                                    feast.date!;
                                context.go('/');
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
  List<_FeastItem> _loadFixedFeasts(DateTime now) {
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

      // Choose year: this year if not passed, else next year
      DateTime date = DateTime(now.year, month, day);
      final today = DateTime(now.year, now.month, now.day);
      if (date.isBefore(today)) {
        date = DateTime(now.year + 1, month, day);
      }

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

  DateTime? _chooseDate(DateTime? thisYear, DateTime? nextYear, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    if (thisYear != null) {
      final d = DateTime(thisYear.year, thisYear.month, thisYear.day);
      if (!d.isBefore(today)) return thisYear;
    }
    if (nextYear != null) return nextYear;
    return thisYear;
  }

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
