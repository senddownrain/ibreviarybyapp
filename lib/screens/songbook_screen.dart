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
import 'package:mybrev_flutter/utils/system_insets.dart';
import 'package:mybrev_flutter/widgets/floating_top_actions.dart';
import 'package:mybrev_flutter/widgets/songs/song_settings_sheet.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(songbookRefreshProvider)();
    });
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
    final compact = ref.watch(
      songPreferencesProvider.select((prefs) => prefs.compactList),
    );
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
      if (filter.selectedTags.isNotEmpty || filter.favoritesOnly) ...[
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (filter.favoritesOnly)
              InputChip(
                key: const Key('songbook-active-favorites'),
                label: const Text('Толькі абраныя'),
                onDeleted: () => ref
                    .read(songsFilterProvider.notifier)
                    .setFavoritesOnly(false),
              ),
            for (final tag in filter.selectedTags)
              InputChip(
                label: Text(tag),
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
          child: LinearProgressIndicator(key: Key('songbook-loading')),
        )
      else if (songs.hasError && !songs.hasValue)
        _SongbookMessage(
          key: const Key('songbook-error'),
          icon: PhosphorIconsLight.cloudSlash,
          title: 'Не атрымалася адкрыць спеўнік',
          message: 'Праверце сетку або сінхранізуйце Спеўнік у наладах.',
          action: TextButton(
            onPressed: () => ref.invalidate(songSeedProvider),
            child: const Text('Паўтарыць'),
          ),
        )
      else if (visible.isEmpty)
        _SongbookMessage(
          key: const Key('songbook-empty'),
          icon: PhosphorIconsLight.musicNotesSimple,
          title: filter.favoritesOnly
              ? 'Няма абраных спеваў для гэтых фільтраў'
              : 'Спевы не знойдзены',
          message: filter.isActive
              ? 'Змяніце пошук або фільтры.'
              : 'Сінхранізуйце Спеўнік у наладах.',
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
                  : SongListRow(
                      song: visible[index - header.length],
                      compact: compact,
                    ),
            ),
          ),
          FloatingTopActions(
            showBack: true,
            seasonColor: cs.tertiary,
            actions: [
              IconButton(
                key: const Key('songbook-settings-action'),
                tooltip: 'Налады спеўніка',
                onPressed: () => showSongSettingsSheet(context),
                icon: const PhosphorIcon(
                  PhosphorIconsRegular.slidersHorizontal,
                  size: 22,
                ),
              ),
            ],
          ),
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

class SongListRow extends ConsumerWidget {
  const SongListRow({super.key, required this.song, this.compact = false});

  final Song song;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorite = ref.watch(
      songPreferencesProvider.select(
        (prefs) => prefs.favoriteSongIds.contains(song.id),
      ),
    );
    final cs = Theme.of(context).colorScheme;
    final tags = compact ? const <String>[] : song.displayTags;
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
          constraints: BoxConstraints(minHeight: compact ? 48 : 62),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: compact ? 7 : 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              height: 1.3,
                              fontSize: compact ? 15 : null,
                            ),
                      ),
                      if (tags.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          tags.join(' · '),
                          key: ValueKey('song-tags-${song.id}'),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              IconButton(
                key: ValueKey('song-favorite-${song.id}'),
                tooltip: favorite ? 'Выдаліць з абраных' : 'Дадаць у абраныя',
                visualDensity: compact ? VisualDensity.compact : null,
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
            SwitchListTile.adaptive(
              key: const Key('song-favorites-only'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Толькі абраныя'),
              value: filter.favoritesOnly,
              onChanged: notifier.setFavoritesOnly,
            ),
            const SizedBox(height: 8),
            Flexible(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final tag in tags)
                      FilterChip(
                        key: ValueKey('song-tag-filter-$tag'),
                        label: Text(tag),
                        selected: filter.selectedTags.contains(tag),
                        onSelected: (_) => notifier.toggleTag(tag),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                TextButton(
                  onPressed: filter.filterCount == 0
                      ? null
                      : notifier.clearFilters,
                  child: const Text('Ачысціць'),
                ),
                const Spacer(),
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
