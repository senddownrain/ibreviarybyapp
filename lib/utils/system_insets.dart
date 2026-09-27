import 'dart:math' as math;

import 'package:flutter/material.dart';

double systemBottomObstruction({
  required double visualInset,
  required double gestureInset,
}) => math.max(visualInset, gestureInset);

/// The window's bottom system/gesture obstruction, in logical pixels.
/// Descendant MediaQuery padding can include the application's floating dock.
double systemBottomInset(BuildContext context) {
  final view = View.of(context);
  final visual = view.viewPadding.bottom / view.devicePixelRatio;
  final gesture = view.systemGestureInsets.bottom / view.devicePixelRatio;
  if (Theme.of(context).platform == TargetPlatform.android) {
    return systemBottomObstruction(visualInset: visual, gestureInset: gesture);
  }

  // Preserve iOS placement when a route supplies additional local padding.
  final media = MediaQuery.of(context);
  return math.max(
    math.max(media.padding.bottom, media.viewPadding.bottom),
    math.max(math.max(media.systemGestureInsets.bottom, visual), gesture),
  );
}

/// Bottom offset inside a Scaffold body for a temporary floating control.
/// A resized body already ends at the IME top, so it only needs the visual gap.
double floatingOverlayBottom(BuildContext context, {required double gap}) =>
    (MediaQuery.viewInsetsOf(context).bottom > 0
        ? 0.0
        : systemBottomInset(context)) +
    gap;

/// Preserve the existing iOS palette placement pending its visual audit.
double floatingPaletteGap(BuildContext context) =>
    Theme.of(context).platform == TargetPlatform.android ? 16 : 8;

/// Extra scroll space beyond the reader's existing bottom padding.
/// The overlay offset and reader padding are measured in the same body space.
double floatingOverlayContentReserve({
  required double overlayHeight,
  required double overlayBottom,
  required double readerBottomPadding,
  required double contentGap,
}) => math.max(
  0,
  overlayHeight + overlayBottom + contentGap - readerBottomPadding,
);
