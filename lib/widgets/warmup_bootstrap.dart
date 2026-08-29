import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/services/parsed_readings_service.dart';

/// Triggers background cache warmup once per app session.
class WarmupBootstrap extends ConsumerStatefulWidget {
  final Widget child;
  const WarmupBootstrap({super.key, required this.child});

  @override
  ConsumerState<WarmupBootstrap> createState() => _WarmupBootstrapState();
}

class _WarmupBootstrapState extends ConsumerState<WarmupBootstrap> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(cacheWarmupProvider));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
