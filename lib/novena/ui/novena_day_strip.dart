import 'package:flutter/material.dart';
import 'package:mybrev_flutter/novena/novena_session.dart';
import 'package:mybrev_flutter/novena/pompeii.dart';

/// The days of a session: marked, today, unmarked past and upcoming ones.
class NovenaDayStrip extends StatelessWidget {
  const NovenaDayStrip({
    super.key,
    required this.session,
    required this.today,
    required this.onSelect,
    this.selected,
    this.cycleOfDay,
  });

  final NovenaSession session;
  final String today;
  final ValueChanged<int> onSelect;

  /// The day being read on the day page.
  final int? selected;

  /// A 54-day novena: show only the row of nine days holding this one.
  final int? cycleOfDay;

  Widget _dot(int day, double size) => _DayDot(
    key: Key('novena-day-$day'),
    day: day,
    size: size,
    state: session.dayState(day, today),
    selected: day == selected,
    onTap: () => onSelect(day),
  );

  /// The same circles, nine to a row (fewer on a very narrow screen), under
  /// the heading of their phase. Nothing scrolls sideways.
  Widget _phases(BuildContext context, BoxConstraints constraints) {
    final theme = Theme.of(context);
    final columns = (constraints.maxWidth / 32).floor().clamp(1, 9);
    final slot = (constraints.maxWidth / columns).floorToDouble().clamp(
      32.0,
      40.0,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final first in const [1, kPompeiiPhaseDays + 1]) ...[
          Padding(
            padding: EdgeInsets.only(top: first == 1 ? 0 : 8, bottom: 4),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      pompeiiPhaseTitle(first).toUpperCase(),
                      key: Key('novena-phase-$first'),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.tertiary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                Text(
                  '${session.completedDays.where((day) => day >= first && day < first + kPompeiiPhaseDays).length}'
                  '/$kPompeiiPhaseDays',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: columns * slot,
            child: Wrap(
              runSpacing: 4,
              children: [
                for (var day = first; day < first + kPompeiiPhaseDays; day++)
                  _dot(day, slot),
              ],
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final cycle = cycleOfDay;
      if (session.durationDays == kPompeiiDays && cycle == null) {
        return _phases(context, constraints);
      }
      final first = cycle == null ? 1 : (cycle - 1) ~/ 9 * 9 + 1;
      final length = cycle == null ? session.durationDays : 9;
      // Nine days share one row also on a narrow phone; longer or narrower
      // strips wrap.
      final slot = (constraints.maxWidth / length).floorToDouble().clamp(
        32.0,
        40.0,
      );
      return Wrap(
        runSpacing: 4,
        children: [
          for (var day = first; day < first + length; day++) _dot(day, slot),
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
