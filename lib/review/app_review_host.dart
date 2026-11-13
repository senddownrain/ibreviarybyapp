import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mybrev_flutter/discovery/discovery_providers.dart';
import 'package:mybrev_flutter/discovery/discovery_state.dart';
import 'package:mybrev_flutter/review/app_review_controller.dart';

/// Section roots: the calm screens where a system sheet is least intrusive.
const Set<String> kReviewRootPaths = {
  '/hours',
  '/readings',
  '/prayers',
  '/bible',
};

/// Counts a day of use on start and, after the person comes back from a text
/// to a section root and the screen stays still for [idle], asks the
/// controller for the system review sheet. All timing is here; the numbers
/// are in `AppReviewPolicy`.
class AppReviewHost extends ConsumerStatefulWidget {
  const AppReviewHost({
    super.key,
    required this.child,
    this.idle = const Duration(seconds: 4),
  });

  final Widget child;
  final Duration idle;

  @override
  ConsumerState<AppReviewHost> createState() => _AppReviewHostState();
}

class _AppReviewHostState extends ConsumerState<AppReviewHost>
    with WidgetsBindingObserver {
  GoRouter? _router;
  Timer? _timer;
  bool _leftRoot = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(
      ref.read(appReviewControllerProvider).recordUse().catchError((Object e) {
        debugPrint('[Review] use not recorded: $e');
      }),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.maybeOf(context);
    if (!identical(router, _router)) {
      _router?.routerDelegate.removeListener(_onRoute);
      _router = router;
      _router?.routerDelegate.addListener(_onRoute);
    }
  }

  String? get _path {
    final router = _router;
    if (router == null) return null;
    final match = router.routerDelegate.currentConfiguration.last;
    return match is ImperativeRouteMatch
        ? match.matches.uri.path
        : router.routerDelegate.currentConfiguration.uri.path;
  }

  void _onRoute() {
    _timer?.cancel();
    final path = _path;
    if (path == null) return;
    if (!kReviewRootPaths.contains(path)) {
      _leftRoot = true;
      return;
    }
    if (!_leftRoot) return; // only after coming back from a text
    _timer = Timer(widget.idle, _tryRequest);
  }

  bool _calm() {
    if (!mounted) return false;
    // `null` is the state before the first lifecycle message: the app is up.
    final life = WidgetsBinding.instance.lifecycleState;
    if (life != null && life != AppLifecycleState.resumed) return false;
    if (ModalRoute.of(context)?.isCurrent != true) return false;
    if (MediaQuery.viewInsetsOf(context).bottom > 0) return false;
    if (!kReviewRootPaths.contains(_path)) return false;
    final tour = ref.read(discoveryStateProvider).value?.tourStatus;
    return tour != TourStatus.inProgress;
  }

  Future<void> _tryRequest() async {
    if (!_calm()) return;
    try {
      final asked = await ref
          .read(appReviewControllerProvider)
          .maybeRequest(calm: _calm);
      if (asked) _leftRoot = false;
    } catch (error) {
      debugPrint('[Review] automatic request skipped: $error');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _router?.routerDelegate.removeListener(_onRoute);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
