import 'package:flutter/material.dart';
import 'package:mybrev_flutter/widgets/loading/app_load_states.dart';

/// «18.0 МБ» — a size the reader decides on (a large update on mobile data).
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes Б';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} КБ';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} МБ';
}

/// The only waiting state of a reading screen: the texts are on the device
/// and are being opened (at launch, for a moment). Never sizes, servers or
/// the network.
class DataLoadingNotice extends StatelessWidget {
  const DataLoadingNotice({
    super.key,
    required this.label,
    this.shape = LoadingShape.none,
  });

  final String label;
  final LoadingShape shape;

  @override
  Widget build(BuildContext context) =>
      AppLoadingState(label: label, shape: shape);
}
