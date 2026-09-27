import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/models/sync_plan.dart';
import 'package:mybrev_flutter/providers/cache_policy_provider.dart';
import 'package:mybrev_flutter/providers/sync_provider.dart';
import 'package:mybrev_flutter/providers/cache_epoch_provider.dart';
import 'package:mybrev_flutter/services/cache_warmup_service.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/widgets/data_loading_notice.dart';

enum _LiturgicalRange {
  standard('Па змаўчанні'),
  fortnight('2 тыдні'),
  twoMonths('2 месяцы'),
  all('Усё');

  const _LiturgicalRange(this.label);
  final String label;
}

class CacheSyncSettings extends ConsumerStatefulWidget {
  const CacheSyncSettings({super.key});
  @override
  ConsumerState<CacheSyncSettings> createState() => _CacheSyncSettingsState();
}

class _CacheSyncSettingsState extends ConsumerState<CacheSyncSettings> {
  _LiturgicalRange _range = _LiturgicalRange.standard;
  String? _runningGroup;
  String? _lastGroup;

  static const _liturgy = {SyncTarget.days, SyncTarget.readings};
  static const _prayers = {SyncTarget.prayers};
  static const _bible = {SyncTarget.bibleBel, SyncTarget.bibleRu};
  static const _songs = {SyncTarget.songs};
  static const _other = {
    SyncTarget.years,
    SyncTarget.invitatoriums,
    SyncTarget.completoriums,
    SyncTarget.prayerCategories,
  };

  Future<void> _sync(String title, SyncPlan plan) async {
    setState(() {
      _runningGroup = title;
      _lastGroup = title;
    });
    final notifier = ref.read(syncStatusProvider.notifier);
    // An explicit group request takes over from optional background work.
    notifier.cancelBackground();
    try {
      await notifier.synchronize(plan);
    } finally {
      if (mounted) setState(() => _runningGroup = null);
    }
  }

  SyncPlan _liturgyPlan(CachePolicy policy) => switch (_range) {
    _LiturgicalRange.standard => SyncPlan(
      targets: _liturgy,
      dates: CacheWarmupService.buildDateOrder(
        DateTime.now(),
        behind: policy.behind,
        ahead: policy.ahead,
      ),
    ),
    _LiturgicalRange.fortnight => const SyncPlan(
      targets: _liturgy,
      period: SyncPeriod.fortnight,
    ),
    _LiturgicalRange.twoMonths => const SyncPlan(
      targets: _liturgy,
      period: SyncPeriod.twoMonths,
    ),
    _LiturgicalRange.all => const SyncPlan(
      targets: _liturgy,
      period: SyncPeriod.all,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(syncStatusProvider);
    final policy = ref.watch(cachePolicyProvider);
    ref.watch(cacheEpochProvider);
    final busy =
        _runningGroup != null || (status.isSyncing && !status.background);
    final bytes = SyncTarget.values.fold<int>(
      0,
      (sum, target) => sum + HiveService.cachedBytes(target.collection),
    );
    final rangeDescription = switch (_range) {
      _LiturgicalRange.standard =>
        '${policy.behind} дзён назад і ${policy.ahead} дзён наперад ад сёння.',
      _LiturgicalRange.fortnight => 'На 2 тыдні ад сёння наперад.',
      _LiturgicalRange.twoMonths => 'На 2 каляндарныя месяцы ад сёння наперад.',
      _LiturgicalRange.all =>
        'Усе літургічныя дні і чытанні без абмежавання дат.',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Сінхранізацыя', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text(
          'Кожная кнопка загружае або абнаўляе з базы толькі сваю групу.',
        ),
        const SizedBox(height: 6),
        Text('Захавана ў кэшы: ${formatCacheBytes(bytes)}'),
        const SizedBox(height: 12),
        if (status.isSyncing) ...[
          LinearProgressIndicator(
            value: status.progress == 0 ? null : status.progress,
          ),
          const SizedBox(height: 8),
          Text(
            '${status.background ? 'У фоне: ' : ''}${status.currentLabel ?? 'Загрузка'}',
          ),
          Text(
            '${status.currentDocCount ?? 0} дакументаў · загружана ${formatCacheBytes(status.downloadedBytes)}',
          ),
          TextButton.icon(
            onPressed: () => ref.read(syncStatusProvider.notifier).cancel(),
            icon: const Icon(Icons.pause),
            label: const Text('Спыніць загрузку'),
          ),
        ] else if (_runningGroup != null) ...[
          const LinearProgressIndicator(),
          const SizedBox(height: 8),
          Text('Падрыхтоўка: $_runningGroup'),
        ] else if (status.downloadedBytes > 0 ||
            status.cancelled ||
            status.error != null) ...[
          Text(
            '${status.background ? 'Фонавая загрузка' : _lastGroup ?? 'Загрузка'}: ${status.cancelled
                ? 'спынена'
                : status.error == null
                ? 'завершана'
                : 'завершана з памылкай'} · ${formatCacheBytes(status.downloadedBytes)}',
          ),
        ],
        if (status.error != null) ...[
          const SizedBox(height: 6),
          Text(
            status.error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const Text(
            'Праверце сетку і паўтарыце загрузку гэтай групы. Захаваныя даныя даступныя афлайн.',
          ),
        ],
        const SizedBox(height: 12),
        _group(
          title: 'Літургія і чытанні',
          targets: _liturgy,
          buttonKey: 'sync-liturgy',
          busy: busy,
          onPressed: () => _sync('Літургія і чытанні', _liturgyPlan(policy)),
          options: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<_LiturgicalRange>(
                key: const Key('sync-liturgy-period'),
                initialValue: _range,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Перыяд'),
                items: [
                  for (final range in _LiturgicalRange.values)
                    DropdownMenuItem(value: range, child: Text(range.label)),
                ],
                onChanged: busy
                    ? null
                    : (value) {
                        if (value != null) setState(() => _range = value);
                      },
              ),
              const SizedBox(height: 8),
              Text(rangeDescription),
            ],
          ),
        ),
        _group(
          title: 'Малітвы',
          targets: _prayers,
          buttonKey: 'sync-prayers',
          busy: busy,
          onPressed: () => _sync('Малітвы', const SyncPlan(targets: _prayers)),
        ),
        _group(
          title: 'Біблія',
          description: 'Беларускі і рускі пераклады.',
          targets: _bible,
          buttonKey: 'sync-bible',
          busy: busy,
          onPressed: () => _sync('Біблія', const SyncPlan(targets: _bible)),
        ),
        _group(
          title: 'Спеўнік',
          description:
              'Спевы і акорды. Убудаваная падборка даступная і без загрузкі.',
          targets: _songs,
          buttonKey: 'sync-songs',
          busy: busy,
          onPressed: () => _sync('Спеўнік', const SyncPlan(targets: _songs)),
        ),
        _group(
          title: 'Астатняе',
          description:
              'Параметры гадоў, заклік, камплета і катэгорыі малітваў.',
          targets: _other,
          buttonKey: 'sync-other',
          busy: busy,
          onPressed: () => _sync('Астатняе', const SyncPlan(targets: _other)),
        ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('Фонавая загрузка'),
          subtitle: Text(
            policy.enabled
                ? 'Уключана · ${policy.behind} дзён назад, ${policy.ahead} дзён наперад'
                : 'Выключана',
          ),
          children: [
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Аўтаматычна захоўваць у фоне'),
              subtitle: const Text(
                'Спачатку загружаецца сённяшні дзень, затым астатнія даныя ў фоне.',
              ),
              value: policy.enabled,
              onChanged: (value) =>
                  ref.read(cachePolicyProvider.notifier).update(enabled: value),
            ),
            _window(
              'Назад ад сёння',
              policy.behind,
              (value) =>
                  ref.read(cachePolicyProvider.notifier).update(behind: value),
            ),
            const SizedBox(height: 12),
            _window(
              'Наперад ад сёння',
              policy.ahead,
              (value) =>
                  ref.read(cachePolicyProvider.notifier).update(ahead: value),
            ),
            const SizedBox(height: 12),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const Key('sync-entire-database'),
          onPressed: busy
              ? null
              : () => _sync(
                  'Уся база',
                  const SyncPlan(
                    targets: {...SyncTarget.values},
                    period: SyncPeriod.all,
                  ),
                ),
          icon: const Icon(Icons.cloud_download_outlined),
          label: const Text('Загрузіць усю базу'),
        ),
        Text(
          'Памеры паказваюць захаваныя даныя без сеткавых накладных выдаткаў. Убудаваная Біблія даступная афлайн і без загрузкі з базы.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _group({
    required String title,
    String? description,
    required Set<SyncTarget> targets,
    required String buttonKey,
    required bool busy,
    required VoidCallback onPressed,
    Widget? options,
  }) {
    final count = targets.fold<int>(
      0,
      (sum, t) => sum + HiveService.boxFor(t.collection).length,
    );
    final bytes = targets.fold<int>(
      0,
      (sum, t) => sum + HiveService.cachedBytes(t.collection),
    );
    final times = targets
        .map((t) => HiveService.getLastSync(t.collection))
        .toList();
    final completed = times.every((time) => time != null);
    final earliest = completed ? (times.cast<DateTime>()..sort()).first : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              if (description != null) ...[
                const SizedBox(height: 4),
                Text(description),
              ],
              const SizedBox(height: 6),
              Text(
                '$count дакументаў · ${formatCacheBytes(bytes)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (earliest != null)
                Text(
                  'Сінхранізавана: ${earliest.day}.${earliest.month}.${earliest.year}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              if (options != null) ...[const SizedBox(height: 12), options],
              const SizedBox(height: 12),
              FilledButton.icon(
                key: Key(buttonKey),
                onPressed: busy ? null : onPressed,
                icon: const Icon(Icons.download_outlined),
                label: Text(
                  _runningGroup == title
                      ? 'Загрузка…'
                      : count == 0
                      ? 'Загрузіць'
                      : 'Сінхранізаваць',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _window(String label, int value, void Function(int) onChanged) {
    final choices = {0, 7, 14, 30, 90, 180, 365, value}.toList()..sort();
    return DropdownButtonFormField<int>(
      key: ValueKey('$label-$value'),
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final days in choices)
          DropdownMenuItem(
            value: days,
            child: Text(days == 0 ? 'Толькі сёння' : '$days дзён'),
          ),
      ],
      onChanged: (days) {
        if (days != null) onChanged(days);
      },
    );
  }
}
