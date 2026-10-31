import 'package:flutter/foundation.dart' show immutable;
import 'package:mybrev_flutter/discovery/discovery_state.dart';

/// What the screen looks like right now, as far as the tour cares.
@immutable
class TourScreenFacts {
  const TourScreenFacts({
    this.routeIsCurrent = true,
    this.atBranchRoot = true,
    this.dockVisible = true,
    this.keyboardVisible = false,
    this.scrolling = false,
    this.hintOnScreen = false,
    this.tourRunning = false,
  });

  /// The shell is the top route (no sheet, dialog, menu or pushed page).
  final bool routeIsCurrent;

  /// On the first screen of a section, not inside a reader.
  final bool atBranchRoot;
  final bool dockVisible;
  final bool keyboardVisible;
  final bool scrolling;
  final bool hintOnScreen;
  final bool tourRunning;

  /// Nothing is competing for the person's attention.
  bool get isCalm =>
      routeIsCurrent &&
      !keyboardVisible &&
      !scrolling &&
      !hintOnScreen &&
      !tourRunning;
}

enum TourOfferBlock {
  alreadyAnswered,
  hintsDisabled,
  notBranchRoot,
  noDock,
  busy,
}

/// Whether the quiet invitation may appear now. Null means yes.
TourOfferBlock? tourOfferBlock(DiscoveryState state, TourScreenFacts facts) {
  if (state.fromNewerSchema) return TourOfferBlock.alreadyAnswered;
  if (state.tourStatus != TourStatus.notOffered) {
    return TourOfferBlock.alreadyAnswered;
  }
  if (!state.hintsEnabled) return TourOfferBlock.hintsDisabled;
  if (!facts.atBranchRoot) return TourOfferBlock.notBranchRoot;
  if (!facts.dockVisible) return TourOfferBlock.noDock;
  if (!facts.isCalm) return TourOfferBlock.busy;
  return null;
}

/// Whether a person-initiated tour can start now. Hints being switched off or
/// an earlier answer never block it; only a busy screen does.
bool manualTourCanStart(TourScreenFacts facts) => facts.isCalm;
