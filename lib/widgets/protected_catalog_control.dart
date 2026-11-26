import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/providers/priest_access_provider.dart';

/// A catalog navigation edge may load the private overlay. A foreground
/// confirmation on the same route leaves the public list and this action.
class ProtectedCatalogControl extends ConsumerStatefulWidget {
  const ProtectedCatalogControl({super.key, this.padding = EdgeInsets.zero});

  final EdgeInsetsGeometry padding;

  @override
  ConsumerState<ProtectedCatalogControl> createState() =>
      _ProtectedCatalogControlState();
}

class _ProtectedCatalogControlState
    extends ConsumerState<ProtectedCatalogControl> {
  bool _visible = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible =
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.isCurrentOf(context) ?? true);
    final entered = visible && !_visible;
    _visible = visible;
    if (entered) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _visible) {
          unawaited(ref.read(priestAccessProvider.notifier).loadCatalog());
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(priestAccessProvider);
    if (!state.quotaBlocked &&
        (!state.canLoadCatalog || state.content != null)) {
      return const SizedBox.shrink();
    }
    final access = ref.read(priestAccessProvider.notifier);
    return Padding(
      padding: widget.padding,
      child: state.catalogLoading
          ? const LinearProgressIndicator()
          : TextButton(
              onPressed: state.quotaBlocked
                  ? access.retryAfterQuota
                  : access.loadCatalog,
              child: Text(
                state.quotaBlocked
                    ? 'Паўтарыць праверку доступу'
                    : 'Паказаць дадатковыя малітвы',
              ),
            ),
    );
  }
}
