import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/providers/data_bootstrap_provider.dart';

/// Keeps bootstrap alive and resumes interrupted background work on app return.
class WarmupBootstrap extends ConsumerStatefulWidget {
  const WarmupBootstrap({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<WarmupBootstrap> createState() => _WarmupBootstrapState();
}

class _WarmupBootstrapState extends ConsumerState<WarmupBootstrap>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(dataBootstrapProvider.notifier).resume());
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(dataBootstrapProvider);
    return widget.child;
  }
}
