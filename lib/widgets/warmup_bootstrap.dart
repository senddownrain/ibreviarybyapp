import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/providers/data_bootstrap_provider.dart';

/// Keeps [dataBootstrapProvider] alive for the app session.
class WarmupBootstrap extends ConsumerWidget {
  final Widget child;
  const WarmupBootstrap({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(dataBootstrapProvider);
    return child;
  }
}
