import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:mybrev_flutter/constants/liturgical.dart';
import 'package:mybrev_flutter/models/mass_reading_sets.dart';
import 'package:mybrev_flutter/ordo/liturgical_catalog.dart';
import 'package:mybrev_flutter/ordo/runtime.dart';
import 'package:mybrev_flutter/providers/cache_epoch_provider.dart';
import 'package:mybrev_flutter/providers/diocese_provider.dart';
import 'package:mybrev_flutter/screens/catalog_year_selector.dart';
import 'package:mybrev_flutter/services/catalog_preview_service.dart';
import 'package:mybrev_flutter/services/liturgical_content_service.dart';
import 'package:mybrev_flutter/widgets/ordo/vestment_marker.dart';

final catalogPreviewProvider =
    FutureProvider.family<ContentPreview, (CatalogEntry, String)>((ref, key) {
      ref.watch(cacheEpochProvider);
      return catalogPreviewFromStore(key.$1, key.$2);
    });

class CatalogEntryScreen extends ConsumerStatefulWidget {
  const CatalogEntryScreen({
    super.key,
    required this.entry,
    required this.mode,
    required this.onOpen,
  });
  final CatalogEntry entry;
  final String mode;
  final bool Function(CalendarOccurrence) onOpen;
  @override
  ConsumerState<CatalogEntryScreen> createState() => _CatalogEntryScreenState();
}

class _CatalogEntryScreenState extends ConsumerState<CatalogEntryScreen> {
  bool calendar = false;
  int year = DateTime.now().year;
  String? diocese;
  @override
  Widget build(BuildContext context) {
    ref.watch(cacheEpochProvider);
    final selected = ref.watch(dioceseSelectionProvider).ordered;
    final places = widget.entry.isPeriod
        ? selected
        : widget.entry.dioceses.where(selected.contains).toList();
    final place = places.contains(diocese)
        ? diocese!
        : places.firstOrNull ?? selected.first;
    final preview = ref.watch(catalogPreviewProvider((widget.entry, place)));
    final occurrence = calendar
        ? calendarOccurrence(
            OrdoRuntime.engine,
            widget.entry,
            year,
            place,
            widget.mode,
          )
        : null;
    final alternative = occurrence != null && !occurrence.canOpen
        ? nearestCatalogYear(
            OrdoRuntime.engine,
            widget.entry,
            year,
            place,
            widget.mode,
          )
        : null;
    return Scaffold(
      appBar: AppBar(title: const Text('Літургічныя тэксты')),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            104 + MediaQuery.viewPaddingOf(context).bottom,
          ),
          children: [
            Text(
              widget.entry.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            if (widget.entry.colors.isNotEmpty)
              VestmentColorLine(colors: widget.entry.colors),
            Text(widget.entry.description),
            preview.when(
              loading: () => const Text('Праверка крыніц…'),
              error: (_, _) => const Text('Крыніцы тэкстаў недаступныя'),
              data: (p) => Text(
                p.status == 'unavailable'
                    ? 'Крыніцы тэкстаў недаступныя'
                    : p.status == 'no-content'
                    ? occurrenceLabels['no-content']!
                    : [
                        if (p.sources.any(
                          (s) =>
                              s.collection != 'liturgicalTemplates' &&
                              s.fields.isNotEmpty,
                        ))
                          'Уласныя тэксты',
                        if (p.sources.any(
                          (s) =>
                              s.collection == 'liturgicalTemplates' &&
                              s.fields.isNotEmpty,
                        ))
                          'Агульныя тэксты',
                        if (p.readings.isNotEmpty) 'Чытанні',
                        if (p.missing.isNotEmpty || p.errors.isNotEmpty)
                          'Няпоўныя крыніцы',
                      ].join(' · '),
              ),
            ),
            if (places.length > 1)
              Wrap(
                spacing: 8,
                children: [
                  for (final d in places)
                    ChoiceChip(
                      label: Text(kDioceseShortNames[d] ?? d),
                      selected: d == place,
                      onSelected: (_) => setState(() => diocese = d),
                    ),
                ],
              ),
            const SizedBox(height: 16),
            Text(
              widget.mode == 'readings'
                  ? 'Рэжым чытанняў'
                  : 'Рэжым літургіі гадзінаў',
            ),
            const SizedBox(height: 8),
            FilledButton(
              key: const Key('catalog-preview'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      CatalogSourceScreen(entry: widget.entry, diocese: place),
                ),
              ),
              child: const Text('Праглядзець тэксты'),
            ),
            OutlinedButton(
              key: const Key('catalog-calendar'),
              onPressed: () => setState(() => calendar = true),
              child: const Text('Адкрыць у календары'),
            ),
            if (!calendar)
              const Text('Год патрэбны толькі для адкрыцця ў календары.'),
            if (occurrence != null) ...[
              const Divider(height: 32),
              Align(
                alignment: Alignment.centerLeft,
                child: CatalogYearSelector(
                  year: year,
                  onChanged: (v) {
                    if (v >= kCalendarFirstDate.year &&
                        v <= kCalendarLastDate.year) {
                      setState(() => year = v);
                    }
                  },
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final y in [
                    DateTime.now().year,
                    DateTime.now().year + 1,
                  ])
                    ActionChip(
                      label: Text('$y'),
                      onPressed: () => setState(() => year = y),
                    ),
                ],
              ),
              Text(
                occurrenceLabels[occurrence.status] ?? occurrence.status,
                key: const Key('catalog-occurrence-status'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (occurrence.effectiveDate != null)
                Text('Дата: ${occurrence.effectiveDate}'),
              if (occurrence.originalDate != null &&
                  occurrence.originalDate != occurrence.effectiveDate)
                Text('Першапачатковая дата: ${occurrence.originalDate}'),
              if (occurrence.reason.isNotEmpty) Text(occurrence.reason),
              if (preview.hasError)
                const Text(
                  'Не ўдалося праверыць наяўнасць крыніц. Дазвол Ordo правяраецца асобна.',
                ),
              if (preview.valueOrNull case final content?)
                if (!content.hasContent && content.errors.isEmpty)
                  const Text(
                    'Тэксты не знойдзены. Гэта не змяняе каляндарнага статусу Ordo.',
                  ),
              FilledButton(
                key: const Key('catalog-open-occurrence'),
                onPressed: occurrence.canOpen
                    ? () => widget.onOpen(
                        calendarOccurrence(
                          OrdoRuntime.engine,
                          widget.entry,
                          year,
                          place,
                          widget.mode,
                        ),
                      )
                    : null,
                child: Text(
                  widget.mode == 'readings'
                      ? 'Адкрыць чытанні'
                      : 'Адкрыць літургію гадзінаў',
                ),
              ),
              if (alternative != null)
                OutlinedButton(
                  key: const Key('catalog-alternative-year'),
                  onPressed: () => setState(() => year = alternative.year),
                  child: Text('Дазволены год: ${alternative.year}'),
                ),
              if (!occurrence.canOpen && alternative == null)
                const Text(
                  'Дазволены год у межах пошуку ±12 гадоў не знойдзены.',
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class CatalogSourceScreen extends ConsumerWidget {
  const CatalogSourceScreen({
    super.key,
    required this.entry,
    required this.diocese,
  });
  final CatalogEntry entry;
  final String diocese;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = ref.watch(catalogPreviewProvider((entry, diocese)));
    return Scaffold(
      appBar: AppBar(title: const Text('Прагляд крыніц')),
      body: SafeArea(
        child: preview.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const Center(
            child: Text('Не ўдалося загрузіць крыніцы тэкстаў.'),
          ),
          data: (content) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(entry.title, style: Theme.of(context).textTheme.titleLarge),
              const Text(
                'Даведачны прагляд уласных і агульных частак. Гэта не поўная літургія гадзінаў на каляндарную дату. Адсутныя часткі не падмяняюцца тэкстамі іншага дня.',
              ),
              if (!content.hasContent && content.errors.isEmpty)
                const Text('Тэксты не знойдзены'),
              if (content.errors.isNotEmpty)
                const Text('Частку крыніц не ўдалося прачытаць.'),
              if (content.missing.isNotEmpty)
                Text('Адсутныя крыніцы: ${content.missing.join(', ')}'),
              for (final source in content.sources)
                ExpansionTile(
                  title: Text(
                    source.label == 'Агульныя тэксты'
                        ? '${source.label} · ${dayTemplateLabel(source.id.split(':').first)}'
                        : source.label,
                  ),
                  subtitle: Text('${source.collection}/${source.id}'),
                  children: [
                    for (final field in source.fields.entries)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              previewFieldLabel(field.key),
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            Html(data: field.value),
                          ],
                        ),
                      ),
                    for (final instruction in source.instructions)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(instruction),
                      ),
                    if (source.fields.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('У гэтай крыніцы няма ўласных тэкстаў.'),
                      ),
                  ],
                ),
              for (final reading in content.readings)
                ExpansionTile(
                  title: Text(
                    'Чытанні · ${reading.title ?? entry.title} · ${reading.year ?? 'усе цыклы'}',
                  ),
                  subtitle: Text('readings/${reading.id}'),
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'Цыклы A/B/C і I/II тут паказаны для даведкі. У календары выкарыстоўваецца цыкл канкрэтнага дня.',
                      ),
                    ),
                    if (reading.massReadings case final mass?)
                      for (final set in mass.sets)
                        ExpansionTile(
                          title: Text(
                            '${set.label} · ${set.cycle ?? 'усе цыклы'}',
                          ),
                          children: [
                            if (set.referenceOnly)
                              const Text('Даступныя толькі біблійныя спасылкі'),
                            for (final preface in set.preface)
                              Html(data: preface),
                            for (final prayer in set.prayers)
                              Html(data: prayer.text ?? ''),
                            for (final section in set.sections)
                              ..._sectionWidgets(section),
                          ],
                        )
                    else
                      ..._readingFields(reading.toMap()),
                  ],
                ),
              SizedBox(height: 104 + MediaQuery.viewPaddingOf(context).bottom),
            ],
          ),
        ),
      ),
    );
  }
}

List<Widget> _readingFields(Map<String, dynamic> map) => [
  for (final item in map.entries)
    if (const {
          'reading',
          'reading1',
          'reading2',
          'psalm',
          'alleluia',
          'gospel',
          'sequence',
        }.contains(item.key) &&
        item.value is Map) ...[
      Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          const {
            'reading': 'Чытанне',
            'reading1': 'Першае чытанне',
            'reading2': 'Другое чытанне',
            'psalm': 'Псальм',
            'alleluia': 'Спеў перад Евангеллем',
            'gospel': 'Евангелле',
            'sequence': 'Секвенцыя',
          }[item.key]!,
        ),
      ),
      ..._textLeaves(item.value),
    ],
];
List<Widget> _textLeaves(Object? value) {
  if (value is String) return [Html(data: value)];
  if (value is List) return [for (final v in value) ..._textLeaves(v)];
  if (value is Map) {
    return [
      for (final e in value.entries)
        if (const {
          'bible',
          'comment',
          'title',
          'text',
          'chorus',
          'altChorus',
          'altChorusRef',
          'verses',
          'verse',
          'acclamation',
          'conclusion',
          'rubrics',
          'alternatives',
          'passion',
          'blocks',
          'runs',
          'legend',
          'lines',
          'speaker',
          'label',
          'year',
        }.contains(e.key))
          ..._textLeaves(e.value),
    ];
  }
  return [];
}

List<Widget> _sectionWidgets(MassReadingSection section) => [
  Padding(
    padding: const EdgeInsets.all(12),
    child: Text(
      section.label ??
          const {
            'reading': 'Чытанне',
            'psalm': 'Псальм',
            'gospel': 'Евангелле',
            'acclamation': 'Спеў перад Евангеллем',
            'rubric': 'Рубрыка',
            'sequence': 'Секвенцыя',
          }[section.kind] ??
          'Чытанне',
    ),
  ),
  for (final text in [
    section.cycle,
    section.year,
    section.bible,
    section.comment,
    section.title,
    section.chorus,
    section.altChorus,
    section.altChorusRef,
    section.text,
    section.verse,
    section.acclamation,
    section.conclusion,
    ...section.verses,
    ...section.rubrics,
  ])
    if (text is String && text.isNotEmpty) Html(data: text),
  if (section.passion case final passion?) ...[
    for (final legend in passion.legend) Html(data: legend),
    for (final block in passion.blocks)
      if (block.isParagraph)
        for (final run in block.runs)
          Html(data: '${run.role?.marker ?? ''} ${run.text}')
      else
        Html(data: block.text),
  ],
  for (final alternative in section.alternatives)
    ..._sectionWidgets(alternative),
];
