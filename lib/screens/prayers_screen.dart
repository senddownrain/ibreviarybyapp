import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:mybrev_flutter/models/prayer.dart';
import 'package:mybrev_flutter/providers/admin_songbook_access_provider.dart';
import 'package:mybrev_flutter/constants/prayer_category_icons.dart';
import 'package:mybrev_flutter/widgets/category_icon.dart';
import 'package:mybrev_flutter/widgets/category_icon_picker.dart';
import 'package:mybrev_flutter/navigation/app_navigation.dart';
import 'package:mybrev_flutter/providers/prayer_categories_provider.dart';
import 'package:mybrev_flutter/providers/prayers_provider.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/providers/priest_access_provider.dart';
import 'package:mybrev_flutter/services/prayer_category_tree.dart';
import 'package:mybrev_flutter/theme/glass.dart';
import 'package:mybrev_flutter/theme/reader.dart';
import 'package:mybrev_flutter/utils/system_insets.dart';
import 'package:mybrev_flutter/widgets/floating_top_actions.dart';
import 'package:mybrev_flutter/widgets/prayerbook_section_tiles.dart';
import 'package:mybrev_flutter/widgets/loading/app_load_states.dart';

const _kMassOrderPrayerId = 'eMmCtxwyJ75ogmL5rwye';

class PrayersScreen extends ConsumerWidget {
  const PrayersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritePrayersProvider);
    final canSeeSongbook =
        ref.watch(adminSongbookAccessProvider).valueOrNull == true;
    final categories = ref.watch(prayerMenuCategoriesProvider);
    final catalog = ref.watch(prayerCatalogProvider);
    final massAvailable = catalog.any(
      (prayer) => prayer.id == _kMassOrderPrayerId,
    );
    final categoryState = ref.watch(globalPrayerCategoriesProvider);
    // Only at the first opening after launch, for a moment.
    final massLoading = ref.watch(prayersContentProvider).isLoading;
    final cs = Theme.of(context).colorScheme;
    final top = MediaQuery.paddingOf(context).top + 78;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          AmbientWash(
            seasonColor: cs.tertiary,
            child: ListView(
              key: const PageStorageKey('prayerbook-root-scroll'),
              padding: EdgeInsets.fromLTRB(
                22,
                top + 8,
                22,
                // The app shell's floating dock is included in padding when
                // extendBody is enabled. Keep the final row clear of it with
                // a small visual gap.
                MediaQuery.paddingOf(context).bottom + 24,
              ),
              children: [
                Text(
                  'Малітоўнік',
                  key: const Key('prayerbook-title'),
                  style: ReaderTheme.of(context).displayTitle(36),
                ),
                const SizedBox(height: 22),
                const _SectionTitle(title: 'Абраныя'),
                if (favorites.isEmpty)
                  const Padding(
                    key: Key('prayerbook-empty-favorites'),
                    padding: EdgeInsets.fromLTRB(2, 8, 2, 12),
                    child: Text('Дадавайце частыя малітвы ў Абраныя'),
                  )
                else
                  for (final prayer in favorites)
                    PrayerListRow(prayer: prayer, showFavorite: true),
                const SizedBox(height: 24),
                const _SectionTitle(title: 'Раздзелы'),
                const SizedBox(height: 12),
                PrayerbookSectionGrid(
                  tiles: [
                    PrayerbookSectionTile(
                      key: const Key('holy-mass-destination'),
                      title: 'Святая Імша',
                      subtitle: massLoading && !massAvailable
                          ? 'Адкрываем тэкст…'
                          : 'Парадак Імшы',
                      icon: PhosphorIconsRegular.church,
                      busy: massLoading && !massAvailable,
                      onTap: () {
                        if (massAvailable) {
                          context.push('/prayers/prayer/$_kMassOrderPrayerId');
                          return;
                        }
                        if (massLoading) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Тэкст Імшы недаступны'),
                          ),
                        );
                      },
                    ),
                    if (canSeeSongbook)
                      PrayerbookSectionTile(
                        key: const Key('songbook-destination'),
                        title: 'Спеўнік',
                        subtitle: 'Пілігрымковы',
                        icon: PhosphorIconsRegular.playlist,
                        onTap: () => context.push('/prayers/songs'),
                      ),
                    PrayerbookSectionTile(
                      key: const Key('catechism-destination'),
                      title: 'Катэхізіс',
                      subtitle: 'Кампендый',
                      icon: PhosphorIconsRegular.bookOpenText,
                      onTap: () => context.push('/prayers/compendium'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _SectionTitle(
                  title: 'Катэгорыі',
                  action: TextButton(
                    key: const Key('manage-prayer-categories'),
                    onPressed: () => context.push('/prayers/categories'),
                    child: const Text('Кіраваць'),
                  ),
                ),
                if (categoryState.isLoading && categories.isEmpty)
                  const AppProgressLine()
                else if (categoryState.hasError && categories.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Text('Катэгорыі пакуль недаступныя'),
                  )
                else if (categories.isEmpty)
                  const Padding(
                    key: Key('prayerbook-empty-categories'),
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Text('Катэгорый пакуль няма'),
                  )
                else
                  for (final node in buildPrayerCategoryTree(categories))
                    _CategoryRow(category: node.category),
                const SizedBox(height: 28),
                const _SectionTitle(title: 'Усе малітвы'),
                _DestinationRow(
                  key: const Key('all-prayers-destination'),
                  title: 'Адкрыць увесь малітоўнік',
                  subtitle: '${catalog.length} малітваў',
                  icon: PhosphorIconsRegular.books,
                  onTap: () => context.push('/prayers/all'),
                ),
                const SizedBox(height: 12),
                _DestinationRow(
                  key: const Key('my-prayers-destination'),
                  title: 'Мае малітвы',
                  subtitle: 'Стварыць або змяніць асабістую малітву',
                  icon: PhosphorIconsRegular.notepad,
                  onTap: () => context.push('/prayers/my'),
                ),
              ],
            ),
          ),
          FloatingTopActions(
            seasonColor: cs.tertiary,
            actions: [
              IconButton(
                key: const Key('prayerbook-search-action'),
                tooltip: 'Пошук малітваў',
                onPressed: () => context.push('/prayers/search'),
                icon: const PhosphorIcon(
                  PhosphorIconsRegular.magnifyingGlass,
                  size: 22,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PrayerCatalogScreen extends ConsumerStatefulWidget {
  const PrayerCatalogScreen({super.key, this.searchInitially = false});

  final bool searchInitially;

  @override
  ConsumerState<PrayerCatalogScreen> createState() =>
      _PrayerCatalogScreenState();
}

class _PrayerCatalogScreenState extends ConsumerState<PrayerCatalogScreen> {
  late final TextEditingController _query;
  late final FocusNode _focus;
  final ScrollController _scrollController = ScrollController();
  AppRouteEntryScope? _routeScope;
  bool _bottomSlotInitialized = false;

  @override
  void initState() {
    super.initState();
    final filter = ref.read(prayersFilterProvider);
    _query = TextEditingController(text: filter.searchQuery);
    _focus = FocusNode();
    if (widget.searchInitially) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _focus.requestFocus(),
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _routeScope = AppRouteEntryScope.maybeOf(context);
    if (_bottomSlotInitialized) return;
    _bottomSlotInitialized = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        AppRouteEntryScope.maybeOf(context)?.showContextualBottomBar(true);
      }
    });
  }

  @override
  void dispose() {
    _routeScope?.showContextualBottomBar(false);
    _query.dispose();
    _focus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(prayerCatalogProvider);
    final filter = ref.watch(prayersFilterProvider);
    final visible = filterAndSortPrayers(
      catalog,
      filter,
      ref.watch(settingsProvider).favoriteIds,
    );
    return _PrayerListPage(
      title: widget.searchInitially ? 'Пошук' : 'Усе малітвы',
      subtitle: widget.searchInitially
          ? 'Назва або тэкст малітвы'
          : 'Увесь малітоўнік адным спісам',
      scrollController: _scrollController,
      scrollKey: widget.searchInitially
          ? const PageStorageKey('prayer-search-scroll')
          : const PageStorageKey('all-prayers-scroll'),
      searchDock: PrayerSearchDock(
        controller: _query,
        focusNode: _focus,
        selectedFilterCount: filter.selectedTags.length,
        onChanged: (value) {
          ref.read(prayersFilterProvider.notifier).setSearch(value);
          setState(() {});
        },
        onSubmitted: ref.read(prayersFilterProvider.notifier).setSearch,
        onClear: () {
          _query.clear();
          ref.read(prayersFilterProvider.notifier).setSearch('');
          setState(() {});
          _focus.requestFocus();
        },
        onFilter: () => _showTagFilter(context),
      ),
      prayers: visible,
      emptyTitle: filter.isActive
          ? 'Малітваў не знойдзена'
          : 'Малітоўнік пакуль пусты',
    );
  }

  Future<void> _showTagFilter(BuildContext context) {
    final bottomSystemInset = systemBottomInset(context);
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      builder: (_) => _PrayerTagsSheet(bottomSystemInset: bottomSystemInset),
    );
  }
}

class PrayerCategoryScreen extends ConsumerStatefulWidget {
  const PrayerCategoryScreen({super.key, required this.categoryId});

  final String categoryId;

  @override
  ConsumerState<PrayerCategoryScreen> createState() =>
      _PrayerCategoryScreenState();
}

class _PrayerCategoryScreenState extends ConsumerState<PrayerCategoryScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final node = findPrayerCategoryNode(
      buildPrayerCategoryTree(ref.watch(prayerMenuCategoriesProvider)),
      widget.categoryId,
    );
    final category = node?.category;
    if (category == null) {
      return const _MissingPrayerbookPage(title: 'Катэгорыя не знойдзена');
    }
    final settings = ref.watch(settingsProvider);
    final prayers = prayersForCategory(
      ref.watch(prayerCatalogProvider),
      category,
      settings,
    );
    return _PrayerListPage(
      title: category.name,
      subtitle: 'Малітвы гэтай катэгорыі',
      scrollController: _scrollController,
      scrollKey: PageStorageKey('prayer-category-${category.id}-scroll'),
      prayers: prayers,
      categories: [for (final child in node!.children) child.category],
      emptyTitle: 'У гэтай катэгорыі няма малітваў',
    );
  }
}

class PrayerCategoriesScreen extends ConsumerWidget {
  const PrayerCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final globals = ref.watch(globalPrayerCategoriesProvider);
    final allowRestricted = ref.watch(priestAccessProvider).content != null;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Stack(
        children: [
          AmbientWash(
            seasonColor: cs.tertiary,
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                20,
                MediaQuery.paddingOf(context).top + 90,
                20,
                152 + MediaQuery.viewPaddingOf(context).bottom,
              ),
              children: [
                Text(
                  'Катэгорыі',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Стандартныя можна схаваць, асабістыя — змяняць і выдаляць.',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 24),
                globals.when(
                  loading: () => const AppProgressLine(),
                  error: (_, _) => const Text(
                    'Не атрымалася загрузіць стандартныя катэгорыі',
                  ),
                  data: (items) => Column(
                    children: [
                      for (final category in items)
                        if (allowRestricted || !category.priestOnly)
                          _ManageCategoryRow(
                            key: ValueKey('manage-global-${category.id}'),
                            category: category,
                            hidden: settings.hiddenGlobalPrayerCategoryIds
                                .contains(category.id),
                            onVisibility: () {
                              final notifier = ref.read(
                                settingsProvider.notifier,
                              );
                              if (settings.hiddenGlobalPrayerCategoryIds
                                  .contains(category.id)) {
                                notifier.showGlobalPrayerCategory(category.id);
                              } else {
                                notifier.hideGlobalPrayerCategory(category.id);
                              }
                            },
                          ),
                    ],
                  ),
                ),
                for (final category in settings.userCategories)
                  _ManageCategoryRow(
                    key: ValueKey('manage-user-${category.id}'),
                    category: PrayerMenuCategory.personal(category),
                    onEdit: () => _editCategory(context, ref, category),
                    onDelete: () => _deleteCategory(context, ref, category),
                  ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  key: const Key('create-category-action'),
                  onPressed: () => _editCategory(context, ref, null),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Стварыць катэгорыю'),
                ),
              ],
            ),
          ),
          FloatingTopActions(showBack: true, seasonColor: cs.tertiary),
        ],
      ),
    );
  }

  Future<void> _editCategory(
    BuildContext context,
    WidgetRef ref,
    UserCategory? existing,
  ) async {
    final catalog = ref.read(prayerCatalogProvider);
    final settings = ref.read(settingsProvider);
    final result = await Navigator.of(context).push<_CategoryDraft>(
      MaterialPageRoute(
        builder: (_) => _CategoryEditorScreen(
          existing: existing,
          prayers: catalog,
          availableTags: ref.read(allTagsProvider),
          memberIds: existing == null
              ? const {}
              : {
                  for (final prayer in catalog)
                    if (settings.prayerCategoryMap[prayer.id]?.contains(
                          existing.id,
                        ) ==
                        true)
                      prayer.id,
                },
        ),
      ),
    );
    if (result == null || !context.mounted) return;
    final notifier = ref.read(settingsProvider.notifier);
    final id = existing == null
        ? notifier.addCategory(
            result.name,
            result.tags,
            iconKey: result.iconKey,
          )
        : existing.id;
    if (existing != null) {
      notifier.updateCategory(
        id,
        result.name,
        result.tags,
        iconKey: result.iconKey,
      );
    }
    for (final prayer in catalog) {
      notifier.setPrayerCategory(
        prayer.id,
        id,
        result.memberIds.contains(prayer.id),
      );
    }
  }

  Future<void> _deleteCategory(
    BuildContext context,
    WidgetRef ref,
    UserCategory category,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Выдаліць катэгорыю?'),
        content: Text(category.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Адмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Выдаліць'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(settingsProvider.notifier).deleteCategory(category.id);
    }
  }
}

class PrayerListRow extends ConsumerWidget {
  const PrayerListRow({
    super.key,
    required this.prayer,
    this.showFavorite = true,
  });

  final Prayer prayer;
  final bool showFavorite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorite = ref
        .watch(settingsProvider)
        .favoriteIds
        .contains(prayer.id);
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: prayer.displayTitle,
      child: InkWell(
        key: ValueKey('prayer-row-${prayer.id}'),
        onTap: () {
          HapticFeedback.lightImpact();
          context.push('/prayers/prayer/${prayer.id}');
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 62),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    prayer.displayTitle,
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(height: 1.3),
                  ),
                ),
              ),
              if (showFavorite)
                IconButton(
                  key: ValueKey('favorite-${prayer.id}'),
                  tooltip: favorite ? 'Выдаліць з абраных' : 'Дадаць у абраныя',
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    ref
                        .read(settingsProvider.notifier)
                        .toggleFavorite(prayer.id);
                  },
                  icon: PhosphorIcon(
                    favorite
                        ? PhosphorIconsFill.heart
                        : PhosphorIconsRegular.heart,
                    color: favorite ? cs.error : cs.onSurfaceVariant,
                    size: 21,
                  ),
                ),
              Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrayerListPage extends StatelessWidget {
  const _PrayerListPage({
    required this.title,
    required this.subtitle,
    required this.prayers,
    required this.emptyTitle,
    required this.scrollController,
    required this.scrollKey,
    this.searchDock,
    this.categories = const [],
  });

  final String title;
  final String subtitle;
  final List<Prayer> prayers;
  final String emptyTitle;
  final ScrollController scrollController;
  final PageStorageKey<String> scrollKey;
  final Widget? searchDock;
  final List<PrayerMenuCategory> categories;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Stack(
        children: [
          AmbientWash(
            seasonColor: cs.tertiary,
            child: ListView(
              key: scrollKey,
              controller: scrollController,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                20,
                MediaQuery.paddingOf(context).top + 90,
                20,
                (searchDock == null ? 120 : 104) +
                    MediaQuery.viewPaddingOf(context).bottom,
              ),
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(subtitle, style: TextStyle(color: cs.onSurfaceVariant)),
                const SizedBox(height: 18),
                for (final category in categories)
                  _CategoryRow(category: category),
                if (categories.isNotEmpty && prayers.isNotEmpty)
                  const SizedBox(height: 18),
                if (prayers.isEmpty && categories.isEmpty)
                  Padding(
                    key: const Key('prayer-list-empty'),
                    padding: const EdgeInsets.symmetric(vertical: 42),
                    child: Text(emptyTitle, textAlign: TextAlign.center),
                  )
                else
                  for (final prayer in prayers) PrayerListRow(prayer: prayer),
              ],
            ),
          ),
          FloatingTopActions(showBack: true, seasonColor: cs.tertiary),
          if (searchDock != null)
            FloatingOverlayPositioned(
              gap: 12,
              child: Center(child: searchDock!),
            ),
        ],
      ),
    );
  }
}

/// Floating search field with a filter action, shared by the prayer catalog
/// and the songbook list.
class PrayerSearchDock extends StatelessWidget {
  const PrayerSearchDock({
    super.key,
    this.hintText = 'Пошук малітваў',
    this.dockKey = const Key('prayer-search-dock'),
    this.fieldKey = const Key('prayer-search-field'),
    this.filterKey = const Key('prayer-filter-action'),
    required this.controller,
    required this.focusNode,
    required this.selectedFilterCount,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
    this.onFilter,
  });

  final String hintText;
  final Key dockKey;
  final Key fieldKey;
  final Key filterKey;
  final TextEditingController controller;
  final FocusNode focusNode;
  final int selectedFilterCount;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  /// Hidden when `null` (a search-only dock, for example the Compendium).
  final VoidCallback? onFilter;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ConstrainedBox(
      key: dockKey,
      constraints: const BoxConstraints(maxWidth: 480),
      child: GlassSurface(
        style: GlassStyle.pill,
        borderRadius: BorderRadius.circular(30),
        child: SizedBox(
          height: 58,
          child: Row(
            children: [
              const SizedBox(width: 17),
              Icon(Icons.search_rounded, size: 23, color: cs.primary),
              const SizedBox(width: 4),
              Expanded(
                child: TextField(
                  key: fieldKey,
                  controller: controller,
                  focusNode: focusNode,
                  textInputAction: TextInputAction.search,
                  onSubmitted: onSubmitted,
                  onChanged: onChanged,
                  decoration: InputDecoration(
                    hintText: hintText,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8),
                    isCollapsed: true,
                  ),
                ),
              ),
              if (controller.text.isNotEmpty)
                IconButton(
                  tooltip: 'Ачысціць пошук',
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              if (onFilter != null)
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      key: filterKey,
                      tooltip: selectedFilterCount == 0
                          ? 'Адкрыць фільтр'
                          : 'Фільтр: выбрана $selectedFilterCount',
                      color: selectedFilterCount == 0
                          ? cs.onSurfaceVariant
                          : cs.primary,
                      onPressed: onFilter,
                      icon: const Icon(Icons.tune_rounded, size: 22),
                    ),
                    if (selectedFilterCount > 0)
                      Positioned(
                        top: 2,
                        right: 1,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: cs.primary,
                            shape: BoxShape.circle,
                          ),
                          child: SizedBox.square(
                            dimension: 18,
                            child: Center(
                              child: Text(
                                '$selectedFilterCount',
                                style: TextStyle(
                                  color: cs.onPrimary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              const SizedBox(width: 6),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrayerTagsSheet extends ConsumerWidget {
  const _PrayerTagsSheet({required this.bottomSystemInset});

  final double bottomSystemInset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags = ref.watch(allTagsProvider);
    final selected = ref.watch(prayersFilterProvider).selectedTags;
    return SafeArea(
      top: false,
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, bottomSystemInset + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Фільтр па тэгах',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final tag in tags)
                      FilterChip(
                        label: Text(tag),
                        selected: selected.contains(tag),
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
                  onPressed: selected.isEmpty
                      ? null
                      : ref.read(prayersFilterProvider.notifier).clearTags,
                  child: const Text('Ачысціць'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.action});
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      ?action,
    ],
  );
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.category});
  final PrayerMenuCategory category;

  @override
  Widget build(BuildContext context) => _DestinationRow(
    key: ValueKey('category-${category.id}'),
    title: category.name,
    leading: CategoryIcon(category.displayIconKey),
    onTap: () =>
        context.push('/prayers/category/${Uri.encodeComponent(category.id)}'),
  );
}

class _DestinationRow extends StatelessWidget {
  const _DestinationRow({
    super.key,
    required this.title,
    this.icon,
    this.leading,
    required this.onTap,
    this.subtitle,
  }) : assert(icon != null || leading != null);
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? leading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    minTileHeight: 58,
    leading: leading ?? Icon(icon),
    title: Text(title),
    subtitle: subtitle == null ? null : Text(subtitle!),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: onTap,
  );
}

class _ManageCategoryRow extends StatelessWidget {
  const _ManageCategoryRow({
    super.key,
    required this.category,
    this.hidden = false,
    this.onVisibility,
    this.onEdit,
    this.onDelete,
  });
  final PrayerMenuCategory category;
  final bool hidden;
  final VoidCallback? onVisibility;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: CategoryIcon(category.displayIconKey),
    title: Text(category.name),
    subtitle: Text(
      category.isGlobal ? 'Стандартная катэгорыя' : 'Ваша катэгорыя',
    ),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onVisibility != null)
          IconButton(
            key: ValueKey('category-visibility-${category.id}'),
            tooltip: hidden ? 'Паказаць' : 'Схаваць',
            onPressed: onVisibility,
            icon: Icon(
              hidden
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
          ),
        if (onEdit != null)
          IconButton(
            tooltip: 'Рэдагаваць',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
        if (onDelete != null)
          IconButton(
            tooltip: 'Выдаліць',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
      ],
    ),
  );
}

class _CategoryDraft {
  const _CategoryDraft(this.name, this.tags, this.memberIds, this.iconKey);
  final String iconKey;
  final String name;
  final List<String> tags;
  final Set<String> memberIds;
}

class _CategoryEditorScreen extends StatefulWidget {
  const _CategoryEditorScreen({
    required this.existing,
    required this.prayers,
    required this.availableTags,
    required this.memberIds,
  });
  final UserCategory? existing;
  final List<Prayer> prayers;
  final List<String> availableTags;
  final Set<String> memberIds;

  @override
  State<_CategoryEditorScreen> createState() => _CategoryEditorScreenState();
}

class _CategoryEditorScreenState extends State<_CategoryEditorScreen> {
  late final TextEditingController _name = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late final Set<String> _tags = {...?widget.existing?.tags};
  late final Set<String> _members = Set<String>.from(widget.memberIds);
  late String _iconKey = widget.existing == null
      ? kDefaultCategoryIconKey
      : displayCategoryIconKey(
          iconKey: widget.existing!.iconKey,
          id: widget.existing!.id,
          name: widget.existing!.name,
          tags: widget.existing!.tags,
        );
  // While creating, the suggested icon follows the name until one is picked.
  bool _iconPicked = false;

  void _suggestIcon() {
    if (widget.existing != null || _iconPicked) return;
    final name = _name.text.trim();
    _iconKey = name.isEmpty && _tags.isEmpty
        ? kDefaultCategoryIconKey
        : suggestCategoryIconKey(name: name, tags: _tags.toList());
  }

  List<String> get _visibleTags => ({...widget.availableTags, ..._tags}.toList()
    ..sort((left, right) => left.toLowerCase().compareTo(right.toLowerCase())));

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickPrayers() async {
    final selected = await Navigator.of(context).push<Set<String>>(
      MaterialPageRoute(
        builder: (_) => _CategoryPrayerPickerScreen(
          prayers: widget.prayers,
          selectedIds: _members,
        ),
      ),
    );
    if (selected != null && mounted) {
      setState(() {
        _members
          ..clear()
          ..addAll(selected);
      });
    }
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(
      context,
      _CategoryDraft(name, _tags.toList(growable: false), _members, _iconKey),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final canSave = _name.text.trim().isNotEmpty;
    final title = widget.existing == null
        ? 'Новая катэгорыя'
        : 'Змяніць катэгорыю';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          TextButton(
            key: const Key('save-category-action'),
            onPressed: canSave ? _save : null,
            child: const Text('Захаваць'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            20,
            18,
            20,
            28 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          children: [
            TextField(
              key: const Key('category-name-field'),
              controller: _name,
              autofocus: widget.existing == null,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
              onChanged: (_) => setState(_suggestIcon),
              decoration: const InputDecoration(
                labelText: 'Назва катэгорыі',
                hintText: 'Напрыклад, Малітвы на кожны дзень',
              ),
            ),
            const SizedBox(height: 16),
            CategoryIconField(
              iconKey: _iconKey,
              onChanged: (key) => setState(() {
                _iconKey = key;
                _iconPicked = true;
              }),
            ),
            const SizedBox(height: 28),
            Text(
              'Хуткі выбар тэгаў',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'У катэгорыю аўтаматычна трапяць усе малітвы з выбранымі тэгамі.',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            if (_visibleTags.isEmpty)
              Text(
                'Тэгаў пакуль няма.',
                style: TextStyle(color: cs.onSurfaceVariant),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in _visibleTags)
                    FilterChip(
                      key: ValueKey('category-tag-$tag'),
                      label: Text(tag),
                      selected: _tags.contains(tag),
                      showCheckmark: true,
                      onSelected: (selected) => setState(() {
                        selected ? _tags.add(tag) : _tags.remove(tag);
                        _suggestIcon();
                      }),
                    ),
                ],
              ),
            const SizedBox(height: 32),
            Text(
              'Асобныя малітвы',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Дадайце малітвы, якія не падыходзяць пад выбраныя тэгі.',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Card(
              margin: EdgeInsets.zero,
              color: cs.surfaceContainerLow,
              child: ListTile(
                key: const Key('pick-category-prayers'),
                minTileHeight: 64,
                leading: const Icon(Icons.playlist_add_rounded),
                title: const Text('Выбраць малітвы'),
                subtitle: Text(
                  _members.isEmpty
                      ? 'Пошук па назве'
                      : 'Выбрана: ${_members.length}',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _pickPrayers,
              ),
            ),
            if (_members.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final prayer in widget.prayers)
                    if (_members.contains(prayer.id))
                      InputChip(
                        label: Text(prayer.displayTitle),
                        onDeleted: () =>
                            setState(() => _members.remove(prayer.id)),
                      ),
                ],
              ),
            ],
            const SizedBox(height: 32),
            FilledButton(
              onPressed: canSave ? _save : null,
              child: const Text('Захаваць катэгорыю'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryPrayerPickerScreen extends StatefulWidget {
  const _CategoryPrayerPickerScreen({
    required this.prayers,
    required this.selectedIds,
  });

  final List<Prayer> prayers;
  final Set<String> selectedIds;

  @override
  State<_CategoryPrayerPickerScreen> createState() =>
      _CategoryPrayerPickerScreenState();
}

class _CategoryPrayerPickerScreenState
    extends State<_CategoryPrayerPickerScreen> {
  final TextEditingController _query = TextEditingController();
  late final Set<String> _selected = Set<String>.from(widget.selectedIds);

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _finish() => Navigator.pop(context, _selected);

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = _query.text.trim().toLowerCase();
    final visible = widget.prayers
        .where(
          (prayer) =>
              normalizedQuery.isEmpty ||
              prayer.displayTitle.toLowerCase().contains(normalizedQuery) ||
              prayer.displayText.toLowerCase().contains(normalizedQuery),
        )
        .toList(growable: false);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Выбар малітваў'),
        actions: [
          TextButton(onPressed: _finish, child: const Text('Гатова')),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
              child: TextField(
                key: const Key('category-prayer-search'),
                controller: _query,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Знайсці малітву',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Ачысціць пошук',
                          onPressed: () => setState(_query.clear),
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    _selected.isEmpty
                        ? 'Нічога не выбрана'
                        : 'Выбрана: ${_selected.length}',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                  const Spacer(),
                  if (_selected.isNotEmpty)
                    TextButton(
                      onPressed: () => setState(_selected.clear),
                      child: const Text('Ачысціць'),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: visible.isEmpty
                  ? const Center(child: Text('Малітваў не знойдзена'))
                  : ListView.builder(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.only(
                        bottom: 20 + MediaQuery.viewPaddingOf(context).bottom,
                      ),
                      itemCount: visible.length,
                      itemBuilder: (context, index) {
                        final prayer = visible[index];
                        final selected = _selected.contains(prayer.id);
                        return CheckboxListTile(
                          key: ValueKey('category-prayer-${prayer.id}'),
                          value: selected,
                          title: Text(prayer.displayTitle),
                          controlAffinity: ListTileControlAffinity.trailing,
                          onChanged: (value) => setState(
                            () => value == true
                                ? _selected.add(prayer.id)
                                : _selected.remove(prayer.id),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: FilledButton(
          key: const Key('confirm-category-prayers'),
          onPressed: _finish,
          child: Text(
            _selected.isEmpty ? 'Гатова' : 'Дадаць (${_selected.length})',
          ),
        ),
      ),
    );
  }
}

class _MissingPrayerbookPage extends StatelessWidget {
  const _MissingPrayerbookPage({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Малітоўнік')),
    body: Center(child: Text(title)),
  );
}
