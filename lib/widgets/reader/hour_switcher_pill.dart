import 'package:flutter/material.dart';

/// Uses the same scroll controller and picker callback as the Office header.
class HourSwitcherPill extends StatefulWidget {
  static TextStyle titleStyle(BuildContext context) =>
      Theme.of(context).textTheme.titleMedium!.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        height: 1.15,
        color: Theme.of(context).colorScheme.onSurface,
      );

  /// Reserve enough shared top chrome for the unabridged, system-scaled label.
  static double chromeHeight(BuildContext context, String title) {
    final triggerWidth = (MediaQuery.sizeOf(context).width - 144).clamp(
      1.0,
      340.0,
    );
    final width = (triggerWidth - 28 - 22).clamp(1.0, double.infinity);
    final painter = TextPainter(
      text: TextSpan(text: title, style: titleStyle(context)),
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
    this.edgeProtectionBuilder,
  });

  final ScrollController controller;
  final GlobalKey titleAnchor;
  final String title;
  final VoidCallback onTap;
  final double topInset;

  /// Shares the measured title state with the top edge; no second scroll listener.
  final Widget Function(bool visible)? edgeProtectionBuilder;

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
        bottom <= widget.topInset - (_visible ? 0 : 6);
    if (_visible != visible && mounted) setState(() => _visible = visible);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_scheduleMeasure);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      if (widget.edgeProtectionBuilder != null)
        widget.edgeProtectionBuilder!(_visible),
      _buildTrigger(context),
    ],
  );

  Widget _buildTrigger(BuildContext context) => Positioned(
    top: MediaQuery.paddingOf(context).top + 8,
    left: 72,
    right: 72,
    child: IgnorePointer(
      ignoring: !_visible,
      child: ExcludeSemantics(
        excluding: !_visible,
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.zero,
            child: AnimatedSlide(
              offset: _visible ? Offset.zero : const Offset(0, -.15),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              child: AnimatedOpacity(
                key: const Key('hour-switcher-opacity'),
                opacity: _visible ? 1 : 0,
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 200),
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
                                style: HourSwitcherPill.titleStyle(context),
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
    ),
  );
}
