import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mybrev_flutter/novena/novena_providers.dart';
import 'package:mybrev_flutter/novena/novena_strings.dart';
import 'package:mybrev_flutter/novena/ui/novena_actions.dart';
import 'package:mybrev_flutter/novena/ui/novena_routes.dart';
import 'package:mybrev_flutter/novena/ui/novena_session_card.dart';

/// The extra block of an ordinary prayer page: start, tracker or history.
/// Nothing for any other prayer; the prayer itself is not touched.
class NovenaPrayerPanel extends ConsumerWidget {
  const NovenaPrayerPanel({super.key, required this.prayerId});

  final String prayerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(novenaBoxProvider) == null) return const SizedBox.shrink();
    final state = ref.watch(novenaProvider);
    final session = state.activeFor(prayerId);
    final supported = ref.watch(supportedNovenaProvider(prayerId));
    final history = state.hasHistory(prayerId);
    if (session == null && supported == null && !history) {
      return const SizedBox.shrink();
    }
    final historyLink = Center(
      child: TextButton(
        key: const Key('novena-open-list'),
        onPressed: () => context.push(novenasLocation),
        child: Text(session == null ? 'Гісторыя навэнн' : 'Мае навэнны'),
      ),
    );
    return Padding(
      key: const Key('novena-panel'),
      padding: const EdgeInsets.only(bottom: 20),
      // Application text inside the reader surface, not prayer text.
      child: SelectionContainer.disabled(
        child: session != null
            ? NovenaSessionCard(session: session, footer: historyLink)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (supported != null) ...[
                    Text(
                      '${supported.definition.durationDays} '
                      '${daysWord(supported.definition.durationDays)} малітвы',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      key: const Key('novena-start'),
                      onPressed: () => runNovenaChange(
                        context,
                        () => ref
                            .read(novenaProvider.notifier)
                            .start(supported.definition, supported.days),
                      ),
                      child: const Text('Распачаць навэнну'),
                    ),
                  ],
                  if (history) historyLink,
                ],
              ),
      ),
    );
  }
}
