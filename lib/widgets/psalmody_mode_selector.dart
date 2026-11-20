import 'package:flutter/material.dart';
import 'package:mybrev_flutter/models/psalmody_preferences.dart';

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
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final shape =
        SegmentedButtonTheme.of(context).style?.shape?.resolve({}) ??
        const StadiumBorder();
    return Material(
      color: Colors.transparent,
      shape: shape.copyWith(side: BorderSide(color: cs.outlineVariant)),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          for (final mode in PsalmodyMode.values)
            Expanded(
              child: Semantics(
                key: ValueKey('psalmody-mode-${mode.name}'),
                label: mode.label,
                button: true,
                selected: value == mode,
                inMutuallyExclusiveGroup: true,
                onTap: () => onChanged(mode),
                child: Tooltip(
                  message: mode.label,
                  excludeFromSemantics: true,
                  child: Ink(
                    decoration: BoxDecoration(
                      color: value == mode
                          ? cs.primary.withValues(alpha: .12)
                          : Colors.transparent,
                      border: mode == PsalmodyMode.leftBreak
                          ? null
                          : Border(left: BorderSide(color: cs.outlineVariant)),
                    ),
                    child: InkWell(
                      excludeFromSemantics: true,
                      onTap: () => onChanged(mode),
                      child: SizedBox(
                        height: 48,
                        child: Center(
                          child: CustomPaint(
                            size: const Size(40, 30),
                            painter: _PsalmodyIcon(
                              mode,
                              value == mode ? cs.primary : cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
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
