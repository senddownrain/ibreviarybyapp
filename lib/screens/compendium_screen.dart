import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import 'package:mybrev_flutter/constants/compendium.dart';
import 'package:mybrev_flutter/providers/compendium_provider.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/theme/glass.dart';
import 'package:mybrev_flutter/theme/reader.dart';
import 'package:mybrev_flutter/utils/compendium_data.dart';
import 'package:mybrev_flutter/widgets/compendium/compendium_search_host.dart';
import 'package:mybrev_flutter/widgets/compendium/compendium_widgets.dart';
import 'package:mybrev_flutter/widgets/floating_top_actions.dart';
import 'package:mybrev_flutter/widgets/loading/app_load_states.dart';

/// `/prayers/compendium`: the four parts and local search.
///
/// Follows the songbook/prayer catalog contract: the search dock replaces the
/// app dock through the contextual bottom slot ([CompendiumSearchHost], shared
/// by every Compendium screen), and the query and scroll position survive
/// Question → Back.
class CompendiumScreen extends ConsumerStatefulWidget {
  const CompendiumScreen({super.key});

  @override
  ConsumerState<CompendiumScreen> createState() => _CompendiumScreenState();
}

class _CompendiumScreenState extends ConsumerState<CompendiumScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(compendiumRefreshProvider)();
    });
  }

  @override
  Widget build(BuildContext context) =>
      const CompendiumSearchHost(inlineResults: true, child: _CompendiumRoot());
}

class _CompendiumRoot extends ConsumerWidget {
  const _CompendiumRoot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final index = ref.watch(compendiumIndexProvider);
    final searching =
        CompendiumSearchScope.maybeOf(context)?.showingResults ?? false;

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
        CompendiumMessage(
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
          child: AppProgressLine(key: Key('compendium-loading')),
        ),
      ];
    } else if (searching) {
      body = compendiumSearchResultItems(context, ref);
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
        ],
      ),
    );
  }
}

/// A whole Part, with source headings inline and every question in order.
class CompendiumPartScreen extends ConsumerStatefulWidget {
  const CompendiumPartScreen({super.key, required this.partId, this.target});

  final String partId;
  final String? target;

  @override
  ConsumerState<CompendiumPartScreen> createState() =>
      _CompendiumPartScreenState();
}

class _CompendiumPartScreenState extends ConsumerState<CompendiumPartScreen> {
  final ItemScrollController _items = ItemScrollController();
  String? _scheduledTarget;

  @override
  void didUpdateWidget(covariant CompendiumPartScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target != widget.target ||
        oldWidget.partId != widget.partId) {
      _scheduledTarget = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final state = ref.watch(compendiumIndexProvider);
    final bodySize = ref.watch(settingsProvider).fontSize;
    final outline = state.valueOrNull?.partReadingOutline(widget.partId);
    final targetIndex = outline?.targetIndices[widget.target];
    if (targetIndex != null && _scheduledTarget != widget.target) {
      _scheduledTarget = widget.target;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _items.isAttached) _items.jumpTo(index: targetIndex + 1);
      });
    }
    final itemCount = outline == null ? 1 : outline.items.length + 2;
    return CompendiumSearchHost(
      child: Scaffold(
        body: Stack(
          children: [
            AmbientWash(
              seasonColor: cs.tertiary,
              child: ScrollablePositionedList.builder(
                key: PageStorageKey('compendium-part-${widget.partId}-scroll'),
                itemScrollController: _items,
                padding: EdgeInsets.fromLTRB(
                  20,
                  MediaQuery.paddingOf(context).top + 90,
                  20,
                  104 + MediaQuery.viewPaddingOf(context).bottom,
                ),
                itemCount: itemCount,
                itemBuilder: (context, position) {
                  if (outline == null) {
                    return state.isLoading
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: AppProgressLine(
                              key: Key('compendium-loading'),
                            ),
                          )
                        : CompendiumMessage(
                            key: const Key('compendium-part-not-found'),
                            icon: PhosphorIconsLight.bookOpenText,
                            title: 'Частка не знойдзена',
                            message: 'Вярніцеся да зместу Кампендыя.',
                            action: TextButton(
                              onPressed: () => context.go(compendiumLocation()),
                              child: const Text('Да зместу'),
                            ),
                          );
                  }
                  if (position == 0) return _PartHeader(outline: outline);
                  if (position == itemCount - 1) {
                    return const CompendiumSourceAttribution();
                  }
                  return _PartItem(
                    item: outline.items[position - 1],
                    bodySize: bodySize,
                  );
                },
              ),
            ),
            FloatingTopActions(showBack: true, seasonColor: cs.tertiary),
          ],
        ),
      ),
    );
  }
}

class _PartHeader extends StatelessWidget {
  const _PartHeader({required this.outline});
  final CompendiumPartOutline outline;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            outline.part.label,
            key: const Key('compendium-part-label'),
            style: theme.labelMedium?.copyWith(
              color: GlassTokens.of(context).accentOnSurface(cs.tertiary),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            outline.part.title,
            key: const Key('compendium-part-title'),
            style: ReaderTheme.of(context).documentTitle(),
          ),
        ],
      ),
    );
  }
}

class _PartItem extends StatelessWidget {
  const _PartItem({required this.item, required this.bodySize});
  final CompendiumPartItem item;
  final double bodySize;

  @override
  Widget build(BuildContext context) {
    if (item.question case final question?) {
      return CompendiumQuestionRow(
        key: ValueKey('compendium-question-row-${question.number}'),
        question: question,
      );
    }
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context).textTheme;
    final reader = ReaderTheme.of(context);
    final accent = GlassTokens.of(context).accentOnSurface(cs.tertiary);
    if (item.kind == CompendiumPartItemKind.leadCitations) {
      return Column(
        key: ValueKey('compendium-inline-${item.id}'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final citation in item.citations)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 10),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(left: BorderSide(color: accent, width: 2)),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text(
                    citation.text,
                    style: theme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                      height: 1.45,
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    }
    final isSection = item.kind == CompendiumPartItemKind.sectionHeading;
    final isSubsection = item.kind == CompendiumPartItemKind.subsectionHeading;
    final isSubtopic = item.kind == CompendiumPartItemKind.subtopicHeading;
    return Padding(
      key: ValueKey('compendium-inline-${item.id}'),
      padding: EdgeInsets.only(
        top: isSection
            ? 25
            : isSubsection
            ? 19
            : isSubtopic
            ? 12
            : 15,
        bottom: isSection ? 12 : 8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.label case final label?) ...[
            Text(
              label,
              style: (isSection ? theme.labelMedium : theme.labelSmall)
                  ?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w800,
                    letterSpacing: isSection ? 1.1 : 0.9,
                  ),
            ),
            const SizedBox(height: 4),
          ],
          Text(
            item.title ?? '',
            style: isSection
                ? reader.majorHeading(bodySize)
                : isSubsection
                ? reader.blockHeading(bodySize)
                : (isSubtopic ? theme.bodyLarge : theme.titleMedium)?.copyWith(
                    fontWeight: FontWeight.w500,
                    fontStyle: isSubtopic ? FontStyle.italic : null,
                  ),
          ),
        ],
      ),
    );
  }
}
