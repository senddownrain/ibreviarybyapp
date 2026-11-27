import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/novena/novena_providers.dart';

/// Refreshes the local date on return from the background and when the day
/// changes in the foreground. No system notifications or background jobs.
class NovenaDayWatcher extends ConsumerStatefulWidget {
  const NovenaDayWatcher({super.key, required this.child});

  final Widget child;

  /// Also catches a changed time zone or clock without a lifecycle event.
  static const maxWait = Duration(minutes: 15);

  /// To the next local midnight; a calendar step, not 24 hours (DST).
  static Duration untilNextDay(DateTime now) {
    final wait = DateTime(now.year, now.month, now.day + 1).difference(now);
    return wait > maxWait ? maxWait : wait + const Duration(seconds: 1);
  }

  @override
  ConsumerState<NovenaDayWatcher> createState() => _NovenaDayWatcherState();
}

class _NovenaDayWatcherState extends ConsumerState<NovenaDayWatcher>
    with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Without storage nothing depends on the date (and no timer is kept).
    if (ref.read(novenaBoxProvider) != null) _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(
      NovenaDayWatcher.untilNextDay(ref.read(novenaClockProvider)()),
      () {
        ref.read(novenaTodayProvider.notifier).refresh();
        _schedule();
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (ref.read(novenaBoxProvider) == null) return;
    if (state == AppLifecycleState.resumed) {
      ref.read(novenaTodayProvider.notifier).refresh();
      _schedule();
    } else if (state == AppLifecycleState.paused) {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
