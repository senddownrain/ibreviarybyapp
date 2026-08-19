import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:mybrev_flutter/providers/prayers_provider.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';

class PrayersScreen extends ConsumerStatefulWidget {
  const PrayersScreen({super.key});

  @override
  ConsumerState<PrayersScreen> createState() => _PrayersScreenState();
}

class _PrayersScreenState extends ConsumerState<PrayersScreen> {
  bool _searchExpanded = false;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prayers = ref.watch(filteredPrayersProvider);
    final filter = ref.watch(prayersFilterProvider);
    final allTags = ref.watch(allTagsProvider);
    final settings = ref.watch(settingsProvider);

    return Column(
      children: [
        // Search bar
        if (_searchExpanded)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Пошук...',
                prefixIcon: const PhosphorIcon(PhosphorIconsRegular.magnifyingGlass, size: 20),
                suffixIcon: IconButton(
                  icon: const PhosphorIcon(PhosphorIconsRegular.x, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    ref.read(prayersFilterProvider.notifier).setSearch('');
                    setState(() => _searchExpanded = false);
                  },
                ),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (val) {
                ref.read(prayersFilterProvider.notifier).setSearch(val);
              },
            ),
          ),
        // Filter chips
        if (allTags.isNotEmpty)
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: allTags.map((tag) {
                final selected = filter.selectedTags.contains(tag);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FilterChip(
                    label: Text(tag),
                    selected: selected,
                    onSelected: (_) {
                      ref.read(prayersFilterProvider.notifier).toggleTag(tag);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        // Actions row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Text(
                '${prayers.length} малітваў',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              if (!_searchExpanded)
                IconButton(
                  icon: const PhosphorIcon(PhosphorIconsRegular.magnifyingGlass, size: 20),
                  onPressed: () => setState(() => _searchExpanded = true),
                ),
              if (filter.selectedTags.isNotEmpty ||
                  filter.searchQuery.isNotEmpty)
                TextButton(
                  onPressed: () {
                    _searchController.clear();
                    ref.read(prayersFilterProvider.notifier).clearFilters();
                    setState(() => _searchExpanded = false);
                  },
                  child: const Text('Скінуць'),
                ),
            ],
          ),
        ),
        // Prayer list
        Expanded(
          child: prayers.isEmpty
              ? const Center(child: Text('Нічога не знойдзена'))
              : ListView.builder(
                  itemCount: prayers.length,
                  itemBuilder: (context, index) {
                    final prayer = prayers[index];
                    final isFav =
                        settings.favoriteIds.contains(prayer.id);
                    return ListTile(
                      title: Text(prayer.displayTitle),
                      subtitle: prayer.tags.isNotEmpty
                          ? Text(prayer.tags.join(', '))
                          : null,
                      onTap: () => context.push('/prayer/${prayer.id}'),
                      trailing: IconButton(
                        icon: PhosphorIcon(
                          isFav ? PhosphorIconsFill.heart : PhosphorIconsRegular.heart,
                          size: 22,
                          color: isFav ? Colors.red : null,
                        ),
                        tooltip: isFav
                            ? 'Выдаліць з улюбёных'
                            : 'Дадаць у улюбёныя',
                        onPressed: () {
                          ref
                              .read(settingsProvider.notifier)
                              .toggleFavorite(prayer.id);
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
