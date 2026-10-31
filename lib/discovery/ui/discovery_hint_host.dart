import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:mybrev_flutter/discovery/discovery_context.dart';
import 'package:mybrev_flutter/discovery/discovery_coordinator.dart';
import 'package:mybrev_flutter/discovery/discovery_providers.dart';
import 'package:mybrev_flutter/discovery/discovery_storage.dart';
import 'package:mybrev_flutter/discovery/hint_definition.dart';
import 'package:mybrev_flutter/discovery/ui/anchor_finder.dart';
import 'package:mybrev_flutter/discovery/ui/coachmark.dart';

/// What a screen knows right now, handed to [DiscoveryHintHost].
class DiscoveryProbe {
  const DiscoveryProbe({
    this.ready = true,
    this.facts = const {},
    this.anchors = const {},
    this.invoke = const {},
    this.blockedBy = const [],
  });

  /// False while the screen's own data is loading.
  final bool ready;
  final Map<String, Object?> facts;

  /// Existing `Key`s of the real controls, by hint anchor id.
  final Map<String, List<Key>> anchors;

  /// Key of the control that «Паказаць» presses, by hint ID.
  final Map<String, Key> invoke;

  /// Keys that, once mounted, mean another surface is active (selection
  /// palette, dialog, …): no hint is shown.
  final List<Key> blockedBy;
}

typedef DiscoveryProbeBuilder =
    DiscoveryProbe Function(
      BuildContext context,
      WidgetRef ref,
      ScrollMetrics? metrics,
    );

/// Binds one screen to the discovery engine. Everything the person sees comes
/// from `DiscoveryCoordinator.request`; this widget only reports facts and
/// keeps the screen calm (no scroll, keyboard, route change or sheet).
class DiscoveryHintHost extends ConsumerStatefulWidget {
  const DiscoveryHintHost({
    super.key,
    required this.screenId,
    required this.probe,
    required this.child,
    this.inline,
    this.dwell = const Duration(milliseconds: 1500),
    this.settle = const Duration(milliseconds: 1200),
  });

  final String screenId;
  final DiscoveryProbeBuilder probe;
  final Widget child;

  /// Inside a panel the hint is drawn in this slot instead of the overlay.
  final ValueNotifier<HintDefinition?>? inline;

  /// How long the screen must be on view before a hint may appear.
  final Duration dwell;

  /// How long the content must stand still after a scroll.
  final Duration settle;

  @override
  ConsumerState<DiscoveryHintHost> createState() => _DiscoveryHintHostState();
}

class _DiscoveryHintHostState extends ConsumerState<DiscoveryHintHost> {
  static const _period = Duration(milliseconds: 600);

  int _ticksFor(Duration d) =>
      (d.inMilliseconds / _period.inMilliseconds).ceil();

  Timer? _timer;
  DiscoveryCoordinator? _coordinator;
  int? _visit;
  // Time is counted in poll ticks, so it follows the (fake) timer clock.
  int _tickNo = 0;
  int _visibleSinceTick = 0;
  int? _scrollEndedTick;
  bool _scrolling = false;
  bool _requesting = false;
  ScrollMetrics? _metrics;
  DiscoveryProbe _lastProbe = const DiscoveryProbe();
  HintSurface? _surface;

  @override
  void initState() {
    super.initState();
    unawaited(_attach());
  }

  Future<void> _attach() async {
    try {
      // Hints need their own box; where Hive was not started (previews,
      // widget tests of other screens) the host stays silent.
      final storage = ref.read(discoveryStorageProvider);
      if (storage is HiveDiscoveryStorage && !Hive.isBoxOpen(storage.boxName)) {
        return;
      }
      final coordinator = await ref.read(discoveryCoordinatorProvider.future);
      if (!mounted) return;
      _coordinator = coordinator;
      _timer = Timer.periodic(
        const Duration(milliseconds: 600),
        (_) => _tick(),
      );
    } catch (error) {
      debugPrint('[Discovery] host disabled: $error');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _leave();
    super.dispose();
  }

  bool get _onView {
    final route = ModalRoute.of(context);
    final routeReady =
        (route?.isCurrent ?? true) &&
        (route?.animation?.status ?? AnimationStatus.completed) ==
            AnimationStatus.completed;
    return routeReady && TickerMode.valuesOf(context).enabled;
  }

  void _leave() {
    final visit = _visit;
    final surface = _surface;
    final presenter = _presenter;
    if (surface != null) presenter?.unbind(surface);
    _surface = null;
    if (visit != null) _coordinator?.endVisit(visit);
    _visit = null;
  }

  CoachmarkPresenter? get _presenter {
    final presenter = _coordinator?.presenter;
    return presenter is CoachmarkPresenter ? presenter : null;
  }

  Rect? _rectOf(Key key) => findAnchorRect(context, key);

  bool _fullyOnScreen(Rect rect) {
    final media = MediaQuery.of(context);
    final size = media.size;
    return rect.width > 0 &&
        rect.height > 0 &&
        rect.left >= 0 &&
        rect.right <= size.width &&
        rect.top >= media.padding.top &&
        rect.bottom <= size.height - media.padding.bottom;
  }

  Future<void> _tick() async {
    final coordinator = _coordinator;
    if (!mounted || coordinator == null || _requesting) return;
    if (!_onView) {
      if (_visit != null) _leave();
      return;
    }
    _tickNo++;
    if (_visit == null) {
      _visit = coordinator.beginVisit(widget.screenId);
      _visibleSinceTick = _tickNo;
    }
    final visit = _visit!;
    final probe = widget.probe(context, ref, _metrics);
    _lastProbe = probe;
    final blocked = probe.blockedBy.any((key) => _rectOf(key) != null);
    final scrollSettled =
        _scrollEndedTick == null ||
        _tickNo - _scrollEndedTick! >= _ticksFor(widget.settle);
    final ui = DiscoveryUiState(
      scrolling: _scrolling || !scrollSettled,
      keyboardVisible: MediaQuery.viewInsetsOf(context).bottom > 0,
      modalOpen: blocked,
      transitioning: _tickNo - _visibleSinceTick < _ticksFor(widget.dwell),
    );
    final anchors = <String>{
      for (final entry in probe.anchors.entries)
        if (entry.value.isNotEmpty &&
            entry.value.every((key) {
              final rect = _rectOf(key);
              return rect != null && _fullyOnScreen(rect);
            }))
          entry.key,
    };
    final context_ = probe.ready
        ? DiscoveryContext(
            screenId: widget.screenId,
            visitId: visit,
            status: DiscoveryDataStatus.ready,
            anchors: anchors,
            facts: probe.facts,
            ui: ui,
          )
        : DiscoveryContext.loading(
            screenId: widget.screenId,
            visitId: visit,
            ui: ui,
          );
    if (coordinator.peek(context_).isNone) return;
    final presenter = _presenter;
    if (presenter == null) return;
    final surface = HintSurface(
      context: context,
      anchors: probe.anchors,
      inline: widget.inline,
      canSnooze: (hint) => coordinator.policy.canSnooze(
        hint,
        coordinator.repository.state.record(hint.id),
      ),
      onResponse: _onResponse,
    );
    presenter.bind(surface);
    _surface = surface;
    _requesting = true;
    try {
      await coordinator.request(context_);
    } finally {
      _requesting = false;
    }
  }

  Future<void> _onResponse(HintDefinition hint, HintResponse response) async {
    final coordinator = _coordinator;
    if (coordinator == null) return;
    final invokeKey = _lastProbe.invoke[hint.id];
    await coordinator.respond(hint.id, response);
    if (response == HintResponse.acted &&
        invokeKey != null &&
        mounted &&
        _surface != null) {
      invokeAnchor(context, invokeKey);
    }
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    _metrics = notification.metrics;
    if (notification is ScrollStartNotification ||
        notification is ScrollUpdateNotification) {
      if (!_scrolling) _presenter?.dismiss();
      _scrolling = true;
    } else if (notification is ScrollEndNotification) {
      _scrolling = false;
      _scrollEndedTick = _tickNo;
    }
    return false;
  }

  /// Using the real control counts as having learned the hint.
  void _onPointerUp(PointerUpEvent event) {
    final presenter = _presenter;
    final shown = presenter?.shown;
    final rect = presenter?.shownAnchorRect;
    if (shown == null || rect == null || !rect.contains(event.position)) {
      return;
    }
    unawaited(_coordinator?.respond(shown.id, HintResponse.acted));
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.inline == null
        ? NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: widget.child,
          )
        : widget.child;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerUp: _onPointerUp,
      child: _HintInlineScope(inline: widget.inline, host: this, child: child),
    );
  }
}

class _HintInlineScope extends InheritedWidget {
  const _HintInlineScope({
    required this.inline,
    required this.host,
    required super.child,
  });

  final ValueNotifier<HintDefinition?>? inline;
  final _DiscoveryHintHostState host;

  @override
  bool updateShouldNotify(_HintInlineScope old) => inline != old.inline;
}

/// Where a panel draws the hint of its [DiscoveryHintHost]; empty otherwise.
class HintInlineSlot extends StatelessWidget {
  const HintInlineSlot({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_HintInlineScope>();
    final inline = scope?.inline;
    if (scope == null || inline == null) return const SizedBox.shrink();
    return ValueListenableBuilder<HintDefinition?>(
      valueListenable: inline,
      builder: (context, hint, _) {
        if (hint == null) return const SizedBox.shrink();
        final host = scope.host;
        final coordinator = host._coordinator;
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: HintCard(
            hint: hint,
            canSnooze:
                coordinator != null &&
                coordinator.policy.canSnooze(
                  hint,
                  coordinator.repository.state.record(hint.id),
                ),
            onResponse: (response) => host._onResponse(hint, response),
          ),
        );
      },
    );
  }
}
