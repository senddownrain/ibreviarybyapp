import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Turns a deliberate horizontal swipe into previous/next navigation.
///
/// A distance threshold keeps small diagonal movements while vertically
/// scrolling from changing the current document. A quick flick may travel a
/// shorter distance and is accepted based on its velocity.
class HorizontalSwipeNavigation extends StatefulWidget {
  const HorizontalSwipeNavigation({
    super.key,
    required this.child,
    this.onPrevious,
    this.onNext,
  });

  final Widget child;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  State<HorizontalSwipeNavigation> createState() =>
      _HorizontalSwipeNavigationState();
}

class _HorizontalSwipeNavigationState extends State<HorizontalSwipeNavigation> {
  static const _minimumDistance = 72.0;
  static const _minimumVelocity = 500.0;

  double _distance = 0;

  void _onStart(DragStartDetails details) => _distance = 0;

  void _onUpdate(DragUpdateDetails details) {
    _distance += details.primaryDelta ?? 0;
  }

  void _onEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final isDeliberate =
        _distance.abs() >= _minimumDistance ||
        velocity.abs() >= _minimumVelocity;
    if (!isDeliberate) return;

    final direction = _distance.abs() >= _minimumDistance
        ? _distance
        : velocity;
    final callback = direction < 0 ? widget.onNext : widget.onPrevious;
    if (callback == null) return;
    HapticFeedback.selectionClick();
    callback();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    key: const Key('horizontal-swipe-navigation'),
    behavior: HitTestBehavior.translucent,
    onHorizontalDragStart: _onStart,
    onHorizontalDragUpdate: _onUpdate,
    onHorizontalDragEnd: _onEnd,
    child: widget.child,
  );
}
