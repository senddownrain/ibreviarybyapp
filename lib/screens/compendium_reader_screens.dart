import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mybrev_flutter/constants/compendium.dart';
import 'package:mybrev_flutter/models/compendium.dart';
import 'package:mybrev_flutter/providers/compendium_provider.dart';
import 'package:mybrev_flutter/screens/compendium_node_screen.dart';
import 'package:mybrev_flutter/utils/compendium_data.dart';
import 'package:mybrev_flutter/widgets/compendium/compendium_search_host.dart';
import 'package:mybrev_flutter/widgets/compendium/compendium_widgets.dart';
import 'package:mybrev_flutter/widgets/reader/reader_scaffold.dart';
import 'package:mybrev_flutter/widgets/reading_scaffold.dart';
import 'package:mybrev_flutter/widgets/loading/app_load_states.dart';

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
          ? const AppProgressLine(key: Key('compendium-loading'))
          : Text(message, key: const Key('compendium-not-found')),
    ),
  ),
);

/// Old topic URLs resolve to the owning Part and its stable heading target.
class CompendiumTopicScreen extends StatelessWidget {
  const CompendiumTopicScreen({super.key, required this.topicId});
  final String topicId;

  @override
  Widget build(BuildContext context) => CompendiumLegacyScreen(id: topicId);
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
                centerLabel: 'Да часткі',
                onCenter: () => context.push(
                  compendiumPartLocation(question.partId, target: question.id),
                ),
                nextLabel: next == null ? null : '${next.number}',
                onNext: next == null ? null : () => open(next),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
