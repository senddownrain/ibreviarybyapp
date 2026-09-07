import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mybrev_flutter/models/prayer.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/providers/prayers_provider.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/theme/glass.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class PrayersScreen extends ConsumerStatefulWidget {
  const PrayersScreen({super.key});

  @override
  ConsumerState<PrayersScreen> createState() => _PrayersScreenState();
}

class _PrayersScreenState extends ConsumerState<PrayersScreen> {
  late final TextEditingController _searchController;
  final _searchFocusNode = FocusNode();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(prayersFilterProvider).searchQuery,
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _setSearch(String value) {
    _searchDebounce?.cancel();
    if (value.trim().isEmpty) {
      ref.read(prayersFilterProvider.notifier).setSearch('');
      return;
    }
    _searchDebounce = Timer(
      const Duration(milliseconds: 300),
      () => ref.read(prayersFilterProvider.notifier).setSearch(value),
    );
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    ref.read(prayersFilterProvider.notifier).setSearch('');
    _searchFocusNode.requestFocus();
  }

  void _clearFilters() {
    _searchDebounce?.cancel();
    _searchController.clear();
    ref.read(prayersFilterProvider.notifier).clearFilters();
  }

  Future<void> _openTagFilter() async {
    FocusScope.of(context).unfocus();
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => const _PrayerTagsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prayers = ref.watch(filteredPrayersProvider);
    final filter = ref.watch(prayersFilterProvider);
    final settings = ref.watch(settingsProvider);
    final seasonColor = ref.watch(liturgicalSeasonColorProvider);
    final cs = Theme.of(context).colorScheme;
    final topPad = MediaQuery.paddingOf(context).top;
    final bottomPad = MediaQuery.viewPaddingOf(context).bottom;

    return Stack(
      children: [
        AmbientWash(
          seasonColor: seasonColor,
          child: CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, topPad + 78, 16, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'МАЛІТОЎНІК',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: cs.tertiary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        filter.selectedCategoryName ?? 'Малітвы',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              if (prayers.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyPrayersState(
                    hasActiveFilters: filter.isActive,
                    onReset: _clearFilters,
                  ),
                )
              else
                SliverList.builder(
                  itemCount: prayers.length,
                  itemBuilder: (context, index) {
                    final prayer = prayers[index];
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: _PrayerCard(
                        prayer: prayer,
                        isFavorite: settings.favoriteIds.contains(prayer.id),
                      ),
                    );
                  },
                ),
              SliverToBoxAdapter(child: SizedBox(height: 100 + bottomPad)),
            ],
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16 + bottomPad,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: _PrayerSearchDock(
                controller: _searchController,
                focusNode: _searchFocusNode,
                queryIsEmpty: _searchController.text.isEmpty,
                selectedTagCount: filter.selectedTags.length,
                onChanged: (value) {
                  setState(() {});
                  _setSearch(value);
                },
                onClear: _clearSearch,
                onFilter: _openTagFilter,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PrayerSearchDock extends StatelessWidget {
  const _PrayerSearchDock({
    required this.controller,
    required this.focusNode,
    required this.queryIsEmpty,
    required this.selectedTagCount,
    required this.onChanged,
    required this.onClear,
    required this.onFilter,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool queryIsEmpty;
  final int selectedTagCount;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback onFilter;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GlassSurface(
      style: GlassStyle.pill,
      borderRadius: BorderRadius.circular(29),
      child: SizedBox(
        height: 58,
        child: Row(
          children: [
            const SizedBox(width: 18),
            PhosphorIcon(
              PhosphorIconsRegular.magnifyingGlass,
              size: 23,
              color: cs.tertiary,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: 'Пошук малітваў',
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 8),
                ),
                onChanged: onChanged,
              ),
            ),
            if (!queryIsEmpty)
              IconButton(
                tooltip: 'Ачысціць пошук',
                onPressed: onClear,
                icon: const PhosphorIcon(PhosphorIconsRegular.x, size: 19),
              ),
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  tooltip: selectedTagCount == 0
                      ? 'Адкрыць фільтр'
                      : 'Фільтр: выбрана $selectedTagCount',
                  onPressed: onFilter,
                  style: selectedTagCount == 0
                      ? null
                      : IconButton.styleFrom(
                          backgroundColor: cs.tertiaryContainer,
                          foregroundColor: cs.tertiary,
                        ),
                  icon: const PhosphorIcon(
                    PhosphorIconsRegular.slidersHorizontal,
                    size: 21,
                  ),
                ),
                if (selectedTagCount > 0)
                  Positioned(
                    top: -1,
                    right: -1,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 17),
                      height: 17,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: cs.tertiary,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(
                        '$selectedTagCount',
                        style: TextStyle(
                          color: cs.onTertiary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

class _PrayerTagsSheet extends ConsumerWidget {
  const _PrayerTagsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags = ref.watch(allTagsProvider);
    final selectedTags = ref.watch(
      prayersFilterProvider.select((filter) => filter.selectedTags),
    );
    final cs = Theme.of(context).colorScheme;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.78,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          16 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'МАЛІТВЫ',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: cs.tertiary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Фільтр па тэгах',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Закрыць фільтр',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const PhosphorIcon(PhosphorIconsRegular.x, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Можна выбраць некалькі тэгаў',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final tag in tags)
                      FilterChip(
                        label: Text(tag),
                        selected: selectedTags.contains(tag),
                        onSelected: (_) => ref
                            .read(prayersFilterProvider.notifier)
                            .toggleTag(tag),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                TextButton(
                  onPressed: selectedTags.isEmpty
                      ? null
                      : () => ref
                            .read(prayersFilterProvider.notifier)
                            .clearTags(),
                  child: const Text('Ачысціць'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Гатова'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PrayerCard extends ConsumerWidget {
  const _PrayerCard({required this.prayer, required this.isFavorite});

  final Prayer prayer;
  final bool isFavorite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () {
          HapticFeedback.lightImpact();
          context.push('/prayer/${prayer.id}');
        },
        child: GlassSurface(
          borderRadius: BorderRadius.circular(22),
          padding: const EdgeInsets.fromLTRB(8, 14, 10, 14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isFavorite
                      ? cs.errorContainer.withValues(alpha: 0.5)
                      : cs.tertiaryContainer,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: (isFavorite ? cs.error : cs.tertiary).withValues(
                      alpha: 0.18,
                    ),
                  ),
                ),
                child: Tooltip(
                  message: isFavorite
                      ? 'Выдаліць з абраных'
                      : 'Дадаць у абраныя',
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      hoverColor: (isFavorite ? cs.error : cs.tertiary)
                          .withValues(alpha: 0.07),
                      splashColor: (isFavorite ? cs.error : cs.tertiary)
                          .withValues(alpha: 0.11),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref
                            .read(settingsProvider.notifier)
                            .toggleFavorite(prayer.id);
                      },
                      child: Center(
                        child: PhosphorIcon(
                          isFavorite
                              ? PhosphorIconsFill.heart
                              : PhosphorIconsRegular.heart,
                          size: 22,
                          color: isFavorite ? cs.error : cs.tertiary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  prayer.displayTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              PhosphorIcon(
                PhosphorIconsRegular.caretRight,
                size: 20,
                color: cs.onSurfaceVariant,
              ),
              const SizedBox(width: 2),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyPrayersState extends StatelessWidget {
  const _EmptyPrayersState({
    required this.hasActiveFilters,
    required this.onReset,
  });

  final bool hasActiveFilters;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 110),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PhosphorIcon(
              PhosphorIconsLight.noteBlank,
              size: 48,
              color: cs.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'Малітвы не знойдзены',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (hasActiveFilters) ...[
              const SizedBox(height: 6),
              Text(
                'Паспрабуйце змяніць пошук або фільтры',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: onReset,
                child: const Text('Скінуць фільтры'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
