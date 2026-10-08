import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/ordo/day_union.dart';
import 'package:mybrev_flutter/constants/liturgical.dart';
import 'package:mybrev_flutter/providers/liturgical_navigation_sync_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/services/liturgical_content_service.dart';

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
  backgroundColor: Colors.transparent,
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
      ref
          .read(liturgicalNavigationControllerProvider)
          .selectDay(date, id ?? option.dayId!, diocese: option.contextDiocese);
    }

    Widget variants(DayOption option) => Padding(
      key: ValueKey('hours-variants-${option.key}'),
      padding: EdgeInsets.only(
        left: celebrations.length > 1 ? 16 : 0,
        bottom: 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Label('ВАРЫЯНТ ЛІТУРГІІ ГАДЗІН'),
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
                      template.label,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    Widget optionRow(DayOption option) => RadioListTile<String>(
      key: ValueKey('hours-celebration-${option.key}'),
      value: option.key,
      contentPadding: EdgeInsets.zero,
      title: Text(
        option.title,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: _metadata(option).isEmpty
          ? null
          : Text(_metadata(option), style: theme.textTheme.bodyMedium),
    );

    final optionsList = RadioGroup<String>(
      groupValue: selected?.key,
      onChanged: (key) {
        final option = options.where((o) => o.key == key).firstOrNull;
        if (option != null) choose(option);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (celebrations.length > 1) const _Label('СВЯТКАВАННЕ'),
          for (final option in celebrations) ...[
            if (celebrations.length == 1 && selected?.key == option.key)
              Padding(
                key: const Key('hours-single-celebration'),
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_metadata(option).isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        _metadata(option),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              )
            else
              optionRow(option),
            if (selected?.key == option.key && option.templates.length > 1)
              variants(option),
          ],
          if (offices.isNotEmpty) ...[
            const Divider(height: 24),
            const _Label('ІНШЫЯ АФІЦЫІ'),
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

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 640,
          maxHeight: MediaQuery.sizeOf(context).height * .88,
        ),
        child: Material(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Іншыя літургічныя варыянты',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Закрыць',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  key: const Key('hours-options-scroll'),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: optionsList,
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Літургія'),
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

String _metadata(DayOption option) => <String>{
  if (option.ordo case final ordo?)
    kRankLabels[ordo.rank] ?? ordoOfficeKindLabel(ordo.officeKind)
  else if (option.subtitle != null)
    option.subtitle!,
  if (option.placeLabel != null) option.placeLabel!,
  ...option.badges,
}.where((s) => s.isNotEmpty).join(' · ');

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 4),
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}
