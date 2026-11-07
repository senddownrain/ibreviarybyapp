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
    final radius = BorderRadius.circular(10);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant),
        borderRadius: radius,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Material(
          color: Colors.transparent,
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
                              : Border(
                                  left: BorderSide(color: cs.outlineVariant),
                                ),
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
                                  value == mode
                                      ? cs.primary
                                      : cs.onSurfaceVariant,
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
        ),
      ),
    );
  }
}

/// Equal full-width touch targets on phones; a compact group on wider surfaces.
class PsalmodyControlRow extends StatelessWidget {
  const PsalmodyControlRow({
    super.key,
    required this.value,
    required this.onChanged,
    this.selectorKey,
  });
  final PsalmodyMode value;
  final ValueChanged<PsalmodyMode> onChanged;
  final Key? selectorKey;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final title = Text(
        'Псальмодыя',
        style: Theme.of(context).textTheme.titleMedium,
      );
      final selector = PsalmodyModeSelector(
        key: selectorKey,
        value: value,
        onChanged: onChanged,
      );
      if (constraints.maxWidth >= 560 &&
          MediaQuery.textScalerOf(context).scale(1) <= 1.5) {
        return Row(
          children: [
            Expanded(child: title),
            const SizedBox(width: 16),
            SizedBox(width: 240, child: selector),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [title, const SizedBox(height: 8), selector],
      );
    },
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
