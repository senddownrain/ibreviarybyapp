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
import 'package:mybrev_flutter/widgets/app_shell_scope.dart';

class PrayersScreen extends ConsumerStatefulWidget {
  const PrayersScreen({super.key});

  @override
  ConsumerState<PrayersScreen> createState() => _PrayersScreenState();
}

class _PrayersScreenState extends ConsumerState<PrayersScreen> {
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
    final seasonColor = ref.watch(liturgicalSeasonColorProvider);
    final cs = Theme.of(context).colorScheme;
    final topPad = MediaQuery.paddingOf(context).top;

    return Stack(
      children: [
        AmbientWash(
      seasonColor: seasonColor,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, topPad + kShellMenuButtonClearance, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'МАЛІТВЫ',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: cs.tertiary,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.1,
                              ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          filter.selectedCategoryName ?? 'Усе малітвы',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.4,
                              ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${prayers.length} ${_prayerCountLabel(prayers.length)}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: () => context.push('/prayers/favorites'),
                    tooltip: 'Абраныя малітвы',
                    icon: const PhosphorIcon(
                      PhosphorIconsRegular.heart,
                      size: 21,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: GlassSurface(
                style: GlassStyle.soft,
                seasonColor: seasonColor,
                borderRadius: BorderRadius.circular(20),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Знайсці малітву',
                    prefixIcon: const PhosphorIcon(
                      PhosphorIconsRegular.magnifyingGlass,
                      size: 20,
                    ),
                    suffixIcon: filter.searchQuery.isEmpty
                        ? null
                        : IconButton(
                            icon: const PhosphorIcon(
                              PhosphorIconsRegular.x,
                              size: 19,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              ref
                                  .read(prayersFilterProvider.notifier)
                                  .setSearch('');
                            },
                          ),
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                  onChanged: ref.read(prayersFilterProvider.notifier).setSearch,
                ),
              ),
            ),
          ),
          if (allTags.isNotEmpty)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: allTags.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 7),
                  itemBuilder: (context, index) {
                    final tag = allTags[index];
                    return FilterChip(
                      label: Text(tag),
                      selected: filter.selectedTags.contains(tag),
                      onSelected: (_) => ref
                          .read(prayersFilterProvider.notifier)
                          .toggleTag(tag),
                    );
                  },
                ),
              ),
            ),
          if (filter.isActive)
            SliverToBoxAdapter(
              child: Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
                  child: TextButton.icon(
                    onPressed: () {
                      _searchController.clear();
                      ref.read(prayersFilterProvider.notifier).clearFilters();
                    },
                    icon: const PhosphorIcon(
                      PhosphorIconsRegular.arrowCounterClockwise,
                      size: 17,
                    ),
                    label: const Text('Скінуць фільтры'),
                  ),
                ),
              ),
            ),
          if (prayers.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyPrayersState(
                onReset: () {
                  _searchController.clear();
                  ref.read(prayersFilterProvider.notifier).clearFilters();
                },
              ),
            )
          else
            SliverList.builder(
              itemCount: prayers.length,
              itemBuilder: (context, index) {
                final prayer = prayers[index];
                return Padding(
                  padding: EdgeInsets.fromLTRB(12, index == 0 ? 4 : 0, 12, 9),
                  child: _PrayerCard(
                    prayer: prayer,
                    isFavorite: settings.favoriteIds.contains(prayer.id),
                  ),
                );
              },
            ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 24 + MediaQuery.viewPaddingOf(context).bottom,
            ),
          ),
        ],
      ),
        ),
        Positioned(
          top: topPad + 10,
          left: 14,
          child: ShellMenuButton.fromScope(context),
        ),
      ],
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
          padding: const EdgeInsets.fromLTRB(14, 13, 8, 13),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: cs.tertiaryContainer,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: cs.tertiary.withValues(alpha: 0.16),
                  ),
                ),
                child: Center(
                  child: PhosphorIcon(
                    isFavorite
                        ? PhosphorIconsFill.heart
                        : PhosphorIconsRegular.handsPraying,
                    size: 23,
                    color: isFavorite ? cs.error : cs.tertiary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prayer.displayTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                    if (prayer.tags.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        prayer.tags.take(3).join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: isFavorite ? 'Выдаліць з абраных' : 'Дадаць у абраныя',
                onPressed: () {
                  HapticFeedback.selectionClick();
                  ref.read(settingsProvider.notifier).toggleFavorite(prayer.id);
                },
                icon: PhosphorIcon(
                  isFavorite
                      ? PhosphorIconsFill.heart
                      : PhosphorIconsRegular.heart,
                  size: 21,
                  color: isFavorite ? cs.error : cs.onSurfaceVariant,
                ),
              ),
              PhosphorIcon(
                PhosphorIconsRegular.caretRight,
                size: 17,
                color: cs.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyPrayersState extends StatelessWidget {
  const _EmptyPrayersState({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PhosphorIcon(
              PhosphorIconsLight.magnifyingGlass,
              size: 52,
              color: cs.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'Нічога не знойдзена',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: onReset,
              child: const Text('Скінуць фільтры'),
            ),
          ],
        ),
      ),
    );
  }
}

String _prayerCountLabel(int count) {
  final mod10 = count % 10;
  final mod100 = count % 100;
  if (mod10 == 1 && mod100 != 11) return 'малітва';
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
    return 'малітвы';
  }
  return 'малітваў';
}
