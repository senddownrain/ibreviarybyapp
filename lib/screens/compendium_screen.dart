import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:mybrev_flutter/constants/compendium.dart';
import 'package:mybrev_flutter/navigation/app_navigation.dart';
import 'package:mybrev_flutter/providers/compendium_provider.dart';
import 'package:mybrev_flutter/screens/prayers_screen.dart';
import 'package:mybrev_flutter/theme/glass.dart';
import 'package:mybrev_flutter/utils/compendium_data.dart';
import 'package:mybrev_flutter/utils/compendium_search.dart';
import 'package:mybrev_flutter/utils/system_insets.dart';
import 'package:mybrev_flutter/widgets/compendium/compendium_widgets.dart';
import 'package:mybrev_flutter/widgets/floating_top_actions.dart';

/// `/prayers/compendium`: the four parts and local search.
///
/// Follows the songbook/prayer catalog contract: the search dock replaces the
/// app dock through the contextual bottom slot, and the query and scroll
/// position survive Question → Back.
class CompendiumScreen extends ConsumerStatefulWidget {
  const CompendiumScreen({super.key});

  @override
  ConsumerState<CompendiumScreen> createState() => _CompendiumScreenState();
}

class _CompendiumScreenState extends ConsumerState<CompendiumScreen> {
  late final TextEditingController _query;
  final FocusNode _focus = FocusNode();
  AppRouteEntryScope? _routeScope;
  bool _bottomSlotInitialized = false;

  @override
  void initState() {
    super.initState();
    _query = TextEditingController(
      text: ref.read(compendiumSearchQueryProvider),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(compendiumRefreshProvider)();
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
    super.dispose();
  }

  void _setQuery(String value) {
    ref.read(compendiumSearchQueryProvider.notifier).set(value);
    setState(() {});
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final index = ref.watch(compendiumIndexProvider);
    final query = ref.watch(compendiumSearchQueryProvider);
    final searching = query.trim().isNotEmpty;

    final header = <Widget>[
      Text(
        'Каталіцкі Касцёл',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: GlassTokens.of(context).accentOnSurface(cs.tertiary),
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        kCompendiumTitle,
        key: const Key('compendium-title'),
        style: Theme.of(
          context,
        ).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 6),
      Text(
        index.valueOrNull == null
            ? 'Катэхізіс у пытаннях і адказах'
            : '${index.requireValue.questions.length} пытанняў і адказаў',
        style: TextStyle(color: cs.onSurfaceVariant),
      ),
      const SizedBox(height: 14),
    ];

    final List<Widget> body;
    if (index.hasError && !index.hasValue) {
      body = [
        _CompendiumMessage(
          key: const Key('compendium-error'),
          icon: PhosphorIconsLight.cloudSlash,
          title: 'Не атрымалася адкрыць Кампендый',
          message:
              'Паспрабуйце яшчэ раз або сінхранізуйце Кампендый у наладах.',
          action: TextButton(
            onPressed: () => ref.invalidate(compendiumBundledProvider),
            child: const Text('Паўтарыць'),
          ),
        ),
      ];
    } else if (!index.hasValue) {
      body = const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: LinearProgressIndicator(key: Key('compendium-loading')),
        ),
      ];
    } else if (searching) {
      body = _results(context);
    } else {
      final data = index.requireValue;
      body = [
        for (final part in data.parts)
          CompendiumListRow(
            key: ValueKey('compendium-part-${part.id}'),
            leading: CompendiumBadge(label: romanNumeral(part.number)),
            eyebrow: part.label,
            title: part.title,
            subtitle: switch (data.partRange(part.id)) {
              (final first, final last) => 'Пытанні $first–$last',
              null => null,
            },
            onTap: () => context.push(compendiumPartLocation(part.id)),
          ),
        const CompendiumSourceAttribution(),
      ];
    }

    final children = [...header, ...body];
    return Scaffold(
      body: Stack(
        children: [
          AmbientWash(
            seasonColor: cs.tertiary,
            child: ListView.builder(
              key: const PageStorageKey('compendium-scroll'),
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
          FloatingOverlayPositioned(
            gap: 12,
            child: Center(
              child: PrayerSearchDock(
                hintText: 'Пошук: слова або нумар',
                dockKey: const Key('compendium-search-dock'),
                fieldKey: const Key('compendium-search-field'),
                controller: _query,
                focusNode: _focus,
                selectedFilterCount: 0,
                onChanged: _setQuery,
                onSubmitted: _submit,
                onClear: () {
                  _query.clear();
                  _setQuery('');
                  _focus.requestFocus();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _results(BuildContext context) {
    final results = ref.watch(compendiumSearchResultsProvider);
    final ready = ref.watch(compendiumSearchIndexProvider) != null;
    final cs = Theme.of(context).colorScheme;
    if (!ready) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: LinearProgressIndicator(),
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
        const _CompendiumMessage(
          key: Key('compendium-empty'),
          icon: PhosphorIconsLight.magnifyingGlass,
          title: 'Нічога не знойдзена',
          message: 'Паспрабуйце іншае слова або нумар пытання.',
        ),
      for (final result in results)
        CompendiumListRow(
          key: ValueKey('compendium-result-${result.question.number}'),
          leading: CompendiumBadge(label: '${result.question.number}'),
          title: result.question.question,
          subtitle: compendiumQuestionContext(result.question),
          onTap: () => openCompendiumQuestion(context, result.question.number),
        ),
    ];
  }
}

/// `/prayers/compendium/part/:partId`: sections → chapters → reading groups.
class CompendiumPartScreen extends ConsumerWidget {
  const CompendiumPartScreen({super.key, required this.partId});

  final String partId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final accent = GlassTokens.of(context).accentOnSurface(cs.tertiary);
    final state = ref.watch(compendiumPartOutlineProvider(partId));
    final outline = state.valueOrNull;

    final children = <Widget>[];
    if (outline == null) {
      children.add(
        state.isLoading
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: LinearProgressIndicator(key: Key('compendium-loading')),
              )
            : _CompendiumMessage(
                key: const Key('compendium-part-not-found'),
                icon: PhosphorIconsLight.bookOpenText,
                title: 'Частка не знойдзена',
                message: 'Вярніцеся да зместу Кампендыя.',
                action: TextButton(
                  onPressed: () => context.go(compendiumLocation()),
                  child: const Text('Да зместу'),
                ),
              ),
      );
    } else {
      children.addAll([
        Text(
          outline.part.label,
          style: textTheme.labelMedium?.copyWith(
            color: accent,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          outline.part.title,
          key: const Key('compendium-part-title'),
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
      ]);
      for (final section in outline.sections) {
        children.addAll([
          const SizedBox(height: 22),
          if (section.label.isNotEmpty)
            Text(
              section.label,
              style: textTheme.labelSmall?.copyWith(
                color: accent,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
          if (section.title.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              section.title,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ]);
        for (final chapter in section.chapters) {
          if ((chapter.title ?? '').isNotEmpty) {
            children.addAll([
              const SizedBox(height: 16),
              if ((chapter.label ?? '').isNotEmpty)
                Text(
                  chapter.label!,
                  style: textTheme.labelSmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
              Text(
                chapter.title!,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ]);
          }
          for (final group in chapter.groups) {
            if (group.parentTitle != null) {
              children.add(
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    group.parentTitle!,
                    style: textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              );
            }
            final topic = group.kind == CompendiumGroupKind.topic;
            children.add(
              CompendiumListRow(
                key: ValueKey('compendium-group-${group.id}'),
                title: topic ? group.title : group.rangeLabel,
                subtitle: topic ? group.rangeLabel : null,
                onTap: () => context.push(compendiumTopicLocation(group.id)),
              ),
            );
          }
        }
      }
      children.add(const CompendiumSourceAttribution());
    }

    return Scaffold(
      body: Stack(
        children: [
          AmbientWash(
            seasonColor: cs.tertiary,
            child: ListView.builder(
              key: PageStorageKey('compendium-part-$partId-scroll'),
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

class _CompendiumMessage extends StatelessWidget {
  const _CompendiumMessage({
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
