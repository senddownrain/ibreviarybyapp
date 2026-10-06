import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/providers/content_updates_provider.dart';

/// Asks once a day whether newer texts exist: shortly after launch (never
/// before the first screen) and when the app returns to the foreground.
class ContentUpdateScheduler extends ConsumerStatefulWidget {
  const ContentUpdateScheduler({super.key, required this.child});
  final Widget child;

  /// Delay after launch: the first screen and its texts come first.
  static const startDelay = Duration(seconds: 5);

  @override
  ConsumerState<ContentUpdateScheduler> createState() =>
      _ContentUpdateSchedulerState();
}

class _ContentUpdateSchedulerState extends ConsumerState<ContentUpdateScheduler>
    with WidgetsBindingObserver {
  Timer? _start;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start = Timer(ContentUpdateScheduler.startDelay, _checkIfDue);
  }

  @override
  void dispose() {
    _start?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _checkIfDue() {
    if (!mounted) return;
    unawaited(ref.read(contentUpdatesProvider.notifier).checkIfDue());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkIfDue();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
