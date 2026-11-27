import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/novena/novena_providers.dart';
import 'package:mybrev_flutter/novena/novena_session.dart';
import 'package:mybrev_flutter/novena/novena_strings.dart';
import 'package:mybrev_flutter/novena/ui/novena_actions.dart';
import 'package:mybrev_flutter/novena/ui/novena_day_strip.dart';

/// Quiet surface shared by the tracker, the list and the suggestion.
class NovenaCard extends StatelessWidget {
  const NovenaCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: cs.outlineVariant, width: 0.7),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: SizedBox(width: double.infinity, child: child),
      ),
    );
  }
}

/// One active session: where it is, its days and the way to pray.
class NovenaSessionCard extends ConsumerWidget {
  const NovenaSessionCard({
    super.key,
    required this.session,
    this.title,
    this.footer,
  });

  final NovenaSession session;

  /// Shown in the list; the prayer page has the title already.
  final String? title;
  final Widget? footer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(novenaTodayProvider);
    final theme = Theme.of(context);
    final day = session.calendarDay(today);
    final overdue = session.isOverdue(today);
    final status = overdue
        ? 'Дні навэнны мінулі'
        : day < 1
        ? 'Пачатак ${novenaDate(session.startDate)}'
        : novenaDayOf(day, session.durationDays);
    final doneToday = day >= 1 && session.completedDays.contains(day);
    return NovenaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title case final title?) ...[
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],
                    Text(
                      status,
                      key: const Key('novena-status'),
                      style: title == null
                          ? theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            )
                          : theme.textTheme.bodyMedium,
                    ),
                    Text(
                      novenaDoneOf(
                        session.completedCount,
                        session.durationDays,
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              NovenaSessionMenu(session: session),
            ],
          ),
          const SizedBox(height: 8),
          NovenaDayStrip(
            session: session,
            today: today,
            onSelect: (day) => openNovenaDay(context, session, day),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const Key('novena-pray'),
              onPressed: () =>
                  openNovenaDay(context, session, session.dayToPray(today)),
              child: Text(
                overdue ? 'Працягнуць навэнну' : 'Памаліцца навэнну',
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              doneToday && !overdue
                  ? 'Малітва на сёння завершана. '
                        '${novenaRemaining(session.remainingCount)}'
                  : novenaRemaining(session.remainingCount),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          ?footer,
        ],
      ),
    );
  }
}
