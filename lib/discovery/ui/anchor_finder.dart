import 'package:flutter/material.dart';

/// Finds mounted widgets by the `Key` they already carry, so a hint can point
/// at a real control without changing it.
Element? findAnchorElement(BuildContext root, Key key) {
  Element? found;
  void visit(Element element) {
    if (found != null) return;
    if (element.widget.key == key) {
      found = element;
      return;
    }
    element.visitChildren(visit);
  }

  (root as Element).visitChildren(visit);
  return found;
}

/// Screen rectangle of the anchor, or null when it is not laid out.
Rect? findAnchorRect(BuildContext root, Key key) {
  final element = findAnchorElement(root, key);
  final box = element?.renderObject;
  if (box is! RenderBox || !box.attached || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}

/// Runs the tap handler of the control that carries [key].
bool invokeAnchor(BuildContext root, Key key) {
  final widget = findAnchorElement(root, key)?.widget;
  final VoidCallback? onPressed = switch (widget) {
    ButtonStyleButton() => widget.onPressed,
    IconButton() => widget.onPressed,
    _ => null,
  };
  if (onPressed == null) return false;
  onPressed();
  return true;
}
