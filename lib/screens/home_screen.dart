import 'package:mybrev_flutter/providers/liturgical_day_presentation_provider.dart';
import 'package:mybrev_flutter/widgets/liturgical_day_header.dart';
import 'package:mybrev_flutter/widgets/liturgical_calendar_sheet.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:mybrev_flutter/constants/hora_items.dart';
import 'package:mybrev_flutter/constants/liturgical.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_navigation_sync_provider.dart';
import 'package:mybrev_flutter/theme/glass.dart';
import 'package:mybrev_flutter/utils/hours_liturgical_options.dart';
import 'package:mybrev_flutter/utils/liturgical_vespers.dart';
import 'package:mybrev_flutter/widgets/data_loading_notice.dart';
import 'package:mybrev_flutter/widgets/loading/app_load_states.dart';
import 'package:mybrev_flutter/widgets/horizontal_swipe_navigation.dart';
import 'package:mybrev_flutter/novena/ui/novena_suggestion_card.dart';
import 'package:mybrev_flutter/widgets/reader/reader_navigation.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = ref.watch(selectedDateProvider);
    final selection = ref.watch(hoursLiturgicalSelectionProvider);
    // The texts are on the device; only at launch they are decoded for a
    // moment. A date is a lookup, never a download.
    final ready = ref.watch(selectedDateReadyProvider);
    final loading = ready.isLoading && selection.selected == null;
    final seasonColor = ref.watch(liturgicalSeasonColorProvider);
    final navigationDirection = ref.watch(homeNavDirectionProvider);
    final dayNavigation = ref.read(liturgicalNavigationControllerProvider);
    final presentation = ref.watch(liturgicalDayPresentationProvider);
    final top = MediaQuery.paddingOf(context).top + 78;

    return Stack(
      children: [
        AmbientWash.hero(seasonColor: seasonColor),
        HorizontalSwipeNavigation(
          followDrag: true,
          onPrevious: date.isAfter(kCalendarFirstDate)
              ? () => dayNavigation.moveBy(-1)
              : null,
          onNext: date.isBefore(kCalendarLastDate)
              ? () => dayNavigation.moveBy(1)
              : null,
          child: LiturgicalDayTransition(
            direction: navigationDirection,
            child: CustomScrollView(
              key: ValueKey('hours-root-${DateUtils.dateOnly(date)}'),
              slivers: [
                SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          14,
                          top + 8,
                          14,
                          116 + MediaQuery.viewPaddingOf(context).bottom,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LiturgicalDayHeader(
                              sectionTitle: 'Літургія гадзінаў',
                              keyPrefix: 'hours',
                              presentation: presentation,
                              onToday: () =>
                                  dayNavigation.openDate(DateTime.now()),
                              onDateTap: () => showLiturgicalCalendarSheet(
                                context: context,
                                pickerRoute: '/hours/picker',
                              ),
                              onVariants: () => showLiturgicalCalendarSheet(
                                context: context,
                                pickerRoute: '/hours/picker',
                                focusVariants: true,
                              ),
                              onPrevious: () => dayNavigation.moveBy(-1),
                              onNext: () => dayNavigation.moveBy(1),
                            ),
                            const NovenaSuggestionSlot(),
                            const SizedBox(height: 22),
                            if (selection.selected != null) ...[
                              // Keep Hour rows at their original 22 dp inset.
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                child: _HoursList(
                                  date: date,
                                  selection: selection,
                                  color: seasonColor,
                                ),
                              ),
                            ] else if (loading) ...[
                              const _HoursLoading(),
                            ] else if (ready.hasError) ...[
                              AppErrorState(
                                title: 'Не ўдалося адкрыць тэксты',
                                message:
                                    'Тэксты праграмы не прачыталіся. '
                                    'Паспрабуйце яшчэ раз.',
                                onRetry: () => ref.invalidate(
                                  liturgicalContentReadyProvider,
                                ),
                              ),
                            ] else ...[
                              const _HoursMessage(
                                icon: PhosphorIconsRegular.calendarX,
                                title: 'Няма літургічнага дня',
                                body: 'Для гэтай даты тэксты адсутнічаюць.',
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HoursList extends StatelessWidget {
  const _HoursList({
    required this.date,
    required this.selection,
    required this.color,
  });

  final DateTime date;
  final HoursLiturgicalSelection selection;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final available = kHoraItems
        .where((hour) => isHourAvailable(selection.day, hour))
        .toList();
    if (available.isEmpty) {
      return const _HoursMessage(
        icon: PhosphorIconsRegular.clockCountdown,
        title: 'Няма даступных гадзін',
        body: 'Для выбранага варыянту няма змесціва літургіі гадзінаў.',
      );
    }
    final vespersTitle = vespersHourTitle(
      selection.effectiveOption?.ordo?.vespersType,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < available.length; index++) ...[
          _HourRow(
            hour: available[index],
            label: available[index].type == 'vespers' ? vespersTitle : null,
            color: color,
            onTap: () {
              final dayId = selection.dayId;
              final option = selection.effectiveOption;
              if (dayId == null || option == null) return;
              HapticFeedback.lightImpact();
              context.push(
                oraRouteForContext(
                  date: date,
                  dayId: dayId,
                  oraType: available[index].type,
                  diocese: selection.diocese,
                ),
              );
            },
          ),
          if (index != available.length - 1)
            const Divider(height: 1, indent: 54),
        ],
      ],
    );
  }
}

class _HourRow extends StatelessWidget {
  const _HourRow({
    required this.hour,
    this.label,
    required this.color,
    required this.onTap,
  });
  final HoraItem hour;
  final String? label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: '${label ?? hour.label}, ${hour.subtitle}',
      child: InkWell(
        key: Key('hours-hour-${hour.type}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 44,
                child: Center(
                  child: PhosphorIcon(
                    hour.icon,
                    size: 23,
                    color: _semanticInk(context, color),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label ?? hour.label,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    Text(
                      hour.subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              PhosphorIcon(
                PhosphorIconsRegular.caretRight,
                size: 17,
                color: cs.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HoursLoading extends StatelessWidget {
  const _HoursLoading();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 44),
    child: DataLoadingNotice(
      label: 'Адкрываем літургію дня',
      shape: LoadingShape.tiles,
    ),
  );
}

class _HoursMessage extends StatelessWidget {
  const _HoursMessage({
    required this.icon,
    required this.title,
    required this.body,
  });
  final PhosphorIconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Center(
        child: Column(
          children: [
            PhosphorIcon(icon, size: 38, color: cs.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

Color _semanticInk(BuildContext context, Color source) {
  final ink = Theme.of(context).colorScheme.onSurface;
  return Color.lerp(source, ink, 0.28)!;
}
