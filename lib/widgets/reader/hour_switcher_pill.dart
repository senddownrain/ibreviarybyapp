import 'package:flutter/material.dart';

/// Uses the same scroll controller and picker callback as the Office header.
class HourSwitcherPill extends StatefulWidget {
  /// Reserve enough shared top chrome for the unabridged, system-scaled label.
  static double chromeHeight(BuildContext context, String title) {
    final triggerWidth = (MediaQuery.sizeOf(context).width - 144).clamp(
      1.0,
      340.0,
    );
    final width = (triggerWidth - 28 - 22).clamp(1.0, double.infinity);
    final painter = TextPainter(
      text: TextSpan(
        text: title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(height: 1.1),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: width);
    final height = (painter.height + 12).clamp(48.0, double.infinity);
    painter.dispose();
    return height;
  }

  const HourSwitcherPill({
    super.key,
    required this.controller,
    required this.titleAnchor,
    required this.title,
    required this.onTap,
    required this.topInset,
  });

  final ScrollController controller;
  final GlobalKey titleAnchor;
  final String title;
  final VoidCallback onTap;
  final double topInset;

  @override
  State<HourSwitcherPill> createState() => _HourSwitcherPillState();
}

class _HourSwitcherPillState extends State<HourSwitcherPill> {
  bool _visible = false;
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_scheduleMeasure);
    _scheduleMeasure();
  }

  @override
  void didUpdateWidget(HourSwitcherPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_scheduleMeasure);
      widget.controller.addListener(_scheduleMeasure);
    }
    _scheduleMeasure();
  }

  void _scheduleMeasure() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) _measure();
    });
  }

  void _measure() {
    final anchor = widget.titleAnchor.currentContext?.findRenderObject();
    final overlay = context.findRenderObject();
    if (anchor is! RenderBox || overlay is! RenderBox || !anchor.hasSize) {
      return;
    }
    final bottom = anchor.localToGlobal(Offset(0, anchor.size.height)).dy;
    final visible =
        widget.controller.hasClients &&
        widget.controller.offset > 0 &&
        bottom <= widget.topInset;
    if (_visible != visible && mounted) setState(() => _visible = visible);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_scheduleMeasure);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Positioned(
    top: MediaQuery.paddingOf(context).top + 8,
    left: 72,
    right: 72,
    child: IgnorePointer(
      ignoring: !_visible,
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.zero,
          child: AnimatedSlide(
            offset: _visible ? Offset.zero : const Offset(0, -.15),
            duration: const Duration(milliseconds: 180),
            child: AnimatedOpacity(
              opacity: _visible ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  key: const Key('hour-switcher-pill'),
                  borderRadius: BorderRadius.circular(12),
                  onTap: widget.onTap,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 340,
                      minHeight: 48,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              widget.title,
                              textAlign: TextAlign.center,
                              style: Theme.of(
                                context,
                              ).textTheme.labelLarge?.copyWith(height: 1.1),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
