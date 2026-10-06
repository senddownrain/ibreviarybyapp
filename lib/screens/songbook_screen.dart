import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:mybrev_flutter/models/song.dart';
import 'package:mybrev_flutter/navigation/app_navigation.dart';
import 'package:mybrev_flutter/providers/songs_provider.dart';
import 'package:mybrev_flutter/screens/prayers_screen.dart';
import 'package:mybrev_flutter/theme/glass.dart';
import 'package:mybrev_flutter/theme/platform_design.dart';
import 'package:mybrev_flutter/utils/system_insets.dart';
import 'package:mybrev_flutter/widgets/floating_top_actions.dart';
import 'package:mybrev_flutter/widgets/loading/app_load_states.dart';

String songLocation(String id) =>
    Uri(pathSegments: ['', 'prayers', 'songs', id]).toString();

/// `/prayers/songs`: searchable, filterable songbook list.
///
/// Follows the Prayer catalog contract: the search dock replaces the app dock
/// through the contextual bottom slot, and query, filters and scroll position
/// survive Song Detail → Back.
class SongbookScreen extends ConsumerStatefulWidget {
  const SongbookScreen({super.key});

  @override
  ConsumerState<SongbookScreen> createState() => _SongbookScreenState();
}

class _SongbookScreenState extends ConsumerState<SongbookScreen> {
  late final TextEditingController _query;
  final FocusNode _focus = FocusNode();
  final ScrollController _scrollController = ScrollController();
  AppRouteEntryScope? _routeScope;
  bool _bottomSlotInitialized = false;

  @override
  void initState() {
    super.initState();
    _query = TextEditingController(
      text: ref.read(songsFilterProvider).searchQuery,
    );
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

  void _setQuery(String value) {
    ref.read(songsFilterProvider.notifier).setSearch(value);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final songs = ref.watch(filteredSongsProvider);
    final filter = ref.watch(songsFilterProvider);
    final visible = songs.valueOrNull ?? const <Song>[];

    final header = <Widget>[
      Text(
        'Спеўнік',
        key: const Key('songbook-title'),
        style: Theme.of(
          context,
        ).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 6),
      Text(
        songs.hasValue ? 'Спеваў: ${visible.length}' : 'Пілігрымкавы спеўнік',
        key: const Key('songbook-count'),
        style: TextStyle(color: cs.onSurfaceVariant),
      ),
      if (filter.selectedTags.isNotEmpty) ...[
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tag in filter.selectedTags)
              _SongTagChip(
                key: ValueKey('songbook-active-tag-$tag'),
                tag: tag,
                selected: true,
                onDeleted: () =>
                    ref.read(songsFilterProvider.notifier).toggleTag(tag),
              ),
          ],
        ),
      ],
      const SizedBox(height: 14),
      if (songs.isLoading && !songs.hasValue)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: AppProgressLine(key: Key('songbook-loading')),
        )
      else if (songs.hasError && !songs.hasValue)
        _SongbookMessage(
          key: const Key('songbook-error'),
          icon: PhosphorIconsLight.warning,
          title: 'Не атрымалася адкрыць спеўнік',
          message: 'Паспрабуйце яшчэ раз.',
          action: TextButton(
            onPressed: () => ref.invalidate(songSeedProvider),
            child: const Text('Паўтарыць'),
          ),
        )
      else if (visible.isEmpty)
        _SongbookMessage(
          key: const Key('songbook-empty'),
          icon: PhosphorIconsLight.musicNotesSimple,
          title: 'Спевы не знойдзены',
          message: filter.isActive
              ? 'Змяніце пошук або фільтры.'
              : 'Спеўнік пусты.',
        ),
    ];

    return Scaffold(
      body: Stack(
        children: [
          AmbientWash(
            seasonColor: cs.tertiary,
            child: ListView.builder(
              key: const PageStorageKey('songbook-scroll'),
              controller: _scrollController,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                20,
                MediaQuery.paddingOf(context).top + 90,
                20,
                128 + MediaQuery.viewPaddingOf(context).bottom,
              ),
              itemCount: header.length + visible.length,
              itemBuilder: (context, index) => index < header.length
                  ? header[index]
                  : SongListRow(song: visible[index - header.length]),
            ),
          ),
          FloatingTopActions(showBack: true, seasonColor: cs.tertiary),
          FloatingOverlayPositioned(
            gap: 12,
            child: Center(
              child: PrayerSearchDock(
                hintText: 'Пошук спеваў',
                dockKey: const Key('song-search-dock'),
                fieldKey: const Key('song-search-field'),
                filterKey: const Key('song-filter-action'),
                controller: _query,
                focusNode: _focus,
                selectedFilterCount: filter.filterCount,
                onChanged: _setQuery,
                onSubmitted: _setQuery,
                onClear: () {
                  _query.clear();
                  _setQuery('');
                  _focus.requestFocus();
                },
                onFilter: () => _showFilter(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showFilter(BuildContext context) {
    final bottomSystemInset = systemBottomInset(context);
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      builder: (_) => _SongFilterSheet(bottomSystemInset: bottomSystemInset),
    );
  }
}

/// Compact song row: title, favorite and chevron. Tags stay searchable and
/// filterable but are not repeated in every row.
class SongListRow extends ConsumerWidget {
  const SongListRow({super.key, required this.song});

  final Song song;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorite = ref.watch(
      songPreferencesProvider.select(
        (prefs) => prefs.favoriteSongIds.contains(song.id),
      ),
    );
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: song.title,
      child: InkWell(
        key: ValueKey('song-row-${song.id}'),
        onTap: () {
          HapticFeedback.lightImpact();
          context.push(songLocation(song.id));
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Text(
                    song.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      height: 1.3,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              IconButton(
                key: ValueKey('song-favorite-${song.id}'),
                tooltip: favorite ? 'Выдаліць з абраных' : 'Дадаць у абраныя',
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  HapticFeedback.selectionClick();
                  ref
                      .read(songPreferencesProvider.notifier)
                      .toggleFavorite(song.id);
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

class _SongFilterSheet extends ConsumerWidget {
  const _SongFilterSheet({required this.bottomSystemInset});

  final double bottomSystemInset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags = ref.watch(songTagsProvider);
    final filter = ref.watch(songsFilterProvider);
    final notifier = ref.read(songsFilterProvider.notifier);
    return SafeArea(
      top: false,
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, bottomSystemInset + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Фільтр спеваў',
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
                      _SongTagChip(
                        key: ValueKey('song-tag-filter-$tag'),
                        tag: tag,
                        selected: filter.selectedTags.contains(tag),
                        onSelected: () => notifier.toggleTag(tag),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            OverflowBar(
              alignment: MainAxisAlignment.spaceBetween,
              spacing: 8,
              overflowSpacing: 8,
              children: [
                TextButton(
                  onPressed: filter.filterCount == 0
                      ? null
                      : notifier.clearFilters,
                  child: const Text('Ачысціць'),
                ),
                FilledButton(
                  key: const Key('song-filter-done'),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Паказаць спевы'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The same compact tag surface in the filter sheet and above the list.
class _SongTagChip extends StatelessWidget {
  const _SongTagChip({
    super.key,
    required this.tag,
    required this.selected,
    this.onSelected,
    this.onDeleted,
  });

  final String tag;
  final bool selected;
  final VoidCallback? onSelected;
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final glass = usesCupertinoGlass(context);
    final tokens = GlassTokens.of(context);
    final base = glass ? tokens.pillFill : cs.surfaceContainerLow;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width - 40,
      ),
      child: InputChip(
        label: Text(tag, maxLines: 2, overflow: TextOverflow.ellipsis),
        selected: selected,
        onSelected: onSelected == null ? null : (_) => onSelected!(),
        onDeleted: onDeleted,
        showCheckmark: onDeleted == null,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        labelPadding: const EdgeInsets.symmetric(horizontal: 2),
        shape: const StadiumBorder(),
        backgroundColor: base,
        selectedColor: glass
            ? Color.alphaBlend(cs.primary.withValues(alpha: 0.16), base)
            : cs.primaryContainer,
        side: BorderSide(
          color: selected
              ? cs.primary.withValues(alpha: 0.45)
              : cs.outlineVariant,
        ),
      ),
    );
  }
}

class _SongbookMessage extends StatelessWidget {
  const _SongbookMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          PhosphorIcon(icon, size: 40, color: cs.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
          ?action,
        ],
      ),
    );
  }
}
