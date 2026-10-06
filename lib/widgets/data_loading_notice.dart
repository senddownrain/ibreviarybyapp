import 'package:flutter/material.dart';
import 'package:mybrev_flutter/widgets/loading/app_load_states.dart';

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
