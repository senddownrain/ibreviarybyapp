import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/models/sync_plan.dart';
import 'package:mybrev_flutter/providers/cache_policy_provider.dart';
import 'package:mybrev_flutter/providers/sync_provider.dart';
import 'package:mybrev_flutter/providers/cache_epoch_provider.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/widgets/data_loading_notice.dart';

class CacheSyncSettings extends ConsumerStatefulWidget {
  const CacheSyncSettings({super.key});
  @override
  ConsumerState<CacheSyncSettings> createState() => _CacheSyncSettingsState();
}

class _CacheSyncSettingsState extends ConsumerState<CacheSyncSettings> {
  final _targets = <SyncTarget>{...SyncTarget.values};
  SyncPeriod _period = SyncPeriod.fortnight;
  DateTime _baseDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(syncStatusProvider);
    final policy = ref.watch(cachePolicyProvider);
    ref.watch(cacheEpochProvider);
    final collections = SyncTarget.values.map((target) => target.collection);
    final bytes = collections.fold<int>(
      0,
      (sum, c) => sum + HiveService.cachedBytes(c),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Сінхранізацыя і афлайн',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'Спачатку загружаецца толькі сённяшні дзень. Іншыя даты і калекцыі захоўваюцца ў фоне; прыкладаннем можна карыстацца падчас загрузкі.',
        ),
        const SizedBox(height: 8),
        Text('Захавана ў кэшы: ${formatCacheBytes(bytes)}'),
        Text(
          'Памер тэкстаў і даных без сеткавых накладных выдаткаў. Убудаваная Біблія даступная афлайн і без сінхранізацыі.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Аўтаматычна захоўваць у фоне'),
          subtitle: const Text(
            'Даты вакол сёння, малітвы, абодва пераклады Бібліі і іншыя калекцыі. Калекцыі абнаўляюцца не часцей за раз на дзень.',
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
        const SizedBox(height: 20),
        Text('Асобная загрузка', style: Theme.of(context).textTheme.titleSmall),
        const Text(
          'Выберыце адну або некалькі груп. Ручная загрузка абнаўляе даныя з сервера.',
        ),
        for (final target in SyncTarget.values)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(target.label),
            subtitle: Text(_description(target)),
            value: _targets.contains(target),
            onChanged: status.isSyncing
                ? null
                : (value) => setState(() {
                    if (value == true) {
                      _targets.add(target);
                    } else {
                      _targets.remove(target);
                    }
                  }),
          ),
        DropdownButtonFormField<SyncPeriod>(
          initialValue: _period,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Перыяд для дзён і чытанняў',
          ),
          items: [
            for (final period in SyncPeriod.values)
              DropdownMenuItem(value: period, child: Text(period.label)),
          ],
          onChanged: status.isSyncing
              ? null
              : (value) => setState(() => _period = value!),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          key: const Key('sync-base-date'),
          onPressed: status.isSyncing
              ? null
              : () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _baseDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100, 12, 31),
                  );
                  if (date != null && mounted) setState(() => _baseDate = date);
                },
          icon: const Icon(Icons.calendar_month_outlined),
          label: Text(
            'Пачатак: ${_baseDate.day}.${_baseDate.month}.${_baseDate.year}',
          ),
        ),
        const Text(
          'Тыдні і месяцы — ад выбранай даты наперад. Каляндарны год — год выбранай даты, ад 1 студзеня да 31 снежня. «Уся калекцыя» захоўвае ўсе дакументы без абмежавання дат.',
        ),
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
            '${status.completedCollections} / ${status.totalCollections} груп · ${status.currentDocCount ?? 0} дакументаў · загружана ${formatCacheBytes(status.downloadedBytes)}',
          ),
          OutlinedButton.icon(
            onPressed: () => ref.read(syncStatusProvider.notifier).cancel(),
            icon: const Icon(Icons.pause),
            label: const Text('Спыніць пасля бягучага запыту'),
          ),
        ] else if (status.downloadedBytes > 0 || status.cancelled) ...[
          Text(
            '${status.cancelled
                ? 'Загрузка спынена. Захаваныя даныя даступныя.'
                : status.error == null
                ? 'Загрузка завершана.'
                : 'Частка даных захавана.'} ${formatCacheBytes(status.downloadedBytes)}',
          ),
          const SizedBox(height: 8),
        ],
        if (status.error != null) ...[
          Text(
            status.error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 8),
          const Text(
            'Праверце сетку і паўтарыце загрузку. Раней захаваныя даныя застаюцца даступнымі.',
          ),
        ],
        FilledButton.icon(
          key: const Key('sync-selected'),
          onPressed: status.isSyncing || _targets.isEmpty
              ? null
              : () => ref
                    .read(syncStatusProvider.notifier)
                    .synchronize(
                      SyncPlan(
                        targets: {..._targets},
                        period: _period,
                        baseDate: _baseDate,
                      ),
                    ),
          icon: const Icon(Icons.download_outlined),
          label: const Text('Загрузіць выбранае'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const Key('sync-entire-database'),
          onPressed: status.isSyncing
              ? null
              : () => ref.read(syncStatusProvider.notifier).forceSyncAll(),
          icon: const Icon(Icons.cloud_download_outlined),
          label: const Text('Загрузіць усю базу'),
        ),
        const Text(
          'Уся база: усе дні і чытанні, малітвы, абодва пераклады Бібліі, гады, заклік, камплета і катэгорыі. Загрузка можа заняць час; яна не перашкаджае чытанню.',
        ),
      ],
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

  String _description(SyncTarget target) {
    final collection = target.collection;
    final last = HiveService.getLastSync(collection);
    final time = last == null
        ? 'яшчэ не сінхранізавана'
        : '${last.day}.${last.month}.${last.year}';
    return '${HiveService.boxFor(collection).length} дакументаў · ${formatCacheBytes(HiveService.cachedBytes(collection))} · $time';
  }
}
