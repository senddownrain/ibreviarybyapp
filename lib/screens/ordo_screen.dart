import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:mybrev_flutter/constants/liturgical.dart';
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/content/content_store.dart';
import 'package:mybrev_flutter/ordo/dates.dart';
import 'package:mybrev_flutter/ordo/day_union.dart';
import 'package:mybrev_flutter/ordo/definitions.dart';
import 'package:mybrev_flutter/ordo/reading_references.dart';
import 'package:mybrev_flutter/ordo/runtime.dart';
import 'package:mybrev_flutter/providers/cache_epoch_provider.dart';
import 'package:mybrev_flutter/providers/diocese_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_navigation_sync_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/services/liturgical_content_service.dart';
import 'package:mybrev_flutter/theme/glass.dart';
import 'package:mybrev_flutter/theme/reader.dart';
import 'package:mybrev_flutter/utils/liturgical_titles.dart';
import 'package:mybrev_flutter/utils/liturgical_visual.dart';
import 'package:mybrev_flutter/widgets/adaptive_app_bar.dart';
import 'package:mybrev_flutter/widgets/ordo/vestment_marker.dart';
import 'package:mybrev_flutter/widgets/reader/reader_navigation.dart';

/// Ordo notes are decoded only when the Ordo is opened (lazy, after the
/// Hours core).
final ordoNotesReadyProvider = FutureProvider<void>((ref) async {
  await ContentStore.instance.ensureLoaded(kOrdoNotesCollections);
});

/// The Ordo of one date for the selected dioceses.
final ordoDayUnionProvider = Provider.family<OrdoDayUnion, String>((ref, iso) {
  ref.watch(cacheEpochProvider);
  final dioceses = ref.watch(dioceseSelectionProvider).ordered;
  final engine = OrdoRuntime.engine;
  return buildOrdoDayUnion([
    for (final diocese in dioceses) engine.resolve(iso, diocese: diocese),
  ]);
});

const _weekdays = ['Пн', 'Аў', 'Ср', 'Чц', 'Пт', 'Сб', 'Нд'];

/// The liturgical calendar (Ordo): a month with the real vestment colours
/// of every date, and the selected day in detail under it.
class OrdoScreen extends ConsumerStatefulWidget {
  const OrdoScreen({super.key, required this.initialDate});

  final DateTime initialDate;

  @override
  ConsumerState<OrdoScreen> createState() => _OrdoScreenState();
}

class _OrdoScreenState extends ConsumerState<OrdoScreen> {
  late String _selected = isoOf(widget.initialDate);
  late DateTime _month = DateTime(
    widget.initialDate.year,
    widget.initialDate.month,
  );

  void _select(String iso) {
    setState(() {
      _selected = iso;
      final date = dateOfIso(iso);
      _month = DateTime(date.year, date.month);
    });
  }

  void _moveMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  @override
  Widget build(BuildContext context) {
    final ready = ref.watch(liturgicalContentReadyProvider);
    ref.watch(ordoNotesReadyProvider);
    final today = isoOf(DateTime.now());
    final union = ready.hasValue
        ? ref.watch(ordoDayUnionProvider(_selected))
        : null;
    final primary = union?.first.primary;
    final visual = primary == null
        ? null
        : liturgicalVisual(
            color: primary.color,
            category: primary.category,
            rank: primary.rank,
          );
    final accent = visual?.accent ?? Theme.of(context).colorScheme.primary;
    final top = MediaQuery.paddingOf(context).top + 64;
    // Narrow phones: a slimmer gutter keeps the seven day cells wide enough
    // to tap (≥ 44 pt from 360 px; the 320 px exception is documented).
    final gutter = MediaQuery.sizeOf(context).width < 380 ? 8.0 : 16.0;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AdaptiveAppBar(
        title: const Text('Каляндар'),
        actions: [
          if (_selected != today)
            TextButton(
              key: const Key('ordo-today'),
              onPressed: () => _select(today),
              child: const Text('Сёння'),
            ),
        ],
      ),
      body: Stack(
        children: [
          AmbientWash.hero(seasonColor: accent),
          if (union == null)
            const Center(child: CircularProgressIndicator.adaptive())
          else
            Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
                  key: const Key('ordo-scroll'),
                  padding: EdgeInsets.fromLTRB(
                    gutter,
                    top + 4,
                    gutter,
                    32 + MediaQuery.viewPaddingOf(context).bottom,
                  ),
                  children: [
                    _MonthHeader(
                      month: _month,
                      onPrevious: () => _moveMonth(-1),
                      onNext: () => _moveMonth(1),
                    ),
                    const SizedBox(height: 8),
                    _MonthGrid(
                      month: _month,
                      selected: _selected,
                      today: today,
                      accent: accent,
                      onSelect: _select,
                    ),
                    const SizedBox(height: 18),
                    _DayDetail(
                      key: ValueKey('ordo-detail-$_selected'),
                      union: union,
                      accent: accent,
                      marianAccent: visual?.marianAccent ?? false,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.month,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

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
          child: Text(
            '${label[0].toUpperCase()}${label.substring(1)}',
            key: const Key('ordo-month-label'),
            textAlign: TextAlign.center,
            style: ReaderTheme.of(context).displayTitle(24),
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

class _MonthGrid extends ConsumerWidget {
  const _MonthGrid({
    required this.month,
    required this.selected,
    required this.today,
    required this.accent,
    required this.onSelect,
  });

  final DateTime month;
  final String selected;
  final String today;
  final Color accent;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(cacheEpochProvider);
    final dioceses = ref.watch(dioceseSelectionProvider).ordered;
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
    return GlassSurface(
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
                                for (final color
                                    in engine
                                        .resolve(iso, diocese: diocese)
                                        .legalColors) {
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
      label:
          '${dayMonthLabel(iso)}${isToday ? ', сёння' : ''}. Колер: $colorLabel',
      excludeSemantics: true,
      child: InkWell(
        key: Key('ordo-day-$iso'),
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            color: isSelected ? accent.withValues(alpha: 0.18) : null,
            borderRadius: BorderRadius.circular(14),
            border: isToday
                ? Border.all(
                    color: Color.lerp(accent, cs.onSurface, 0.2)!,
                    width: 1.6,
                  )
                : isSelected
                ? Border.all(color: accent.withValues(alpha: 0.55))
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$day',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: isSelected || isToday || sunday
                      ? FontWeight.w800
                      : FontWeight.w500,
                  color: sunday ? cs.error : cs.onSurface,
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

class _DayDetail extends ConsumerWidget {
  const _DayDetail({
    super.key,
    required this.union,
    required this.accent,
    required this.marianAccent,
  });

  final OrdoDayUnion union;
  final Color accent;
  final bool marianAccent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final day = union.first;
    final date = dateOfIso(day.date);
    final weekday = DateFormat('EEEE', 'be').format(date);
    final psalter = toRomanNumeral(day.psalterWeek);
    final cycle = day.period == 'ordinary' && !day.season.isSunday
        ? 'Год ${day.readingCycle.weekday == '1' ? 'I' : 'II'}'
        : 'Год ${day.readingCycle.sunday}';
    final periodTitle = formatLiturgicalPeriodTitle(
      periodType: day.period,
      periodWeek: day.week,
      dayOfWeek: day.dayOfWeek,
      date: date,
    );
    final notesReady = OrdoRuntime.notesReady;
    final engine = OrdoRuntime.engine;
    final notes = <String, (Json, List<String>)>{};
    if (notesReady) {
      for (final ordo in union.days) {
        for (final note in engine.notesOf(ordo)) {
          final id = '${note['id']}';
          final entry = notes[id] ??= (note, <String>[]);
          entry.$2.add(ordo.diocese);
        }
      }
    }
    final index = ReadingReferenceIndex.current();
    final references = {
      for (final ordo in union.days)
        ordo.diocese: {
          for (final item in readingReferencesForDay(ordo, index))
            item.optionId: item,
        },
    };

    return GlassSurface(
      key: const Key('ordo-day-detail'),
      seasonColor: accent,
      accentBar: accent,
      padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${weekday[0].toUpperCase()}${weekday.substring(1)}, '
            '${DateFormat('d MMMM y', 'be').format(date)}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            [
              periodLabelMap[day.period] ?? '',
              if (periodTitle.isNotEmpty) periodTitle,
            ].where((p) => p.isNotEmpty).join(' · '),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            [
              if (psalter.isNotEmpty) '$psalter тыдзень Псалтыра',
              cycle,
            ].join(' · '),
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          VestmentColorLine(colors: union.colors, marianAccent: marianAccent),
          if (union.days.length > 1 && union.differs) ...[
            const SizedBox(height: 10),
            _Explain(
              text:
                  'Выбраныя дыяцэзіі адрозніваюцца ў гэты дзень: святкаванні '
                  'асобных дыяцэзій пазначаны іх назвамі.',
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'СВЯТКАВАННІ ДНЯ',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.9,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          for (final row in union.rows)
            _CelebrationRow(
              row: row,
              date: date,
              references: references[row.dioceses.first]?[row.option.id],
            ),
          const SizedBox(height: 14),
          FilledButton.icon(
            key: const Key('ordo-open-hours'),
            style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () => _openHours(context, ref, date, null, null),
            icon: const PhosphorIcon(PhosphorIconsRegular.clock, size: 20),
            label: const Text('Літургія гадзін гэтага дня'),
          ),
          const SizedBox(height: 18),
          Text(
            'НАТАТКІ ORDO',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.9,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          if (!notesReady)
            Text(
              'Нататкі адкрываюцца…',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            )
          else if (notes.isEmpty)
            Text(
              'Для гэтага дня нататак няма.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            )
          else
            for (final (note, dioceses) in notes.values)
              _NoteRow(
                note: note,
                badges: dioceses.length == union.days.length
                    ? const []
                    : [for (final id in dioceses) kDioceseBadges[id] ?? id],
              ),
        ],
      ),
    );
  }
}

/// Opens the Hours of [date] (optionally one option in one diocese).
void _openHours(
  BuildContext context,
  WidgetRef ref,
  DateTime date,
  String? optionId,
  String? diocese,
) {
  String? dayId;
  if (optionId != null) {
    final content = LiturgicalContentService().contentForDate(
      date,
      diocese: diocese ?? kDefaultDiocese,
    );
    dayId = content.options
        .where((option) => option.ordo?.optionId == optionId)
        .firstOrNull
        ?.dayId;
  }
  ref
      .read(liturgicalNavigationControllerProvider)
      .openDate(date, dayId: dayId, diocese: dayId == null ? null : diocese);
  context.go('/hours');
}

class _Explain extends StatelessWidget {
  const _Explain({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PhosphorIcon(PhosphorIconsRegular.info, size: 18, color: cs.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }
}

class _CelebrationRow extends ConsumerWidget {
  const _CelebrationRow({
    required this.row,
    required this.date,
    required this.references,
  });

  final OrdoUnionRow row;
  final DateTime date;
  final OptionReadingReferences? references;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final option = row.option;
    final role = switch (row.role) {
      'primary' => 'Асноўнае',
      'alternative' => 'Па выбары',
      _ => 'Успамін (commemoratio)',
    };
    final rank = ordoRankLabel(option);
    final diocese = row.dioceses.first;
    final canOpen = row.role != 'commemoration';
    final chips = [...row.badges, ...ordoOptionNotes(option)];
    return Padding(
      key: Key('ordo-row-${option.id}-${row.role}'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: VestmentMarker(
              colors: [option.color, ...option.colorAlternatives],
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [role.toUpperCase(), if (rank.isNotEmpty) rank].join(' · '),
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  option.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: row.role == 'primary'
                        ? FontWeight.w800
                        : FontWeight.w600,
                  ),
                ),
                Text(
                  'Колер: ${vestmentColorsLabel(option)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                if (chips.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [for (final chip in chips) _Badge(chip)],
                  ),
                ],
                if (references != null) ...[
                  const SizedBox(height: 6),
                  _References(references: references!),
                ],
                if (canOpen)
                  Wrap(
                    spacing: 4,
                    children: [
                      TextButton.icon(
                        key: Key('ordo-hours-${option.id}'),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(48, 44),
                        ),
                        onPressed: () =>
                            _openHours(context, ref, date, option.id, diocese),
                        icon: const PhosphorIcon(
                          PhosphorIconsRegular.clock,
                          size: 18,
                        ),
                        label: const Text('Гадзіны'),
                      ),
                      TextButton.icon(
                        key: Key('ordo-readings-${option.id}'),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(48, 44),
                        ),
                        onPressed: () {
                          final content = LiturgicalContentService()
                              .contentForDate(date, diocese: diocese);
                          final dayId = content.options
                              .where((o) => o.ordo?.optionId == option.id)
                              .firstOrNull
                              ?.dayId;
                          context.go(
                            readingsRouteForContext(
                              date: date,
                              dayId: dayId,
                              diocese: diocese,
                              optionId: option.id,
                            ),
                          );
                        },
                        icon: const PhosphorIcon(
                          PhosphorIconsRegular.bookOpen,
                          size: 18,
                        ),
                        label: const Text('Чытанні'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: cs.onSecondaryContainer),
      ),
    );
  }
}

class _References extends StatelessWidget {
  const _References({required this.references});
  final OptionReadingReferences references;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final small = theme.textTheme.bodySmall;
    if (references.status == ReadingReferenceStatus.referenceOnly) {
      return Text(
        'Чытанні: ${references.reference}',
        key: const Key('ordo-reference-only'),
        style: small,
      );
    }
    final doc = references.documents.firstOrNull;
    if (doc == null || doc.rows.isEmpty) {
      return Text(
        'Тэкст / спасылкі пакуль недаступныя',
        key: const Key('ordo-readings-missing'),
        style: small?.copyWith(color: cs.onSurfaceVariant),
      );
    }
    return Column(
      key: const Key('ordo-reading-references'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final row in doc.rows)
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${row.label} ',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: row.citation),
              ],
            ),
            style: small,
          ),
        if (references.alternatives.isNotEmpty)
          Text(
            'Або ўласныя чытанні святкавання',
            style: small?.copyWith(color: cs.onSurfaceVariant),
          ),
      ],
    );
  }
}

class _NoteRow extends StatelessWidget {
  const _NoteRow({required this.note, required this.badges});
  final Json note;
  final List<String> badges;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = '${note['text'] ?? note['title'] ?? ''}'.trim();
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: theme.textTheme.bodyMedium),
                if (badges.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Wrap(
                      spacing: 6,
                      children: [for (final badge in badges) _Badge(badge)],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
