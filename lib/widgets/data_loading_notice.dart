import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/providers/connectivity_provider.dart';
import 'package:mybrev_flutter/providers/sync_provider.dart';
import 'package:mybrev_flutter/services/hive_service.dart';

String formatCacheBytes(int bytes) {
  if (bytes < 1024) return '$bytes Б';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} КБ';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} МБ';
}

class DataLoadingNotice extends ConsumerWidget {
  const DataLoadingNotice({
    super.key,
    required this.label,
    this.collections = const ['days', 'readings'],
  });
  final String label;
  final List<String> collections;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(syncStatusProvider);
    final offline = ref.watch(connectivityProvider).value == false;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 180, child: LinearProgressIndicator()),
          const SizedBox(height: 12),
          Text(label, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(
            offline
                ? 'Няма сеткі · шукаем захаваныя даныя'
                : 'Адсутныя даныя запытваем з сервера',
            textAlign: TextAlign.center,
          ),
          if (HiveService.isCacheReady) ...[
            const SizedBox(height: 6),
            ValueListenableBuilder<int>(
              valueListenable: HiveService.cacheRevision,
              builder: (context, _, child) => Text(
                'У кэшы: ${formatCacheBytes(collections.fold<int>(0, (sum, name) => sum + HiveService.cachedBytes(name)))}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
