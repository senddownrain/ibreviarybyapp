import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:html/dom.dart' as dom;
import 'package:mybrev_flutter/novena/novena_definition.dart';
import 'package:mybrev_flutter/novena/novena_providers.dart';
import 'package:mybrev_flutter/novena/novena_session.dart';
import 'package:mybrev_flutter/novena/novena_strings.dart';
import 'package:mybrev_flutter/novena/pompeii.dart';
import 'package:mybrev_flutter/novena/ui/novena_pompeii.dart';
import 'package:mybrev_flutter/novena/ui/novena_actions.dart';
import 'package:mybrev_flutter/novena/ui/novena_day_strip.dart';
import 'package:mybrev_flutter/novena/ui/novena_markdown.dart';
import 'package:mybrev_flutter/theme/reader.dart';
import 'package:mybrev_flutter/utils/prayer_link.dart';
import 'package:mybrev_flutter/widgets/prayer_content.dart';
import 'package:mybrev_flutter/widgets/reader/reader_scaffold.dart';
import 'package:mybrev_flutter/widgets/reading_scaffold.dart';

/// All texts of one day, from the snapshot taken when the session started.
/// Reading marks nothing; the person does.
class NovenaDayScreen extends ConsumerStatefulWidget {
  const NovenaDayScreen({super.key, required this.sessionId, this.day = 1});

  final String sessionId;
  final int day;

  @override
  ConsumerState<NovenaDayScreen> createState() => _NovenaDayScreenState();
}

class _NovenaDayScreenState extends ConsumerState<NovenaDayScreen> {
  final _scroll = ScrollController();
  late int _day = widget.day;

  /// A 54-day novena: the grouped grid of all days instead of one row.
  bool _allDays = false;
  late final List<List<NovenaBlock>>? _snapshot = ref
      .read(novenaStoreProvider)
      .snapshot(widget.sessionId);

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _select(int day) {
    setState(() => _day = day);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Widget _message(String text) => ReaderScaffold(
    semanticLabel: text,
    content: Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Text(text, textAlign: TextAlign.center),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(novenaProvider);
    final session = state.session(widget.sessionId);
    final days = _snapshot;
    if (session == null ||
        session.status == NovenaStatus.stopped ||
        days == null ||
        days.isEmpty) {
      return _message('Навэнна не знойдзена');
    }
    final today = ref.watch(novenaTodayProvider);
    // Access rules outrank the snapshot: a withdrawn or closed prayer is
    // not shown from the cache.
    final prayers = ref.watch(novenaPublicPrayersProvider);
    final day = _day.clamp(1, days.length);
    final compact = state.compact;
    final cs = Theme.of(context).colorScheme;
    final pompeii = session.novenaId == kPompeiiNovenaId;

    return ReadingScaffold(
      builder: (context, textStyle) => ReaderScaffold(
        key: const Key('novena-day-reader'),
        semanticLabel: 'Тэкст навэнны, дзень $day',
        seasonColor: cs.tertiary,
        scrollController: _scroll,
        showScrollToTop: true,
        contextHeader: ReaderContextHeader(
          eyebrow:
              '${novenaDate(session.dateOfDay(day))} · '
              '${novenaDayOf(day, session.durationDays)}'
              '${pompeii ? ' · ${pompeiiPhaseTitle(day).toUpperCase()}' : ''}',
          title: session.title,
          accentColor: cs.tertiary,
          details: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (pompeii) ...[
                Text(
                  '${novenaDoneOf(session.completedCount, session.durationDays)}'
                  ' · ${novenaRemaining(session.remainingCount).toLowerCase()}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
              ],
              // One row of nine like any novena; all 54 are one tap away.
              NovenaDayStrip(
                session: session,
                today: today,
                selected: day,
                onSelect: _select,
                cycleOfDay: pompeii && !_allDays ? day : null,
              ),
              if (pompeii)
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      key: const Key('novena-all-days'),
                      onPressed: () => setState(() => _allDays = !_allDays),
                      child: Text(_allDays ? 'Схаваць дні' : 'Усе 54 дні'),
                    ),
                    const PompeiiOrderLink(prayerId: kPompeiiNovenaId),
                  ],
                ),
              const SizedBox(height: 10),
              SegmentedButton<bool>(
                key: const Key('novena-reading-mode'),
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: false, label: Text('Поўны')),
                  ButtonSegment(value: true, label: Text('Кампактны')),
                ],
                selected: {compact},
                onSelectionChanged: (value) => runNovenaChange(
                  context,
                  () => ref
                      .read(novenaProvider.notifier)
                      .setCompact(value.single),
                ),
              ),
            ],
          ),
        ),
        content: prayers == null
            ? const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            : _DayContent(
                key: ValueKey('novena-content-$day-$compact'),
                session: session,
                day: day,
                today: today,
                blocks: days[day - 1],
                available: (block) =>
                    prayers.containsKey(session.novenaId) &&
                    (block.prayerId == null ||
                        prayers.containsKey(block.prayerId)),
                compact: compact,
                textStyle: textStyle,
              ),
      ),
    );
  }
}

class _DayContent extends ConsumerWidget {
  const _DayContent({
    super.key,
    required this.session,
    required this.day,
    required this.today,
    required this.blocks,
    required this.available,
    required this.compact,
    required this.textStyle,
  });

  final NovenaSession session;
  final int day;
  final String today;
  final List<NovenaBlock> blocks;
  final bool Function(NovenaBlock) available;
  final bool compact;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final done = session.completedDays.contains(day);
    final canMark = session.canMark(day, today);
    // A finished novena that was started again keeps its marks: undoing one
    // would make a second active session, which the store refuses.
    final canUndo =
        session.isActive ||
        ref.watch(
          novenaProvider.select(
            (state) => state.activeFor(session.novenaId) == null,
          ),
        );
    Future<void> mark(bool value) => runNovenaChange(
      context,
      () => ref
          .read(novenaProvider.notifier)
          .setDay(session.sessionId, day, value),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SelectionArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < blocks.length; i++)
                if (!available(blocks[i]))
                  Padding(
                    key: Key('novena-block-unavailable-$i'),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text('Гэты тэкст цяпер недаступны.'),
                  )
                else
                  NovenaBlockView(
                    key: ValueKey('novena-block-$i'),
                    block: blocks[i],
                    compact: compact,
                    textStyle: textStyle,
                  ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (done) ...[
          FilledButton.tonalIcon(
            key: const Key('novena-marked'),
            onPressed: null,
            icon: const Icon(Icons.check_rounded),
            label: const Text('Малітва завершана'),
          ),
          if (canUndo)
            Center(
              child: TextButton(
                key: const Key('novena-unmark'),
                onPressed: () => mark(false),
                child: const Text('Скасаваць адзнаку'),
              ),
            ),
        ] else if (canMark)
          FilledButton.icon(
            key: const Key('novena-mark'),
            onPressed: () => mark(true),
            icon: const Icon(Icons.check_rounded),
            label: const Text('Малітва завершана'),
          )
        else
          const Text(
            'Гэты дзень яшчэ не настаў. Тэкст можна прачытаць загадзя.',
            key: Key('novena-future-day'),
            textAlign: TextAlign.center,
          ),
        const SizedBox(height: 8),
        Text(
          session.status == NovenaStatus.completed
              ? 'Навэнна завершана'
              : novenaDoneOf(session.completedCount, session.durationDays),
          key: const Key('novena-progress'),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// One block with the reader's font, theme, alignment and hyphenation. In the
/// compact mode known prayers and litanies are folded, never dropped.
class NovenaBlockView extends StatefulWidget {
  const NovenaBlockView({
    super.key,
    required this.block,
    required this.compact,
    required this.textStyle,
  });

  final NovenaBlock block;
  final bool compact;
  final TextStyle textStyle;

  @override
  State<NovenaBlockView> createState() => _NovenaBlockViewState();
}

class _NovenaBlockViewState extends State<NovenaBlockView> {
  bool _open = false;

  void _onLinkTap(
    String? url,
    Map<String, String> attributes,
    dom.Element? element,
  ) => openLinkedPrayer(context, url);

  @override
  Widget build(BuildContext context) {
    final block = widget.block;
    final body = PrayerDocumentBody(
      markdown: novenaDisplayMarkdown(block),
      textStyle: widget.textStyle,
      onLinkTap: _onLinkTap,
    );
    final title = block.title?.trim() ?? '';
    final padded = Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: body,
    );
    final part = block.kind == 'part';
    if ((block.kind != 'prayer' && !part) || title.isEmpty) return padded;
    final reader = ReaderTheme.of(context);
    final heading = reader
        .blockHeading(widget.textStyle.fontSize ?? 16)
        .copyWith(color: reader.rubric);
    // A part of the Rosary is opened when it is prayed, in both modes.
    if (!part && (!widget.compact || !block.collapsible)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!novenaStartsWithTitle(block.markdown, title))
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              child: Semantics(
                header: true,
                child: Text(title, style: heading),
              ),
            ),
          padded,
        ],
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
            child: Semantics(
              expanded: _open,
              child: ListTile(
                title: Text(title),
                trailing: Icon(
                  _open ? Icons.remove_rounded : Icons.add_rounded,
                ),
                onTap: () => setState(() => _open = !_open),
              ),
            ),
          ),
          if (_open)
            Padding(padding: const EdgeInsets.only(top: 8), child: body),
        ],
      ),
    );
  }
}

/// A prayer linked from a day text, opened above the day page so that Back
/// returns to it. Public prayers only.
void openLinkedPrayer(BuildContext context, String? url) {
  final location = prayerLinkLocation(url);
  if (location == null) return;
  final id = Uri.decodeComponent(location.split('/').last);
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => _LinkedPrayerPage(prayerId: id)),
  );
}

class _LinkedPrayerPage extends ConsumerWidget {
  const _LinkedPrayerPage({required this.prayerId});

  final String prayerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prayer = ref.watch(novenaPublicPrayersProvider)?[prayerId];
    return ReadingScaffold(
      builder: (context, textStyle) => ReaderScaffold(
        semanticLabel: 'Тэкст малітвы',
        contextHeader: ReaderContextHeader(
          eyebrow: 'МАЛІТВА',
          title: prayer?.title ?? 'Малітва',
        ),
        content: prayer == null
            ? const Text('Малітва недаступная.')
            : SelectionArea(
                child: PrayerDocumentBody(
                  markdown: novenaDisplayText(prayer.text),
                  textStyle: textStyle,
                  onLinkTap: (url, _, _) => openLinkedPrayer(context, url),
                ),
              ),
      ),
    );
  }
}
