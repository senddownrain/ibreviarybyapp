import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:mybrev_flutter/constants/hora_items.dart';
import 'package:mybrev_flutter/constants/liturgical.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_navigation_sync_provider.dart';
import 'package:mybrev_flutter/services/liturgical_content_service.dart';
import 'package:mybrev_flutter/theme/glass.dart';
import 'package:mybrev_flutter/theme/platform_design.dart';
import 'package:mybrev_flutter/theme/reader.dart';
import 'package:mybrev_flutter/utils/hours_liturgical_options.dart';
import 'package:mybrev_flutter/utils/liturgical_theme.dart';
import 'package:mybrev_flutter/utils/liturgical_titles.dart';
import 'package:mybrev_flutter/widgets/ambient_date_picker.dart';
import 'package:mybrev_flutter/widgets/data_loading_notice.dart';
import 'package:mybrev_flutter/widgets/loading/app_load_states.dart';
import 'package:mybrev_flutter/widgets/horizontal_swipe_navigation.dart';
import 'package:mybrev_flutter/widgets/reader/reader_navigation.dart';
import 'package:mybrev_flutter/widgets/selection_option_card.dart';

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
    final today = DateUtils.dateOnly(DateTime.now());
    final isToday = DateUtils.isSameDay(date, today);
    final top = MediaQuery.paddingOf(context).top + 78;

    return Stack(
      children: [
        AmbientWash.hero(seasonColor: seasonColor),
        HorizontalSwipeNavigation(
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
                          22,
                          top + 8,
                          22,
                          116 + MediaQuery.viewPaddingOf(context).bottom,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Text(
                                    'Літургія гадзін',
                                    style: ReaderTheme.of(
                                      context,
                                    ).displayTitle(36),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _CalendarAction(
                                  color: seasonColor,
                                  onTap: () => context.push(
                                    Uri(
                                      path: '/hours/ordo',
                                      queryParameters: {
                                        'date': liturgicalDateKey(date),
                                      },
                                    ).toString(),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 22),
                            _DateHeader(
                              date: date,
                              color: seasonColor,
                              onTap: () => _showDateActions(context, ref, date),
                              onToday: isToday
                                  ? null
                                  : () => dayNavigation.openDate(today),
                            ),
                            const SizedBox(height: 28),
                            if (selection.selected case final selected?) ...[
                              _Celebration(
                                option: selected,
                                isManual:
                                    selected.key != selection.primary?.key,
                                color: seasonColor,
                              ),
                              if (selection.alternativesCount > 0) ...[
                                const SizedBox(height: 14),
                                TextButton.icon(
                                  key: const Key('hours-alternatives-control'),
                                  style: TextButton.styleFrom(
                                    minimumSize: const Size(48, 48),
                                    foregroundColor: _semanticInk(
                                      context,
                                      seasonColor,
                                    ),
                                  ),
                                  onPressed: () => _showAlternatives(
                                    context,
                                    date,
                                    seasonColor,
                                  ),
                                  icon: const PhosphorIcon(
                                    PhosphorIconsRegular.stack,
                                    size: 19,
                                  ),
                                  label: Text(
                                    'Іншыя літургічныя варыянты · '
                                    '${selection.alternativesCount}',
                                  ),
                                ),
                              ],
                              const SizedBox(height: 28),
                              _HoursList(
                                date: date,
                                selection: selection,
                                color: seasonColor,
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

/// Top-right entry to the liturgical calendar (Ordo) of the selected date:
/// a compact capsule, glyph + word, so it is found without guessing.
class _CalendarAction extends StatelessWidget {
  const _CalendarAction({required this.color, required this.onTap});

  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ink = _semanticInk(context, color);
    // The word stays while it fits beside the title; at a large text scale
    // on a narrow phone the capsule keeps only its glyph (same target).
    final media = MediaQuery.of(context);
    final showLabel =
        media.textScaler.scale(1) <= 1.3 && media.size.width >= 340;
    return Semantics(
      button: true,
      label: 'Каляндар: літургічны каляндар дня',
      excludeSemantics: true,
      child: Material(
        color: Color.alphaBlend(color.withValues(alpha: 0.14), cs.surface),
        shape: StadiumBorder(
          side: BorderSide(color: color.withValues(alpha: 0.35)),
        ),
        child: InkWell(
          key: const Key('hours-calendar-action'),
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PhosphorIcon(
                    PhosphorIconsRegular.calendarDots,
                    size: 19,
                    color: ink,
                  ),
                  if (showLabel) ...[
                    const SizedBox(width: 6),
                    Text(
                      'Каляндар',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DateHeader extends StatelessWidget {
  const _DateHeader({
    required this.date,
    required this.color,
    required this.onTap,
    this.onToday,
  });

  final DateTime date;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback? onToday;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: 'Дата ${DateFormat('d MMMM y', 'be').format(date)}. Змяніць дату',
      child: InkWell(
        key: const Key('hours-date-action'),
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _sentenceCase(DateFormat('EEEE', 'be').format(date)),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      DateFormat('d MMMM y', 'be').format(date),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (onToday != null)
                TextButton(
                  key: const Key('hours-today-action'),
                  onPressed: onToday,
                  child: const Text('Сёння'),
                )
              else
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: PhosphorIcon(
                    PhosphorIconsRegular.caretDown,
                    size: 18,
                    color: _semanticInk(context, color),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Celebration extends StatelessWidget {
  const _Celebration({
    required this.option,
    required this.isManual,
    required this.color,
  });

  final DayOption option;
  final bool isManual;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final semantic = _semanticInk(context, color);
    final placeLabel = option.day == null
        ? ''
        : liturgicalDayPlaceLabel(option.day!);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            key: const Key('hours-celebration-accent'),
            width: 4,
            margin: const EdgeInsets.symmetric(vertical: 3),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (option.subtitle case final subtitle?)
                  Text(
                    '${isManual ? 'ВЫБРАНЫ ВАРЫЯНТ · ' : ''}$subtitle'
                        .toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: semantic,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                const SizedBox(height: 5),
                Text(
                  option.title,
                  key: const Key('hours-celebration-title'),
                  style: ReaderTheme.of(context)
                      .displayTitle(29)
                      .copyWith(color: cs.onSurface, height: 1.18),
                ),
                if (option.badges.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    key: const Key('hours-celebration-badges'),
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final badge in option.badges)
                        Chip(
                          label: Text(badge),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                    ],
                  ),
                ],
                if (placeLabel.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          placeLabel,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
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
        body: 'Для выбранага варыянту няма змесціва Літургіі гадзін.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ЛІТУРГІЯ ГАДЗІН',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        for (var index = 0; index < available.length; index++) ...[
          _HourRow(
            hour: available[index],
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
    required this.color,
    required this.onTap,
  });
  final HoraItem hour;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: '${hour.label}, ${hour.subtitle}',
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
                      hour.label,
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

enum _DateAction { today, previous, next, calendar, advanced }

Future<void> _showDateActions(
  BuildContext context,
  WidgetRef ref,
  DateTime date,
) async {
  final color = ref.read(liturgicalSeasonColorProvider);
  final dayNavigation = ref.read(liturgicalNavigationControllerProvider);
  final action = await showModalBottomSheet<_DateAction>(
    context: context,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.fromLTRB(
        10,
        0,
        10,
        10 + MediaQuery.viewPaddingOf(sheetContext).bottom,
      ),
      child: AdaptiveChromeSurface(
        role: ChromeSurfaceRole.group,
        seasonColor: color,
        borderRadius: BorderRadius.circular(30),
        child: const Padding(
          padding: EdgeInsets.fromLTRB(12, 14, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DateActionTile(
                icon: PhosphorIconsRegular.calendarCheck,
                label: 'Сёння',
                action: _DateAction.today,
              ),
              _DateActionTile(
                icon: PhosphorIconsRegular.arrowLeft,
                label: 'Папярэдні дзень',
                action: _DateAction.previous,
              ),
              _DateActionTile(
                icon: PhosphorIconsRegular.arrowRight,
                label: 'Наступны дзень',
                action: _DateAction.next,
              ),
              Divider(),
              _DateActionTile(
                icon: PhosphorIconsRegular.calendarBlank,
                label: 'Выбраць дату',
                action: _DateAction.calendar,
              ),
              _DateActionTile(
                icon: PhosphorIconsRegular.magnifyingGlass,
                label: 'Знайсці літургічны дзень / свята',
                action: _DateAction.advanced,
              ),
            ],
          ),
        ),
      ),
    ),
  );
  if (action == null || !context.mounted) return;
  switch (action) {
    case _DateAction.today:
      dayNavigation.openDate(DateTime.now());
      return;
    case _DateAction.previous:
      final target = DateUtils.addDaysToDate(date, -1);
      if (!target.isBefore(kCalendarFirstDate)) {
        dayNavigation.openDate(target);
      }
      return;
    case _DateAction.next:
      final target = DateUtils.addDaysToDate(date, 1);
      if (!target.isAfter(kCalendarLastDate)) {
        dayNavigation.openDate(target);
      }
      return;
    case _DateAction.calendar:
      final picked = await showAmbientDatePicker(
        context: context,
        initialDate: date,
        seasonColor: color,
      );
      if (picked != null) {
        dayNavigation.openDate(picked);
      }
      return;
    case _DateAction.advanced:
      context.push('/hours/picker');
      return;
  }
}

class _DateActionTile extends StatelessWidget {
  const _DateActionTile({
    required this.icon,
    required this.label,
    required this.action,
  });
  final PhosphorIconData icon;
  final String label;
  final _DateAction action;

  @override
  Widget build(BuildContext context) => ListTile(
    minTileHeight: 52,
    leading: PhosphorIcon(icon, size: 21),
    title: Text(label),
    onTap: () => Navigator.of(context).pop(action),
  );
}

Future<void> _showAlternatives(
  BuildContext context,
  DateTime date,
  Color color,
) => showModalBottomSheet<void>(
  context: context,
  useRootNavigator: true,
  backgroundColor: Colors.transparent,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => _AlternativesSheet(date: date, color: color),
);

class _AlternativesSheet extends ConsumerWidget {
  const _AlternativesSheet({required this.date, required this.color});
  final DateTime date;
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(hoursLiturgicalSelectionProvider);
    final selected = selection.selected;
    final selectedColor = selected == null
        ? color
        : liturgicalColorForDay(
            selection.day,
            fallbackPeriodType: selected.contextPeriodType,
          );
    final groups = <String, List<DayOption>>{};
    for (final option in selection.sortedOptions) {
      if (!option.disabled && option.day != null) {
        groups.putIfAbsent(_groupKey(option), () => []).add(option);
      }
    }
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 720),
        child: AdaptiveChromeSurface(
          role: ChromeSurfaceRole.group,
          seasonColor: selectedColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Іншыя літургічныя варыянты',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Літургія',
                      onPressed: () => Navigator.pop(context),
                      icon: const PhosphorIcon(PhosphorIconsRegular.x),
                    ),
                  ],
                ),
              ),
              if (selected != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: _Celebration(
                    option: selected,
                    isManual: selected.key != selection.primary?.key,
                    color: selectedColor,
                  ),
                ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
                  children: [
                    for (final entry in groups.entries) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
                        child: Text(
                          _groupLabel(entry.key),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                        ),
                      ),
                      RadioGroup<String>(
                        groupValue: selected?.key,
                        onChanged: (key) {
                          final option = entry.value
                              .where((candidate) => candidate.key == key)
                              .firstOrNull;
                          if (option?.dayId case final dayId?) {
                            ref
                                .read(liturgicalNavigationControllerProvider)
                                .selectDay(
                                  date,
                                  dayId,
                                  diocese: option!.contextDiocese,
                                );
                          }
                        },
                        child: Column(
                          children: [
                            for (final option in entry.value)
                              RadioListTile<String>(
                                value: option.key,
                                title: Text(option.title),
                                subtitle: _optionSubtitle(option) == null
                                    ? null
                                    : Text(_optionSubtitle(option)!),
                              ),
                          ],
                        ),
                      ),
                    ],
                    if ((selected?.templates.length ?? 0) > 1) ...[
                      const Divider(height: 28),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          'ШАБЛОН СВЯТКАВАННЯ',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Выберыце набор агульных тэкстаў для гэтага святкавання.',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                            const SizedBox(height: 10),
                            for (final template in selected!.templates)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: SelectionOptionCard(
                                  key: ValueKey(
                                    'hours-template-${template.id}',
                                  ),
                                  title: template.label,
                                  leading: const Icon(
                                    Icons.auto_stories_outlined,
                                  ),
                                  accentColor: selectedColor,
                                  selected: template.id == selection.dayId,
                                  onTap: () => ref
                                      .read(
                                        liturgicalNavigationControllerProvider,
                                      )
                                      .selectDay(
                                        date,
                                        template.id,
                                        diocese: selected.contextDiocese,
                                      ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Літургія'),
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

String? _optionSubtitle(DayOption option) {
  final parts = [
    ?option.displaySubtitle,
    if (option.badges.isNotEmpty) option.badges.join(', '),
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

String _groupKey(DayOption option) {
  if (option.source == LiturgicalOptionSource.officeForDead) return 'office';
  if ((option.day?.field('_place') ?? '').trim().isNotEmpty) return 'local';
  return 'celebrations';
}

String _groupLabel(String group) => switch (group) {
  'local' => 'МЯСЦОВЫ КАЛЯНДАР',
  'office' => 'ІНШЫ АФІЦЫЙ',
  _ => 'СВЯТКАВАННІ ДНЯ',
};

Color _semanticInk(BuildContext context, Color source) {
  final ink = Theme.of(context).colorScheme.onSurface;
  return Color.lerp(source, ink, 0.28)!;
}

String _sentenceCase(String value) =>
    value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
