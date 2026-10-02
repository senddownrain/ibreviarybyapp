import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mybrev_flutter/constants/compendium.dart';
import 'package:mybrev_flutter/navigation/app_navigation.dart';
import 'package:mybrev_flutter/providers/compendium_provider.dart';
import 'package:mybrev_flutter/providers/prayers_provider.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/providers/songs_provider.dart';
import 'package:mybrev_flutter/screens/prayers_screen.dart';
import 'package:mybrev_flutter/screens/songbook_screen.dart';
import 'package:mybrev_flutter/theme/glass.dart';
import 'package:mybrev_flutter/utils/compendium_data.dart';
import 'package:mybrev_flutter/utils/compendium_search.dart';
import 'package:mybrev_flutter/utils/song_chords.dart';
import 'package:mybrev_flutter/widgets/bottom_control_geometry.dart';
import 'package:mybrev_flutter/widgets/compendium/compendium_widgets.dart';
import 'package:mybrev_flutter/widgets/floating_top_actions.dart';
import 'package:mybrev_flutter/utils/system_insets.dart';

enum LibrarySearchScope {
  prayers('Малітвы'),
  songs('Спеўнік'),
  compendium('Катэхізіс');

  const LibrarySearchScope(this.label);
  final String label;
}

/// Shared browser rows. Only the active domain is watched and built.
class LibraryBrowserResults extends ConsumerWidget {
  const LibraryBrowserResults({
    super.key,
    required this.scope,
    required this.query,
  });

  final LibrarySearchScope scope;
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trimmed = query.trim();
    switch (scope) {
      case LibrarySearchScope.prayers:
        final prayers = filterAndSortPrayers(
          ref.watch(prayerCatalogProvider),
          PrayersFilter(searchQuery: trimmed),
          ref.watch(settingsProvider).favoriteIds,
        );
        return SliverList.builder(
          itemCount: prayers.length + 1,
          itemBuilder: (context, index) => index == 0
              ? Text(
                  trimmed.isEmpty
                      ? 'Каталог малітваў'
                      : 'Знойдзена: ${prayers.length}',
                  key: const Key('library-results-count'),
                  style: Theme.of(context).textTheme.titleMedium,
                )
              : PrayerListRow(
                  prayer: prayers[index - 1],
                  rowKey: ValueKey(
                    'library-prayer-row-${prayers[index - 1].id}',
                  ),
                ),
        );
      case LibrarySearchScope.songs:
        final state = ref.watch(songsProvider);
        if (!state.hasValue) {
          return SliverToBoxAdapter(
            child: Text(
              state.hasError ? 'Спеўнік недаступны' : 'Загрузка спеўніка…',
            ),
          );
        }
        final songs = filterSongs(state.requireValue, query: trimmed);
        return SliverList.builder(
          itemCount: songs.length + 1,
          itemBuilder: (context, index) => index == 0
              ? Text(
                  trimmed.isEmpty ? 'Усе спевы' : 'Знойдзена: ${songs.length}',
                  key: const Key('library-results-count'),
                  style: Theme.of(context).textTheme.titleMedium,
                )
              : SongListRow(song: songs[index - 1]),
        );
      case LibrarySearchScope.compendium:
        if (trimmed.isEmpty) {
          final state = ref.watch(compendiumIndexProvider);
          if (!state.hasValue) {
            return SliverToBoxAdapter(
              child: Text(
                state.hasError
                    ? 'Катэхізіс недаступны'
                    : 'Загрузка Катэхізіса…',
              ),
            );
          }
          final data = state.requireValue;
          return SliverList.builder(
            itemCount: data.parts.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Text(
                  'Часткі Кампендыя',
                  key: const Key('library-results-count'),
                  style: Theme.of(context).textTheme.titleMedium,
                );
              }
              final part = data.parts[index - 1];
              return CompendiumListRow(
                key: ValueKey('library-part-${part.id}'),
                leading: CompendiumBadge(label: romanNumeral(part.number)),
                eyebrow: part.label,
                title: part.title,
                subtitle: switch (data.partRange(part.id)) {
                  (final first, final last) => 'Пытанні $first–$last',
                  null => null,
                },
                onTap: () => context.push(compendiumPartLocation(part.id)),
              );
            },
          );
        }
        final index = ref.watch(compendiumSearchIndexProvider);
        if (index == null) {
          return const SliverToBoxAdapter(child: Text('Загрузка Катэхізіса…'));
        }
        final results = searchCompendium(index, trimmed);
        return SliverList.builder(
          itemCount: results.length + 1,
          itemBuilder: (context, position) => position == 0
              ? Text(
                  'Знойдзена: ${results.length}',
                  key: const Key('library-results-count'),
                  style: Theme.of(context).textTheme.titleMedium,
                )
              : CompendiumQuestionRow(
                  key: ValueKey(
                    'library-question-${results[position - 1].question.number}',
                  ),
                  question: results[position - 1].question,
                  subtitle: compendiumQuestionContext(
                    results[position - 1].question,
                  ),
                ),
        );
    }
  }
}

class LibraryScopeSelector extends StatelessWidget {
  const LibraryScopeSelector({
    super.key,
    required this.scope,
    required this.onChanged,
  });
  final LibrarySearchScope scope;
  final ValueChanged<LibrarySearchScope> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final candidate in LibrarySearchScope.values)
        ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: BottomControlGeometry.minimumTarget,
          ),
          child: ChoiceChip(
            key: Key('library-scope-${candidate.name}'),
            label: Text(candidate.label),
            selected: scope == candidate,
            onSelected: (_) => onChanged(candidate),
          ),
        ),
    ],
  );
}

/// One query and three search domains. Every domain keeps its own matching
/// function, data source and result row; switching scope changes only those.
class LibrarySearchScreen extends ConsumerStatefulWidget {
  const LibrarySearchScreen({
    super.key,
    required this.initialScope,
    this.initialQuery = '',
  });

  final LibrarySearchScope initialScope;
  final String initialQuery;

  @override
  ConsumerState<LibrarySearchScreen> createState() =>
      _LibrarySearchScreenState();
}

class _LibrarySearchScreenState extends ConsumerState<LibrarySearchScreen> {
  late final TextEditingController _query = TextEditingController(
    text: widget.initialQuery,
  );
  final FocusNode _focus = FocusNode();
  late LibrarySearchScope _scope = widget.initialScope;
  AppRouteEntryScope? _routeScope;
  bool _bottomSlotInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _routeScope = AppRouteEntryScope.maybeOf(context);
    if (_bottomSlotInitialized) return;
    _bottomSlotInitialized = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _routeScope?.showContextualBottomBar(true);
    });
  }

  @override
  void dispose() {
    _routeScope?.showContextualBottomBar(false);
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          AmbientWash(
            seasonColor: Theme.of(context).colorScheme.tertiary,
            child: CustomScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    MediaQuery.paddingOf(context).top + 90,
                    20,
                    0,
                  ),
                  sliver: SliverList.list(
                    children: [
                      Text(
                        'Пошук у Малітоўніку',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 16),
                      LibraryScopeSelector(
                        scope: _scope,
                        onChanged: (scope) => setState(() => _scope = scope),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    0,
                    20,
                    BottomControlGeometry.searchHeight +
                        BottomControlGeometry.gap +
                        systemBottomInset(context) +
                        BottomControlGeometry.contentGap,
                  ),
                  sliver: LibraryBrowserResults(
                    scope: _scope,
                    query: _query.text,
                  ),
                ),
              ],
            ),
          ),
          const FloatingTopActions(showBack: true),
          FloatingOverlayPositioned(
            gap: BottomControlGeometry.gap,
            child: Center(
              child: PrayerSearchDock(
                hintText: 'Пошук у Малітоўніку',
                dockKey: const Key('library-search-dock'),
                fieldKey: const Key('library-search-field'),
                controller: _query,
                focusNode: _focus,
                selectedFilterCount: 0,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _focus.unfocus(),
                onClear: () {
                  _query.clear();
                  setState(() {});
                  _focus.requestFocus();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
