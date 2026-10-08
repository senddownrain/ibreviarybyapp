import 'package:flutter/material.dart';
import 'package:mybrev_flutter/theme/reader.dart';

/// Uses the same scroll controller and picker callback as the Office header.
class HourSwitcherPill extends StatefulWidget {
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
    final top = overlay.localToGlobal(Offset.zero).dy;
    final visible =
        widget.controller.hasClients &&
        widget.controller.offset > 0 &&
        bottom <= top + widget.topInset;
    if (_visible != visible && mounted) setState(() => _visible = visible);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_scheduleMeasure);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: IgnorePointer(
      ignoring: !_visible,
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          // The space between Back and Aa already belongs to reader chrome.
          // Keep the pill there so no additional band covers document lines.
          padding: EdgeInsets.fromLTRB(72, widget.topInset - 44, 72, 0),
          child: AnimatedSlide(
            offset: _visible ? Offset.zero : const Offset(0, -.15),
            duration: const Duration(milliseconds: 180),
            child: AnimatedOpacity(
              opacity: _visible ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              child: Material(
                color: ReaderTheme.of(context).surface,
                shape: StadiumBorder(
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                elevation: 1,
                child: InkWell(
                  key: const Key('hour-switcher-pill'),
                  customBorder: const StadiumBorder(),
                  onTap: widget.onTap,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 340,
                      minHeight: 40,
                      maxHeight: 40,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              widget.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textScaler: MediaQuery.textScalerOf(
                                context,
                              ).clamp(maxScaleFactor: 1.4),
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
