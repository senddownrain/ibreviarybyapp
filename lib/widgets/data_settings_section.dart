import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/providers/connectivity_provider.dart';
import 'package:mybrev_flutter/providers/content_updates_provider.dart';
import 'package:mybrev_flutter/widgets/data_loading_notice.dart';
import 'package:mybrev_flutter/widgets/loading/app_load_states.dart';

const _months = [
  'студзеня',
  'лютага',
  'сакавіка',
  'красавіка',
  'мая',
  'чэрвеня',
  'ліпеня',
  'жніўня',
  'верасня',
  'кастрычніка',
  'лістапада',
  'снежня',
];

DateTime _day(DateTime date, [int offset = 0]) =>
    DateTime(date.year, date.month, date.day + offset);

/// «сёння, 09:42» · «учора, 18:03» · «12 верасня».
String formatCheckTime(DateTime? time, {DateTime? now}) {
  if (time == null) return 'яшчэ не правяралася';
  final current = now ?? DateTime.now();
  final hm =
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  if (_day(time) == _day(current)) return 'сёння, $hm';
  if (_day(time) == _day(current, -1)) return 'учора, $hm';
  return formatContentDate(time);
}

/// «6 кастрычніка 2026».
String formatContentDate(DateTime date) =>
    '${date.day} ${_months[date.month - 1]} ${date.year}';

/// What the update status line says.
String contentUpdateStatus(ContentUpdateState state, {bool offline = false}) {
  switch (state.phase) {
    case ContentUpdatePhase.checking:
      return 'Правяраем абнаўленні…';
    case ContentUpdatePhase.updating:
      return 'Абнаўляем тэксты…';
    case ContentUpdatePhase.waitingForConsent:
      return 'Даступна абнаўленне · ${formatBytes(state.pendingBytes)}';
    case ContentUpdatePhase.waitingForWifi:
      return 'Абнаўленне загрузіцца, калі з’явіцца Wi‑Fi';
    case ContentUpdatePhase.idle:
      if (state.failed) {
        return 'Не ўдалося праверыць абнаўленні. Тэксты на прыладзе даступныя.';
      }
      if (state.lastCheck == null) {
        return offline
            ? 'Абнаўленні праверацца, калі з’явіцца сетка'
            : 'Абнаўленні яшчэ не правяраліся';
      }
      return 'Тэксты актуальныя · праверана ${formatCheckTime(state.lastCheck)}';
  }
}

/// Settings → «Даныя і афлайн».
///
/// The texts ship with the app; the reader controls nothing about storage
/// or periods. What is left: are the texts here, are they current, a manual
/// check, and consent to a large update on mobile data.
class DataSettingsSection extends ConsumerWidget {
  const DataSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final update = ref.watch(contentUpdatesProvider);
    final offline = ref.watch(isOfflineProvider);
    final notifier = ref.read(contentUpdatesProvider.notifier);
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final date = contentDate();

    return Column(
      key: const Key('data-settings'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Даныя і афлайн', style: text.titleMedium),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                Icons.check_circle_outline,
                size: 20,
                color: cs.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Тэксты даступныя без сеткі',
                    key: const Key('data-offline-status'),
                    style: text.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Літургія гадзін, чытанні, малітвы, Біблія, спеўнік і '
                    'Кампендый уваходзяць у праграму.',
                    style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text('Абнаўленні тэкстаў', style: text.titleSmall),
        const SizedBox(height: 4),
        Text(
          contentUpdateStatus(update, offline: offline),
          key: const Key('data-update-status'),
          style: text.bodyMedium?.copyWith(
            color: update.failed ? cs.error : null,
          ),
        ),
        if (date != null)
          Text(
            'Тэксты ад ${formatContentDate(date)}',
            key: const Key('data-content-date'),
            style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        const SizedBox(height: 8),
        // Two pixels, always: nothing below moves when a check starts.
        AppRefreshBar(active: update.isBusy),
        const SizedBox(height: 8),
        if (update.phase == ContentUpdatePhase.waitingForConsent)
          _LargeUpdateConsent(
            bytes: update.pendingBytes,
            onDownload: notifier.downloadNow,
            onWait: notifier.waitForWifi,
          )
        else
          FilledButton.tonal(
            key: const Key('data-check-updates'),
            onPressed: update.isBusy || offline
                ? null
                : update.phase == ContentUpdatePhase.waitingForWifi
                ? notifier.downloadNow
                : notifier.check,
            child: Text(
              update.phase == ContentUpdatePhase.waitingForWifi
                  ? 'Загрузіць зараз'
                  : 'Праверыць абнаўленні',
            ),
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

/// A large update on mobile data: the reader decides, once, for this update.
class _LargeUpdateConsent extends StatelessWidget {
  const _LargeUpdateConsent({
    required this.bytes,
    required this.onDownload,
    required this.onWait,
  });

  final int bytes;
  final VoidCallback onDownload;
  final VoidCallback onWait;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      key: const Key('data-large-update'),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Вы выкарыстоўваеце мабільную сетку.', style: text.bodyMedium),
            const SizedBox(height: 10),
            FilledButton(
              key: const Key('data-large-update-download'),
              onPressed: onDownload,
              child: Text('Загрузіць ${formatBytes(bytes)}'),
            ),
            TextButton(
              key: const Key('data-large-update-wait'),
              onPressed: onWait,
              child: const Text('Пачакаць Wi‑Fi'),
            ),
          ],
        ),
      ),
    );
  }
}
