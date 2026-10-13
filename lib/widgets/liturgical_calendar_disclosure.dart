import 'package:flutter/material.dart';

/// A controlled disclosure; the owning selector retains its date and choices.
class LiturgicalCalendarDisclosure extends StatelessWidget {
  const LiturgicalCalendarDisclosure({
    super.key,
    required this.expanded,
    required this.onChanged,
    required this.calendar,
    required this.controlKey,
  });

  final bool expanded;
  final ValueChanged<bool> onChanged;
  final Widget calendar;
  final Key controlKey;

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 200);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          expanded: expanded,
          child: TextButton(
            key: controlKey,
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            onPressed: () => onChanged(!expanded),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    expanded ? 'Схаваць каляндар' : 'Паказаць каляндар',
                  ),
                ),
                const SizedBox(width: 12),
                AnimatedRotation(
                  turns: expanded ? .5 : 0,
                  duration: duration,
                  child: const Icon(Icons.keyboard_arrow_down, size: 20),
                ),
              ],
            ),
          ),
        ),
        ClipRect(
          child: AnimatedSize(
            duration: duration,
            alignment: Alignment.topCenter,
            child: expanded ? calendar : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}
