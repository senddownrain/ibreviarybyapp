import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/discovery/discovery_coordinator.dart';
import 'package:mybrev_flutter/discovery/discovery_providers.dart';
import 'package:mybrev_flutter/discovery/discovery_repository.dart';
import 'package:mybrev_flutter/discovery/discovery_state.dart';
import 'package:mybrev_flutter/discovery/tour/tour_anchor_finder.dart';
import 'package:mybrev_flutter/discovery/tour/tour_card.dart';
import 'package:mybrev_flutter/discovery/tour/tour_policy.dart';
import 'package:mybrev_flutter/discovery/tour/tour_steps.dart';
import 'package:mybrev_flutter/navigation/app_navigation.dart';
import 'package:mybrev_flutter/services/hive_service.dart';

/// What the tour needs to know about the app shell. The production
/// implementation lives in `app_shell.dart`; tests supply a fake.
abstract class TourShell {
  Listenable get changes;
  AppBranch get branch;

  /// First screen of the section (not a reader).
  bool get atBranchRoot;
  bool get dockVisible;

  /// Switches section without resetting the section the person is in.
  void selectBranch(AppBranch branch);
}

/// On once the app's local storage is up (always, in the running app). Widget
/// tests of the shell have no Hive and stay free of the discovery storage
/// unless they opt in.
final tourEnabledProvider = Provider<bool>(
  (ref) => HiveService.isSettingsReady,
);

/// Set for the rest of the app run in which the welcome screen was answered:
/// no invitation then. The next launch offers it as before.
final tourInviteDeferredProvider = StateProvider<bool>((ref) => false);

/// «Як карыстацца дадаткам» bumps this; the host starts a manual tour.
final tourRequestProvider = StateProvider<int>((ref) => 0);

/// Quiet delay before the invitation, restarted by any activity.
const Duration kTourInviteSettle = Duration(milliseconds: 1500);

/// How long a step waits for its control after a section switch.
const Duration kTourAnchorWait = Duration(milliseconds: 2500);

/// ... and when the section is already open (data may still be arriving).
const Duration kTourAnchorWaitInPlace = Duration(milliseconds: 700);

enum _Phase { idle, inviting, running }

/// Offers and runs the product tour on top of the app shell. Everything is
/// local: the state lives in the discovery box.
class TourHost extends ConsumerStatefulWidget {
  const TourHost({
    super.key,
    required this.shell,
    required this.child,
    this.steps = defaultTourSteps,
  });

  final TourShell shell;
  final Widget child;
  final List<TourStep> steps;

  @override
  ConsumerState<TourHost> createState() => _TourHostState();
}

class _TourHostState extends ConsumerState<TourHost>
    with WidgetsBindingObserver {
  _Phase _phase = _Phase.idle;
  TourSession? _session;
  Rect? _rect;
  bool _waiting = false;
  bool _forward = true;
  bool _scrolling = false;
  AppBranch? _origin;
  Timer? _settle;
  Timer? _poll;
  Timer? _pending;
  int _pendingTries = 0;
  bool _staleChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.shell.changes.addListener(_onShellChanged);
  }

  @override
  void didUpdateWidget(covariant TourHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shell != widget.shell) {
      oldWidget.shell.changes.removeListener(_onShellChanged);
      widget.shell.changes.addListener(_onShellChanged);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.shell.changes.removeListener(_onShellChanged);
    _settle?.cancel();
    _poll?.cancel();
    _pending?.cancel();
    _setAutomaticBlocked(false);
    super.dispose();
  }

  DiscoveryRepository? get _repository =>
      ref.read(discoveryRepositoryProvider).valueOrNull;

  /// Kept so [dispose] can release the block after `ref` is gone.
  DiscoveryCoordinator? _blocked;

  void _setAutomaticBlocked(bool value) {
    if (value) {
      _blocked = ref.read(discoveryCoordinatorProvider).valueOrNull;
      _blocked?.automaticBlocked = true;
    } else {
      _blocked?.automaticBlocked = false;
      _blocked = null;
    }
  }

  TourScreenFacts _facts() {
    final route = ModalRoute.of(context);
    final view = View.of(context);
    return TourScreenFacts(
      routeIsCurrent: route?.isCurrent ?? true,
      atBranchRoot: widget.shell.atBranchRoot,
      dockVisible: widget.shell.dockVisible,
      keyboardVisible: view.viewInsets.bottom > 0,
      scrolling: _scrolling,
      hintOnScreen:
          ref.read(discoveryCoordinatorProvider).valueOrNull?.presented != null,
      tourRunning: _phase == _Phase.running,
    );
  }

  void _onShellChanged() {
    if (!mounted) return;
    if (_phase == _Phase.inviting) {
      // Leaving the screen the invitation was shown on closes it.
      if (!widget.shell.atBranchRoot) _closeInvitation();
      return;
    }
    _scheduleInvitation();
  }

  @override
  void didChangeMetrics() {
    if (!mounted) return;
    if (_phase == _Phase.running) {
      // Rotation or text-scale change moves the control: measure again after
      // the new layout.
      WidgetsBinding.instance.addPostFrameCallback((_) => _remeasure());
    } else {
      _scheduleInvitation();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleInvitation();
  }

  /// A run that was cut off by the system never resumes on its own.
  void _settleStaleRun(DiscoveryState state) {
    if (_staleChecked) return;
    _staleChecked = true;
    if (state.tourStatus == TourStatus.inProgress && _phase != _Phase.running) {
      unawaited(_repository?.setTourStatus(TourStatus.skipped));
    }
  }

  void _scheduleInvitation() {
    _settle?.cancel();
    if (_phase != _Phase.idle || !ref.read(tourEnabledProvider)) return;
    if (ref.read(tourInviteDeferredProvider)) return;
    final state = ref.read(discoveryStateProvider).valueOrNull;
    if (state == null) return;
    _settleStaleRun(state);
    if (tourOfferBlock(state, _facts()) != null) return;
    _settle = Timer(kTourInviteSettle, _offerNow);
  }

  void _offerNow() {
    if (!mounted || _phase != _Phase.idle) return;
    final repository = _repository;
    if (repository == null) return;
    if (tourOfferBlock(repository.state, _facts()) != null) return;
    setState(() => _phase = _Phase.inviting);
    _setAutomaticBlocked(true);
    // The offer is used up as soon as it is on screen: ignoring it, leaving
    // the screen or killing the app never brings it back by itself.
    unawaited(repository.setTourStatus(TourStatus.declined));
  }

  void _closeInvitation() {
    if (_phase != _Phase.inviting) return;
    setState(() => _phase = _Phase.idle);
    _setAutomaticBlocked(false);
  }

  void _declineInvitation() {
    unawaited(_repository?.setTourStatus(TourStatus.declined));
    _closeInvitation();
  }

  void _acceptInvitation() {
    _closeInvitation();
    _begin(manual: false);
  }

  /// Starts the tour once the screen is calm; gives up after a few tries.
  void _requestManualStart() {
    _pending?.cancel();
    _pendingTries = 0;
    void attempt() {
      if (!mounted) return;
      if (_phase == _Phase.inviting) _declineInvitation();
      if (manualTourCanStart(_facts())) {
        _begin(manual: true);
        return;
      }
      if (++_pendingTries > 20) return;
      _pending = Timer(const Duration(milliseconds: 150), attempt);
    }

    // Take the keyboard away first; the tour never shares the screen with it.
    FocusManager.instance.primaryFocus?.unfocus();
    attempt();
  }

  void _begin({required bool manual}) {
    if (_phase == _Phase.running) return;
    final session = TourSession(widget.steps);
    if (session.isEmpty) return;
    ref.read(hintPresenterProvider).dismiss();
    _setAutomaticBlocked(true);
    unawaited(_repository?.setTourStatus(TourStatus.inProgress));
    setState(() {
      _phase = _Phase.running;
      _session = session;
      _origin = widget.shell.branch;
      _forward = true;
    });
    _enterStep();
  }

  void _enterStep() {
    final session = _session;
    if (session == null) return;
    _poll?.cancel();
    final step = session.current;
    final needed = step.branch;
    setState(() {
      _rect = null;
      _waiting = true;
    });
    final switching = needed != null && needed != widget.shell.branch;
    if (switching) widget.shell.selectBranch(needed);
    const tick = Duration(milliseconds: 80);
    final maxTicks =
        (switching ? kTourAnchorWait : kTourAnchorWaitInPlace).inMilliseconds ~/
        tick.inMilliseconds;
    var ticks = 0;
    void check() {
      if (!mounted || _session != session) return;
      final onSection =
          step.branch == null || step.branch == widget.shell.branch;
      final rect = onSection ? resolveStepRect(context, step) : null;
      if (rect != null) {
        _poll?.cancel();
        setState(() {
          _rect = rect;
          _waiting = false;
        });
        _announce(session);
      } else if (++ticks > maxTicks) {
        _poll?.cancel();
        _skipMissing();
      }
    }

    check();
    if (_waiting) {
      _poll = Timer.periodic(tick, (_) => check());
    }
  }

  /// The control of the current step is not there: drop the step, go on.
  void _skipMissing() {
    final session = _session;
    if (session == null) return;
    debugPrint('[Tour] step ${session.current.id} skipped: anchor missing');
    final more = session.dropCurrent(forward: _forward);
    if (session.isEmpty) {
      _finish(TourStatus.skipped);
    } else if (!more && _forward) {
      // The dropped step was the last one: the tour is over.
      _finish(TourStatus.completed);
    } else {
      _enterStep();
    }
  }

  void _remeasure() {
    final session = _session;
    if (!mounted || _phase != _Phase.running || session == null) return;
    final rect = resolveStepRect(context, session.current);
    if (rect == null) {
      _enterStep();
    } else if (rect != _rect) {
      setState(() => _rect = rect);
    }
  }

  void _announce(TourSession session) {
    final step = session.current;
    SemanticsService.sendAnnouncement(
      View.of(context),
      'Крок ${session.progressBe}. ${step.titleBe}. ${step.bodyBe}',
      Directionality.of(context),
    );
  }

  void _next() {
    final session = _session;
    if (session == null) return;
    _forward = true;
    if (session.next()) {
      _enterStep();
    } else {
      _finish(TourStatus.completed);
    }
  }

  void _back() {
    final session = _session;
    if (session == null) return;
    _forward = false;
    if (session.back()) _enterStep();
  }

  void _finish(TourStatus status) {
    _poll?.cancel();
    final origin = _origin;
    setState(() {
      _phase = _Phase.idle;
      _session = null;
      _rect = null;
      _waiting = false;
    });
    _setAutomaticBlocked(false);
    unawaited(_repository?.setTourStatus(status));
    if (origin != null && origin != widget.shell.branch) {
      widget.shell.selectBranch(origin);
    }
    _origin = null;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(tourRequestProvider, (previous, next) {
      if (previous != next) _requestManualStart();
    });
    if (ref.watch(tourEnabledProvider)) {
      ref.listen<AsyncValue<DiscoveryState>>(discoveryStateProvider, (_, next) {
        if (next.hasValue) _scheduleInvitation();
      });
    }
    final running = _phase == _Phase.running && _session != null;
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        final moving =
            notification is ScrollStartNotification ||
            notification is ScrollUpdateNotification;
        if (moving != _scrolling && notification.depth == 0) {
          _scrolling = moving;
          if (moving) {
            _settle?.cancel();
          } else {
            _scheduleInvitation();
          }
        }
        return false;
      },
      child: PopScope(
        canPop: !running,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && running) _finish(TourStatus.skipped);
        },
        child: Stack(
          children: [
            Positioned.fill(child: widget.child),
            if (_phase == _Phase.inviting)
              TourInvitation(
                dockTop: _dockTop(context),
                onAccept: _acceptInvitation,
                onDecline: _declineInvitation,
              ),
            if (running)
              TourLayer(
                session: _session!,
                anchor: _rect,
                waiting: _waiting,
                onNext: _next,
                onBack: _back,
                onSkip: () => _finish(TourStatus.skipped),
              ),
          ],
        ),
      ),
    );
  }

  /// Top edge of the bottom dock, so the invitation sits above it.
  double? _dockTop(BuildContext context) {
    for (final key in const ['app-dock-full', 'app-dock-compact']) {
      final rects = findTourAnchorRects(context, TourAnchor.exact(key));
      if (rects.isNotEmpty) return rects.first.top;
    }
    return null;
  }
}
