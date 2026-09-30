import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/providers/connectivity_provider.dart';
import 'package:mybrev_flutter/widgets/loading/app_load_states.dart';

String formatCacheBytes(int bytes) {
  if (bytes < 1024) return '$bytes Б';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} КБ';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} МБ';
}

/// First load of a screen: what is being loaded, in the reader's words.
///
/// Storage sizes, servers and collections belong to Settings → «Даныя
/// праграмы», not to a reading screen.
class DataLoadingNotice extends ConsumerWidget {
  const DataLoadingNotice({
    super.key,
    required this.label,
    this.shape = LoadingShape.none,
    // Kept for source compatibility; sizes are no longer shown here.
    this.collections = const ['days', 'readings'],
  });

  final String label;
  final LoadingShape shape;
  final List<String> collections;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = ref.watch(connectivityProvider).value == false;
    return AppLoadingState(
      label: label,
      detail: offline ? 'Няма сеткі — шукаем захаваныя тэксты' : null,
      shape: shape,
    );
  }
}
