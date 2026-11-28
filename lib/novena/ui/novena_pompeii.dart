import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/novena/novena_providers.dart';
import 'package:mybrev_flutter/novena/novena_strings.dart';
import 'package:mybrev_flutter/novena/pompeii.dart';
import 'package:mybrev_flutter/novena/ui/novena_markdown.dart';
import 'package:mybrev_flutter/novena/ui/novena_session_card.dart';
import 'package:mybrev_flutter/widgets/prayer_content.dart';

/// The two phases, before the novena is started.
class PompeiiPhasesCard extends StatelessWidget {
  const PompeiiPhasesCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget phase(int first) => Expanded(
      child: Column(
        children: [
          Text(
            pompeiiPhaseTitle(first),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            '$kPompeiiPhaseDays ${daysWord(kPompeiiPhaseDays)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
    return NovenaCard(
      child: Row(
        key: const Key('novena-pompeii-phases'),
        children: [phase(1), phase(kPompeiiPhaseDays + 1)],
      ),
    );
  }
}

/// «Парадак Пампейскай навэнны»: the whole instruction of the prayer itself.
class PompeiiOrderLink extends ConsumerWidget {
  const PompeiiOrderLink({super.key, required this.prayerId});

  final String prayerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prayer = ref.watch(novenaPublicPrayersProvider)?[prayerId];
    if (prayer == null) return const SizedBox.shrink();
    return Center(
      widthFactor: 1,
      heightFactor: 1,
      child: TextButton(
        key: const Key('novena-pompeii-order'),
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          useRootNavigator: true,
          useSafeArea: true,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (context) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: PrayerDocumentBody(
              markdown: novenaDisplayText(prayer.text),
              textStyle: Theme.of(context).textTheme.bodyLarge!,
            ),
          ),
        ),
        child: const Text(
          'Парадак Пампейскай навэнны',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
