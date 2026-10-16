import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mybrev_flutter/constants/liturgical.dart';
import 'package:mybrev_flutter/ordo/dates.dart';
import 'package:mybrev_flutter/ordo/liturgical_catalog.dart';
import 'package:mybrev_flutter/screens/catalog_entry_screen.dart';
import 'package:mybrev_flutter/ordo/runtime.dart';
import 'package:mybrev_flutter/providers/cache_epoch_provider.dart';
import 'package:mybrev_flutter/providers/diocese_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_navigation_sync_provider.dart';
import 'package:mybrev_flutter/services/liturgical_content_service.dart';
import 'package:mybrev_flutter/navigation/app_navigation.dart';
import 'package:mybrev_flutter/widgets/ordo/vestment_marker.dart';
import 'package:mybrev_flutter/widgets/reader/reader_navigation.dart';

final pickerFeastsProvider = Provider<List<CatalogEntry>>((ref) {
  ref.watch(cacheEpochProvider);
  return feastCatalog(
    OrdoRuntime.engine.definitions,
    ref.watch(dioceseSelectionProvider).ordered,
  );
});

/// Opens [date] (optionally one celebration) in the Hours or the Readings.
bool openPickedDate(
  BuildContext context,
  WidgetRef ref,
  DateTime date, {
  required bool readingsMode,
  String? optionId,
  String? diocese,
}) {
  final place = diocese ?? ref.read(dioceseSelectionProvider).primary;
  if (date.isBefore(kCalendarFirstDate) || date.isAfter(kCalendarLastDate)) {
    return false;
  }
  final day = OrdoRuntime.engine.resolve(date, diocese: place);
  if (optionId != null &&
      !(readingsMode ? day.options : day.officeOptions).any(
        (o) => o.id == optionId,
      )) {
    return false;
  }
  String? dayId;
  if (optionId != null) {
    dayId = LiturgicalContentService()
        .contentForDate(date, diocese: place)
        .options
        .where((option) => option.ordo?.optionId == optionId)
        .firstOrNull
        ?.dayId;
  }
  if (!readingsMode && optionId != null && dayId == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Тэксты гэтага варыянта не знойдзены. Даступны даведачны прагляд крыніц.',
        ),
      ),
    );
    return false;
  }
  if (readingsMode) {
    AppNavigationScope.maybeOf(context)?.shellState.clearOraReturn();
    context.push(
      readingsRouteForContext(
        date: date,
        dayId: dayId,
        diocese: place,
        optionId: optionId,
      ),
    );
    return true;
  }
  ref
      .read(liturgicalNavigationControllerProvider)
      .openDate(date, dayId: dayId, diocese: place);
  context.push('/hours');
  return true;
}

class LiturgicalPickerScreen extends ConsumerWidget {
  const LiturgicalPickerScreen({super.key, this.mode = 'hours'});
  final String mode;
  bool get isReadingsMode => mode == 'readings';
  @override
  Widget build(BuildContext context, WidgetRef ref) => SafeArea(
    bottom: false,
    child: DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
            child: Row(
              children: [
                IconButton(
                  key: const Key('liturgical-picker-back'),
                  tooltip: 'Назад',
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                Expanded(
                  child: Text(
                    isReadingsMode
                        ? 'Знайсці чытанні'
                        : 'Знайсці літургічны дзень',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
          ),
          const TabBar(
            tabs: [
              Tab(text: 'Па перыядзе'),
              Tab(text: 'Па свяце'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _PeriodPicker(mode: mode),
                _FeastsPickerCombined(mode: mode),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> showCatalogEntry(
  BuildContext context,
  WidgetRef ref,
  CatalogEntry entry,
  String mode,
) async {
  final occurrence = await Navigator.of(context, rootNavigator: true)
      .push<CalendarOccurrence>(
        MaterialPageRoute(
          builder: (entryContext) => CatalogEntryScreen(
            entry: entry,
            mode: mode,
            onOpen: (occurrence) {
              Navigator.of(entryContext).pop(occurrence);
              return true;
            },
          ),
        ),
      );
  if (occurrence != null && context.mounted) {
    openPickedDate(
      context,
      ref,
      dateOfIso(occurrence.effectiveDate!),
      readingsMode: mode == 'readings',
      optionId: occurrence.optionId,
      diocese: occurrence.diocese,
    );
  }
}

class _FeastsPickerCombined extends ConsumerStatefulWidget {
  const _FeastsPickerCombined({required this.mode});
  final String mode;
  @override
  ConsumerState<_FeastsPickerCombined> createState() =>
      _FeastsPickerCombinedState();
}

class _FeastsPickerCombinedState extends ConsumerState<_FeastsPickerCombined>
    with AutomaticKeepAliveClientMixin {
  String query = '', filter = 'all';
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final entries = ref
        .watch(pickerFeastsProvider)
        .where((e) => e.matches(query, filter))
        .toList();
    return CustomScrollView(
      key: const Key('picker-feasts'),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  key: const Key('picker-feast-search'),
                  decoration: const InputDecoration(
                    labelText: 'Пошук па назве, даце, рангу, дыяцэзіі',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => setState(() => query = v),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final f in {
                      'all': 'Усе',
                      'fixed': 'Нерухомыя',
                      'dynamic': 'Рухомыя',
                    }.entries)
                      ChoiceChip(
                        key: Key('picker-filter-${f.key}'),
                        label: Text(f.value),
                        selected: filter == f.key,
                        onSelected: (_) => setState(() => filter = f.key),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (entries.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('Нічога не знойдзена'),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.builder(
            itemCount: entries.length,
            itemBuilder: (context, i) => _CatalogRow(
              entry: entries[i],
              onTap: () =>
                  showCatalogEntry(context, ref, entries[i], widget.mode),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 104 + MediaQuery.viewPaddingOf(context).bottom,
          ),
        ),
      ],
    );
  }
}

class _CatalogRow extends StatelessWidget {
  const _CatalogRow({required this.entry, required this.onTap});
  final CatalogEntry entry;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      key: Key('picker-entry-${entry.id}'),
      leading: entry.colors.isEmpty
          ? null
          : VestmentMarker(colors: entry.colors, size: 18),
      title: Text(entry.title),
      subtitle: Text('${entry.description}\n${entry.contentLabel}'),
      onTap: onTap,
    ),
  );
}

class _PeriodPicker extends ConsumerWidget {
  const _PeriodPicker({required this.mode});
  final String mode;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(cacheEpochProvider);
    final entries = periodCatalog(OrdoRuntime.engine.definitions);
    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        104 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      children: [
        for (final period in periodLabelMap.entries)
          Card(
            child: ListTile(
              key: Key('picker-period-${period.key}'),
              title: Text(period.value),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final picked = await showModalBottomSheet<CatalogEntry>(
                  context: context,
                  useRootNavigator: true,
                  useSafeArea: true,
                  isScrollControlled: true,
                  builder: (sheetContext) => SizedBox(
                    height: MediaQuery.sizeOf(sheetContext).height * 0.85,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text(
                          period.value,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        for (final entry in entries.where(
                          (e) => e.period == period.key,
                        ))
                          _CatalogRow(
                            entry: entry,
                            onTap: () => Navigator.of(sheetContext).pop(entry),
                          ),
                      ],
                    ),
                  ),
                );
                if (picked != null && context.mounted) {
                  showCatalogEntry(context, ref, picked, mode);
                }
              },
            ),
          ),
      ],
    );
  }
}
