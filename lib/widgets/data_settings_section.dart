import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/models/sync_plan.dart';
import 'package:mybrev_flutter/providers/cache_epoch_provider.dart';
import 'package:mybrev_flutter/providers/cache_policy_provider.dart';
import 'package:mybrev_flutter/providers/connectivity_provider.dart';
import 'package:mybrev_flutter/providers/sync_provider.dart';
import 'package:mybrev_flutter/services/cache_warmup_service.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/widgets/cache_sync_settings.dart';
import 'package:mybrev_flutter/widgets/data_loading_notice.dart';
import 'package:mybrev_flutter/widgets/loading/app_load_states.dart';

/// Readiness of one kind of content, in the reader's words.
enum DataReadiness { ready, loading, partial, missing }

class DataGroupStatus {
  const DataGroupStatus(this.title, this.readiness, this.detail);
  final String title;
  final DataReadiness readiness;
  final String detail;
}

DateTime _day(DateTime date, [int offset = 0]) =>
    DateTime(date.year, date.month, date.day + offset);

/// «Сёння, 12:34» · «учора» · «12.09».
String formatLastUpdate(DateTime? time, {DateTime? now}) {
  if (time == null) return 'яшчэ не абнаўлялася';
  final current = now ?? DateTime.now();
  final hm =
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  if (_day(time) == _day(current)) return 'сёння, $hm';
  if (_day(time) == _day(current, -1)) return 'учора, $hm';
  return '${time.day.toString().padLeft(2, '0')}.${time.month.toString().padLeft(2, '0')}.${time.year}';
}

/// Status of every content group for «Даныя праграмы». No collection,
/// service or file names — only what the reader can open without a network.
List<DataGroupStatus> collectDataStatus({
  DateTime? now,
  String? syncingCollection,
}) {
  final today = _day(now ?? DateTime.now());
  DataReadiness dated(String collection) {
    final todayReady = HiveService.isDateCached(collection, today);
    final tomorrowReady = HiveService.isDateCached(collection, _day(today, 1));
    if (todayReady && tomorrowReady) return DataReadiness.ready;
    if (syncingCollection == collection) return DataReadiness.loading;
    return todayReady ? DataReadiness.partial : DataReadiness.missing;
  }

  String datedDetail(String collection) {
    if (HiveService.getMetaFlag('fullCache_$collection') == true) {
      return 'усе дні даступныя без сеткі';
    }
    final todayReady = HiveService.isDateCached(collection, today);
    final tomorrowReady = HiveService.isDateCached(collection, _day(today, 1));
    if (todayReady && tomorrowReady) return 'сёння і заўтра гатовыя';
    if (todayReady) return 'сёння гатова, заўтра загрузіцца';
    return 'загрузіцца пры адкрыцці';
  }

  DataGroupStatus stored(
    String title,
    List<String> collections, {
    bool bundled = false,
  }) {
    final loading = collections.contains(syncingCollection);
    final has = collections.every(
      (name) => HiveService.boxFor(name).isNotEmpty,
    );
    if (loading) {
      return DataGroupStatus(title, DataReadiness.loading, 'абнаўляецца');
    }
    if (has || bundled) {
      return DataGroupStatus(
        title,
        DataReadiness.ready,
        has ? 'даступна без сеткі' : 'убудавана ў праграму',
      );
    }
    return DataGroupStatus(title, DataReadiness.missing, 'яшчэ не загружана');
  }

  return [
    const DataGroupStatus(
      'Літургічны каляндар',
      DataReadiness.ready,
      'вылічаецца на прыладзе',
    ),
    DataGroupStatus('Літургія гадзін', dated('days'), datedDetail('days')),
    DataGroupStatus('Чытанні', dated('readings'), datedDetail('readings')),
    stored('Малітвы', const ['prayers']),
    stored('Біблія', const ['bible_bel'], bundled: true),
    stored('Спеўнік', const ['songs'], bundled: true),
    stored('Кампендый Катэхізіса', const ['compendium'], bundled: true),
  ];
}

/// Settings → «Даныя і загрузка»: what is kept on the device, whether it is
/// ready for offline use and how the app may update it. The technical
/// controls live one level deeper, in «Даныя праграмы».
class DataSettingsSection extends ConsumerWidget {
  const DataSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final policy = ref.watch(cachePolicyProvider);
    final status = ref.watch(syncStatusProvider);
    final offline = ref.watch(isOfflineProvider);
    ref.watch(cacheEpochProvider);
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final groups = collectDataStatus(
      syncingCollection: status.isSyncing ? status.currentCollection : null,
    );
    final essentials = groups.take(4);
    final ready = essentials.every(
      (item) => item.readiness == DataReadiness.ready,
    );
    final bytes = SyncTarget.values.fold<int>(
      0,
      (sum, target) => sum + HiveService.cachedBytes(target.collection),
    );
    final lastUpdate =
        [
          for (final name in const ['days', 'readings', 'prayers'])
            HiveService.getLastSync(name),
        ].whereType<DateTime>().fold<DateTime?>(
          null,
          (latest, time) =>
              latest == null || time.isAfter(latest) ? time : latest,
        );
    final notifier = ref.read(cachePolicyProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Даныя і загрузка', style: text.titleMedium),
        const SizedBox(height: 4),
        SwitchListTile.adaptive(
          key: const Key('data-auto-update'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Аўтаматычнае абнаўленне'),
          subtitle: const Text('Тэксты абнаўляюцца самі, калі ёсць сетка'),
          value: policy.enabled,
          onChanged: (value) => notifier.update(enabled: value),
        ),
        SwitchListTile.adaptive(
          key: const Key('data-prefetch-nearby'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Рыхтаваць бліжэйшыя дні'),
          subtitle: const Text('Заўтра і ўчора адкрываюцца без чакання'),
          value: policy.enabled && policy.prefetchNearby,
          onChanged: policy.enabled
              ? (value) => notifier.update(prefetchNearby: value)
              : null,
        ),
        SwitchListTile.adaptive(
          key: const Key('data-wifi-only'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Вялікія абнаўленні толькі па Wi-Fi'),
          subtitle: const Text('Біблія, спеўнік і кампендый'),
          value: policy.wifiOnlyLarge,
          onChanged: (value) => notifier.update(wifiOnlyLarge: value),
        ),
        const SizedBox(height: 12),
        DecoratedBox(
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
                Text('Даныя для працы без сеткі', style: text.titleSmall),
                const SizedBox(height: 4),
                Text(
                  status.isSyncing
                      ? 'Абнаўляюцца…'
                      : ready
                      ? 'Гатовыя для працы'
                      : offline
                      ? 'Няма сеткі — даступна тое, што ўжо захавана'
                      : 'Сённяшні дзень загрузіцца пры адкрыцці',
                  key: const Key('data-offline-status'),
                ),
                const SizedBox(height: 8),
                // Real progress only; otherwise an indeterminate line.
                AppRefreshBar(
                  active: status.isSyncing,
                  value: status.isSyncing && status.progress > 0
                      ? status.progress
                      : null,
                ),
                const SizedBox(height: 8),
                Text(
                  'Апошняе абнаўленне: ${formatLastUpdate(lastUpdate)}',
                  style: text.bodySmall,
                ),
                Text(
                  'Выкарыстана: ${formatCacheBytes(bytes)}',
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.tonal(
          key: const Key('data-update-now'),
          onPressed: status.isSyncing && !status.background || offline
              ? null
              : () {
                  final sync = ref.read(syncStatusProvider.notifier);
                  sync.cancelBackground();
                  sync.synchronize(
                    SyncPlan(
                      targets: const {
                        SyncTarget.days,
                        SyncTarget.readings,
                        SyncTarget.prayers,
                        SyncTarget.invitatoriums,
                        SyncTarget.completoriums,
                        SyncTarget.prayerCategories,
                      },
                      dates: CacheWarmupService.buildDateOrder(
                        DateTime.now(),
                        behind: policy.behind,
                        ahead: policy.ahead,
                      ),
                    ),
                  );
                },
          child: const Text('Абнавіць даныя'),
        ),
        if (status.error != null && !status.isSyncing) ...[
          const SizedBox(height: 8),
          Text(
            'Не ўсё ўдалося абнавіць. Захаваныя тэксты даступныя.',
            style: text.bodySmall?.copyWith(color: cs.error),
          ),
        ],
        const SizedBox(height: 4),
        ListTile(
          key: const Key('data-details'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Даныя праграмы'),
          subtitle: const Text('Што захавана і дадатковыя загрузкі'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showDataStatusSheet(context),
        ),
      ],
    );
  }
}

Future<void> showDataStatusSheet(BuildContext context) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (context) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: 0.86,
    minChildSize: 0.5,
    maxChildSize: 0.95,
    builder: (context, controller) => ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      children: const [DataStatusPanel()],
    ),
  ),
);

/// «Даныя праграмы»: a plain list of what is available offline, then the
/// detailed downloads for those who want them.
class DataStatusPanel extends ConsumerWidget {
  const DataStatusPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusProvider);
    ref.watch(cacheEpochProvider);
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final groups = collectDataStatus(
      syncingCollection: status.isSyncing ? status.currentCollection : null,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Даныя праграмы', style: text.titleLarge),
        const SizedBox(height: 12),
        for (final group in groups)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    switch (group.readiness) {
                      DataReadiness.ready => Icons.check_circle_outline,
                      DataReadiness.loading => Icons.sync,
                      DataReadiness.partial => Icons.timelapse,
                      DataReadiness.missing => Icons.cloud_download_outlined,
                    },
                    size: 20,
                    color: group.readiness == DataReadiness.ready
                        ? cs.primary
                        : cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(group.title, style: text.titleSmall),
                      Text(
                        group.detail,
                        style: text.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        ExpansionTile(
          key: const Key('data-advanced'),
          tilePadding: EdgeInsets.zero,
          title: const Text('Дадатковыя загрузкі'),
          subtitle: const Text('Асобныя раздзелы, перыяд, уся база'),
          children: const [CacheSyncSettings()],
        ),
        const SizedBox(height: 8),
        TextButton(
          key: const Key('data-clear-texts'),
          onPressed: status.isSyncing
              ? null
              : () => _confirmClear(context, ref),
          child: const Text('Ачысціць загружаныя тэксты'),
        ),
      ],
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ачысціць загружаныя тэксты?'),
        content: const Text(
          'Будуць выдалены захаваныя тэксты Літургіі гадзін і чытанняў. '
          'Налады, свае малітвы і вылучэнні застануцца. Тэксты загрузяцца '
          'зноў, калі будзе сетка.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Скасаваць'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ачысціць'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await HiveService.clearDownloadedTexts();
    ref.read(cacheEpochProvider.notifier).state++;
  }
}
