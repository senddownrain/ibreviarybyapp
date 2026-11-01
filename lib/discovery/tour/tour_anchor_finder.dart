import 'package:flutter/material.dart';
import 'package:mybrev_flutter/discovery/tour/tour_steps.dart';

/// Screen rectangles of the mounted, visible widgets whose `Key('…')` matches
/// [anchor], in tree order. Widgets of a section that is switched away
/// (`Offstage`) or hidden (`Visibility`) are ignored.
List<Rect> findTourAnchorRects(BuildContext root, TourAnchor anchor) {
  final found = <Rect>[];
  void visit(Element element) {
    final key = element.widget.key;
    if (key is ValueKey<String> && anchor.test(key.value)) {
      final rect = _visibleRect(element);
      if (rect != null) found.add(rect);
      return;
    }
    element.visitChildren(visit);
  }

  (root as Element).visitChildren(visit);
  return found;
}

Rect? _visibleRect(Element element) {
  final box = element.renderObject;
  if (box is! RenderBox || !box.attached || !box.hasSize) return null;
  var visible = true;
  element.visitAncestorElements((ancestor) {
    final widget = ancestor.widget;
    if (widget is Offstage && widget.offstage) visible = false;
    if (widget is Visibility && !widget.visible) visible = false;
    return visible;
  });
  if (!visible || box.size.isEmpty) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}

/// Rectangle for one step: the first matcher with a hit, or the union of all
/// hits when the step highlights several controls together.
Rect? resolveStepRect(BuildContext root, TourStep step) {
  Rect? union;
  for (final anchor in step.anchors) {
    final rects = findTourAnchorRects(root, anchor);
    if (rects.isEmpty) continue;
    if (!step.unionAll) return rects.first;
    for (final rect in rects) {
      union = union == null ? rect : union.expandToInclude(rect);
    }
  }
  return union;
}
