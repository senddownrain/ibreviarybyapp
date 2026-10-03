import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:mybrev_flutter/constants/compendium.dart';
import 'package:mybrev_flutter/navigation/app_navigation.dart';
import 'package:mybrev_flutter/providers/compendium_provider.dart';
import 'package:mybrev_flutter/screens/prayers_screen.dart';
import 'package:mybrev_flutter/theme/glass.dart';
import 'package:mybrev_flutter/utils/compendium_search.dart';
import 'package:mybrev_flutter/utils/system_insets.dart';
import 'package:mybrev_flutter/widgets/compendium/compendium_widgets.dart';
import 'package:mybrev_flutter/widgets/floating_top_actions.dart';
import 'package:mybrev_flutter/widgets/reader/reader_scaffold.dart';
import 'package:mybrev_flutter/widgets/loading/app_load_states.dart';

/// Height of [PrayerSearchDock].
const double kCompendiumSearchDockHeight = 58;

/// Gap between the dock and the bottom system inset.
const double kCompendiumSearchDockGap = 12;

/// Search state of the enclosing [CompendiumSearchHost].
class CompendiumSearchScope extends InheritedWidget {
  const CompendiumSearchScope({
    super.key,
    required this.showingResults,
    required super.child,
  });

  /// Whether search results replace the screen's own content.
  final bool showingResults;

  static CompendiumSearchScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CompendiumSearchScope>();

  @override
  bool updateShouldNotify(CompendiumSearchScope oldWidget) =>
      showingResults != oldWidget.showingResults;
}

/// Persistent bottom search for every Compendium screen.
///
/// Each Compendium route wraps its content in a host: the host registers the
/// route's contextual bottom slot (the search dock replaces the app dock, as
/// in the songbook and the prayer catalog) and places the shared
/// [PrayerSearchDock]. The query lives in [compendiumSearchQueryProvider], so
/// every dock shows the same global query and search is never limited to the
/// current part.
///
/// While the user searches from a screen, global results replace its content
/// (the content stays mounted offstage, keeping its scroll position). Back
/// or clearing the query closes the results and restores that screen; a
/// result opens the normal question reader, and Back from it returns to the
/// results. The root renders results inline ([inlineResults]).
class CompendiumSearchHost extends ConsumerStatefulWidget {
  const CompendiumSearchHost({
    super.key,
    required this.child,
    this.inlineResults = false,
    this.reader = false,
  });

  final Widget child;

  /// The child renders results itself ([compendiumSearchResultItems]) and
  /// reads [CompendiumSearchScope.showingResults].
  final bool inlineResults;

  /// A [ReaderScaffold] child: the reader's bottom padding reserves room for
  /// the dock so the answer and the source footer scroll fully above it, and
  /// the dock follows the reader's fullscreen mode.
  final bool reader;

  @override
  ConsumerState<CompendiumSearchHost> createState() =>
      _CompendiumSearchHostState();
}

class _CompendiumSearchHostState extends ConsumerState<CompendiumSearchHost> {
  late final TextEditingController _query;
  final FocusNode _focus = FocusNode();
  AppRouteEntryScope? _routeScope;
  bool _bottomSlotInitialized = false;

  /// Search was started (or, on the root, restored) on this screen.
  late bool _active;

  @override
  void initState() {
    super.initState();
    final query = ref.read(compendiumSearchQueryProvider);
    _query = TextEditingController(text: query);
    _active = widget.inlineResults && query.trim().isNotEmpty;
    _focus.addListener(_onFocus);
    // A query edited on another Compendium screen is shown here on return.
    ref.listenManual(compendiumSearchQueryProvider, (_, next) {
      if (_query.text != next) _query.text = next;
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
    _focus.removeListener(_onFocus);
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onFocus() {
    if (_focus.hasFocus && !_active) setState(() => _active = true);
  }

  void _setQuery(String value) {
    ref.read(compendiumSearchQueryProvider.notifier).set(value);
    setState(() => _active = true);
  }

  /// Enter on an exact question number opens that question (as in MyBrev).
  void _submit(String value) {
    _setQuery(value);
    final results = ref.read(compendiumSearchResultsProvider);
    if (results.isNotEmpty &&
        results.first.field == CompendiumSearchField.number) {
      openCompendiumQuestion(context, results.first.question.number);
    }
  }

  void _clear() {
    _query.clear();
    ref.read(compendiumSearchQueryProvider.notifier).set('');
    setState(() => _active = false);
    _focus.requestFocus();
  }

  void _close() {
    _focus.unfocus();
    setState(() => _active = false);
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(compendiumSearchQueryProvider);
    final showingResults = _active && query.trim().isNotEmpty;
    final overlayResults = showingResults && !widget.inlineResults;
    final chrome = widget.reader
        ? ReaderChromeModeScope.maybeControllerOf(context)?.value
        : null;
    final dockVisible =
        chrome != ReaderChromeMode.hidden || _active || _focus.hasFocus;
    final dockBottom = floatingOverlayBottom(
      context,
      gap: kCompendiumSearchDockGap,
    );

    Widget content = widget.child;
    if (widget.reader) {
      // ReaderContentSurface and the scroll-to-top control already reserve
      // MediaQuery bottom padding for the (here replaced) app dock.
      final media = MediaQuery.of(context);
      content = MediaQuery(
        data: media.copyWith(
          padding: media.padding.copyWith(
            bottom: dockBottom + kCompendiumSearchDockHeight,
          ),
        ),
        child: content,
      );
    }
    if (!widget.inlineResults) {
      content = Offstage(
        offstage: overlayResults,
        child: TickerMode(enabled: !overlayResults, child: content),
      );
    }

    return PopScope<void>(
      canPop: !showingResults,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && showingResults) _close();
      },
      child: CompendiumSearchScope(
        showingResults: showingResults,
        child: Stack(
          children: [
            Positioned.fill(child: content),
            if (overlayResults)
              const Positioned.fill(
                key: Key('compendium-search-overlay'),
                child: _CompendiumSearchResultsPage(),
              ),
            if (dockVisible)
              // Keyboard-aware placement shared with the other floating docks.
              FloatingOverlayPositioned(
                gap: kCompendiumSearchDockGap,
                child: Center(
                  child: Material(
                    type: MaterialType.transparency,
                    child: PrayerSearchDock(
                      hintText: 'Пошук: слова або нумар',
                      dockKey: const Key('compendium-search-dock'),
                      fieldKey: const Key('compendium-search-field'),
                      controller: _query,
                      focusNode: _focus,
                      selectedFilterCount: 0,
                      onChanged: _setQuery,
                      onSubmitted: _submit,
                      onClear: _clear,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Global results started from a nested Compendium screen, in the root's
/// list language (Ambient wash, floating back, Compendium rows).
class _CompendiumSearchResultsPage extends ConsumerWidget {
  const _CompendiumSearchResultsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final children = <Widget>[
      Text(
        kCompendiumTitle,
        style: textTheme.labelMedium?.copyWith(
          color: GlassTokens.of(context).accentOnSurface(cs.tertiary),
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        'Пошук',
        key: const Key('compendium-search-title'),
        style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 14),
      ...compendiumSearchResultItems(context, ref),
    ];
    return Scaffold(
      body: Stack(
        children: [
          AmbientWash(
            seasonColor: cs.tertiary,
            child: ListView.builder(
              key: const PageStorageKey('compendium-search-scroll'),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                20,
                MediaQuery.paddingOf(context).top + 90,
                20,
                104 + MediaQuery.viewPaddingOf(context).bottom,
              ),
              itemCount: children.length,
              itemBuilder: (context, index) => children[index],
            ),
          ),
          FloatingTopActions(showBack: true, seasonColor: cs.tertiary),
        ],
      ),
    );
  }
}

/// Result count, empty state and result rows for the current global query,
/// as list items (built lazily by the caller's list). Only Belarusian
/// question text and real source headings are shown; hidden aliases affect
/// matching only.
List<Widget> compendiumSearchResultItems(BuildContext context, WidgetRef ref) {
  final results = ref.watch(compendiumSearchResultsProvider);
  final ready = ref.watch(compendiumSearchIndexProvider) != null;
  final cs = Theme.of(context).colorScheme;
  if (!ready) {
    return const [
      Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: AppProgressLine(),
      ),
    ];
  }
  return [
    Semantics(
      liveRegion: true,
      child: Text(
        'Знойдзена: ${results.length}',
        key: const Key('compendium-results-count'),
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      ),
    ),
    if (results.isEmpty)
      const CompendiumMessage(
        key: Key('compendium-empty'),
        icon: PhosphorIconsLight.magnifyingGlass,
        title: 'Нічога не знойдзена',
        message: 'Паспрабуйце іншае слова або нумар пытання.',
      ),
    for (final result in results)
      CompendiumQuestionRow(
        key: ValueKey('compendium-result-${result.question.number}'),
        question: result.question,
        subtitle: compendiumQuestionContext(result.question),
      ),
  ];
}
