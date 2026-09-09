import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:mybrev_flutter/models/prayer.dart';
import 'package:mybrev_flutter/providers/prayer_categories_provider.dart';
import 'package:mybrev_flutter/providers/prayers_provider.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/theme/glass.dart';
import 'package:mybrev_flutter/widgets/floating_top_actions.dart';

class PrayersScreen extends ConsumerWidget {
  const PrayersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritePrayersProvider);
    final categories = ref.watch(prayerMenuCategoriesProvider);
    final catalog = ref.watch(prayerCatalogProvider);
    final categoryState = ref.watch(globalPrayerCategoriesProvider);
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
                20,
                top + 16,
                20,
                120 + MediaQuery.viewPaddingOf(context).bottom,
              ),
              children: [
                Text(
                  'Малітоўнік',
                  key: const Key('prayerbook-title'),
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.7,
                  ),
                ),
                const SizedBox(height: 30),
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
                _SectionTitle(
                  title: 'Катэгорыі',
                  action: TextButton(
                    key: const Key('manage-prayer-categories'),
                    onPressed: () => context.push('/prayers/categories'),
                    child: const Text('Кіраваць'),
                  ),
                ),
                if (categoryState.isLoading && categories.isEmpty)
                  const LinearProgressIndicator()
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
                  for (final category in categories)
                    _CategoryRow(category: category),
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
  Timer? _debounce;
  late bool _searching;

  @override
  void initState() {
    super.initState();
    final filter = ref.read(prayersFilterProvider);
    _query = TextEditingController(text: filter.searchQuery);
    _focus = FocusNode();
    _searching = widget.searchInitially || filter.searchQuery.isNotEmpty;
    if (widget.searchInitially) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _focus.requestFocus(),
      );
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    _focus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _setQuery(String value) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 250),
      () => ref.read(prayersFilterProvider.notifier).setSearch(value),
    );
  }

  void _showSearch() {
    setState(() => _searching = true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
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
      topAction: IconButton(
        key: const Key('catalog-search-action'),
        tooltip: 'Пошук малітваў',
        onPressed: _showSearch,
        icon: const PhosphorIcon(PhosphorIconsRegular.magnifyingGlass),
      ),
      searchField: _searching
          ? TextField(
              key: const Key('prayer-search-field'),
              controller: _query,
              focusNode: _focus,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Знайсці малітву',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Ачысціць пошук',
                        onPressed: () {
                          _debounce?.cancel();
                          _query.clear();
                          ref
                              .read(prayersFilterProvider.notifier)
                              .setSearch('');
                          setState(() {});
                          _focus.requestFocus();
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
              onChanged: (value) {
                _setQuery(value);
                setState(() {});
              },
            )
          : null,
      filterAction: _searching
          ? TextButton.icon(
              key: const Key('prayer-filter-action'),
              onPressed: () => _showTagFilter(context),
              icon: const Icon(Icons.tune_rounded),
              label: Text(
                filter.selectedTags.isEmpty
                    ? 'Фільтры'
                    : 'Фільтры · ${filter.selectedTags.length}',
              ),
            )
          : null,
      prayers: visible,
      emptyTitle: filter.isActive
          ? 'Малітваў не знойдзена'
          : 'Малітоўнік пакуль пусты',
    );
  }

  Future<void> _showTagFilter(BuildContext context) =>
      showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        showDragHandle: true,
        isScrollControlled: true,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
        builder: (_) => const _PrayerTagsSheet(),
      );
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
    final category = ref
        .watch(prayerMenuCategoriesProvider)
        .where((item) => item.id == widget.categoryId)
        .firstOrNull;
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
      topAction: IconButton(
        key: const Key('category-manage-action'),
        tooltip: 'Кіраваць катэгорыямі',
        onPressed: () => context.push('/prayers/categories'),
        icon: const Icon(Icons.more_horiz_rounded),
      ),
      prayers: prayers,
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
                120 + MediaQuery.viewPaddingOf(context).bottom,
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
                  loading: () => const LinearProgressIndicator(),
                  error: (_, _) => const Text(
                    'Не атрымалася загрузіць стандартныя катэгорыі',
                  ),
                  data: (items) => Column(
                    children: [
                      for (final category in items)
                        _ManageCategoryRow(
                          key: ValueKey('manage-global-${category.id}'),
                          category: category,
                          hidden: settings.hiddenGlobalPrayerCategoryIds
                              .contains(category.id),
                          onVisibility: () {
                            final notifier = ref.read(
                              settingsProvider.notifier,
                            );
                            if (settings.hiddenGlobalPrayerCategoryIds.contains(
                              category.id,
                            )) {
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
    final result = await showDialog<_CategoryDraft>(
      context: context,
      builder: (_) => _CategoryEditorDialog(
        existing: existing,
        prayers: catalog,
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
    );
    if (result == null || !context.mounted) return;
    final notifier = ref.read(settingsProvider.notifier);
    final id = existing == null
        ? notifier.addCategory(result.name, result.tags)
        : existing.id;
    if (existing != null) {
      notifier.updateCategory(id, result.name, result.tags);
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
    this.topAction,
    this.searchField,
    this.filterAction,
  });

  final String title;
  final String subtitle;
  final List<Prayer> prayers;
  final String emptyTitle;
  final ScrollController scrollController;
  final PageStorageKey<String> scrollKey;
  final Widget? topAction;
  final Widget? searchField;
  final Widget? filterAction;

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
                120 + MediaQuery.viewPaddingOf(context).bottom,
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
                if (searchField != null) ...[
                  const SizedBox(height: 20),
                  searchField!,
                  Align(alignment: Alignment.centerRight, child: filterAction),
                ] else
                  const SizedBox(height: 18),
                if (prayers.isEmpty)
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
          FloatingTopActions(
            showBack: true,
            seasonColor: cs.tertiary,
            actions: topAction == null ? const [] : [topAction!],
          ),
        ],
      ),
    );
  }
}

class _PrayerTagsSheet extends ConsumerWidget {
  const _PrayerTagsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags = ref.watch(allTagsProvider);
    final selected = ref.watch(prayersFilterProvider).selectedTags;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
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
    icon: PhosphorIconsRegular.folder,
    onTap: () => context.push('/prayers/category/${category.id}'),
  );
}

class _DestinationRow extends StatelessWidget {
  const _DestinationRow({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    this.subtitle,
  });
  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    minTileHeight: 58,
    leading: Icon(icon),
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
  const _CategoryDraft(this.name, this.tags, this.memberIds);
  final String name;
  final List<String> tags;
  final Set<String> memberIds;
}

class _CategoryEditorDialog extends StatefulWidget {
  const _CategoryEditorDialog({
    required this.existing,
    required this.prayers,
    required this.memberIds,
  });
  final UserCategory? existing;
  final List<Prayer> prayers;
  final Set<String> memberIds;

  @override
  State<_CategoryEditorDialog> createState() => _CategoryEditorDialogState();
}

class _CategoryEditorDialogState extends State<_CategoryEditorDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late final TextEditingController _tags = TextEditingController(
    text: widget.existing?.tags.join(', ') ?? '',
  );
  late final Set<String> _members = Set<String>.from(widget.memberIds);

  @override
  void dispose() {
    _name.dispose();
    _tags.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.existing == null ? 'Новая катэгорыя' : 'Змяніць катэгорыю',
    ),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('category-name-field'),
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Назва'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tags,
              decoration: const InputDecoration(
                labelText: 'Тэгі',
                helperText: 'Праз коску; катэгорыя застаецца tag-based',
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Дададзеныя малітвы',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            for (final prayer in widget.prayers)
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(prayer.displayTitle),
                value: _members.contains(prayer.id),
                onChanged: (selected) => setState(
                  () => selected == true
                      ? _members.add(prayer.id)
                      : _members.remove(prayer.id),
                ),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Адмена'),
      ),
      FilledButton(
        key: const Key('save-category-action'),
        onPressed: () {
          final name = _name.text.trim();
          if (name.isEmpty) return;
          final tags = _tags.text
              .split(',')
              .map((tag) => tag.trim())
              .where((tag) => tag.isNotEmpty)
              .toSet()
              .toList();
          Navigator.pop(context, _CategoryDraft(name, tags, _members));
        },
        child: const Text('Захаваць'),
      ),
    ],
  );
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
