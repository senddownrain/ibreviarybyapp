import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:mybrev_flutter/constants/compendium.dart';
import 'package:mybrev_flutter/models/compendium.dart';
import 'package:mybrev_flutter/providers/compendium_provider.dart';
import 'package:mybrev_flutter/theme/glass.dart';
import 'package:mybrev_flutter/utils/compendium_data.dart';
import 'package:mybrev_flutter/widgets/compendium/compendium_search_host.dart';
import 'package:mybrev_flutter/widgets/compendium/compendium_widgets.dart';
import 'package:mybrev_flutter/widgets/floating_top_actions.dart';

/// One structural level of the Compendium: a ЧАСТКА, a РАЗДЗЕЛ or a
/// ПАДРАЗДЗЕЛ (`/prayers/compendium/part/:partId`,
/// `/prayers/compendium/node/:nodeId`).
///
/// The browsing rule is the same on every level: the screen shows the node's
/// header, then the questions the source prints directly under that heading,
/// then the node's real children as destinations. Nothing below a child is
/// flattened onto this screen, so a question is always listed exactly once,
/// on the screen of its nearest real owner:
///
/// - part → its sections;
/// - section → its direct questions, its subsections, and the named topics
///   that belong to it directly;
/// - subsection → its direct questions and its named topics.
///
/// A named topic opens the topic reader (`CompendiumTopicScreen`).
class CompendiumNodeScreen extends ConsumerWidget {
  const CompendiumNodeScreen({super.key, required this.nodeId})
    : _partOnly = false;

  /// The part outline; [nodeId] is a part id (`p2`) or number (`2`).
  const CompendiumNodeScreen.part({super.key, required String partId})
    : nodeId = partId,
      _partOnly = true;

  final String nodeId;
  final bool _partOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final state = _partOnly
        ? ref.watch(compendiumPartOutlineProvider(nodeId))
        : ref.watch(compendiumNodeProvider(nodeId));
    final node = state.valueOrNull;

    // A topic id (or a legacy reading-group id) is not a structural screen:
    // hand it to the topic route, which also resolves technical groups.
    if (!_partOnly && state.hasValue && (node == null || !node.isStructural)) {
      final isGroup =
          ref.watch(compendiumGroupProvider(nodeId)).valueOrNull != null;
      if (isGroup) {
        return _CompendiumRedirect(location: compendiumTopicLocation(nodeId));
      }
    }

    final List<Widget> children;
    if (node == null || !node.isStructural) {
      children = [
        state.isLoading
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: LinearProgressIndicator(key: Key('compendium-loading')),
              )
            : CompendiumMessage(
                key: Key(
                  _partOnly
                      ? 'compendium-part-not-found'
                      : 'compendium-node-not-found',
                ),
                icon: PhosphorIconsLight.bookOpenText,
                title: _partOnly
                    ? 'Частка не знойдзена'
                    : 'Раздзел не знойдзены',
                message: 'Вярніцеся да зместу Кампендыя.',
                action: TextButton(
                  onPressed: () => context.go(compendiumLocation()),
                  child: const Text('Да зместу'),
                ),
              ),
      ];
    } else {
      children = [
        _CompendiumNodeHeader(node: node),
        for (final citation in node.leadCitations)
          _CompendiumLeadCitation(citation: citation),
        for (final question in node.directQuestions)
          CompendiumQuestionRow(
            key: ValueKey('compendium-question-row-${question.number}'),
            question: question,
          ),
        if (node.directQuestions.isNotEmpty && node.children.isNotEmpty)
          const SizedBox(height: 10),
        for (final child in node.children) ..._destination(context, child),
        const CompendiumSourceAttribution(),
      ];
    }

    return CompendiumSearchHost(
      child: Scaffold(
        body: Stack(
          children: [
            AmbientWash(
              seasonColor: cs.tertiary,
              child: ListView.builder(
                key: PageStorageKey(
                  _partOnly
                      ? 'compendium-part-$nodeId-scroll'
                      : 'compendium-node-$nodeId-scroll',
                ),
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
      ),
    );
  }

  /// The row of a child node, by level.
  List<Widget> _destination(BuildContext context, CompendiumNavNode child) =>
      switch (child.kind) {
        CompendiumNodeKind.part || CompendiumNodeKind.section => [
          CompendiumSectionRow(
            key: ValueKey('compendium-section-${child.id}'),
            node: child,
          ),
        ],
        CompendiumNodeKind.chapter => [
          CompendiumSubsectionRow(
            key: ValueKey('compendium-subsection-${child.id}'),
            node: child,
          ),
        ],
        CompendiumNodeKind.topic => [
          // A source heading printed above a run of topics.
          if (child.heading case final heading?)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                heading,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          CompendiumTopicRow(
            key: ValueKey('compendium-group-${child.id}'),
            node: child,
          ),
        ],
      };
}

/// Page header of a structural node: where it is, its level label, its title
/// and its question range. A part and a section use the page-title size; a
/// subsection is one step smaller, matching its rows.
class _CompendiumNodeHeader extends StatelessWidget {
  const _CompendiumNodeHeader({required this.node});

  final CompendiumNavNode node;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final accent = GlassTokens.of(context).accentOnSurface(cs.tertiary);
    final isPart = node.kind == CompendiumNodeKind.part;
    final isSubsection = node.kind == CompendiumNodeKind.chapter;
    final trail = node.contextTrail;
    final label = node.displayLabel ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (trail.isNotEmpty) ...[
            Text(
              trail.join(' · '),
              key: const Key('compendium-node-context'),
              style: textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (label.isNotEmpty)
            Text(
              label,
              key: const Key('compendium-node-label'),
              style: textTheme.labelMedium?.copyWith(
                color: accent,
                fontWeight: isPart ? FontWeight.w700 : FontWeight.w800,
                letterSpacing: isPart ? null : 1.1,
              ),
            ),
          const SizedBox(height: 4),
          Text(
            node.title,
            key: Key(
              isPart ? 'compendium-part-title' : 'compendium-node-title',
            ),
            style:
                (isSubsection ? textTheme.titleLarge : textTheme.headlineSmall)
                    ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            node.rangeLabel,
            key: const Key('compendium-node-range'),
            style: textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// A quotation the source prints under a heading, in the list language
/// (the reader uses `CompendiumCitationBlock`).
class _CompendiumLeadCitation extends StatelessWidget {
  const _CompendiumLeadCitation({required this.citation});

  final CompendiumCitation citation;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: GlassTokens.of(context).accentOnSurface(cs.tertiary),
              width: 2,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Text(
            citation.text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
              fontStyle: FontStyle.italic,
              height: 1.45,
            ),
          ),
        ),
      ),
    );
  }
}

/// Replaces the current route with [location] after the first frame.
class _CompendiumRedirect extends StatefulWidget {
  const _CompendiumRedirect({required this.location});

  final String location;

  @override
  State<_CompendiumRedirect> createState() => _CompendiumRedirectState();
}

class _CompendiumRedirectState extends State<_CompendiumRedirect> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.pushReplacement(widget.location);
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: LinearProgressIndicator(key: Key('compendium-loading')),
      ),
    ),
  );
}
