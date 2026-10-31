import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:mybrev_flutter/discovery/discovery_clock.dart';
import 'package:mybrev_flutter/discovery/discovery_context.dart';
import 'package:mybrev_flutter/discovery/discovery_repository.dart';
import 'package:mybrev_flutter/discovery/hint_catalog.dart';
import 'package:mybrev_flutter/discovery/hint_definition.dart';
import 'package:mybrev_flutter/discovery/hint_eligibility.dart';

/// The single app-wide place that puts a hint on screen. Stage 3 supplies the
/// real coachmark; the engine only knows this contract.
abstract class HintPresenter {
  /// Shows [hint] next to its anchor. Completes with `true` once it is really
  /// on screen, `false` if it could not be shown (anchor gone, no overlay).
  Future<bool> present(HintDefinition hint);

  /// Removes whatever is shown; safe when nothing is.
  void dismiss();
}

/// Default presenter: never shows anything, so the engine is inert until a
/// screen supplies a real one.
class NullHintPresenter implements HintPresenter {
  const NullHintPresenter();

  @override
  Future<bool> present(HintDefinition hint) async => false;

  @override
  void dismiss() {}
}

enum HintResponse {
  /// The person used the feature the hint points at.
  acted,

  /// «Зразумела».
  acknowledged,

  /// «Пазней».
  later,

  /// «Не паказваць».
  never,
}

class HintRequestResult {
  const HintRequestResult(this.decision, {required this.presented});

  final HintDecision decision;

  /// True only if the presenter reported a real display.
  final bool presented;

  String get label => decision.label;
}

/// Serializes automatic hints: at most one request in flight and one hint on
/// screen; counts a display only after the presenter confirms it.
class DiscoveryCoordinator {
  DiscoveryCoordinator({
    required this.repository,
    required this.catalog,
    required this.clock,
    required this.presenter,
    this.policy = const HintPolicy(),
  });

  final DiscoveryRepository repository;
  final HintCatalog catalog;
  final DiscoveryClock clock;
  final HintPresenter presenter;
  final HintPolicy policy;

  int _visitCounter = 0;
  int? _currentVisit;
  String? _currentScreen;
  bool _autoShownThisVisit = false;
  bool _requestInFlight = false;
  HintDefinition? _presented;
  int? _presentedVisit;

  HintDefinition? get presented => _presented;

  /// A screen came into view. Anything shown for another visit is removed.
  int beginVisit(String screenId) {
    _clearPresented();
    _currentVisit = ++_visitCounter;
    _currentScreen = screenId;
    _autoShownThisVisit = false;
    return _currentVisit!;
  }

  /// The screen is leaving; later results for [visitId] are ignored.
  void endVisit(int visitId) {
    if (_currentVisit != visitId) return;
    _clearPresented();
    _currentVisit = null;
    _currentScreen = null;
  }

  void _clearPresented() {
    if (_presented != null) presenter.dismiss();
    _presented = null;
    _presentedVisit = null;
  }

  bool _isCurrent(DiscoveryContext context) =>
      _currentVisit == context.visitId && _currentScreen == context.screenId;

  /// What would be shown now. Side-effect free.
  HintDecision peek(DiscoveryContext context) {
    if (!_isCurrent(context)) {
      return HintDecision.none({'*': SuppressionReason.staleVisit});
    }
    return policy.decide(
      catalog: catalog.all,
      context: context,
      state: repository.state,
      now: clock.now(),
      sessionIndex: repository.sessionIndex,
      sessionAutoShown: repository.sessionAutoShown,
      autoShownThisVisit: _autoShownThisVisit,
      presenterBusy: _requestInFlight || _presented != null,
    );
  }

  /// Decides and, if a hint qualifies, asks the presenter to show it.
  Future<HintRequestResult> request(DiscoveryContext context) async {
    final decision = peek(context);
    final hint = decision.hint;
    if (hint == null) return HintRequestResult(decision, presented: false);
    _requestInFlight = true;
    bool mounted;
    try {
      mounted = await presenter.present(hint);
    } catch (_) {
      mounted = false;
    } finally {
      _requestInFlight = false;
    }
    // The person may have left while the overlay was being built.
    if (!mounted || !_isCurrent(context)) {
      if (mounted) presenter.dismiss();
      return HintRequestResult(decision, presented: false);
    }
    _presented = hint;
    _presentedVisit = context.visitId;
    _autoShownThisVisit = true;
    await repository.recordShown(hint, automatic: true);
    return HintRequestResult(decision, presented: true);
  }

  /// The person answered the hint on screen.
  Future<void> respond(String hintId, HintResponse response) async {
    final visit = _presentedVisit ?? _currentVisit ?? 0;
    switch (response) {
      case HintResponse.acted:
      case HintResponse.acknowledged:
        await repository.complete(hintId);
      case HintResponse.later:
        final hint = catalog.byId(hintId);
        final record = repository.state.record(hintId);
        if (hint != null && policy.canSnooze(hint, record)) {
          await repository.snooze(hintId, visitId: visit);
        }
      case HintResponse.never:
        await repository.dismiss(hintId);
    }
    if (_presented?.id == hintId) _clearPresented();
  }

  @visibleForTesting
  int get currentVisit => _currentVisit ?? 0;
}
