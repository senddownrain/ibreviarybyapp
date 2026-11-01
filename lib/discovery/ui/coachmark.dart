import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/discovery/discovery_coordinator.dart';
import 'package:mybrev_flutter/discovery/hint_definition.dart';
import 'package:mybrev_flutter/discovery/ui/anchor_finder.dart';

/// What the screen that owns the current visit tells the presenter.
class HintSurface {
  HintSurface({
    required this.context,
    required this.anchors,
    required this.canSnooze,
    required this.onResponse,
    this.inline,
  });

  /// Context inside the screen; used to locate anchors and the overlay.
  final BuildContext context;

  /// Existing `Key`s of the real controls, by hint anchor id.
  final Map<String, List<Key>> anchors;
  final bool Function(HintDefinition hint) canSnooze;
  final void Function(HintDefinition hint, HintResponse response) onResponse;

  /// Set when the hint lives inside a panel instead of the overlay.
  final ValueNotifier<HintDefinition?>? inline;
}

/// The one presenter of the app: a small card next to the real control.
class CoachmarkPresenter implements HintPresenter {
  HintSurface? _surface;
  OverlayEntry? _entry;
  HintDefinition? _shown;

  void bind(HintSurface surface) => _surface = surface;

  void unbind(HintSurface surface) {
    if (!identical(_surface, surface)) return;
    dismiss();
    _surface = null;
  }

  Rect? _anchorRect(HintSurface surface, String anchorId) {
    Rect? union;
    for (final key in surface.anchors[anchorId] ?? const <Key>[]) {
      final rect = findAnchorRect(surface.context, key);
      if (rect == null) return null;
      union = union == null ? rect : union.expandToInclude(rect);
    }
    return union;
  }

  @override
  Future<bool> present(HintDefinition hint) async {
    final surface = _surface;
    if (surface == null || !surface.context.mounted) return false;
    dismiss();
    final inline = surface.inline;
    if (inline != null) {
      inline.value = hint;
      _shown = hint;
      return true;
    }
    final rect = _anchorRect(surface, hint.anchorId);
    final overlay = Overlay.maybeOf(surface.context, rootOverlay: true);
    if (rect == null || overlay == null) return false;
    final entry = OverlayEntry(
      builder: (_) => _AnchoredHint(
        key: const Key('discovery-hint'),
        anchor: rect,
        child: HintCard(
          key: const Key('discovery-hint-card'),
          hint: hint,
          canSnooze: surface.canSnooze(hint),
          onResponse: (response) => surface.onResponse(hint, response),
        ),
      ),
    );
    overlay.insert(entry);
    _entry = entry;
    _shown = hint;
    return true;
  }

  @override
  void dismiss() {
    _entry?.remove();
    _entry?.dispose();
    _entry = null;
    _surface?.inline?.value = null;
    _shown = null;
  }

  HintDefinition? get shown => _shown;

  /// Current screen rectangle of the shown hint's anchor.
  Rect? get shownAnchorRect {
    final surface = _surface;
    final hint = _shown;
    if (surface == null || hint == null || !surface.context.mounted) {
      return null;
    }
    return _anchorRect(surface, hint.anchorId);
  }
}

final coachmarkPresenterProvider = Provider<CoachmarkPresenter>((ref) {
  final presenter = CoachmarkPresenter();
  ref.onDispose(presenter.dismiss);
  return presenter;
});

class _AnchoredHint extends StatelessWidget {
  const _AnchoredHint({super.key, required this.anchor, required this.child});

  final Rect anchor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final fade = MediaQuery.disableAnimationsOf(context)
        ? child
        : TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 180),
            builder: (_, value, child) => Opacity(opacity: value, child: child),
            child: child,
          );
    return CustomSingleChildLayout(
      delegate: _AnchoredLayout(
        anchor: anchor,
        safe: MediaQuery.paddingOf(context),
      ),
      child: fade,
    );
  }
}

class _AnchoredLayout extends SingleChildLayoutDelegate {
  _AnchoredLayout({required this.anchor, required this.safe});

  final Rect anchor;
  final EdgeInsets safe;
  static const _gap = 10.0;
  static const _margin = 16.0;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(
        maxWidth: (constraints.maxWidth - 2 * _margin).clamp(0, 340),
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    var dx = anchor.center.dx - childSize.width / 2;
    dx = dx.clamp(_margin, size.width - _margin - childSize.width);
    final below = anchor.bottom + _gap;
    final fitsBelow = below + childSize.height <= size.height - safe.bottom - 8;
    final dy = fitsBelow ? below : anchor.top - _gap - childSize.height;
    return Offset(dx, dy.clamp(safe.top + 4, size.height));
  }

  @override
  bool shouldRelayout(_AnchoredLayout old) =>
      old.anchor != anchor || old.safe != safe;
}

/// The hint itself: Belarusian copy and the answers the engine understands.
class HintCard extends StatelessWidget {
  const HintCard({
    super.key,
    required this.hint,
    required this.canSnooze,
    required this.onResponse,
  });

  final HintDefinition hint;
  final bool canSnooze;
  final void Function(HintResponse response) onResponse;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final action = hint.actionLabelBe;
    return Semantics(
      container: true,
      liveRegion: true,
      label: hint.copyBe,
      child: Material(
        key: Key('discovery-hint-${hint.id}'),
        color: cs.surfaceContainerHigh,
        elevation: 6,
        shadowColor: Colors.black54,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hint.copyBe,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                alignment: WrapAlignment.end,
                children: [
                  if (action != null)
                    TextButton(
                      key: const Key('discovery-hint-show'),
                      onPressed: () => onResponse(HintResponse.acted),
                      child: Text(action),
                    )
                  else
                    TextButton(
                      key: const Key('discovery-hint-ack'),
                      onPressed: () => onResponse(HintResponse.acknowledged),
                      child: const Text('Зразумела'),
                    ),
                  if (action != null && canSnooze)
                    TextButton(
                      key: const Key('discovery-hint-later'),
                      onPressed: () => onResponse(HintResponse.later),
                      child: const Text('Пазней'),
                    ),
                  TextButton(
                    key: const Key('discovery-hint-never'),
                    onPressed: () => onResponse(HintResponse.never),
                    child: const Text('Не паказваць'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
