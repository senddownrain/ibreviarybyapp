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
import 'package:mybrev_flutter/widgets/liturgical_selector_components.dart';

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

  bool _pickingMonth = false;
  bool _pickingYear = false;
  late int _pickerYear = _month.year;
  ScrollController? _yearScroll;

  @override
  void dispose() {
    _yearScroll?.dispose();
    super.dispose();
  }

  void _toggleYears() {
    if (!_pickingYear) {
      _yearScroll?.dispose();
      _yearScroll = ScrollController(
        keepScrollOffset: false,
        initialScrollOffset:
            ((_pickerYear - kCalendarFirstDate.year) * 48.0 - 96).clamp(
              0.0,
              (kCalendarLastDate.year - kCalendarFirstDate.year + 1) * 48.0 -
                  240,
            ),
      );
    }
    setState(() => _pickingYear = !_pickingYear);
  }

  void _jumpToMonth() => setState(() {
    _pickerYear = _month.year;
    _pickingMonth = !_pickingMonth;
    _pickingYear = false;
  });

  Widget _picker(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            IconButton(
              key: const Key('ordo-previous-year'),
              tooltip: 'Папярэдні год',
              onPressed: _pickerYear > kCalendarFirstDate.year
                  ? () => setState(() => _pickerYear--)
                  : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: TextButton(
                key: const Key('ordo-pick-year'),
                onPressed: _toggleYears,
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '$_pickerYear',
                      style: theme.textTheme.titleLarge?.copyWith(fontSize: 21),
                    ),
                    Icon(
                      _pickingYear
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              key: const Key('ordo-next-year'),
              tooltip: 'Наступны год',
              onPressed: _pickerYear < kCalendarLastDate.year
                  ? () => setState(() => _pickerYear++)
                  : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        if (_pickingYear)
          SizedBox(
            height: 240,
            child: ListView(
              key: const Key('ordo-year-list'),
              controller: _yearScroll,
              itemExtent: 48,
              children: [
                for (
                  var year = kCalendarFirstDate.year;
                  year <= kCalendarLastDate.year;
                  year++
                )
                  ListTile(
                    key: Key('ordo-year-$year'),
                    selected: year == _pickerYear,
                    title: Text('$year', textAlign: TextAlign.center),
                    onTap: () => setState(() {
                      _pickerYear = year;
                      _pickingYear = false;
                    }),
                  ),
              ],
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              // Measure names with the real theme/font scaler; never break a
              // month name just to keep three columns at large system text.
              var widestName = 0.0;
              for (var month = 1; month <= 12; month++) {
                final name = DateFormat(
                  'LLLL',
                  'be',
                ).format(DateTime(_pickerYear, month));
                final measurement = TextPainter(
                  text: TextSpan(
                    text: '${name[0].toUpperCase()}${name.substring(1)}',
                    style: theme.textTheme.labelLarge,
                  ),
                  textScaler: MediaQuery.textScalerOf(context),
                  textDirection: Directionality.of(context),
                  maxLines: 1,
                )..layout();
                if (measurement.width > widestName) {
                  widestName = measurement.width;
                }
                measurement.dispose();
              }
              final columns = (constraints.maxWidth / (widestName + 16))
                  .floor()
                  .clamp(1, 3);
              return Column(
                children: [
                  for (var row = 0; row < 12 ~/ columns; row++)
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var column = 0; column < columns; column++)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(3),
                                child: _monthButton(row * columns + column + 1),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        TextButton(
          key: const Key('ordo-picker-days'),
          onPressed: () => setState(() {
            _pickingMonth = false;
            _pickingYear = false;
          }),
          child: const Text('Да дзён месяца'),
        ),
      ],
    );
  }

  Widget _monthButton(int month) {
    final cs = Theme.of(context).colorScheme;
    final selected = _month.year == _pickerYear && _month.month == month;
    final available =
        !DateTime(_pickerYear, month + 1, 0).isBefore(kCalendarFirstDate) &&
        !DateTime(_pickerYear, month).isAfter(kCalendarLastDate);
    final label = DateFormat('LLLL', 'be').format(DateTime(_pickerYear, month));
    return Semantics(
      selected: selected,
      child: OutlinedButton(
        key: Key('ordo-month-$month'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          backgroundColor: selected ? cs.surfaceContainerHigh : null,
          foregroundColor: cs.onSurface,
          side: BorderSide(color: selected ? cs.outline : cs.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: available
            ? () => setState(() {
                _month = DateTime(_pickerYear, month);
                _pickingMonth = false;
              })
            : null,
        child: Text(
          '${label[0].toUpperCase()}${label.substring(1)}',
          textAlign: TextAlign.center,
        ),
      ),
    );
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
        if (_pickingMonth)
          _picker(context)
        else
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
        if (_pickingMonth)
          const SizedBox.shrink()
        else if (ready.hasError)
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
    final monthLabel = DateFormat('LLLL', 'be').format(month);
    String capitalise(String text) =>
        '${text[0].toUpperCase()}${text.substring(1)}';
    final style = Theme.of(context).textTheme.titleLarge?.copyWith(
      fontSize: LiturgicalSelectorTokens.titleSize,
      fontWeight: FontWeight.w600,
    );
    final previous = IconButton(
      key: const Key('ordo-previous-month'),
      tooltip: 'Папярэдні месяц',
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      onPressed: onPrevious,
      icon: const PhosphorIcon(PhosphorIconsRegular.caretLeft),
    );
    final next = IconButton(
      key: const Key('ordo-next-month'),
      tooltip: 'Наступны месяц',
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      onPressed: onNext,
      icon: const PhosphorIcon(PhosphorIconsRegular.caretRight),
    );
    Widget heading(String text) => TextButton(
      key: const Key('ordo-jump-month'),
      onPressed: onJump,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              text,
              key: const Key('ordo-month-label'),
              textAlign: TextAlign.center,
              style: style,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down, size: 20),
        ],
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final measurement = TextPainter(
          text: TextSpan(text: capitalise(monthLabel), style: style),
          textScaler: MediaQuery.textScalerOf(context),
          textDirection: Directionality.of(context),
          maxLines: 1,
        )..layout();
        final separateYear = measurement.width > constraints.maxWidth - 96 - 48;
        measurement.dispose();
        if (separateYear) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              heading(capitalise(monthLabel)),
              Row(
                children: [
                  previous,
                  Expanded(
                    child: TextButton(
                      onPressed: onJump,
                      child: Text('${month.year}', style: style),
                    ),
                  ),
                  next,
                ],
              ),
            ],
          );
        }
        return Row(
          children: [
            previous,
            Expanded(child: heading(capitalise(label))),
            next,
          ],
        );
      },
    );
  }
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
      builder: (context, constraints) => SizedBox(
        width: constraints.maxWidth,
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
                                  return colors;
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
            color: isSelected ? cs.surfaceContainerHighest : null,
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
                  color: sunday ? cs.error : cs.onSurface,
                  decoration: isToday ? TextDecoration.underline : null,
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
