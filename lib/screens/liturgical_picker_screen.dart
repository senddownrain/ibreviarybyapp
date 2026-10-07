import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:mybrev_flutter/constants/liturgical.dart';
import 'package:mybrev_flutter/ordo/definitions.dart';
import 'package:mybrev_flutter/ordo/dates.dart';
import 'package:mybrev_flutter/ordo/day_union.dart';
import 'package:mybrev_flutter/ordo/ordo_picker.dart';
import 'package:mybrev_flutter/ordo/runtime.dart';
import 'package:mybrev_flutter/providers/cache_epoch_provider.dart';
import 'package:mybrev_flutter/providers/diocese_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_navigation_sync_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/providers/readings_navigation_provider.dart';
import 'package:mybrev_flutter/services/liturgical_content_service.dart';
import 'package:mybrev_flutter/theme/glass.dart';
import 'package:mybrev_flutter/navigation/app_navigation.dart';
import 'package:mybrev_flutter/utils/liturgical_visual.dart';
import 'package:mybrev_flutter/widgets/ordo/vestment_marker.dart';
import 'package:mybrev_flutter/widgets/reader/reader_navigation.dart';

/// Celebrations of a year for the selected dioceses (computed once).
final pickerFeastsProvider =
    Provider.family<List<PickerFeast>, (int, List<String>)>((ref, key) {
      ref.watch(cacheEpochProvider);
      return pickerFeastsOfYear(OrdoRuntime.engine, key.$1, key.$2);
    });

/// Opens [date] (optionally one celebration) in the Hours or the Readings.
void openPickedDate(
  BuildContext context,
  WidgetRef ref,
  DateTime date, {
  required bool readingsMode,
  String? optionId,
  String? diocese,
}) {
  String? dayId;
  if (optionId != null) {
    dayId = LiturgicalContentService()
        .contentForDate(date, diocese: diocese ?? kDioceses.first)
        .options
        .where((option) => option.ordo?.optionId == optionId)
        .firstOrNull
        ?.dayId;
  }
  if (readingsMode) {
    AppNavigationScope.maybeOf(context)?.shellState.clearOraReturn();
    context.go(
      readingsRouteForContext(
        date: date,
        dayId: dayId,
        diocese: dayId == null ? null : diocese,
        optionId: optionId,
      ),
    );
    return;
  }
  ref
      .read(liturgicalNavigationControllerProvider)
      .openDate(date, dayId: dayId, diocese: dayId == null ? null : diocese);
  context.go('/hours');
}

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
    _year = widget.isReadingsMode
        ? ref.read(readingsBranchStateProvider).date.year
        : ref.read(selectedDateProvider).year;
  }

  @override
  Widget build(BuildContext context) {
    final seasonColor = ref.watch(liturgicalSeasonColorProvider);
    return DefaultTabController(
      length: 2,
      child: AmbientWash(
        seasonColor: seasonColor,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverToBoxAdapter(
              child: Column(
                key: const Key('liturgical-picker-heading'),
                children: [
                  SafeArea(
                    bottom: false,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        key: const Key('liturgical-picker-back'),
                        tooltip: 'Назад',
                        onPressed: () => Navigator.maybePop(context),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'ЛІТУРГІЧНЫ КАЛЯНДАР',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: seasonColor,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.3,
                              ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          widget.isReadingsMode
                              ? 'Знайсці чытанні'
                              : 'Знайсці дзень',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 12),
                        GlassSurface(
                          style: GlassStyle.soft,
                          borderRadius: BorderRadius.circular(20),
                          padding: const EdgeInsets.fromLTRB(14, 7, 8, 7),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final label = Row(
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
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                              final years = _YearSelector(
                                year: _year,
                                onChanged: (year) =>
                                    setState(() => _year = year),
                              );
                              final scale = MediaQuery.textScalerOf(
                                context,
                              ).scale(1);
                              // Narrow or large text: the year gets its own
                              // line, never squeezed.
                              if (constraints.maxWidth < 300 * scale) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    label,
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: years,
                                    ),
                                  ],
                                );
                              }
                              return Row(
                                children: [
                                  Expanded(child: label),
                                  years,
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _PickerTabsHeaderDelegate(
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerLowest,
              ),
            ),
          ],
          body: TabBarView(
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
      ),
    );
  }
}

// ─── Period picker ─────────────────────────────────────────────────────────────

class _PickerTabsHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _PickerTabsHeaderDelegate({required this.backgroundColor});

  final Color backgroundColor;

  static const double _extent = 56;

  @override
  double get minExtent => _extent;

  @override
  double get maxExtent => _extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ColoredBox(
      key: const Key('liturgical-picker-tabs-header'),
      color: backgroundColor,
      child: Padding(
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
    );
  }

  @override
  bool shouldRebuild(covariant _PickerTabsHeaderDelegate oldDelegate) {
    return oldDelegate.backgroundColor != backgroundColor;
  }
}

class _PeriodPicker extends StatelessWidget {
  final WidgetRef ref;
  final int year;
  final bool readingsMode;
  const _PeriodPicker({
    required this.ref,
    required this.year,
    required this.readingsMode,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 104 + bottomInset),
      children: periodLabelMap.entries.map((entry) {
        final vestment = kPeriodVestment[entry.key] ?? 'viridis';
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            key: Key('picker-period-${entry.key}'),
            minTileHeight: 56,
            leading: VestmentMarker(colors: [vestment], size: 20),
            title: Text(entry.value),
            subtitle: Text(vestmentLabel(vestment)),
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
    final positions = pickerPositions(year, period);
    final exactDates = pickerExactDates(year, period);
    final dioceses = ref.read(dioceseSelectionProvider).ordered;
    final engine = OrdoRuntime.engine;
    List<String> colorsOf(String iso) {
      final colors = <String>[];
      for (final diocese in dioceses) {
        for (final color in engine.resolve(iso, diocese: diocese).legalColors) {
          if (!colors.contains(color)) colors.add(color);
        }
      }
      return colors.take(3).toList();
    }

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => _WeekDaySheet(
        periodLabel: periodLabel,
        // Christmas and the days after Ash Wednesday are found by date.
        positions: period == 'christmas'
            ? const {}
            : {
                for (final entry in positions.entries)
                  if (entry.key > 0) entry.key: entry.value,
              },
        exactDates: exactDates,
        exactDatesFirst: period == 'lent' || period == 'christmas',
        colorsOf: colorsOf,
        onSelected: (iso) {
          Navigator.of(ctx).pop();
          openPickedDate(
            context,
            ref,
            dateOfIso(iso),
            readingsMode: readingsMode,
          );
        },
      ),
    );
  }
}

class _WeekDaySheet extends StatefulWidget {
  final String periodLabel;
  final Map<int, Map<int, String>> positions;
  final List<String> exactDates;
  final bool exactDatesFirst;
  final List<String> Function(String iso) colorsOf;
  final ValueChanged<String> onSelected;

  const _WeekDaySheet({
    required this.periodLabel,
    required this.positions,
    required this.exactDates,
    required this.exactDatesFirst,
    required this.colorsOf,
    required this.onSelected,
  });

  @override
  State<_WeekDaySheet> createState() => _WeekDaySheetState();
}

class _WeekDaySheetState extends State<_WeekDaySheet> {
  late int _selectedWeek =
      (widget.positions.keys.toList()..sort()).firstOrNull ?? 1;

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
    final weeks = widget.positions.keys.toList()..sort();
    final days = widget.positions[_selectedWeek] ?? const <int, String>{};
    final dayKeys = days.keys.toList()..sort();

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.86,
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 20,
          bottom:
              MediaQuery.viewInsetsOf(context).bottom +
              MediaQuery.viewPaddingOf(context).bottom +
              24,
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
                colorsOf: widget.colorsOf,
                onSelected: widget.onSelected,
              ),
              if (weeks.isNotEmpty) const Divider(height: 28),
            ],
            if (weeks.isNotEmpty) ...[
              Text('Тыдзень', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final week in weeks)
                    ChoiceChip(
                      key: Key('picker-week-$week'),
                      label: Text(toRomanWeek(week)),
                      selected: week == _selectedWeek,
                      onSelected: (_) => setState(() => _selectedWeek = week),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Text('Дзень', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final day in dayKeys)
                    FilledButton.tonalIcon(
                      key: Key('picker-day-$day'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: () => widget.onSelected(days[day]!),
                      icon: VestmentMarker(
                        colors: widget.colorsOf(days[day]!),
                        size: 12,
                      ),
                      label: Text(
                        '${_dayLabels[day] ?? '$day'} · '
                        '${DateFormat('d.MM', 'be').format(dateOfIso(days[day]!))}',
                      ),
                    ),
                ],
              ),
            ],
            if (!widget.exactDatesFirst && widget.exactDates.isNotEmpty) ...[
              if (weeks.isNotEmpty) const Divider(height: 28),
              _ExactDateChoices(
                dates: widget.exactDates,
                colorsOf: widget.colorsOf,
                onSelected: widget.onSelected,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String toRomanWeek(int week) {
  const numerals = [(10, 'X'), (9, 'IX'), (5, 'V'), (4, 'IV'), (1, 'I')];
  var rest = week;
  final out = StringBuffer();
  for (final (value, numeral) in numerals) {
    while (rest >= value) {
      out.write(numeral);
      rest -= value;
    }
  }
  return out.toString();
}

class _ExactDateChoices extends StatelessWidget {
  const _ExactDateChoices({
    required this.dates,
    required this.colorsOf,
    required this.onSelected,
  });

  final List<String> dates;
  final List<String> Function(String iso) colorsOf;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    if (dates.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Каляндарная дата', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final iso in dates)
              OutlinedButton.icon(
                key: Key('picker-date-$iso'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 48),
                ),
                onPressed: () => onSelected(iso),
                icon: VestmentMarker(colors: colorsOf(iso), size: 12),
                label: Text(DateFormat('d MMM', 'be').format(dateOfIso(iso))),
              ),
          ],
        ),
      ],
    );
  }
}

/// Year: «‹ 2027 ›» with a grid of years in numeric order (the selected
/// one highlighted and scrolled into view).
class _YearSelector extends StatelessWidget {
  const _YearSelector({required this.year, required this.onChanged});

  final int year;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: const Key('picker-year-previous'),
          tooltip: 'Папярэдні год',
          onPressed: () => onChanged(year - 1),
          icon: const PhosphorIcon(PhosphorIconsRegular.caretLeft, size: 18),
        ),
        TextButton(
          key: const Key('picker-year'),
          style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
          onPressed: () async {
            final picked = await showModalBottomSheet<int>(
              context: context,
              useRootNavigator: true,
              useSafeArea: true,
              isScrollControlled: true,
              builder: (_) => _YearGrid(selected: year),
            );
            if (picked != null) onChanged(picked);
          },
          child: Text(
            '$year',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
          ),
        ),
        IconButton(
          key: const Key('picker-year-next'),
          tooltip: 'Наступны год',
          onPressed: () => onChanged(year + 1),
          icon: const PhosphorIcon(PhosphorIconsRegular.caretRight, size: 18),
        ),
      ],
    );
  }
}

class _YearGrid extends StatelessWidget {
  const _YearGrid({required this.selected});
  final int selected;

  @override
  Widget build(BuildContext context) {
    final years = pickerYears(selected);
    const columns = 4;
    const rowHeight = 56.0;
    final row = years.indexOf(selected) ~/ columns;
    final controller = ScrollController(
      initialScrollOffset: (row - 1).clamp(0, 1000) * rowHeight,
    );
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Год', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: rowHeight * 5),
              child: GridView.builder(
                key: const Key('picker-year-grid'),
                controller: controller,
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisExtent: rowHeight,
                ),
                itemCount: years.length,
                itemBuilder: (context, index) {
                  final year = years[index];
                  final isSelected = year == selected;
                  return Padding(
                    padding: const EdgeInsets.all(4),
                    child: isSelected
                        ? FilledButton(
                            key: Key('picker-year-$year'),
                            onPressed: () => Navigator.pop(context, year),
                            child: Text('$year'),
                          )
                        : OutlinedButton(
                            key: Key('picker-year-$year'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: year == DateTime.now().year
                                  ? cs.primary
                                  : null,
                            ),
                            onPressed: () => Navigator.pop(context, year),
                            child: Text('$year'),
                          ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
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
    final dioceses = ref.watch(dioceseSelectionProvider).ordered;
    final all = ref.watch(pickerFeastsProvider((widget.year, dioceses)));
    final query = _query.trim().toLowerCase();
    final filtered = query.isEmpty
        ? all
        : all
              .where(
                (f) =>
                    f.title.toLowerCase().contains(query) ||
                    dayMonthLabel(f.date).contains(query),
              )
              .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            key: const Key('picker-feast-search'),
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
                  key: const Key('picker-feasts'),
                  padding: EdgeInsets.fromLTRB(
                    16,
                    0,
                    16,
                    104 + MediaQuery.viewPaddingOf(context).bottom,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) => _FeastRow(
                    feast: filtered[i],
                    onTap: () => openPickedDate(
                      context,
                      ref,
                      dateOfIso(filtered[i].date),
                      readingsMode: widget.readingsMode,
                      optionId: filtered[i].id,
                      diocese: filtered[i].dioceses.first,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

/// A celebration of the year: its real vestment colour as a quiet marker,
/// title, final date and rank; transfers and dioceses as small badges.
class _FeastRow extends StatelessWidget {
  const _FeastRow({required this.feast, required this.onTap});

  final PickerFeast feast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final weekday = DateFormat('EEEE', 'be').format(dateOfIso(feast.date));
    final rank = ordoRankLabel(feast.option);
    final badges = [...feast.badges, ...ordoOptionNotes(feast.option)];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        key: Key('picker-feast-${feast.id}-${feast.date}'),
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
            child: Row(
              children: [
                VestmentMarker(colors: feast.colors, size: 16),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        feast.title,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          '${dayMonthLabel(feast.date)}, $weekday',
                          if (rank.isNotEmpty) rank,
                          vestmentColorsLabel(feast.option),
                        ].join(' · '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      if (badges.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            for (final badge in badges)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: cs.secondaryContainer.withValues(
                                    alpha: 0.7,
                                  ),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text(
                                  badge,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: cs.onSecondaryContainer,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const PhosphorIcon(PhosphorIconsRegular.caretRight, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
