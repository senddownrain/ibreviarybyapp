import 'package:flutter/foundation.dart' show immutable;

/// Reliability of the facts a screen reports. Only `ready` can show a hint.
enum DiscoveryDataStatus { loading, ready, error, unknown }

/// What the person is doing right now. Any `true` blocks automatic hints.
@immutable
class DiscoveryUiState {
  const DiscoveryUiState({
    this.scrolling = false,
    this.activeReading = false,
    this.dragging = false,
    this.keyboardVisible = false,
    this.modalOpen = false,
    this.transitioning = false,
  });

  /// Nothing is happening: the only state in which a hint may appear.
  static const calm = DiscoveryUiState();

  final bool scrolling;
  final bool activeReading;
  final bool dragging;
  final bool keyboardVisible;

  /// Another sheet, dialog or menu is open.
  final bool modalOpen;

  /// A route, tab or date change is in flight.
  final bool transitioning;

  bool get isCalm =>
      !scrolling &&
      !activeReading &&
      !dragging &&
      !keyboardVisible &&
      !modalOpen &&
      !transitioning;
}

/// Typed snapshot a screen hands to the engine.
@immutable
class DiscoveryContext {
  const DiscoveryContext({
    required this.screenId,
    required this.visitId,
    this.status = DiscoveryDataStatus.unknown,
    this.anchors = const {},
    this.facts = const {},
    this.ui = DiscoveryUiState.calm,
  });

  /// Not ready: nothing reliable to report.
  const DiscoveryContext.loading({
    required this.screenId,
    required this.visitId,
    this.anchors = const {},
    this.ui = DiscoveryUiState.calm,
  }) : status = DiscoveryDataStatus.loading,
       facts = const {};

  const DiscoveryContext.error({
    required this.screenId,
    required this.visitId,
    this.anchors = const {},
    this.ui = DiscoveryUiState.calm,
  }) : status = DiscoveryDataStatus.error,
       facts = const {};

  /// Screen identifier, e.g. `readings`; empty means unknown source.
  final String screenId;

  /// Token from `DiscoveryCoordinator.beginVisit`; stale tokens are ignored.
  final int visitId;
  final DiscoveryDataStatus status;

  /// Anchor IDs of widgets that are mounted, visible and tappable now.
  final Set<String> anchors;

  /// Reported facts by key; a missing key is an unknown fact.
  final Map<String, Object?> facts;
  final DiscoveryUiState ui;
}
