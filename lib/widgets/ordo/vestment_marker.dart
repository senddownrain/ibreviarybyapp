import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mybrev_flutter/utils/liturgical_visual.dart';

/// Vestment colours of a date or an option, one visual vocabulary for the
/// Ordo month, the day detail and the picker.
///
/// One colour is a dot; several legal colours are equal segments of one
/// ring (never a gradient that invents a colour). White is drawn as its
/// white fabric with a neutral rim, so it stays visible on a light surface. The
/// colour is never the only carrier of meaning: callers give a label.
class VestmentMarker extends StatelessWidget {
  const VestmentMarker({
    super.key,
    required this.colors,
    this.size = 12,
    this.semanticLabel,
  });

  final List<String> colors;
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final label =
        semanticLabel ??
        colors.map(vestmentLabel).where((l) => l.isNotEmpty).join(', ');
    return Semantics(
      label: label.isEmpty ? null : 'Колер: $label',
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _VestmentPainter(
            colors,
            Theme.of(context).colorScheme.surface,
          ),
        ),
      ),
    );
  }
}

class _VestmentPainter extends CustomPainter {
  _VestmentPainter(this.colors, this.surface);
  final List<String> colors;
  final Color surface;

  @override
  void paint(Canvas canvas, Size size) {
    if (colors.isEmpty) return;
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final rim = math.max(1.0, radius * 0.12);
    final sweep = 2 * math.pi / colors.length;
    for (var i = 0; i < colors.length; i++) {
      final vestment =
          kVestmentColors[colors[i]] ?? kVestmentColors['viridis']!;
      final rect = Rect.fromCircle(center: center, radius: radius - rim / 2);
      final start = -math.pi / 2 + i * sweep;
      canvas.drawArc(
        rect,
        start,
        sweep,
        true,
        Paint()..color = vestment.swatch,
      );
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..color = vestment.ring
          ..style = PaintingStyle.stroke
          ..strokeWidth = rim,
      );
    }
    if (colors.length > 1) {
      // Thin separators keep the segments readable.
      final separator = Paint()
        ..color = surface.withValues(alpha: 0.9)
        ..strokeWidth = math.max(0.8, radius * 0.12);
      for (var i = 0; i < colors.length; i++) {
        final angle = -math.pi / 2 + i * sweep;
        canvas.drawLine(
          center,
          center + Offset(math.cos(angle), math.sin(angle)) * radius,
          separator,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_VestmentPainter old) =>
      old.colors.join() != colors.join() || old.surface != surface;
}

/// «Колер літургічнага адзення: Белы» with its marker.
class VestmentColorLine extends StatelessWidget {
  const VestmentColorLine({
    super.key,
    required this.colors,
    this.marianAccent = false,
  });

  final List<String> colors;
  final bool marianAccent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = colors.map(vestmentLabel).join(' або ');
    return Row(
      key: const Key('ordo-vestment-color'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: VestmentMarker(colors: colors, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Колер літургічнага адзення: '),
                TextSpan(
                  text: label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (marianAccent)
                  TextSpan(
                    text: ' · марыйнае свята',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
              ],
            ),
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
