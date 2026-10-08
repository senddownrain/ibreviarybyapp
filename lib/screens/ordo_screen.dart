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
import 'package:mybrev_flutter/providers/liturgical_navigation_sync_provider.dart';
import 'package:mybrev_flutter/theme/glass.dart';
import 'package:mybrev_flutter/utils/liturgical_titles.dart';
import 'package:mybrev_flutter/utils/liturgical_visual.dart';
import 'package:mybrev_flutter/widgets/adaptive_app_bar.dart';
import 'package:mybrev_flutter/widgets/ordo/vestment_marker.dart';
import 'package:mybrev_flutter/widgets/reader/reader_navigation.dart';
import 'package:mybrev_flutter/widgets/liturgical_calendar_sheet.dart';
import 'package:mybrev_flutter/utils/civil_date.dart';
import 'package:mybrev_flutter/content/content_store.dart';
import 'package:mybrev_flutter/models/mass_reading_sets.dart';
import 'package:url_launcher/url_launcher.dart';

export 'package:mybrev_flutter/providers/ordo_provider.dart';
export 'package:mybrev_flutter/screens/ordo_month_screen.dart';

/// Backwards-compatible day entry; the month has its own route and screen.
class OrdoScreen extends ConsumerStatefulWidget {
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
  ConsumerState<OrdoScreen> createState() => _OrdoScreenState();
}

class _OrdoScreenState extends ConsumerState<OrdoScreen> {
  late DateTime _date = DateUtils.dateOnly(widget.initialDate);
  bool _calendarOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(liturgicalContentReadyProvider.future);
      if (!mounted) return;
      final saved = ref.read(hoursLiturgicalOverridesProvider)[isoOf(_date)];
      final id =
          widget.dayId ??
          saved?.dayId ??
          (widget.diocese == null
              ? null
              : resolveHoursLiturgicalSelection(
                  LiturgicalContentService()
                      .contentForDate(_date, diocese: widget.diocese!)
                      .options,
                ).dayId);
      ref
          .read(liturgicalNavigationControllerProvider)
          .openDate(
            _date,
            dayId: id,
            diocese: widget.diocese ?? saved?.diocese,
          );
    });
  }

  void _moveDay(int delta) {
    final date = addCivilDays(_date, delta);
    if (date.isBefore(kCalendarFirstDate) || date.isAfter(kCalendarLastDate)) {
      return;
    }
    setState(() => _date = date);
    final saved = ref.read(hoursLiturgicalOverridesProvider)[isoOf(date)];
    final diocese = saved?.diocese ?? widget.diocese;
    final id =
        saved?.dayId ??
        (diocese == null
            ? null
            : resolveHoursLiturgicalSelection(
                LiturgicalContentService()
                    .contentForDate(date, diocese: diocese)
                    .options,
              ).dayId);
    ref
        .read(liturgicalNavigationControllerProvider)
        .openDate(date, dayId: id, diocese: diocese);
  }

  Future<void> _openCalendar() async {
    ref.read(liturgicalNavigationControllerProvider).openDate(_date);
    _calendarOpen = true;
    try {
      await showLiturgicalCalendarSheet(
        context: context,
        pickerRoute: '/hours/picker',
        diocese:
            ref.read(hoursLiturgicalSelectionProvider).diocese ??
            widget.diocese,
      );
    } finally {
      _calendarOpen = false;
    }
  }

  void _openMonth() => context.push(
    Uri(
      path: '/hours/ordo/month',
      queryParameters: {
        'date': isoOf(_date),
        'diocese':
            ?(ref
                .read(hoursLiturgicalOverridesProvider)[isoOf(_date)]
                ?.diocese ??
            widget.diocese),
      },
    ).toString(),
  );

  @override
  Widget build(BuildContext context) {
    ref.listen<DateTime>(selectedDateProvider, (_, date) {
      if (_calendarOpen && !DateUtils.isSameDay(_date, date)) {
        setState(() => _date = DateUtils.dateOnly(date));
      }
    });
    ref.watch(cacheEpochProvider);
    final ready = ref.watch(liturgicalContentReadyProvider);
    final notes = ref.watch(ordoNotesReadyProvider);
    final iso = isoOf(_date);
    final saved = ref.watch(hoursLiturgicalOverridesProvider)[iso];
    final effectiveDayId =
        saved?.dayId ??
        (DateUtils.isSameDay(_date, widget.initialDate) ? widget.dayId : null);
    final contextDiocese = saved?.diocese ?? widget.diocese;
    final selected = ref.watch(dioceseSelectionProvider).ordered;
    final union = !ready.hasValue
        ? null
        : contextDiocese == null
        ? ref.watch(ordoDayUnionProvider(iso))
        : buildOrdoDayUnion([
            for (final id in <String>{contextDiocese, ...selected})
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
      appBar: AdaptiveAppBar(
        title: const Text('Літургічны дзень'),
        actions: [
          IconButton(
            key: const Key('ordo-open-month'),
            tooltip: 'Літургічны каляндар',
            icon: const PhosphorIcon(PhosphorIconsRegular.listBullets),
            onPressed: _openMonth,
          ),
        ],
      ),
      body: Stack(
        children: [
          AmbientWash.hero(seasonColor: accent),
          if (ready.hasError)
            const Center(child: Text('Не ўдалося адкрыць літургічны дзень'))
          else if (union == null)
            const Center(child: CircularProgressIndicator.adaptive())
          else
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.only(
                  top:
                      MediaQuery.paddingOf(context).top +
                      kFloatingAppBarContentInset,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: ListView(
                    key: const Key('ordo-scroll'),
                    padding: EdgeInsets.fromLTRB(
                      12,
                      0,
                      12,
                      24 + MediaQuery.viewPaddingOf(context).bottom,
                    ),
                    children: [
                      _DayDetail(
                        union: union,
                        marianAccent: visual?.marianAccent ?? false,
                        dayId: effectiveDayId,
                        notesError: notes.hasError,
                        contextDiocese: contextDiocese,
                        onPrevious: _date.isAfter(kCalendarFirstDate)
                            ? () => _moveDay(-1)
                            : null,
                        onNext: _date.isBefore(kCalendarLastDate)
                            ? () => _moveDay(1)
                            : null,
                        onDateTap: _openCalendar,
                        onMonthTap: _openMonth,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DayDetail extends ConsumerWidget {
  const _DayDetail({
    required this.union,
    required this.marianAccent,
    this.dayId,
    this.notesError = false,
    this.contextDiocese,
    required this.onPrevious,
    required this.onNext,
    required this.onDateTap,
    required this.onMonthTap,
  });

  final OrdoDayUnion union;
  final bool marianAccent;
  final String? dayId;
  final bool notesError;
  final String? contextDiocese;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onDateTap;
  final VoidCallback onMonthTap;

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
    final periodTitle =
        formatLiturgicalPeriodTitle(
          periodType: day.period,
          periodWeek: day.week,
          dayOfWeek: day.dayOfWeek,
          date: date,
        ).replaceFirst(
          RegExp(',\\s*${RegExp.escape(weekday)}\$', caseSensitive: false),
          '',
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
          final id = '${display['text']}'.trim();
          final entry = notes[id] ??= (display, <String>[]);
          if (!entry.$2.contains(ordo.diocese)) entry.$2.add(ordo.diocese);
        }
      }
    }
    // Lectionary / Liturgy of the Hours volumes (§13.1): one line in the
    // facts, above the notes.
    final books = notesReady
        ? union.booksLines(engine.booksOf)
        : const <(String, List<String>)>[];
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
              (row) =>
                  (contextDiocese == null ||
                      row.dioceses.contains(contextDiocese)) &&
                  LiturgicalContentService()
                      .contentForDate(
                        date,
                        diocese: row.dioceses.contains(contextDiocese)
                            ? contextDiocese!
                            : row.dioceses.first,
                      )
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
    final chosenDiocese = chosen.dioceses.contains(contextDiocese)
        ? contextDiocese!
        : chosen.dioceses.first;
    final officeContent = LiturgicalContentService().contentForDate(
      date,
      diocese: chosenDiocese,
    );
    final officeSelection = resolveHoursLiturgicalSelection(
      officeContent.options,
      selectedDayId: dayId,
      selectedDiocese: chosenDiocese,
    );
    final readingGroups =
        <String, (OptionReadingReferences, Set<OrdoUnionRow>, Set<String>)>{};
    for (final row in legal) {
      for (final diocese in row.dioceses) {
        final refs = references[diocese]?[row.option.id];
        if (refs == null) continue;
        // Memorials may keep weekday texts while their own readings are
        // available only as a citation in Ordo. Keep both sets visible.
        if (refs.reference != null &&
            refs.status != ReadingReferenceStatus.referenceOnly) {
          final entry = readingGroups['reference-only|${refs.reference}'] ??= (
            OptionReadingReferences(
              optionId: refs.optionId,
              title: refs.title,
              officeKind: refs.officeKind,
              status: ReadingReferenceStatus.referenceOnly,
              documents: const [],
              alternatives: const [],
              reference: refs.reference,
            ),
            <OrdoUnionRow>{},
            <String>{},
          );
          entry.$2.add(row);
          entry.$3.add(diocese);
        }
        final documents = [...refs.documents, ...refs.alternatives];
        if (documents.isEmpty) {
          final entry = readingGroups['${refs.status}|${refs.reference}'] ??= (
            refs,
            <OrdoUnionRow>{},
            <String>{},
          );
          entry.$2.add(row);
          entry.$3.add(diocese);
        }
        for (final doc in documents) {
          // A weekday shared by memorials appears once. Structured Mass sets
          // retain the document identity so their different contexts survive.
          final raw = ContentStore.instance.collection('readings').get(doc.id);
          final structured = raw is Map && raw['massReadings'] != null;
          final signature = structured || doc.rows.isEmpty
              ? doc.id
              : '${doc.year}|${doc.rows.map((r) => '${r.key}:${r.citation}').join(';')}';
          final entry = readingGroups[signature] ??= (
            OptionReadingReferences(
              optionId: refs.optionId,
              title: refs.title,
              officeKind: refs.officeKind,
              status: refs.status,
              documents: refs.documents.contains(doc) ? [doc] : const [],
              alternatives: refs.alternatives.contains(doc) ? [doc] : const [],
              reference: refs.reference,
            ),
            <OrdoUnionRow>{},
            <String>{},
          );
          entry.$2.add(row);
          entry.$3.add(diocese);
        }
      }
    }
    // Group identical directions across dioceses without losing their scope.
    final directions = <String, Set<String>>{};
    for (final ordo in union.days) {
      final lines = <String>{
        switch (ordo.evening.vespersType) {
          'first' => 'Першыя нешпары: ${ordo.evening.title}',
          'second' => 'Другія нешпары: ${ordo.evening.title}',
          _ => 'Нешпары гэтага дня: ${ordo.evening.title}',
        },
        if (ordo.firstVespersCelebratedOnEve)
          'Першыя нешпары святкавання — напярэдадні.',
        'Камплета: ${_complineLabel(ordo.evening.compline)}',
        if (ordo.evening.omittedFirstVespers != null)
          'Першыя нешпары наступнага святкавання саступаюць нешпарам гэтага дня.',
        for (final row in legal.where((r) => r.dioceses.contains(ordo.diocese)))
          if (ordo.office(row.option.id) ??
                  (row.role == 'primary'
                      ? ordo.office(ordo.sources.office.optionId)
                      : null)
              case final office?) ...[
            '${legal.length > 1 ? '${row.option.title}: ' : ''}Te Deum ${office.teDeum ? 'спяваецца' : 'не спяваецца'}',
            ...office.notes,
          ],
      };
      for (final line in lines) {
        (directions[line] ??= <String>{}).add(ordo.diocese);
      }
    }
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
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
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
              Row(
                children: [
                  IconButton(
                    key: const Key('ordo-previous-day'),
                    tooltip: 'Папярэдні дзень',
                    onPressed: onPrevious,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: TextButton(
                      key: const Key('ordo-date-action'),
                      onPressed: onDateTap,
                      child: Text(
                        DateFormat('d MMMM y', 'be').format(date),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('ordo-next-day'),
                    tooltip: 'Наступны дзень',
                    onPressed: onNext,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              _CelebrationRow(
                row: chosen,
                heading: true,
                title: chosen.option.title.replaceFirst(
                  RegExp(
                    ',\\s*${RegExp.escape(weekday)}\$',
                    caseSensitive: false,
                  ),
                  '',
                ),
              ),
              const _Badge('Абрана'),
              const SizedBox(height: 8),
              if (!chosen.option.isTemporal)
                Text(
                  [
                    periodTitle.isNotEmpty
                        ? periodTitle
                        : periodLabelMap[day.period] ?? '',
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
              for (final (label, badges) in books)
                Padding(
                  key: Key('ordo-books-${badges.join('-')}'),
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    [label, ...badges].join(' · '),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              VestmentColorLine(
                colors: [
                  chosen.option.color,
                  ...chosen.option.colorAlternatives,
                ],
                marianAccent:
                    liturgicalVisual(
                      color: chosen.option.color,
                      category: chosen.option.category,
                      rank: chosen.option.rank,
                    )?.marianAccent ??
                    marianAccent,
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
        if (union.rows.length > 1 || suppressed.isNotEmpty)
          _Section(
            title: 'Іншыя святкаванні дня',
            children: [
              for (final row in union.rows.where(
                (r) => r.role == 'primary' && r != chosen,
              ))
                _CelebrationRow(row: row),
              if (union.rows.any(
                (r) => r.role == 'alternative' && r != chosen,
              )) ...[
                const SizedBox(height: 8),
                Text('Можна выбраць замест', style: theme.textTheme.bodyMedium),
                for (final row in union.rows.where(
                  (r) => r.role == 'alternative' && r != chosen,
                ))
                  _CelebrationRow(row: row),
              ],
              for (final row in union.rows.where(
                (r) => r.role == 'commemoration',
              ))
                _CelebrationRow(row: row),
              if (suppressed.isNotEmpty)
                ExpansionTile(
                  title: Text('Не адзначаюцца · ${suppressed.length}'),
                  tilePadding: EdgeInsets.zero,
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
          action: IconButton(
            key: const Key('ordo-open-readings'),
            tooltip: 'Адкрыць чытанні',
            icon: const Icon(Icons.menu_book_outlined),
            onPressed: () => _openReadings(
              context,
              date,
              chosen,
              selectedDayId: dayId,
              contextDiocese: chosenDiocese,
            ),
          ),
          children: [
            if (readingGroups.isEmpty)
              const Text('Тэкст / спасылкі пакуль недаступныя'),
            for (final (refs, rows, dioceses) in readingGroups.values) ...[
              if (readingGroups.length > 1) ...[
                const SizedBox(height: 12),
                Text(
                  rows
                      .map(
                        (r) => r == chosen
                            ? 'Абранае святкаванне'
                            : r.option.title,
                      )
                      .join(' / '),
                  style: theme.textTheme.titleMedium,
                ),
                if (dioceses.length < union.days.length)
                  Text(
                    dioceses.map((id) => kDioceseBadges[id] ?? id).join(' · '),
                  ),
              ],
              _References(references: refs, cycle: day.readingCycle.sunday),
            ],
          ],
        ),
        _Section(
          title: 'Літургія гадзін',
          action: IconButton(
            key: const Key('ordo-open-hours'),
            tooltip: 'Адкрыць Літургію гадзін',
            icon: const Icon(Icons.arrow_forward),
            onPressed: () => _openHours(
              context,
              ref,
              date,
              chosenDiocese,
              selectedDayId: officeSelection.dayId,
            ),
          ),
          children: [
            if (officeSelection.day == null)
              const Text('Тэксты Літургіі гадзін пакуль недаступныя')
            else if (union.dayOf(chosenDiocese).sources.split)
              Text(
                'Літургія гадзін — з дня: ${union.dayOf(chosenDiocese).sources.office.title}',
                key: const Key('ordo-office-split'),
              )
            else if (officeSelection.selected?.title != chosen.option.title)
              Text(
                officeSelection.selected?.title ?? 'Тэксты пакуль недаступныя',
                style: theme.textTheme.titleMedium,
              )
            else
              const Text('З абранага святкавання'),
            for (final template
                in officeSelection.selected?.templates ?? <DayTemplate>[])
              Padding(
                key: Key('ordo-template-${template.id}'),
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '• ${template.label == 'Перыяд' ? 'З дня' : template.label}',
                      ),
                    ),
                    if (template.id == officeSelection.template?.id)
                      const _Badge('Абрана'),
                  ],
                ),
              ),
            _Action(
              key: const Key('ordo-office-options'),
              label: 'Варыянты Літургіі гадзін',
              onTap: onDateTap,
            ),
          ],
        ),
        _Section(
          title: 'Асаблівыя ўказанні',
          collapsed: true,
          storageKey: 'ordo-directions-${day.date}',
          children: [
            for (final entry in directions.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  [
                    entry.key,
                    if (entry.value.length < union.days.length)
                      entry.value
                          .map((id) => kDioceseBadges[id] ?? id)
                          .join(' · '),
                  ].join(' · '),
                ),
              ),
            ...directionNotes,
          ],
        ),
        _Section(
          title: 'Літургічныя заўвагі',
          collapsed: true,
          storageKey: 'ordo-notes-${day.date}',
          children: [
            if (massNotes.isNotEmpty) ...[
              Text('Імша', style: theme.textTheme.titleMedium),
              ...massNotes,
            ],
            if (officeNotes.isNotEmpty) ...[
              Text('Літургія гадзін', style: theme.textTheme.titleMedium),
              ...officeNotes,
            ],
            if (notesError)
              const Text(
                'Не ўдалося прачытаць літургічныя заўвагі. Паспрабуйце адкрыць дзень яшчэ раз.',
              )
            else if (!notesReady)
              const Text('Заўвагі адкрываюцца…')
            else if (groups.isEmpty && massNotes.isEmpty && officeNotes.isEmpty)
              const Text('Для гэтага дня заўваг няма.')
            else
              for (final entry in groups.entries)
                if (entry.key == 'Агульныя ўказанні перыяду')
                  ExpansionTile(
                    key: PageStorageKey('ordo-notes-${day.date}-${entry.key}'),
                    title: Text(entry.key),
                    subtitle: Text('${entry.value.length}'),
                    tilePadding: EdgeInsets.zero,
                    children: entry.value,
                  )
                else ...[
                  Text(entry.key, style: theme.textTheme.titleMedium),
                  ...entry.value,
                ],
          ],
        ),
        const Divider(height: 32),
        ListTile(
          key: const Key('ordo-bottom-month'),
          leading: const Icon(Icons.calendar_month_outlined),
          title: const Text('Літургічны каляндар'),
          trailing: const Icon(Icons.chevron_right),
          onTap: onMonthTap,
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.children,
    this.action,
    this.collapsed = false,
    this.storageKey,
  });
  final String title;
  final List<Widget> children;
  final Widget? action;
  final bool collapsed;
  final String? storageKey;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
    child: DefaultTextStyle.merge(
      style: const TextStyle(fontSize: 16, height: 1.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(height: 24),
          if (collapsed)
            ExpansionTile(
              key: PageStorageKey(storageKey ?? title),
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 12),
              expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
              title: Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              children: children,
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ?action,
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ],
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
  String? contextDiocese,
}) {
  final diocese = contextDiocese ?? row.dioceses.first;
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
  String? diocese, {
  String? selectedDayId,
}) {
  final contextDiocese = diocese ?? ref.read(dioceseSelectionProvider).primary;
  final content = LiturgicalContentService().contentForDate(
    date,
    diocese: contextDiocese,
  );
  final selection = resolveHoursLiturgicalSelection(
    content.options,
    selectedDayId: selectedDayId,
    selectedDiocese: contextDiocese,
  );
  if (selection.dayId case final id?) {
    ref
        .read(liturgicalNavigationControllerProvider)
        .openDate(date, dayId: id, diocese: contextDiocese);
    context.go('/hours');
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
  const _CelebrationRow({required this.row, this.heading = false, this.title});

  final OrdoUnionRow row;
  final bool heading;
  final String? title;

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
    final rank = heading && option.officeKind == 'all-souls'
        ? 'Успамін'
        : ordoRankLabel(option);
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
                  title ?? option.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: heading ? 25 : 16,
                    fontWeight: heading || row.role == 'primary'
                        ? FontWeight.w600
                        : FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    if (rank.isNotEmpty) rank,
                    if (row.role == 'commemoration') role,
                    if (!heading) vestmentColorsLabel(option),
                  ].join(' · '),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 14,
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
  const _References({required this.references, required this.cycle});
  final OptionReadingReferences references;
  final String cycle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final small = theme.textTheme.bodyLarge;
    if (references.status == ReadingReferenceStatus.referenceOnly) {
      return Column(
        key: const Key('ordo-reference-only'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Чытанні: ${references.reference}', style: small),
          Text(
            'Поўны тэкст гэтых чытанняў пакуль недаступны',
            style: small?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      );
    }
    final documents = [...references.documents, ...references.alternatives];
    if (documents.isEmpty) {
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
          if (_massSets(doc.id) case final sets?)
            _MassSetReferences(sets: sets, cycle: cycle)
          else if (doc.rows.isEmpty)
            Text(
              'Тэкст / спасылкі пакуль недаступныя',
              key: const Key('ordo-readings-missing'),
              style: small?.copyWith(color: cs.onSurfaceVariant),
            )
          else
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

MassReadings? _massSets(String id) {
  final raw = ContentStore.instance.collection('readings').get(id);
  return raw is Map ? MassReadings.fromMap(raw['massReadings']) : null;
}

class _MassSetReferences extends StatelessWidget {
  const _MassSetReferences({required this.sets, required this.cycle});
  final MassReadings sets;
  final String cycle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final set in sets.sets) ...[
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Text(
            set.label,
            key: ValueKey('ordo-mass-set-${set.id}'),
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        if (set.referenceOnly)
          const Text('Спасылкі; поўны тэкст пакуль недаступны'),
        for (final citation in set.citations(cycle))
          Text(
            '${citation.label}: ${[citation.bible, ...citation.alternatives].join(' або ')}',
          ),
        if (set.citations(cycle).isEmpty)
          const Text('Спасылкі пакуль недаступныя'),
        if (set.note case final note?) Text(note),
        if (set.sourceUrl ?? sets.sourceUrl case final url?)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Крыніца чытанняў'),
              onPressed: () => _openSource(url),
            ),
          ),
      ],
    ],
  );
}

void _openSource(String url) {
  final uri = Uri.tryParse(url);
  if (uri != null && ['https', 'http'].contains(uri.scheme)) launchUrl(uri);
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
