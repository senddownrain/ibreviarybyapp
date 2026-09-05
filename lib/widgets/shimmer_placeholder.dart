import 'package:flutter/material.dart';

/// Animated shimmer skeleton for loading states.
class ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerBox({
    super.key,
    this.width = double.infinity,
    this.height = 20,
    this.borderRadius = 10,
  });

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.06);
    final highlight = isDark
        ? Colors.white.withValues(alpha: 0.14)
        : Colors.black.withValues(alpha: 0.12);

    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: [
                (_anim.value - 0.3).clamp(0, 1),
                _anim.value.clamp(0, 1),
                (_anim.value + 0.3).clamp(0, 1),
              ],
              colors: [base, highlight, base],
            ),
          ),
        );
      },
    );
  }
}

/// A card-shaped shimmer skeleton that resembles a liturgical day card.
class DayCardShimmer extends StatelessWidget {
  const DayCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const ShimmerBox(width: 14, height: 14, borderRadius: 4),
                const SizedBox(width: 8),
                const ShimmerBox(width: 160, height: 12),
              ],
            ),
            const SizedBox(height: 16),
            const ShimmerBox(width: 120, height: 28, borderRadius: 6),
            const SizedBox(height: 12),
            Row(
              children: [
                const ShimmerBox(width: 80, height: 14),
                const Spacer(),
                const ShimmerBox(width: 80, height: 28, borderRadius: 14),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A list-tile shimmer skeleton resembling a hora/reading tile.
class TileShimmer extends StatelessWidget {
  const TileShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            ShimmerBox(width: 42, height: 42, borderRadius: 14),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  ShimmerBox(height: 14),
                  SizedBox(height: 8),
                  ShimmerBox(width: 120, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
