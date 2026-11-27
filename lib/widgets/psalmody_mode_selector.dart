import 'package:flutter/material.dart';
import 'package:mybrev_flutter/models/psalmody_preferences.dart';
import 'package:mybrev_flutter/widgets/reader_icon_segments.dart';

/// The same compact control is used in settings and in the existing Aa panel.
class PsalmodyModeSelector extends StatelessWidget {
  const PsalmodyModeSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final PsalmodyMode value;
  final ValueChanged<PsalmodyMode> onChanged;

  @override
  Widget build(BuildContext context) => ReaderIconSegments<PsalmodyMode>(
    value: value,
    choices: PsalmodyMode.values,
    label: (mode) => mode.label,
    onChanged: onChanged,
    segmentKey: (mode) => ValueKey('psalmody-mode-${mode.name}'),
    content: (context, mode) => CustomPaint(
      size: const Size(40, 30),
      painter: _PsalmodyIcon(mode, IconTheme.of(context).color!),
    ),
  );
}

class _PsalmodyIcon extends CustomPainter {
  const _PsalmodyIcon(this.mode, this.color);
  final PsalmodyMode mode;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 6; i++) {
      final continuation = mode == PsalmodyMode.leftBreakIndent && i.isOdd;
      final shiftedStrophe =
          mode == PsalmodyMode.alternatingStanzas && (i == 2 || i == 3);
      final left = continuation || shiftedStrophe ? 9.0 : 2.0;
      final top = 3.0 + i * 4 + (i ~/ 2) * 2;
      final width = i.isOdd ? 23.0 : 28.0;
      canvas.drawLine(Offset(left, top), Offset(left + width, top), paint);
    }
  }

  @override
  bool shouldRepaint(_PsalmodyIcon oldDelegate) =>
      mode != oldDelegate.mode || color != oldDelegate.color;
}
