import 'package:mybrev_flutter/utils/picked_feast_readings.dart';
import 'package:mybrev_flutter/widgets/floating_top_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:mybrev_flutter/constants/hora_items.dart';
import 'package:mybrev_flutter/constants/liturgical.dart';
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/content/content_store.dart';
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
import 'package:mybrev_flutter/utils/hours_liturgical_options.dart';
import 'package:mybrev_flutter/widgets/ordo/vestment_marker.dart';
import 'package:mybrev_flutter/widgets/reader/reader_navigation.dart';

/// Search all Belarusian dioceses; Settings still control liturgical days.
final pickerFeastsProvider = Provider.family<List<PickerFeast>, int>((
  ref,
  year,
) {
  ref.watch(cacheEpochProvider);
  return pickerFeastsOfYear(OrdoRuntime.engine, year, kDioceses);
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
    final day = OrdoRuntime.engine.resolve(
      isoOf(date),
      diocese: diocese ?? kDioceses.first,
    );
    final legal = readingsMode ? day.options : day.officeOptions;
    if (!legal.any((option) => option.id == optionId)) return;
    dayId = LiturgicalContentService()
        .contentForDate(date, diocese: diocese ?? kDioceses.first)
        .options
        .where((option) => option.ordo?.optionId == optionId)
        .firstOrNull
        ?.dayId;
    if (!readingsMode && dayId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Тэксты гэтага святкавання недаступныя')),
      );
      return;
    }
  }
  if (readingsMode) {
    AppNavigationScope.maybeOf(context)?.shellState.clearOraReturn();
    context.go(
      readingsRouteForContext(
        date: date,
        dayId: dayId,
        diocese: optionId == null ? null : diocese,
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

/// Opens existing readers on a real legal occurrence of the chosen definition.
/// Content is checked before navigating; an unrelated day is never a fallback.
Future<void> openPickedFeast(
  BuildContext context,
  WidgetRef ref,
  PickerFeast feast,
  int year, {
  required bool readingsMode,
}) async {
  await ContentStore.instance.ensureLoaded(kLiturgicalCollections);
  if (!context.mounted) return;
  final diocese =
      ref
          .read(dioceseSelectionProvider)
          .ordered
          .where(feast.dioceses.contains)
          .firstOrNull ??
      feast.dioceses.first;
  final service = LiturgicalContentService();
  for (final day in pickerFeastTextDays(
    OrdoRuntime.engine,
    feast,
    year,
    diocese,
    readingsMode: readingsMode,
  )) {
    if (!context.mounted) return;
    final date = dateOfIso(day.date);
    final content = service.contentForDate(date, diocese: diocese);
    final office = content.options
        .where((o) => o.optionId == feast.id)
        .firstOrNull;
    if (office == null) continue;
    if (!readingsMode) {
      final templates = office.templates
          .where((t) => kHoraItems.any((hour) => isHourAvailable(t.day, hour)))
          .toList();
      final template =
          templates.where((t) => t.choice != 'current-day').firstOrNull ??
          templates.firstOrNull;
      final text = template?.day ?? office.day;
      final dayId = template?.id ?? office.dayId;
      if (office.disabled ||
          dayId == null ||
          text == null ||
          !kHoraItems.any((hour) => isHourAvailable(text, hour)) ||
          content.optionOwning(dayId)?.optionId != feast.id) {
        continue;
      }
      ref
          .read(liturgicalNavigationControllerProvider)
          .openDate(date, dayId: dayId, diocese: diocese, fromSearch: true);
      final selected = ref.read(hoursLiturgicalSelectionProvider);
      if (selected.dayId != dayId || selected.selected?.optionId != feast.id) {
        continue;
      }
      final messenger = ScaffoldMessenger.of(context);
      final opened = context.push<void>('/hours');
      _notifyPickedYear(messenger, year, date.year);
      await opened;
      return;
    }
    final dayId = office.dayId;
    if (dayId == null) continue;
    if (!await preparePickedFeastReadings(
      context,
      ref,
      date: date,
      dayId: dayId,
      diocese: diocese,
      optionId: feast.id,
    ))
      return;
    if (!context.mounted) return;
    AppNavigationScope.maybeOf(context)?.shellState.clearOraReturn();
    final messenger = ScaffoldMessenger.of(context);
    final opened = context.push<void>(
      readingsRouteForContext(
        date: date,
        dayId: dayId,
        diocese: diocese,
        optionId: feast.id,
      ),
    );
    _notifyPickedYear(messenger, year, date.year);
    await opened;
    return;
  }
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Тэксты гэтага святкавання недаступныя')),
    );
  }
}

void _notifyPickedYear(
  ScaffoldMessengerState messenger,
  int searched,
  int opened,
) {
  if (searched == opened) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!messenger.mounted) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 5),
        content: Text(
          'У $searched годзе гэтае святкаванне не адзначаецца. '
          'Адкрыты тэксты за $opened год.',
        ),
      ),
    );
  });
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
  late final int _year;

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
                  FloatingTopActions(
                    leading: IconButton(
                      key: const Key('liturgical-picker-back'),
                      tooltip: 'Назад',
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.arrow_back_rounded),
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
                                      : 'Рэжым літургіі гадзінаў',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
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

// ─── Combined feasts picker (dynamic + fixed) ──────────────────────────────────

class _FeastsPickerCombined extends ConsumerStatefulWidget {
  const _FeastsPickerCombined({required this.year, required this.readingsMode});

  final int year;
  final bool readingsMode;

  @override
  ConsumerState<_FeastsPickerCombined> createState() =>
      _FeastsPickerCombinedState();
}

class _FeastsPickerCombinedState extends ConsumerState<_FeastsPickerCombined>
    with AutomaticKeepAliveClientMixin<_FeastsPickerCombined> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String _filter = 'all';
  bool _opening = false;

  static const _filters = {
    'all': 'Усе',
    'fixed': 'Нерухомыя',
    'movable': 'Рухомыя',
  };

  @override
  bool get wantKeepAlive => true;

  Future<void> _openFeast(PickerFeast feast) async {
    if (_opening) return;
    _opening = true;
    try {
      await openPickedFeast(
        context,
        ref,
        feast,
        widget.year,
        readingsMode: widget.readingsMode,
      );
    } catch (error) {
      debugPrint('Picker texts: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не ўдалося адкрыць тэксты святкавання'),
          ),
        );
      }
    } finally {
      _opening = false;
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final all = ref.watch(pickerFeastsProvider(widget.year));
    final query = _query.trim().toLowerCase();
    final filtered = all
        .where(
          (f) =>
              (_filter == 'all' || f.kind == _filter) &&
              (query.isEmpty ||
                  f.title.toLowerCase().contains(query) ||
                  [f.nominalDate, f.date].nonNulls.any(
                    (date) =>
                        date.contains(query) ||
                        dayMonthLabel(date).contains(query) ||
                        fixedDateKey(date).contains(query),
                  )),
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
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_query.isNotEmpty)
                    IconButton(
                      tooltip: 'Ачысціць пошук',
                      icon: const PhosphorIcon(
                        PhosphorIconsRegular.x,
                        size: 20,
                      ),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      },
                    ),
                  PopupMenuButton<String>(
                    key: const Key('picker-feast-filter'),
                    tooltip: 'Фільтр: ${_filters[_filter]}',
                    icon: Badge(
                      isLabelVisible: _filter != 'all',
                      child: const Icon(Icons.filter_list, size: 20),
                    ),
                    onSelected: (value) => setState(() => _filter = value),
                    itemBuilder: (context) => [
                      for (final entry in _filters.entries)
                        CheckedPopupMenuItem(
                          key: Key('picker-filter-${entry.key}'),
                          value: entry.key,
                          checked: _filter == entry.key,
                          child: Text(entry.value),
                        ),
                    ],
                  ),
                ],
              ),
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
                    onTap: () => _openFeast(filtered[i]),
                  ),
                ),
        ),
      ],
    );
  }
}

/// A celebration of the year: its real vestment colour as a quiet marker,
/// title, nominal date and rank; transfers, status and dioceses as small badges.
class _FeastRow extends StatelessWidget {
  const _FeastRow({required this.feast, required this.onTap});

  final PickerFeast feast;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final displayDate = feast.kind == 'fixed'
        ? feast.nominalDate ?? feast.date
        : feast.date;
    final visual = liturgicalVisual(
      color: feast.option.color,
      category: feast.option.category,
      rank: feast.option.rank,
    );
    final rank = ordoRankLabel(feast.option);
    final badges = [
      ...feast.badges,
      ...ordoOptionNotes(feast.option).where(
        (note) => !feast.transferred || !note.startsWith('Перанесена з '),
      ),
      if (feast.transferred && feast.date != null)
        'Перанесена на ${dayMonthLabel(feast.date!)}',
      if (feast.status != null) feast.status!,
    ];
    final accent = visual?.accent ?? cs.primary;
    final ink = Color.lerp(
      accent,
      cs.onSurface,
      theme.brightness == Brightness.dark ? 0.48 : 0.18,
    )!;
    return Card(
      color: Color.alphaBlend(accent.withValues(alpha: 0.035), cs.surface),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: accent.withValues(alpha: 0.25)),
      ),
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
                Container(
                  key: Key('picker-date-tile-${feast.id}'),
                  width: MediaQuery.sizeOf(context).width <= 340 ? 76 : 92,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (displayDate != null) ...[
                        Semantics(
                          label: dayMonthLabel(displayDate),
                          excludeSemantics: true,
                          child: Column(
                            children: [
                              Text(
                                '${dateOfIso(displayDate).day}',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: ink,
                                ),
                              ),
                              Text(
                                dayMonthLabel(
                                  displayDate,
                                ).split(' ').skip(1).join(' '),
                                textAlign: TextAlign.center,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else
                        Text(
                          'Дата не вызначана',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelMedium,
                        ),
                      const SizedBox(height: 8),
                      VestmentMarker(colors: feast.colors, size: 16),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
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
                          if (feast.kind == 'movable') 'Рухомае',
                          if (rank.isNotEmpty) rank,
                          vestmentColorsLabel(feast.option),
                        ].where((label) => label.isNotEmpty).join(' · '),
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
                if (onTap != null)
                  PhosphorIcon(
                    PhosphorIconsRegular.caretRight,
                    size: 18,
                    color: visual?.accent,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
