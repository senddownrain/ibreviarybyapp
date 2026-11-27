import 'package:flutter/material.dart';
import 'package:mybrev_flutter/novena/novena_session.dart';

/// The days of a session: marked, today, unmarked past and upcoming ones.
class NovenaDayStrip extends StatelessWidget {
  const NovenaDayStrip({
    super.key,
    required this.session,
    required this.today,
    required this.onSelect,
    this.selected,
  });

  final NovenaSession session;
  final String today;
  final ValueChanged<int> onSelect;

  /// The day being read on the day page.
  final int? selected;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      // Nine days share one row also on a narrow phone; longer or narrower
      // strips wrap.
      final slot = (constraints.maxWidth / session.durationDays)
          .floorToDouble()
          .clamp(32.0, 40.0);
      return Wrap(
        runSpacing: 4,
        children: [
          for (var day = 1; day <= session.durationDays; day++)
            _DayDot(
              key: Key('novena-day-$day'),
              day: day,
              size: slot,
              state: session.dayState(day, today),
              selected: day == selected,
              onTap: () => onSelect(day),
            ),
        ],
      );
    },
  );
}

class _DayDot extends StatelessWidget {
  const _DayDot({
    super.key,
    required this.day,
    required this.size,
    required this.state,
    required this.selected,
    required this.onTap,
  });

  final int day;
  final double size;
  final NovenaDayState state;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (fill, ink, border, label) = switch (state) {
      NovenaDayState.completed => (
        cs.primary,
        cs.onPrimary,
        cs.primary,
        'адзначаны',
      ),
      NovenaDayState.today => (
        cs.tertiaryContainer,
        cs.onTertiaryContainer,
        cs.tertiary,
        'сённяшні, не адзначаны',
      ),
      NovenaDayState.missed => (
        Colors.transparent,
        cs.onSurface,
        cs.outline,
        'мінулы, не адзначаны',
      ),
      NovenaDayState.upcoming => (
        Colors.transparent,
        cs.onSurfaceVariant,
        Colors.transparent,
        'яшчэ не настаў',
      ),
    };
    return Semantics(
      button: true,
      selected: selected,
      label: 'Дзень $day, $label',
      excludeSemantics: true,
      onTap: onTap,
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        child: SizedBox(
          width: size,
          height: 40,
          child: Center(
            child: Container(
              width: size > 36 ? 32 : size - 3,
              height: size > 36 ? 32 : size - 3,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: fill,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? cs.onSurface : border,
                  width: selected || state == NovenaDayState.today ? 2 : 1,
                ),
              ),
              child: state == NovenaDayState.completed
                  ? Icon(Icons.check_rounded, size: 18, color: ink)
                  // A fixed circle: the number must not outgrow it.
                  : Text(
                      '$day',
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                        color: ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
