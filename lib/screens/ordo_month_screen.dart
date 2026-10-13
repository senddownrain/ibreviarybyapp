import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mybrev_flutter/constants/liturgical.dart';
import 'package:mybrev_flutter/ordo/dates.dart';
import 'package:mybrev_flutter/ordo/day_union.dart';
import 'package:mybrev_flutter/ordo/runtime.dart';
import 'package:mybrev_flutter/providers/cache_epoch_provider.dart';
import 'package:mybrev_flutter/providers/diocese_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/widgets/adaptive_app_bar.dart';
import 'package:mybrev_flutter/widgets/ordo/vestment_marker.dart';

/// Monthly overview; the coloured grid remains a separate date picker.
class OrdoMonthScreen extends ConsumerStatefulWidget {
  const OrdoMonthScreen({super.key, required this.initialDate, this.diocese});
  final DateTime initialDate;
  final String? diocese;

  @override
  ConsumerState<OrdoMonthScreen> createState() => _OrdoMonthScreenState();
}

class _OrdoMonthScreenState extends ConsumerState<OrdoMonthScreen> {
  late DateTime _month = DateTime(
    widget.initialDate.year,
    widget.initialDate.month,
  );
  final _scroll = ScrollController();
  final _anchor = GlobalKey();
  String? _scrolledMonth;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _move(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _scrolledMonth = null;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final ready = ref.watch(liturgicalContentReadyProvider);
    ref.watch(cacheEpochProvider);
    final dioceses = ref.watch(dioceseSelectionProvider).ordered;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final today = DateUtils.dateOnly(DateTime.now());
    bool inMonth(DateTime date) =>
        date.year == _month.year && date.month == _month.month;
    final target = inMonth(widget.initialDate)
        ? widget.initialDate
        : inMonth(today)
        ? today
        : null;
    final monthKey = '${_month.year}-${_month.month}';
    if (ready.hasValue && _scrolledMonth != monthKey) {
      _scrolledMonth = monthKey;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || monthKey != _scrolledMonth) return;
        final anchorContext = _anchor.currentContext;
        if (anchorContext != null) {
          Scrollable.ensureVisible(anchorContext, alignment: .25);
        }
      });
    }
    final label = DateFormat('LLLL y', 'be').format(_month);
    return Scaffold(
      appBar: AdaptiveAppBar(
        showOverflow: true,
        title: const Text('Літургічны каляндар'),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        key: const Key('ordo-previous-month'),
                        tooltip: 'Папярэдні месяц',
                        onPressed:
                            _month.isAfter(
                              DateTime(
                                kCalendarFirstDate.year,
                                kCalendarFirstDate.month,
                              ),
                            )
                            ? () => _move(-1)
                            : null,
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Expanded(
                        child: Text(
                          '${label[0].toUpperCase()}${label.substring(1)}',
                          key: const Key('ordo-month-label'),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        key: const Key('ordo-next-month'),
                        tooltip: 'Наступны месяц',
                        onPressed:
                            _month.isBefore(
                              DateTime(
                                kCalendarLastDate.year,
                                kCalendarLastDate.month,
                              ),
                            )
                            ? () => _move(1)
                            : null,
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ready.hasError
                      ? const Center(child: Text('Не ўдалося адкрыць каляндар'))
                      : !ready.hasValue
                      ? const Center(
                          child: CircularProgressIndicator.adaptive(),
                        )
                      : SingleChildScrollView(
                          key: const Key('ordo-month-list'),
                          controller: _scroll,
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                          // At most 31 variable-height groups. Eager layout lets us
                          // locate the selected date exactly at any text scale.
                          child: Column(
                            children: [
                              for (
                                var day = 1;
                                day <=
                                    DateUtils.getDaysInMonth(
                                      _month.year,
                                      _month.month,
                                    );
                                day++
                              )
                                Builder(
                                  builder: (context) {
                                    final date = DateTime(
                                      _month.year,
                                      _month.month,
                                      day,
                                    );
                                    final iso = isoOf(date);
                                    final union = buildOrdoDayUnion([
                                      for (final diocese in dioceses)
                                        OrdoRuntime.engine.resolve(
                                          iso,
                                          diocese: diocese,
                                        ),
                                    ]);
                                    final isToday = DateUtils.isSameDay(
                                      date,
                                      today,
                                    );
                                    final selected = DateUtils.isSameDay(
                                      date,
                                      widget.initialDate,
                                    );
                                    return Padding(
                                      key: DateUtils.isSameDay(date, target)
                                          ? _anchor
                                          : null,
                                      padding: const EdgeInsets.only(bottom: 2),
                                      child: Semantics(
                                        selected: selected,
                                        child: Material(
                                          color: selected
                                              ? cs.primary.withValues(
                                                  alpha: .07,
                                                )
                                              : isToday
                                              ? cs.onSurface.withValues(
                                                  alpha: .04,
                                                )
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          child: InkWell(
                                            key: Key('ordo-day-$iso'),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            onTap: () => context.push(
                                              Uri(
                                                path: '/hours/ordo',
                                                queryParameters: {
                                                  'date': iso,
                                                  'diocese': ?widget.diocese,
                                                },
                                              ).toString(),
                                            ),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 12,
                                                  ),
                                              child: Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  SizedBox(
                                                    width: 48,
                                                    child: Column(
                                                      children: [
                                                        Text(
                                                          '$day',
                                                          style: theme
                                                              .textTheme
                                                              .titleLarge
                                                              ?.copyWith(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color:
                                                                    date.weekday ==
                                                                        DateTime
                                                                            .sunday
                                                                    ? cs.error
                                                                    : cs.onSurface,
                                                              ),
                                                        ),
                                                        Text(
                                                          DateFormat(
                                                            'EE',
                                                            'be',
                                                          ).format(date),
                                                          style: theme
                                                              .textTheme
                                                              .bodyMedium,
                                                        ),
                                                        if (isToday)
                                                          Container(
                                                            margin:
                                                                const EdgeInsets.only(
                                                                  top: 4,
                                                                ),
                                                            width: 6,
                                                            height: 6,
                                                            decoration:
                                                                BoxDecoration(
                                                                  color: cs
                                                                      .primary,
                                                                  shape: BoxShape
                                                                      .circle,
                                                                ),
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .stretch,
                                                      children: [
                                                        for (final row
                                                            in union.rows)
                                                          _MonthEntry(row: row),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthEntry extends StatelessWidget {
  const _MonthEntry({required this.row});
  final OrdoUnionRow row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final option = row.option;
    final secondary = row.role != 'primary';
    final metadata = [
      if (!option.isTemporal || secondary) ordoRankLabel(option),
      if (row.role == 'alternative') 'на выбар',
      if (row.role == 'commemoration') 'успамін (commemoratio)',
      ...row.badges,
    ].where((s) => s.isNotEmpty).join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  option.title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontSize: 16,
                    fontWeight: secondary ? FontWeight.w400 : FontWeight.w600,
                    color: secondary
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.onSurface,
                  ),
                ),
                if (metadata.isNotEmpty)
                  Text(
                    metadata,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 13,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: VestmentMarker(
              colors: [option.color, ...option.colorAlternatives],
              size: 12,
            ),
          ),
        ],
      ),
    );
  }
}
