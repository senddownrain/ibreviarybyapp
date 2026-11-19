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
    this.borderlessSurfaceColor,
  });

  final DateTime date;
  final String keyPrefix;
  final VoidCallback onDateTap;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onToday;
  final Color? borderlessSurfaceColor;

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
    // Date navigation is contextual, not a raised floating toolbar: keep a
    // quiet, unified surface that stays below the celebration in hierarchy.
    return DecoratedBox(
      key: Key('$keyPrefix-date-control'),
      decoration: BoxDecoration(
        color:
            borderlessSurfaceColor ??
            cs.onSurface.withValues(alpha: dark ? 0.025 : 0.015),
        border: borderlessSurfaceColor == null
            ? Border.all(
                color: cs.onSurface.withValues(alpha: dark ? 0.09 : 0.08),
                width: 0.8,
              )
            : null,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(2),
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
                          // No second card inside the date capsule.
                          // Only the glyph is accented; the state layer
                          // appears on press/focus and stays inside the 48 dp
                          // touch target.
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            overlayColor: todayAccent.withValues(alpha: 0.14),
                            shape: const CircleBorder(),
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
