import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:mybrev_flutter/constants/liturgical.dart';
import 'package:mybrev_flutter/ordo/dates.dart';
import 'package:mybrev_flutter/ordo/day_union.dart';
import 'package:mybrev_flutter/ordo/definitions.dart';
import 'package:mybrev_flutter/ordo/reading_references.dart';
import 'package:mybrev_flutter/ordo/runtime.dart';
import 'package:mybrev_flutter/providers/diocese_provider.dart';
import 'package:mybrev_flutter/providers/cache_epoch_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/services/liturgical_content_service.dart';
import 'package:mybrev_flutter/providers/ordo_provider.dart';
import 'package:mybrev_flutter/utils/hours_liturgical_options.dart';
import 'package:mybrev_flutter/widgets/ordo/liturgical_month_calendar.dart';
import 'package:mybrev_flutter/theme/glass.dart';
import 'package:mybrev_flutter/theme/reader.dart';
import 'package:mybrev_flutter/utils/liturgical_titles.dart';
import 'package:mybrev_flutter/utils/liturgical_visual.dart';
import 'package:mybrev_flutter/widgets/adaptive_app_bar.dart';
import 'package:mybrev_flutter/widgets/ordo/vestment_marker.dart';
import 'package:mybrev_flutter/widgets/reader/reader_navigation.dart';

export 'package:mybrev_flutter/providers/ordo_provider.dart';

/// Backwards-compatible day entry; the month has its own route and screen.
class OrdoScreen extends ConsumerWidget {
  const OrdoScreen({
    super.key,
    required this.initialDate,
    this.dayId,
    this.diocese,
  });
  final DateTime initialDate;
  final String? dayId;
  final String? diocese;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(cacheEpochProvider);
    final ready = ref.watch(liturgicalContentReadyProvider);
    final notes = ref.watch(ordoNotesReadyProvider);
    final iso = isoOf(initialDate);
    final selected = ref.watch(dioceseSelectionProvider).ordered;
    final union = !ready.hasValue
        ? null
        : diocese == null
        ? ref.watch(ordoDayUnionProvider(iso))
        : buildOrdoDayUnion([
            for (final id in <String>{diocese!, ...selected})
              OrdoRuntime.engine.resolve(iso, diocese: id),
          ]);
    final primary = union?.first.primary;
    final visual = primary == null
        ? null
        : liturgicalVisual(
            color: primary.color,
            category: primary.category,
            rank: primary.rank,
          );
    final accent = visual?.accent ?? Theme.of(context).colorScheme.primary;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AdaptiveAppBar(title: const Text('Ordo дня')),
      body: Stack(
        children: [
          AmbientWash.hero(seasonColor: accent),
          if (ready.hasError)
            const Center(child: Text('Не ўдалося адкрыць Ordo'))
          else if (union == null)
            const Center(child: CircularProgressIndicator.adaptive())
          else
            Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
                  key: const Key('ordo-scroll'),
                  padding: EdgeInsets.fromLTRB(
                    12,
                    MediaQuery.paddingOf(context).top +
                        kFloatingAppBarContentInset,
                    12,
                    24 + MediaQuery.viewPaddingOf(context).bottom,
                  ),
                  children: [
                    _DayDetail(
                      union: union,
                      accent: accent,
                      marianAccent: visual?.marianAccent ?? false,
                      dayId: dayId,
                      notesError: notes.hasError,
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      key: const Key('ordo-open-month'),
                      leading: const PhosphorIcon(
                        PhosphorIconsRegular.calendarDots,
                      ),
                      title: Text(
                        '${DateFormat('LLLL y', 'be').format(initialDate)} · увесь каляндар',
                      ),
                      trailing: const PhosphorIcon(
                        PhosphorIconsRegular.caretRight,
                      ),
                      onTap: () => context.push(
                        Uri(
                          path: '/hours/ordo/month',
                          queryParameters: {'date': iso, 'diocese': ?diocese},
                        ).toString(),
                      ),
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

class OrdoMonthScreen extends StatelessWidget {
  const OrdoMonthScreen({super.key, required this.initialDate, this.diocese});
  final DateTime initialDate;
  final String? diocese;
  @override
  Widget build(BuildContext context) => Scaffold(
    extendBodyBehindAppBar: true,
    appBar: AdaptiveAppBar(title: const Text('Літургічны каляндар')),
    body: Stack(
      children: [
        AmbientWash.hero(seasonColor: Theme.of(context).colorScheme.primary),
        Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                8,
                MediaQuery.paddingOf(context).top + kFloatingAppBarContentInset,
                8,
                24 + MediaQuery.viewPaddingOf(context).bottom,
              ),
              children: [
                LiturgicalMonthCalendar(
                  initialDate: initialDate,
                  diocese: diocese,
                  onSelected: (date) => context.push(
                    Uri(
                      path: '/hours/ordo',
                      queryParameters: {
                        'date': isoOf(date),
                        'diocese': ?diocese,
                      },
                    ).toString(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _DayDetail extends ConsumerWidget {
  const _DayDetail({
    required this.union,
    required this.accent,
    required this.marianAccent,
    this.dayId,
    this.notesError = false,
  });

  final OrdoDayUnion union;
  final Color accent;
  final bool marianAccent;
  final String? dayId;
  final bool notesError;

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
          final variants = note['variants'];
          final variant = variants is List
              ? variants
                    .whereType<Map>()
                    .where((item) => item['diocese'] == ordo.diocese)
                    .firstOrNull
              : null;
          final display = {...note, 'text': variant?['text'] ?? note['text']};
          final id = '${note['id']}|${display['text']}';
          final entry = notes[id] ??= (display, <String>[]);
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

    final groups = <String, List<Widget>>{};
    const labels = {
      'liturgical-rule': 'Літургічныя ўказанні',
      'mass': 'Імша',
      'office': 'Літургія гадзін',
      'devotion': 'Набажэнствы',
      'blessing': 'Благаслаўленні',
      'procession': 'Працэсіі',
      'indulgence': 'Адпусты',
      'special-prayer-day': 'Асаблівыя дні малітвы',
      'pastoral-note': 'Дыяцэзіяльныя і душпастырскія заўвагі',
      'announcement': 'Аб’явы',
      'other': 'Іншыя заўвагі',
    };
    for (final (note, dioceses) in notes.values) {
      final selector = note['selector'];
      final periodNote =
          selector is Map &&
          ['period', 'period-phase'].contains(selector['type']);
      final category = '${note['category'] ?? 'other'}';
      final group = periodNote
          ? 'Агульныя ўказанні перыяду'
          : labels[category] ?? 'Іншыя заўвагі';
      groups
          .putIfAbsent(group, () => [])
          .add(
            _NoteRow(
              note: note,
              badges: dioceses.length == union.days.length
                  ? const []
                  : [for (final id in dioceses) kDioceseBadges[id] ?? id],
            ),
          );
    }
    final massNotes = groups.remove('Імша') ?? const <Widget>[];
    final officeNotes = groups.remove('Літургія гадзін') ?? const <Widget>[];
    final directionNotes =
        groups.remove('Літургічныя ўказанні') ?? const <Widget>[];
    final legal = union.rows
        .where((row) => row.role != 'commemoration')
        .toList();
    final chosen =
        legal
            .where(
              (row) => LiturgicalContentService()
                  .contentForDate(date, diocese: row.dioceses.first)
                  .options
                  .any(
                    (option) =>
                        option.optionId == row.option.id &&
                        dayId != null &&
                        option.ownsDayId(dayId!),
                  ),
            )
            .firstOrNull ??
        legal.first;
    final suppressed = <String, (String, List<String>)>{};
    for (final ordo in union.days) {
      for (final option in ordo.suppressed) {
        (suppressed[option.id] ??= (
          option.title,
          <String>[],
        )).$2.add(ordo.diocese);
      }
    }
    return Column(
      key: const Key('ordo-day-detail'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassSurface(
          seasonColor: accent,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${weekday[0].toUpperCase()}${weekday.substring(1)}',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('d MMMM y', 'be').format(date),
                style: ReaderTheme.of(context).displayTitle(28),
              ),
              const SizedBox(height: 8),
              Text(
                [
                  periodLabelMap[day.period] ?? '',
                  if (periodTitle.isNotEmpty) periodTitle,
                ].where((p) => p.isNotEmpty).join(' · '),
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 4),
              Text(
                [if (psalter.isNotEmpty) 'Псалтыр $psalter', cycle].join(' · '),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              VestmentColorLine(
                colors: union.colors,
                marianAccent: marianAccent,
              ),
              if (union.days.length > 1 && union.differs) ...[
                const SizedBox(height: 12),
                const _Explain(
                  text:
                      'Выбраныя дыяцэзіі адрозніваюцца ў гэты дзень: святкаванні асобных дыяцэзій пазначаны іх назвамі.',
                ),
              ],
            ],
          ),
        ),
        _Section(
          title: 'Святкаванне дня',
          accent: accent,
          children: [
            for (final row in union.rows) _CelebrationRow(row: row),
            if (suppressed.isNotEmpty)
              ExpansionTile(
                title: const Text('Святкаванні, якія саступаюць месца'),
                children: [
                  for (final (title, dioceses) in suppressed.values)
                    ListTile(
                      title: Text(title),
                      subtitle: dioceses.length == union.days.length
                          ? null
                          : Text(
                              dioceses
                                  .map((id) => kDioceseBadges[id] ?? id)
                                  .join(' · '),
                            ),
                    ),
                ],
              ),
          ],
        ),
        _Section(
          title: 'Імша і чытанні',
          accent: accent,
          children: [
            Text(cycle, style: theme.textTheme.bodyLarge),
            for (final row in legal) ...[
              const SizedBox(height: 12),
              Text(row.option.title, style: theme.textTheme.titleMedium),
              if (row.badges.isNotEmpty) Text(row.badges.join(' · ')),
              if (references[row.dioceses.first]?[row.option.id]
                  case final refs?)
                _References(references: refs),
              _Action(
                key: Key('ordo-readings-${row.option.id}'),
                label: 'Адкрыць чытанні',
                onTap: () =>
                    _openReadings(context, date, row, selectedDayId: dayId),
              ),
            ],
            ...massNotes,
          ],
        ),
        _Section(
          title: 'Літургія гадзін',
          accent: accent,
          children: [
            Text(
              'Псалтыр $psalter · уласныя і агульныя тэксты паводле Ordo',
              style: theme.textTheme.bodyLarge,
            ),
            for (final row in legal) ...[
              const SizedBox(height: 12),
              Text(
                '${row.option.title} · ${ordoOfficeKindLabel(row.option.officeKind)}',
                style: theme.textTheme.titleMedium,
              ),
              if (row.badges.isNotEmpty) Text(row.badges.join(' · ')),
              for (final option
                  in LiturgicalContentService()
                      .contentForDate(date, diocese: row.dioceses.first)
                      .options
                      .where((o) => o.optionId == row.option.id))
                if (option.templates.length > 1) ...[
                  const SizedBox(height: 8),
                  const Text('Варыянт Літургіі гадзін'),
                  for (final template in option.templates)
                    _Action(
                      key: Key('ordo-template-${template.id}'),
                      label: template.label,
                      onTap: () => context.push(
                        horaRouteForContext(
                          date: date,
                          dayId: template.id,
                          diocese: row.dioceses.first,
                          optionId: row.option.id,
                        ),
                      ),
                    ),
                ],
              _Action(
                key: Key('ordo-hours-${row.option.id}'),
                label: 'Адкрыць літургію гадзін',
                onTap: () => _openHours(
                  context,
                  ref,
                  date,
                  row.option.id,
                  row.dioceses.first,
                  selectedDayId: dayId,
                ),
              ),
            ],
            for (final row in union.rows.where(
              (r) => r.role == 'commemoration',
            ))
              Text(
                'Успамін: ${row.option.title}',
                style: theme.textTheme.bodyLarge,
              ),
            _Action(
              key: const Key('ordo-open-hours'),
              label: 'Літургія гадзін гэтага дня',
              onTap: () => _openHours(
                context,
                ref,
                date,
                chosen.option.id,
                chosen.dioceses.first,
                selectedDayId: dayId,
              ),
            ),
            ...officeNotes,
          ],
        ),
        _Section(
          title: 'Асаблівыя ўказанні',
          accent: accent,
          children: [
            for (final ordo in union.days) ...[
              if (union.days.length > 1)
                Text(
                  kDioceseBadges[ordo.diocese] ?? ordo.diocese,
                  style: theme.textTheme.titleMedium,
                ),
              Text(switch (ordo.evening.vespersType) {
                'first' => 'Першыя нешпары: ${ordo.evening.title}',
                'second' => 'Другія нешпары: ${ordo.evening.title}',
                _ => 'Нешпары гэтага дня: ${ordo.evening.title}',
              }, style: theme.textTheme.bodyLarge),
              if (ordo.firstVespersCelebratedOnEve)
                const Text('Першыя нешпары святкавання — напярэдадні.'),
              for (final row in legal.where(
                (r) => r.dioceses.contains(ordo.diocese),
              )) ...[
                const SizedBox(height: 6),
                Text(
                  '${legal.length > 1 ? '${row.option.title}: ' : ''}Te Deum ${ordo.office(row.option.id)!.teDeum ? 'спяваецца' : 'не спяваецца'}',
                ),
                for (final note in ordo.office(row.option.id)!.notes)
                  Text(note),
              ],
              const SizedBox(height: 6),
              Text('Камплета: ${_complineLabel(ordo.evening.compline)}'),
              if (ordo.evening.omittedFirstVespers != null)
                const Text(
                  'Першыя нешпары наступнага святкавання саступаюць нешпарам гэтага дня.',
                ),
              const SizedBox(height: 8),
            ],
            ...directionNotes,
          ],
        ),
        _Section(
          title: 'Заўвагі ORDO',
          accent: accent,
          children: [
            if (notesError)
              const Text(
                'Не ўдалося прачытаць заўвагі Ordo. Паспрабуйце адкрыць дзень яшчэ раз.',
              )
            else if (!notesReady)
              const Text('Заўвагі адкрываюцца…')
            else if (groups.isEmpty)
              const Text('Для гэтага дня заўваг няма.')
            else
              for (final entry in groups.entries)
                if (entry.key == 'Літургічныя ўказанні')
                  ...entry.value
                else
                  ExpansionTile(
                    key: PageStorageKey('ordo-notes-${day.date}-${entry.key}'),
                    title: Text(entry.key),
                    tilePadding: EdgeInsets.zero,
                    children: entry.value,
                  ),
          ],
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.accent,
    required this.children,
  });
  final String title;
  final Color accent;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: GlassSurface(
      seasonColor: accent,
      padding: const EdgeInsets.all(18),
      child: DefaultTextStyle.merge(
        style: const TextStyle(fontSize: 16, height: 1.4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    ),
  );
}

class _Action extends StatelessWidget {
  const _Action({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => TextButton(
    style: TextButton.styleFrom(
      minimumSize: const Size(48, 48),
      alignment: Alignment.centerLeft,
    ),
    onPressed: onTap,
    child: Row(
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 8),
        const PhosphorIcon(PhosphorIconsRegular.caretRight, size: 18),
      ],
    ),
  );
}

String _complineLabel(String value) => switch (value) {
  'current-weekday' => 'з гэтага дня тыдня',
  'sunday-after-first-vespers' => 'пасля першых нешпараў нядзелі',
  'sunday-after-second-vespers' => 'пасля другіх нешпараў нядзелі',
  'sunday-after-first-or-second-vespers' =>
    'пасля першых або другіх нешпараў нядзелі',
  _ => 'спецыяльны варыянт; апісанне пакуль недаступнае',
};

void _openReadings(
  BuildContext context,
  DateTime date,
  OrdoUnionRow row, {
  String? selectedDayId,
}) {
  final diocese = row.dioceses.first;
  final option = LiturgicalContentService()
      .contentForDate(date, diocese: diocese)
      .options
      .where((o) => o.optionId == row.option.id)
      .firstOrNull;
  context.push(
    readingsRouteForContext(
      date: date,
      dayId:
          option != null &&
              selectedDayId != null &&
              option.ownsDayId(selectedDayId)
          ? selectedDayId
          : option?.dayId,
      diocese: diocese,
      optionId: row.option.id,
    ),
  );
}

/// Opens the Hours of [date] (optionally one option in one diocese).
void _openHours(
  BuildContext context,
  WidgetRef ref,
  DateTime date,
  String? optionId,
  String? diocese, {
  String? selectedDayId,
}) {
  final contextDiocese = diocese ?? ref.read(dioceseSelectionProvider).primary;
  final content = LiturgicalContentService().contentForDate(
    date,
    diocese: contextDiocese,
  );
  final option = content.options
      .where((o) => o.optionId == optionId)
      .firstOrNull;
  final selection = resolveHoursLiturgicalSelection(
    option == null ? content.options : [option],
    selectedDayId: selectedDayId,
    selectedDiocese: contextDiocese,
  );
  if (selection.dayId case final id?) {
    context.push(
      horaRouteForContext(
        date: date,
        dayId: id,
        diocese: contextDiocese,
        optionId: selection.selected?.optionId,
      ),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Тэксты Літургіі гадзін гэтага святкавання пакуль недаступныя.',
        ),
      ),
    );
  }
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
          child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
        ),
      ],
    );
  }
}

class _CelebrationRow extends StatelessWidget {
  const _CelebrationRow({required this.row});

  final OrdoUnionRow row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final option = row.option;
    final role = switch (row.role) {
      'primary' => 'Асноўнае',
      'alternative' => 'Па выбары',
      _ => 'Успамін (commemoratio)',
    };
    final rank = ordoRankLabel(option);
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
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  option.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: row.role == 'primary' ? 24 : 20,
                    fontWeight: row.role == 'primary'
                        ? FontWeight.w800
                        : FontWeight.w600,
                  ),
                ),
                Text(
                  'Колер: ${vestmentColorsLabel(option)}',
                  style: theme.textTheme.bodyLarge?.copyWith(
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
        ).textTheme.bodyMedium?.copyWith(color: cs.onSecondaryContainer),
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
    final small = theme.textTheme.bodyLarge;
    if (references.status == ReadingReferenceStatus.referenceOnly) {
      return Text(
        'Чытанні: ${references.reference}',
        key: const Key('ordo-reference-only'),
        style: small,
      );
    }
    final documents = [...references.documents, ...references.alternatives];
    if (documents.isEmpty || documents.every((d) => d.rows.isEmpty)) {
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
        for (final doc in documents) ...[
          const SizedBox(height: 8),
          if (references.alternatives.contains(doc))
            Text(
              'Або ўласныя чытанні святкавання',
              style: small?.copyWith(fontWeight: FontWeight.w700),
            ),
          if (documents.length > 1 && doc.title.isNotEmpty)
            Text(doc.title, style: small),
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
        ],
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
                Text(text, style: theme.textTheme.bodyLarge),
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
