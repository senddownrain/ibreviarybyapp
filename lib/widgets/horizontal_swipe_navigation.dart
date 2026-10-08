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
    this.followDrag = false,
  });

  final Widget child;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final bool followDrag;

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
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 300),
      reverseDuration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 240),
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
  double _offset = 0;
  bool _dragging = false;

  void _onStart(DragStartDetails details) {
    _distance = 0;
    _dragging = true;
  }

  void _onUpdate(DragUpdateDetails details) {
    _distance += details.primaryDelta ?? 0;
    if (widget.followDrag && !MediaQuery.disableAnimationsOf(context)) {
      final allowed = _distance < 0
          ? widget.onNext != null
          : widget.onPrevious != null;
      setState(() => _offset = allowed ? (_distance * .25).clamp(-36, 36) : 0);
    }
  }

  void _resetDrag() => setState(() {
    _dragging = false;
    _offset = 0;
  });

  void _onEnd(DragEndDetails details) {
    _resetDrag();
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
    onHorizontalDragCancel: _resetDrag,
    child: widget.followDrag
        ? AnimatedContainer(
            duration: _dragging || MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(_offset, 0, 0),
            child: widget.child,
          )
        : widget.child,
  );
}
