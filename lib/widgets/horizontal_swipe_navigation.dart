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

/// Shared transition for dated liturgical content and Bible chapters.
class LiturgicalDayTransition extends StatelessWidget {
  const LiturgicalDayTransition({
    super.key,
    required this.direction,
    required this.child,
  });

  final int direction;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final currentChild = child;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 240),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: Alignment.topCenter,
        children: [...previousChildren, ?currentChild],
      ),
      transitionBuilder: (transitionChild, animation) {
        final isIncoming = transitionChild.key == currentChild.key;
        final horizontalOffset = direction == 0
            ? 0.0
            : direction * (isIncoming ? 0.12 : -0.08);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset(horizontalOffset, 0),
              end: Offset.zero,
            ).animate(animation),
            child: transitionChild,
          ),
        );
      },
      child: currentChild,
    );
  }
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
