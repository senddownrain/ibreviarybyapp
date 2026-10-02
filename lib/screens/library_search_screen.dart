import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mybrev_flutter/navigation/app_navigation.dart';
import 'package:mybrev_flutter/providers/compendium_provider.dart';
import 'package:mybrev_flutter/providers/prayers_provider.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/providers/songs_provider.dart';
import 'package:mybrev_flutter/screens/prayers_screen.dart';
import 'package:mybrev_flutter/screens/songbook_screen.dart';
import 'package:mybrev_flutter/theme/glass.dart';
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

  List<Widget> _results() {
    final query = _query.text.trim();
    if (query.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Text('Увядзіце слова або нумар пытання.'),
        ),
      ];
    }
    switch (_scope) {
      case LibrarySearchScope.prayers:
        final prayers = filterAndSortPrayers(
          ref.watch(prayerCatalogProvider),
          PrayersFilter(searchQuery: query),
          ref.watch(settingsProvider).favoriteIds,
        );
        return [
          Text(
            'Знойдзена: ${prayers.length}',
            key: const Key('library-results-count'),
          ),
          if (prayers.isEmpty) const Text('Малітваў не знойдзена'),
          for (final prayer in prayers) PrayerListRow(prayer: prayer),
        ];
      case LibrarySearchScope.songs:
        final songs = ref.watch(songsProvider);
        if (!songs.hasValue) {
          return [
            Text(songs.hasError ? 'Спеўнік недаступны' : 'Загрузка спеўніка…'),
          ];
        }
        final results = filterSongs(songs.requireValue, query: query);
        return [
          Text(
            'Знойдзена: ${results.length}',
            key: const Key('library-results-count'),
          ),
          if (results.isEmpty) const Text('Спеваў не знойдзена'),
          for (final song in results) SongListRow(song: song),
        ];
      case LibrarySearchScope.compendium:
        final index = ref.watch(compendiumSearchIndexProvider);
        if (index == null) return const [Text('Загрузка Катэхізіса…')];
        final results = searchCompendium(index, query);
        return [
          Text(
            'Знойдзена: ${results.length}',
            key: const Key('library-results-count'),
          ),
          if (results.isEmpty) const Text('Пытанняў не знойдзена'),
          for (final result in results)
            CompendiumQuestionRow(
              key: ValueKey('library-question-${result.question.number}'),
              question: result.question,
              subtitle: compendiumQuestionContext(result.question),
            ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          AmbientWash(
            seasonColor: Theme.of(context).colorScheme.tertiary,
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                20,
                MediaQuery.paddingOf(context).top + 90,
                20,
                BottomControlGeometry.searchHeight +
                    BottomControlGeometry.gap +
                    systemBottomInset(context) +
                    BottomControlGeometry.contentGap,
              ),
              children: [
                Text(
                  'Пошук у Малітоўніку',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final scope in LibrarySearchScope.values)
                      ConstrainedBox(
                        constraints: const BoxConstraints(
                          minHeight: BottomControlGeometry.minimumTarget,
                        ),
                        child: ChoiceChip(
                          key: Key('library-scope-${scope.name}'),
                          label: Text(scope.label),
                          selected: _scope == scope,
                          onSelected: (_) => setState(() => _scope = scope),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                ..._results(),
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
