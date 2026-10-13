import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mybrev_flutter/constants/liturgical.dart';

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
  Widget build(BuildContext context) => Row(
    children: [
      IconButton(
        key: Key('$keyPrefix-previous-day'),
        tooltip: 'Папярэдні дзень',
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        onPressed: date.isAfter(kCalendarFirstDate) ? onPrevious : null,
        icon: const Icon(Icons.chevron_left, size: 22),
      ),
      Expanded(
        child: TextButton(
          key: Key('$keyPrefix-date-action'),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            minimumSize: const Size(48, 48),
          ),
          onPressed: onDateTap,
          child: Text(
            DateFormat('d MMMM y', 'be').format(date),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
      IconButton(
        key: Key('$keyPrefix-next-day'),
        tooltip: 'Наступны дзень',
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        onPressed: date.isBefore(kCalendarLastDate) ? onNext : null,
        icon: const Icon(Icons.chevron_right, size: 22),
      ),
    ],
  );
}
