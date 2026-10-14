import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mybrev_flutter/constants/liturgical.dart';
import 'package:mybrev_flutter/widgets/liturgical_heading_text.dart';

/// The same date control for Hours, Readings and the informational Ordo day.
class LiturgicalDateNavigationRow extends StatelessWidget {
  const LiturgicalDateNavigationRow({
    super.key,
    required this.date,
    required this.keyPrefix,
    required this.onDateTap,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime date;
  final String keyPrefix;
  final VoidCallback onDateTap;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final style = (Theme.of(context).textTheme.titleMedium ?? const TextStyle())
        .copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurface,
        );
    final fullDate = DateFormat('d MMMM y', 'be').format(date);
    final previous = IconButton(
      key: Key('$keyPrefix-previous-day'),
      tooltip: 'Папярэдні дзень',
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      onPressed: date.isAfter(kCalendarFirstDate) ? onPrevious : null,
      icon: const Icon(Icons.chevron_left, size: 22),
    );
    final next = IconButton(
      key: Key('$keyPrefix-next-day'),
      tooltip: 'Наступны дзень',
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      onPressed: date.isBefore(kCalendarLastDate) ? onNext : null,
      icon: const Icon(Icons.chevron_right, size: 22),
    );
    Widget dateButton(String label) => TextButton(
      key: Key('$keyPrefix-date-action'),
      style: TextButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      onPressed: onDateTap,
      child: Semantics(
        label: fullDate,
        excludeSemantics: true,
        child: LiturgicalHeadingText(
          label,
          style: style,
          textAlign: TextAlign.center,
        ),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final measurement = TextPainter(
          text: TextSpan(
            text: DateFormat('MMMM', 'be').format(date),
            style: style,
          ),
          textScaler: MediaQuery.textScalerOf(context),
          textDirection: Directionality.of(context),
          maxLines: 1,
        )..layout();
        final fullWidthDate =
            measurement.width > constraints.maxWidth - 96 - 24;
        measurement.dispose();
        if (fullWidthDate) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              dateButton(DateFormat('d MMMM', 'be').format(date)),
              Row(
                children: [
                  previous,
                  Expanded(
                    child: TextButton(
                      onPressed: onDateTap,
                      child: Text('${date.year}', style: style),
                    ),
                  ),
                  next,
                ],
              ),
            ],
          );
        }
        return Row(
          children: [
            previous,
            Expanded(child: dateButton(fullDate)),
            next,
          ],
        );
      },
    );
  }
}
