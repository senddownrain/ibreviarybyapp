import 'dart:math' as math;

import 'package:flutter/material.dart';

double systemBottomObstruction({
  required double visualInset,
  required double gestureInset,
}) => math.max(visualInset, gestureInset);

/// The window's bottom system/gesture obstruction, in logical pixels.
/// Descendant MediaQuery padding can include the application's floating dock.
double systemBottomInset(BuildContext context) {
  // The window values alone do not subscribe this widget to metric changes.
  final media = MediaQuery.of(context);
  final view = View.of(context);
  final visual = view.viewPadding.bottom / view.devicePixelRatio;
  final gesture = view.systemGestureInsets.bottom / view.devicePixelRatio;
  if (Theme.of(context).platform == TargetPlatform.android) {
    return systemBottomObstruction(visualInset: visual, gestureInset: gesture);
  }

  // Preserve iOS placement when a route supplies additional local padding.
  return math.max(
    math.max(media.padding.bottom, media.viewPadding.bottom),
    math.max(math.max(media.systemGestureInsets.bottom, visual), gesture),
  );
}

/// Bottom offset inside a Scaffold body for a temporary floating control.
/// A nested Scaffold can consume MediaQuery.viewInsets before this widget
/// builds. Read the window inset to detect the keyboard in that case.
double floatingOverlayBottom(BuildContext context, {required double gap}) {
  // Keep a MediaQuery dependency so this offset rebuilds when the IME moves.
  final localInsets = MediaQuery.viewInsetsOf(context).bottom;
  if (View.of(context).viewInsets.bottom > 0 || localInsets > 0) return gap;
  return systemBottomInset(context) + gap;
}

/// Repositions a floating control when the window resizes for the keyboard.
/// Nested Scaffolds can remove the IME from their MediaQuery, so their children
/// do not necessarily rebuild when the raw window inset changes.
class FloatingOverlayPositioned extends StatefulWidget {
  const FloatingOverlayPositioned({
    super.key,
    required this.gap,
    required this.child,
    this.left = 16,
    this.right = 16,
  });

  final double gap;
  final double left;
  final double right;
  final Widget child;

  @override
  State<FloatingOverlayPositioned> createState() =>
      _FloatingOverlayPositionedState();
}

class _FloatingOverlayPositionedState extends State<FloatingOverlayPositioned>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeMetrics() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Positioned(
    left: widget.left,
    right: widget.right,
    bottom: floatingOverlayBottom(context, gap: widget.gap),
    child: widget.child,
  );
}

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
