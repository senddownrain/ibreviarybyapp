import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:mybrev_flutter/constants/liturgical.dart';
import 'package:mybrev_flutter/ordo/dates.dart';
import 'package:mybrev_flutter/ordo/day_union.dart';
import 'package:mybrev_flutter/ordo/runtime.dart';
import 'package:mybrev_flutter/providers/cache_epoch_provider.dart';
import 'package:mybrev_flutter/providers/diocese_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/theme/glass.dart';
import 'package:mybrev_flutter/utils/liturgical_visual.dart';
import 'package:mybrev_flutter/widgets/ordo/vestment_marker.dart';

const _weekdays = ['Пн', 'Аў', 'Ср', 'Чц', 'Пт', 'Сб', 'Нд'];

/// Shared offline ORDO calendar. Only the caller decides what selecting a date does.
class LiturgicalMonthCalendar extends ConsumerStatefulWidget {
  const LiturgicalMonthCalendar({
    super.key,
    required this.initialDate,
    required this.onSelected,
    this.seasonColor,
    this.diocese,
  });
  final DateTime initialDate;
  final ValueChanged<DateTime> onSelected;
  final Color? seasonColor;
  final String? diocese;
  @override
  ConsumerState<LiturgicalMonthCalendar> createState() => _CalendarState();
}

class _CalendarState extends ConsumerState<LiturgicalMonthCalendar> {
  late DateTime _month = DateTime(
    widget.initialDate.year,
    widget.initialDate.month,
  );
  void _move(int delta) =>
      setState(() => _month = DateTime(_month.year, _month.month + delta));

  Future<void> _jumpToMonth() async {
    final month = await showDialog<DateTime>(
      context: context,
      builder: (_) => _MonthJumpDialog(month: _month),
    );
    if (mounted && month != null) setState(() => _month = month);
  }

  @override
  void didUpdateWidget(covariant LiturgicalMonthCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!DateUtils.isSameDay(oldWidget.initialDate, widget.initialDate)) {
      _month = DateTime(widget.initialDate.year, widget.initialDate.month);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = ref.watch(liturgicalContentReadyProvider);
    final accent = widget.seasonColor ?? Theme.of(context).colorScheme.primary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MonthHeader(
          month: _month,
          onJump: _jumpToMonth,
          onPrevious:
              _month.isAfter(
                DateTime(kCalendarFirstDate.year, kCalendarFirstDate.month),
              )
              ? () => _move(-1)
              : null,
          onNext:
              _month.isBefore(
                DateTime(kCalendarLastDate.year, kCalendarLastDate.month),
              )
              ? () => _move(1)
              : null,
        ),
        const SizedBox(height: 8),
        if (ready.hasError)
          const Text('Не ўдалося адкрыць каляндар')
        else if (!ready.hasValue)
          const Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator.adaptive(),
          )
        else
          _MonthGrid(
            month: _month,
            selected: isoOf(widget.initialDate),
            today: isoOf(DateTime.now()),
            accent: accent,
            diocese: widget.diocese,
            onSelect: (iso) => widget.onSelected(dateOfIso(iso)),
          ),
      ],
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.month,
    required this.onPrevious,
    required this.onNext,
    required this.onJump,
  });

  final DateTime month;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onJump;

  @override
  Widget build(BuildContext context) {
    final label = DateFormat('LLLL y', 'be').format(month);
    return Row(
      children: [
        IconButton(
          key: const Key('ordo-previous-month'),
          tooltip: 'Папярэдні месяц',
          onPressed: onPrevious,
          icon: const PhosphorIcon(PhosphorIconsRegular.caretLeft),
        ),
        Expanded(
          child: TextButton(
            key: const Key('ordo-jump-month'),
            onPressed: onJump,
            child: Text(
              '${label[0].toUpperCase()}${label.substring(1)}',
              key: const Key('ordo-month-label'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        IconButton(
          key: const Key('ordo-next-month'),
          tooltip: 'Наступны месяц',
          onPressed: onNext,
          icon: const PhosphorIcon(PhosphorIconsRegular.caretRight),
        ),
      ],
    );
  }
}

/// Browsing a month never commits a daily selection.
class _MonthJumpDialog extends StatefulWidget {
  const _MonthJumpDialog({required this.month});
  final DateTime month;

  @override
  State<_MonthJumpDialog> createState() => _MonthJumpDialogState();
}

class _MonthJumpDialogState extends State<_MonthJumpDialog> {
  late int _year = widget.month.year;
  late int _month = widget.month.month;

  List<int> get _months => [
    for (var month = 1; month <= 12; month++)
      if (!DateTime(_year, month + 1, 0).isBefore(kCalendarFirstDate) &&
          !DateTime(_year, month).isAfter(kCalendarLastDate))
        month,
  ];

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Перайсці да месяца'),
    scrollable: true,
    content: SizedBox(
      width: 320,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<int>(
            key: ValueKey('ordo-jump-year-$_year'),
            initialValue: _year,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Год'),
            items: [
              for (
                var year = kCalendarFirstDate.year;
                year <= kCalendarLastDate.year;
                year++
              )
                DropdownMenuItem(value: year, child: Text('$year')),
            ],
            onChanged: (year) {
              if (year == null) return;
              setState(() {
                _year = year;
                _month = _month.clamp(_months.first, _months.last);
              });
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            key: ValueKey('ordo-jump-month-$_year-$_month'),
            initialValue: _month,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Месяц'),
            items: [
              for (final month in _months)
                DropdownMenuItem(
                  value: month,
                  child: Text(
                    DateFormat('LLLL', 'be').format(DateTime(_year, month)),
                  ),
                ),
            ],
            onChanged: (month) {
              if (month != null) setState(() => _month = month);
            },
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Скасаваць'),
      ),
      FilledButton(
        key: const Key('ordo-jump-apply'),
        onPressed: () => Navigator.pop(context, DateTime(_year, _month)),
        child: const Text('Паказаць'),
      ),
    ],
  );
}

class _MonthGrid extends ConsumerWidget {
  const _MonthGrid({
    required this.month,
    required this.selected,
    required this.today,
    required this.accent,
    required this.onSelect,
    this.diocese,
  });

  final DateTime month;
  final String selected;
  final String today;
  final Color accent;
  final ValueChanged<String> onSelect;
  final String? diocese;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(cacheEpochProvider);
    final selectedDioceses = ref.watch(dioceseSelectionProvider).ordered;
    final dioceses = {?diocese, ...selectedDioceses};
    final engine = OrdoRuntime.engine;
    final first = isoFromParts(month.year, month.month, 1);
    final lead = isoWeekday(first) - 1;
    final days = [
      for (final iso in daysOfYear(month.year))
        if (parseIso(iso).month == month.month) iso,
    ];
    final cells = <String?>[for (var i = 0; i < lead; i++) null, ...days];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        // Keep the grid's scroll offset separate from an enclosing
        // ExpansionTile's boolean PageStorage value.
        key: const PageStorageKey('liturgical-month-grid-scroll'),
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: constraints.maxWidth.clamp(322.0, 696.0),
          child: GlassSurface(
            seasonColor: accent,
            padding: const EdgeInsets.fromLTRB(2, 10, 2, 8),
            child: Column(
              children: [
                Row(
                  children: [
                    for (final (index, label) in _weekdays.indexed)
                      Expanded(
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: index == 6
                                ? theme.colorScheme.error
                                : theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                for (var row = 0; row < cells.length ~/ 7; row++)
                  Row(
                    children: [
                      for (final iso in cells.sublist(row * 7, row * 7 + 7))
                        Expanded(
                          child: iso == null
                              ? const SizedBox(height: 52)
                              : _DayCell(
                                  iso: iso,
                                  colors: () {
                                    final colors = <String>[];
                                    for (final diocese in dioceses) {
                                      final day = engine.resolve(
                                        iso,
                                        diocese: diocese,
                                      );
                                      for (final color in {
                                        ...day.legalColors,
                                        for (final option in day.options)
                                          ...option.colorAlternatives,
                                      }) {
                                        if (!colors.contains(color)) {
                                          colors.add(color);
                                        }
                                      }
                                    }
                                    return colors.take(3).toList();
                                  }(),
                                  isToday: iso == today,
                                  isSelected: iso == selected,
                                  accent: accent,
                                  onTap: () => onSelect(iso),
                                ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.iso,
    required this.colors,
    required this.isToday,
    required this.isSelected,
    required this.accent,
    required this.onTap,
  });

  final String iso;
  final List<String> colors;
  final bool isToday;
  final bool isSelected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final day = parseIso(iso).day;
    final sunday = isoWeekday(iso) == 7;
    final colorLabel = colors.map(vestmentLabel).join(', ');
    return Semantics(
      button: true,
      selected: isSelected,
      onTap: onTap,
      label:
          '${dayMonthLabel(iso)}${isToday ? ', сёння' : ''}. Колер: $colorLabel',
      excludeSemantics: true,
      child: InkWell(
        key: Key('ordo-day-$iso'),
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(vertical: 6),
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            color: isSelected
                ? Color.alphaBlend(
                    cs.onSurface.withValues(alpha: .08),
                    cs.secondaryContainer,
                  )
                : null,
            borderRadius: BorderRadius.circular(14),
            border: isSelected
                ? Border.all(color: cs.outline.withValues(alpha: .8))
                : isToday
                ? Border.all(color: cs.outline.withValues(alpha: .4))
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$day',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: isSelected || sunday
                      ? FontWeight.w800
                      : FontWeight.w500,
                  color: isSelected
                      ? cs.onSecondaryContainer
                      : sunday
                      ? cs.error
                      : cs.onSurface,
                ),
                maxLines: 1,
              ),
              const SizedBox(height: 3),
              VestmentMarker(colors: colors, size: 10),
            ],
          ),
        ),
      ),
    );
  }
}
