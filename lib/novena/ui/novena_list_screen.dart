import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mybrev_flutter/novena/novena_providers.dart';
import 'package:mybrev_flutter/novena/novena_session.dart';
import 'package:mybrev_flutter/novena/pompeii.dart';
import 'package:mybrev_flutter/novena/novena_strings.dart';
import 'package:mybrev_flutter/novena/ui/novena_actions.dart';
import 'package:mybrev_flutter/novena/ui/novena_routes.dart';
import 'package:mybrev_flutter/novena/ui/novena_session_card.dart';

/// «Мае навэнны»: the active sessions (the choice when there are several),
/// the finished ones, and the switch of the start suggestions.
class NovenaListScreen extends ConsumerWidget {
  const NovenaListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(novenaProvider);
    final theme = Theme.of(context);
    Widget section(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.tertiary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: ListView(
          key: const Key('novena-list'),
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            24 + MediaQuery.viewPaddingOf(context).bottom,
          ),
          children: [
            if (state.active.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Цяпер няма актыўных навэнн.',
                  textAlign: TextAlign.center,
                ),
              )
            else ...[
              section('АКТЫЎНЫЯ'),
              for (final session in state.active)
                Padding(
                  key: ValueKey(session.sessionId),
                  padding: const EdgeInsets.only(bottom: 10),
                  child: NovenaSessionCard(
                    session: session,
                    title: session.title,
                    footer: Center(
                      child: TextButton(
                        key: const Key('novena-whole-prayer'),
                        onPressed: () => context.push(
                          novenaPrayerLocation,
                          extra: session.novenaId,
                        ),
                        child: const Text('Уся малітва'),
                      ),
                    ),
                  ),
                ),
            ],
            if (state.completed.isNotEmpty) ...[
              section('ЗАВЕРШАНЫЯ'),
              for (final session in state.completed)
                _CompletedRow(session: session),
            ],
            const SizedBox(height: 12),
            Center(
              child: TextButton.icon(
                key: const Key('novena-start-new'),
                onPressed: () => _chooseNovena(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Распачаць новую навэнну'),
              ),
            ),
            const Divider(height: 32),
            SwitchListTile(
              key: const Key('novena-suggestions-switch'),
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              title: const Text('Прапаноўваць навэнны'),
              subtitle: const Text(
                'Картка ў дзень рэкамендаванага пачатку. Бягучыя навэнны '
                'і індыкатар застаюцца.',
              ),
              value: state.suggestionsEnabled,
              onChanged: (value) => runNovenaChange(
                context,
                () => ref.read(novenaProvider.notifier).setSuggestions(value),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompletedRow extends StatelessWidget {
  const _CompletedRow({required this.session});

  final NovenaSession session;

  @override
  Widget build(BuildContext context) => ListTile(
    key: ValueKey(session.sessionId),
    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
    leading: Icon(
      Icons.check_rounded,
      color: Theme.of(context).colorScheme.primary,
    ),
    title: Text(session.title),
    subtitle: Text(
      '${novenaDate(session.startDate)} – '
      '${novenaDate(session.finishedDate ?? session.startDate)}',
    ),
    onTap: () => openNovenaDay(context, session, session.durationDays),
  );
}

Future<void> _chooseNovena(BuildContext context) async {
  final id = await showModalBottomSheet<String>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _NovenaChoice(),
  );
  if (id != null && context.mounted) openNovenaPrayer(context, id);
}

/// The supported novenas; the choice opens the ordinary prayer page.
class _NovenaChoice extends ConsumerWidget {
  const _NovenaChoice();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prayers = ref.watch(novenaPublicPrayersProvider);
    final all = ref.watch(novenaDefinitionsProvider).values;
    final pompeii = ref.watch(supportedNovenaProvider(kPompeiiNovenaId));
    final items = [
      if (prayers != null)
        for (final definition in all)
          if (prayers.containsKey(definition.sourcePrayerId) &&
              definition.sourcePrayerId != kPompeiiNovenaId)
            definition,
      if (pompeii != null) pompeii.definition,
    ]..sort((a, b) => a.title.compareTo(b.title));
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Text('Пакуль няма даступных навэнн.'),
      );
    }
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.75,
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: items.length,
        itemBuilder: (context, index) => ListTile(
          title: Text(items[index].title),
          onTap: () => Navigator.pop(context, items[index].sourcePrayerId),
        ),
      ),
    );
  }
}

/// Opens the ordinary page of the prayer (its id and links are unchanged).
void openNovenaPrayer(BuildContext context, String prayerId) =>
    context.go('/prayers/prayer/${Uri.encodeComponent(prayerId)}');
