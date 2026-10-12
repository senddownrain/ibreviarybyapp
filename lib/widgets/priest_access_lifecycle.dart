import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/providers/priest_access_provider.dart';

class PriestAccessLifecycle extends ConsumerStatefulWidget {
  const PriestAccessLifecycle({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<PriestAccessLifecycle> createState() =>
      _PriestAccessLifecycleState();
}

class _PriestAccessLifecycleState extends ConsumerState<PriestAccessLifecycle>
    with WidgetsBindingObserver {
  StreamSubscription<List<ConnectivityResult>>? _connectivity;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final controller = ref.read(priestAccessProvider.notifier);
    void network(List<ConnectivityResult> results) {
      if (!mounted) return;
      if (!results.any((result) => result != ConnectivityResult.none)) {
        controller.suspend(online: false);
      } else {
        unawaited(controller.resume(online: true));
      }
    }

    _connectivity = Connectivity().onConnectivityChanged.listen(network);
    unawaited(
      Connectivity()
          .checkConnectivity()
          .then(network)
          .catchError((Object _) {}),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = ref.read(priestAccessProvider.notifier);
    if (state == AppLifecycleState.resumed) {
      unawaited(controller.resume(foreground: true));
    } else {
      controller.suspend(foreground: false);
    }
  }

  @override
  void dispose() {
    _connectivity?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
