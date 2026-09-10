import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Bottom clearance for controls that float over a reader.
///
/// Some Android edge-to-edge combinations (notably three-button navigation on
/// Samsung devices) report a zero bottom viewPadding to nested Scaffolds. The
/// platform fallback keeps critical controls above that navigation bar.
double readerSystemBottomClearance(BuildContext context) {
  final media = MediaQuery.of(context);
  final view = View.of(context);
  final directViewPadding = view.viewPadding.bottom / view.devicePixelRatio;
  final reported = math.max(
    math.max(media.padding.bottom, media.viewPadding.bottom),
    math.max(media.systemGestureInsets.bottom, directViewPadding),
  );
  final platformFallback = Theme.of(context).platform == TargetPlatform.android
      ? 56.0
      : 0.0;
  return math.max(reported, platformFallback);
}
