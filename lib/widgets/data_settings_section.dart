import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/providers/connectivity_provider.dart';
import 'package:mybrev_flutter/providers/content_updates_provider.dart';
import 'package:mybrev_flutter/widgets/loading/app_load_states.dart';

DateTime _day(DateTime date, [int offset = 0]) =>
    DateTime(date.year, date.month, date.day + offset);

/// «сёння, 09:42» · «учора, 18:03» · «12.09.2026».
String formatCheckTime(DateTime time, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final hm =
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  if (_day(time) == _day(current)) return 'сёння, $hm';
  if (_day(time) == _day(current, -1)) return 'учора, $hm';
  return '${time.day.toString().padLeft(2, '0')}.'
      '${time.month.toString().padLeft(2, '0')}.${time.year}';
}

/// «2026.10.06» — the version of the texts (About screen, not Settings).
String formatContentVersion(DateTime date) =>
    '${date.year}.${date.month.toString().padLeft(2, '0')}.'
    '${date.day.toString().padLeft(2, '0')}';

/// The two status lines: what the texts are, and when they were checked.
(String, String?) contentUpdateStatus(
  ContentUpdateState state, {
  bool offline = false,
}) {
  final checked = state.lastCheck == null
      ? null
      : 'Праверана ${formatCheckTime(state.lastCheck!)}';
  switch (state.phase) {
    case ContentUpdatePhase.checking:
      return ('Правяраем абнаўленні…', checked);
    case ContentUpdatePhase.updating:
      return ('Абнаўляем тэксты…', checked);
    case ContentUpdatePhase.idle:
      if (state.failed) {
        return (
          'Не ўдалося праверыць абнаўленні',
          'Тэксты на прыладзе даступныя',
        );
      }
      if (state.awaitsAppRelease) {
        return ('Новыя тэксты прыйдуць з абнаўленнем праграмы', checked);
      }
      if (state.lastCheck == null) {
        return (
          offline
              ? 'Абнаўленні праверацца, калі з’явіцца сетка'
              : 'Абнаўленні яшчэ не правяраліся',
          null,
        );
      }
      return ('Актуальныя', checked);
  }
}

/// Settings → «Даныя і афлайн»: only what the reader needs to know.
///
/// The texts ship with the app; updates are small and arrive by themselves
/// on any network. Nothing here is about Wi-Fi, sizes, periods or storage.
class DataSettingsSection extends ConsumerWidget {
  const DataSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final update = ref.watch(contentUpdatesProvider);
    final offline = ref.watch(isOfflineProvider);
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final (status, detail) = contentUpdateStatus(update, offline: offline);

    return Column(
      key: const Key('data-settings'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Даныя і афлайн', style: text.titleMedium),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(Icons.check_circle_outline, size: 20, color: cs.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Тэксты даступныя без сеткі',
                key: const Key('data-offline-status'),
                style: text.titleSmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text('Абнаўленні тэкстаў', style: text.titleSmall),
        const SizedBox(height: 4),
        Text(
          status,
          key: const Key('data-update-status'),
          style: text.bodyMedium,
        ),
        if (detail != null)
          Text(
            detail,
            key: const Key('data-update-detail'),
            style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        const SizedBox(height: 8),
        // Two pixels, always: nothing below moves when a check starts.
        AppRefreshBar(active: update.isBusy),
        const SizedBox(height: 8),
        FilledButton.tonal(
          key: const Key('data-check-updates'),
          onPressed: update.isBusy || offline
              ? null
              : ref.read(contentUpdatesProvider.notifier).check,
          child: const Text('Праверыць абнаўленні'),
        ),
        if (offline) ...[
          const SizedBox(height: 6),
          Text(
            'Няма сеткі. Усе тэксты працуюць і так.',
            style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}
