import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/ordo/day_union.dart';
import 'package:mybrev_flutter/constants/liturgical.dart';
import 'package:mybrev_flutter/providers/liturgical_navigation_sync_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/services/liturgical_content_service.dart';
import 'package:mybrev_flutter/widgets/liturgical_selector_components.dart';
import 'package:mybrev_flutter/widgets/liturgical_calendar_sheet.dart';
import 'package:mybrev_flutter/analytics/local_analytics.dart'
    show analyticsFeature;

/// Standalone selector entry point. Calendar callers can keep their own API.
Future<void> showHoursOptionsSheet({
  required BuildContext context,
  required DateTime date,
  required Color color,
}) => showModalBottomSheet<void>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => HoursOptionsSheet(date: date, color: color),
);

/// Changes apply immediately to the Hours underneath; the footer returns to it.
class HoursOptionsSheet extends ConsumerWidget {
  const HoursOptionsSheet({
    super.key,
    required this.date,
    required this.color,
    this.embedded = false,
  });
  final DateTime date;
  final Color color;
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(hoursLiturgicalSelectionProvider);
    final selected = selection.selected;
    final options = selection.sortedOptions
        .where((option) => !option.disabled && option.day != null)
        .toList();
    final celebrations = options
        .where((o) => o.source != LiturgicalOptionSource.officeForDead)
        .toList();
    final offices = options
        .where((o) => o.source == LiturgicalOptionSource.officeForDead)
        .toList();
    final theme = Theme.of(context);
    void choose(DayOption option, [String? id]) {
      analyticsFeature('hour_option_select');
      ref
          .read(liturgicalNavigationControllerProvider)
          .selectDay(date, id ?? option.dayId!, diocese: option.contextDiocese);
    }

    Widget variants(DayOption option) => Padding(
      key: ValueKey('hours-variants-${option.key}'),
      padding: const EdgeInsets.only(left: 32, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const LiturgicalSelectorHeading('Варыянт літургіі гадзінаў'),
          RadioGroup<String>(
            groupValue: selection.template?.id ?? selection.dayId,
            onChanged: (id) {
              if (id != null) choose(option, id);
            },
            child: Column(
              children: [
                for (final template in option.templates)
                  RadioListTile<String>(
                    key: ValueKey('hours-template-${template.id}'),
                    value: template.id,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      template.label == 'Перыяд' ? 'З дня' : template.label,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    Widget optionRow(DayOption option) {
      final ordo = option.ordo;
      final colors = <String>{
        if (ordo != null) ordo.color,
        ...?ordo?.colorAlternatives,
      }.toList();
      return LiturgicalCelebrationChoice(
        key: ValueKey('hours-celebration-${option.key}'),
        value: option.key,
        title: option.title,
        subtitle: _metadata(option),
        selected: selected?.key == option.key,
        colors: colors,
      );
    }

    final optionsList = RadioGroup<String>(
      groupValue: selected?.key,
      onChanged: (key) {
        final option = options.where((o) => o.key == key).firstOrNull;
        if (option != null) choose(option);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const LiturgicalSelectorHeading('СВЯТКАВАННЕ'),
          for (final option in celebrations) ...[
            optionRow(option),
            if (selected?.key == option.key && option.templates.length > 1)
              variants(option),
          ],
          if (offices.isNotEmpty) ...[
            const Divider(height: 24),
            const LiturgicalSelectorHeading('ІНШЫЯ АФІЦЫІ'),
            for (final option in offices) ...[
              optionRow(option),
              if (selected?.key == option.key && option.templates.length > 1)
                variants(option),
            ],
          ],
        ],
      ),
    );
    if (embedded) return optionsList;

    return const LiturgicalCalendarSheet(focusVariants: true);
  }
}

String _metadata(DayOption option) => <String>{
  if (option.ordo case final ordo?)
    kRankLabels[ordo.rank] ?? ordoOfficeKindLabel(ordo.officeKind)
  else if (option.subtitle != null)
    option.subtitle!,
  if (option.placeLabel != null) option.placeLabel!,
  ...option.badges,
}.where((s) => s.isNotEmpty).join(' · ');
