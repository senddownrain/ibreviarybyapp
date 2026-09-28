import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:mybrev_flutter/constants/compendium.dart';
import 'package:mybrev_flutter/models/compendium.dart';
import 'package:mybrev_flutter/providers/compendium_provider.dart';
import 'package:mybrev_flutter/theme/reader.dart';
import 'package:mybrev_flutter/utils/compendium_data.dart';
import 'package:mybrev_flutter/widgets/compendium/compendium_search_host.dart';
import 'package:mybrev_flutter/widgets/compendium/compendium_widgets.dart';
import 'package:mybrev_flutter/widgets/reader/reader_scaffold.dart';
import 'package:mybrev_flutter/widgets/reading_scaffold.dart';
import 'package:mybrev_flutter/widgets/text_scale_control.dart';

/// Loading / not-found state on the shared reader foundation.
Widget _readerMessage({
  required bool loading,
  required String message,
  required String semanticLabel,
}) => CompendiumSearchHost(
  reader: true,
  child: ReaderScaffold(
    semanticLabel: semanticLabel,
    content: Center(
      child: loading
          ? const Padding(
              padding: EdgeInsets.only(top: 24),
              child: LinearProgressIndicator(key: Key('compendium-loading')),
            )
          : Text(message, key: const Key('compendium-not-found')),
    ),
  ),
);

/// Pager label of a neighbouring group: its question range («6–10», «1»).
String _pagerLabel(CompendiumGroup group) =>
    group.firstQuestion == group.lastQuestion
    ? '${group.firstQuestion}'
    : '${group.firstQuestion}–${group.lastQuestion}';

/// Location of a reading group; an untitled one-question lead-in opens as
/// its question (it is not a source heading).
String _groupLocation(CompendiumGroup group) =>
    switch (compendiumGroupQuestionRedirect(group)) {
      final number? => compendiumQuestionLocation(number),
      null => compendiumTopicLocation(group.id),
    };

/// `/prayers/compendium/topic/:topicId`: one reading group with expandable
/// questions, on the shared Reader foundation.
///
/// Named topics are source headings. An untitled lead-in (legacy links such
/// as `p1-s1-intro`) is not: a one-question lead-in shows the question
/// reader, a longer one is titled by the nearest real heading (chapter or
/// section) with its question range as metadata only.
class CompendiumTopicScreen extends ConsumerStatefulWidget {
  const CompendiumTopicScreen({super.key, required this.topicId});

  final String topicId;

  @override
  ConsumerState<CompendiumTopicScreen> createState() =>
      _CompendiumTopicScreenState();
}

class _CompendiumTopicScreenState extends ConsumerState<CompendiumTopicScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(compendiumGroupProvider(widget.topicId));
    final group = state.valueOrNull;
    if (group == null) {
      return _readerMessage(
        loading: state.isLoading,
        message: state.hasError
            ? 'Не атрымалася адкрыць Кампендый'
            : 'Тэма не знойдзена',
        semanticLabel: 'Кампендый',
      );
    }
    if (compendiumGroupQuestionRedirect(group) case final number?) {
      return CompendiumQuestionScreen(number: '$number');
    }
    final index = ref.watch(compendiumIndexProvider).requireValue;
    final (previous, next) = index.neighbours(group.id);
    final expanded = ref.watch(compendiumExpandedProvider)[group.id] ?? {};
    final cs = Theme.of(context).colorScheme;
    // Real headings only: the title is the topic, or for an untitled lead-in
    // the nearest heading above it; the eyebrow is the part and the heading
    // just above the title (no duplicated fallbacks).
    final trail = groupContextTrail(group);
    final title = trail.last;
    final eyebrow = [
      trail.first,
      if (trail.length > 2) trail[trail.length - 2],
    ].join(' · ');
    void open(CompendiumGroup target) =>
        context.pushReplacement(_groupLocation(target));

    return ReadingScaffold(
      builder: (context, textStyle) => CompendiumSearchHost(
        reader: true,
        child: ReaderScaffold(
          key: ValueKey('compendium-topic-${group.id}'),
          scrollKey: PageStorageKey('compendium-topic-${group.id}-scroll'),
          semanticLabel: 'Кампендый: $title',
          seasonColor: cs.tertiary,
          chromeMode: ReaderChromeMode.compact,
          scrollController: _scrollController,
          showScrollToTop: true,
          actions: const [TextScaleControl()],
          onSwipePrevious: previous == null ? null : () => open(previous),
          onSwipeNext: next == null ? null : () => open(next),
          contextHeader: ReaderContextHeader(
            eyebrow: eyebrow,
            subtitle: group.parentTitle,
            title: title,
            metadata: group.rangeLabel,
            accentColor: cs.tertiary,
          ),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final citation in group.leadCitations)
                CompendiumCitationBlock(
                  citation: citation,
                  textStyle: textStyle,
                ),
              for (final (i, question) in group.questions.indexed) ...[
                if (question.subtopicTitle != null &&
                    question.subtopicTitle !=
                        (i == 0 ? null : group.questions[i - 1].subtopicTitle))
                  Padding(
                    padding: const EdgeInsets.only(top: 18, bottom: 4),
                    child: Text(
                      question.subtopicTitle!,
                      style: ReaderTheme.of(
                        context,
                      ).blockHeading(textStyle.fontSize ?? 18),
                    ),
                  ),
                _CompendiumQuestionTile(
                  question: question,
                  expanded: expanded.contains(question.number),
                  textStyle: textStyle,
                  onToggle: () => ref
                      .read(compendiumExpandedProvider.notifier)
                      .toggle(group.id, question.number),
                ),
              ],
              CompendiumPager(
                previousLabel: previous == null ? null : _pagerLabel(previous),
                onPrevious: previous == null ? null : () => open(previous),
                nextLabel: next == null ? null : _pagerLabel(next),
                onNext: next == null ? null : () => open(next),
              ),
              const CompendiumSourceAttribution(onReader: true),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompendiumQuestionTile extends StatelessWidget {
  const _CompendiumQuestionTile({
    required this.question,
    required this.expanded,
    required this.textStyle,
    required this.onToggle,
  });

  final CompendiumQuestion question;
  final bool expanded;
  final TextStyle textStyle;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final reader = ReaderTheme.of(context);
    final size = textStyle.fontSize ?? 18;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: reader.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: expanded,
            child: InkWell(
              key: ValueKey('compendium-question-toggle-${question.number}'),
              onTap: () {
                HapticFeedback.selectionClick();
                onToggle();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(minWidth: size * 2.2),
                      child: Text(
                        '${question.number}',
                        style: textStyle.copyWith(
                          color: reader.rubric,
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        question.question,
                        style: textStyle.copyWith(
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: EdgeInsets.only(top: size * 0.3),
                      child: AnimatedRotation(
                        turns: expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: PhosphorIcon(
                          PhosphorIconsRegular.caretDown,
                          size: 18,
                          color: reader.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: EdgeInsets.only(left: size * 2.2, bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CompendiumAnswer(question: question, textStyle: textStyle),
                  TextButton(
                    key: ValueKey(
                      'compendium-open-question-${question.number}',
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: reader.rubric,
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: () =>
                        openCompendiumQuestion(context, question.number),
                    child: Text('Адкрыць пытанне ${question.number}'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// `/prayers/compendium/question/:number`: one question, deep-linkable, with
/// its context and previous/next navigation.
class CompendiumQuestionScreen extends ConsumerStatefulWidget {
  const CompendiumQuestionScreen({super.key, required this.number});

  final String number;

  @override
  ConsumerState<CompendiumQuestionScreen> createState() =>
      _CompendiumQuestionScreenState();
}

class _CompendiumQuestionScreenState
    extends ConsumerState<CompendiumQuestionScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(compendiumQuestionProvider(widget.number));
    final question = state.valueOrNull;
    if (question == null) {
      return _readerMessage(
        loading: state.isLoading,
        message: state.hasError
            ? 'Не атрымалася адкрыць Кампендый'
            : 'Пытанне ${widget.number} не знойдзена',
        semanticLabel: 'Кампендый',
      );
    }
    final index = ref.watch(compendiumIndexProvider).requireValue;
    final previous = index.getQuestion(question.number - 1);
    final next = index.getQuestion(question.number + 1);
    final cs = Theme.of(context).colorScheme;
    final group = index.groupOf(question);
    // «Уся тэма» only for a real topic; an untitled lead-in with several
    // questions is offered by its range, a one-question lead-in not at all.
    final String? centerLabel = group == null
        ? null
        : group.hasSourceHeading
        ? 'Уся тэма'
        : group.questions.length > 1
        ? group.rangeLabel
        : null;
    void open(CompendiumQuestion target) =>
        context.pushReplacement(compendiumQuestionLocation(target.number));

    return ReadingScaffold(
      builder: (context, textStyle) => CompendiumSearchHost(
        reader: true,
        child: ReaderScaffold(
          key: ValueKey('compendium-question-${question.number}'),
          scrollKey: PageStorageKey('compendium-question-${question.number}'),
          semanticLabel: 'Пытанне ${question.number}. ${question.question}',
          seasonColor: cs.tertiary,
          chromeMode: ReaderChromeMode.compact,
          scrollController: _scrollController,
          showScrollToTop: true,
          actions: const [TextScaleControl()],
          onSwipePrevious: previous == null ? null : () => open(previous),
          onSwipeNext: next == null ? null : () => open(next),
          contextHeader: ReaderContextHeader(
            eyebrow: 'ПЫТАННЕ ${question.number}',
            title: question.question,
            metadata: questionContextTrail(question).join(' · '),
            accentColor: cs.tertiary,
          ),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CompendiumAnswer(question: question, textStyle: textStyle),
              CompendiumPager(
                previousLabel: previous == null ? null : '${previous.number}',
                onPrevious: previous == null ? null : () => open(previous),
                centerLabel: centerLabel,
                onCenter: centerLabel == null
                    ? null
                    : () => context.push(compendiumTopicLocation(group!.id)),
                nextLabel: next == null ? null : '${next.number}',
                onNext: next == null ? null : () => open(next),
              ),
              const CompendiumSourceAttribution(onReader: true),
            ],
          ),
        ),
      ),
    );
  }
}
