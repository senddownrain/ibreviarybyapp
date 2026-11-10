import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mybrev_flutter/constants/liturgical.dart';
import 'package:mybrev_flutter/widgets/liturgical_heading_text.dart';

/// A single date control shared by the Hours and Readings headers.
///
/// The Today action occupies a permanent slot, so the date never shifts when
/// the user navigates away from today. The icon is only visible and focusable
/// on another date.
class LiturgicalDateNavigationRow extends StatelessWidget {
  const LiturgicalDateNavigationRow({
    super.key,
    required this.date,
    required this.keyPrefix,
    required this.onDateTap,
    required this.onPrevious,
    required this.onNext,
    this.onToday,
  });

  final DateTime date;
  final String keyPrefix;
  final VoidCallback onDateTap;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isToday = DateUtils.isSameDay(date, DateTime.now());
    final dark = theme.brightness == Brightness.dark;
    final todayAccent = dark
        ? const Color(0xFF77C7F3)
        : const Color(0xFF176B9A);
    final fullDate = DateFormat('d MMMM y', 'be').format(date);
    final style = (theme.textTheme.titleMedium ?? const TextStyle()).copyWith(
      fontSize: 17,
      fontWeight: FontWeight.w600,
      color: cs.onSurface,
    );

    const target = BoxConstraints.tightFor(width: 48, height: 48);
    return DecoratedBox(
      key: Key('$keyPrefix-date-control'),
      decoration: BoxDecoration(
        color: cs.onSurface.withValues(alpha: dark ? 0.07 : 0.04),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.11)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            IconButton(
              key: Key('$keyPrefix-previous-day'),
              tooltip: 'Папярэдні дзень',
              constraints: target,
              padding: EdgeInsets.zero,
              color: cs.onSurfaceVariant,
              onPressed: date.isAfter(kCalendarFirstDate) ? onPrevious : null,
              icon: const Icon(Icons.chevron_left, size: 23),
            ),
            Expanded(
              child: TextButton(
                key: Key('$keyPrefix-date-action'),
                style: TextButton.styleFrom(
                  foregroundColor: cs.onSurface,
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: onDateTap,
                child: Semantics(
                  label: 'Выбраць дату: $fullDate',
                  excludeSemantics: true,
                  child: LiturgicalHeadingText(
                    fullDate,
                    style: style,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            if (onToday != null)
              SizedBox(
                width: 48,
                height: 48,
                child: AnimatedSwitcher(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  child: isToday
                      ? const SizedBox(key: ValueKey('today-slot-empty'))
                      : IconButton(
                          key: Key('$keyPrefix-today'),
                          tooltip: 'Вярнуцца на сёння',
                          constraints: target,
                          padding: EdgeInsets.zero,
                          color: todayAccent,
                          style: IconButton.styleFrom(
                            backgroundColor: todayAccent.withValues(alpha: 0.17),
                            side: BorderSide(
                              color: todayAccent.withValues(alpha: 0.42),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: onToday,
                          icon: const Icon(Icons.history, size: 21),
                        ),
                ),
              ),
            IconButton(
              key: Key('$keyPrefix-next-day'),
              tooltip: 'Наступны дзень',
              constraints: target,
              padding: EdgeInsets.zero,
              color: cs.onSurfaceVariant,
              onPressed: date.isBefore(kCalendarLastDate) ? onNext : null,
              icon: const Icon(Icons.chevron_right, size: 23),
            ),
          ],
        ),
      ),
    );
  }
}
