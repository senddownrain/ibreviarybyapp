import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/discovery/discovery_providers.dart';
import 'package:mybrev_flutter/discovery/tour/tour_host.dart';

/// «Падказкі» in the settings: the switch for automatic hints, the manual
/// tour and the confirmed reset of the hint history.
class DiscoverySettingsSection extends ConsumerWidget {
  const DiscoverySettingsSection({super.key});

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Скінуць падказкі?'),
        content: const Text(
          'Падказкі, якія вы ўжо бачылі ці схавалі, змогуць з’явіцца зноў. '
          'Астатнія налады і вашы даныя застануцца.',
        ),
        actions: [
          TextButton(
            key: const Key('discovery-reset-cancel'),
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Адмена'),
          ),
          FilledButton(
            key: const Key('discovery-reset-confirm'),
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Скінуць'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final repository = await ref.read(discoveryRepositoryProvider.future);
    await repository.resetHistory();
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(const SnackBar(content: Text('Гісторыя падказак скінута')));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(discoveryStateProvider).valueOrNull;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Падказкі', style: theme.textTheme.titleMedium),
        SwitchListTile.adaptive(
          key: const Key('settings-hints-enabled'),
          title: const Text('Паказваць падказкі'),
          subtitle: const Text(
            'Рэдкія кароткія парады каля кнопак. '
            'Тур «Як карыстацца дадаткам» застаецца даступным.',
          ),
          value: state?.hintsEnabled ?? true,
          onChanged: state == null
              ? null
              : (value) async {
                  final repository = await ref.read(
                    discoveryRepositoryProvider.future,
                  );
                  await repository.setHintsEnabled(value);
                },
          contentPadding: EdgeInsets.zero,
        ),
        ListTile(
          key: const Key('settings-tour-start'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Як карыстацца дадаткам'),
          subtitle: const Text('Кароткі тур па галоўных месцах'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            // Back to the screen the settings were opened from, then start.
            Navigator.of(context).maybePop();
            ref.read(tourRequestProvider.notifier).state++;
          },
        ),
        ListTile(
          key: const Key('settings-hints-reset'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Скінуць падказкі'),
          subtitle: const Text('Паказаць убачаныя і схаваныя падказкі зноў'),
          onTap: () => _confirmReset(context, ref),
        ),
      ],
    );
  }
}
