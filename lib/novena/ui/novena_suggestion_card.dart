import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/novena/novena_providers.dart';
import 'package:mybrev_flutter/novena/novena_strings.dart';
import 'package:mybrev_flutter/novena/ui/novena_actions.dart';
import 'package:mybrev_flutter/novena/ui/novena_list_screen.dart';
import 'package:mybrev_flutter/novena/ui/novena_session_card.dart';

/// One small card on the start date of recommended novenas; several share it.
class NovenaSuggestionSlot extends ConsumerWidget {
  const NovenaSuggestionSlot({
    super.key,
    this.padding = const EdgeInsets.only(top: 14),
  });

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Nothing is loaded for a tracker without storage or switched off.
    if (ref.watch(novenaBoxProvider) == null) return const SizedBox.shrink();
    final items = ref.watch(novenaSuggestionsProvider);
    if (items.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final today = ref.watch(novenaTodayProvider);
    return Padding(
      key: const Key('novena-suggestion'),
      padding: padding,
      child: NovenaCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              novenaDate(today).toUpperCase(),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.tertiary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Сёння можна распачаць навэнну',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            for (final item in items) ...[
              const SizedBox(height: 8),
              Text(item.definition.title),
              const SizedBox(height: 6),
              FilledButton.tonal(
                key: Key('novena-suggestion-start-${item.definition.novenaId}'),
                onPressed: () async {
                  final controller = ref.read(novenaProvider.notifier);
                  final started = await runNovenaChange(
                    context,
                    () => controller.start(item.definition, item.days),
                  );
                  if (started != null && context.mounted) {
                    openNovenaPrayer(context, item.definition.sourcePrayerId);
                  }
                },
                child: const Text(
                  'Распачаць навэнну',
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: const Key('novena-suggestion-dismiss'),
                onPressed: () => runNovenaChange(
                  context,
                  () => ref
                      .read(novenaProvider.notifier)
                      .dismiss(items.map((item) => item.definition.novenaId)),
                ),
                child: const Text('Не цяпер'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
