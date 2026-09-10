import 'package:mybrev_flutter/constants/hora_items.dart';
import 'package:mybrev_flutter/models/day.dart';
import 'package:mybrev_flutter/services/liturgical_content_service.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/utils/liturgical_office.dart';

/// The temporary Stage 3 primary contract.
///
/// [LiturgicalContentService] already returns production-sorted options, so the
/// first usable item is primary for now. TODO: strengthen this adapter with the
/// future normative precedence resolver without leaking that policy into UI.
DayOption? resolvePrimaryLiturgicalOption(List<DayOption> sortedOptions) {
  return sortedOptions.firstOrNull;
}

class HoursLiturgicalSelection {
  const HoursLiturgicalSelection({
    required this.primary,
    required this.selected,
    required this.template,
    required this.sortedOptions,
  });

  final DayOption? primary;
  final DayOption? selected;
  final DayTemplate? template;
  final List<DayOption> sortedOptions;

  LiturgicalDay? get day => template?.day ?? selected?.day;
  String? get dayId => day?.id;
  int get alternativesCount => primary == null ? 0 : sortedOptions.length - 1;

  DayOption? get effectiveOption {
    final option = selected;
    final effectiveDay = day;
    if (option == null || effectiveDay == null || option.day == effectiveDay) {
      return option;
    }
    return DayOption(
      source: option.source,
      title: option.title,
      key: option.key,
      contextPeriodType: option.contextPeriodType,
      subtitle: option.subtitle,
      day: effectiveDay,
      order: option.order,
      disabled: option.disabled,
      templates: option.templates,
    );
  }
}

HoursLiturgicalSelection resolveHoursLiturgicalSelection(
  List<DayOption> sortedOptions, {
  String? selectedDayId,
}) {
  final primary = resolvePrimaryLiturgicalOption(sortedOptions);
  DayOption? selected = primary;
  DayTemplate? template;

  if (selectedDayId != null) {
    for (final option in sortedOptions) {
      if (option.disabled || option.day == null) continue;
      final matchingTemplate = option.templates
          .where((candidate) => candidate.id == selectedDayId)
          .firstOrNull;
      if (option.dayId == selectedDayId || matchingTemplate != null) {
        selected = option;
        template = matchingTemplate;
        break;
      }
    }
  }

  if (selected != null) {
    template ??= selected.templates
        .where((candidate) => candidate.id == selected!.dayId)
        .firstOrNull;
    template ??= selected.templates.firstOrNull;
  }

  return HoursLiturgicalSelection(
    primary: primary,
    selected: selected,
    template: template,
    sortedOptions: sortedOptions,
  );
}

String completoriumRecordIdForDay(LiturgicalDay? day) {
  if (day == null) return '';
  final period = (day.periodType ?? day.field('_periodType') ?? '').trim();
  final weekday =
      day.dayOfWeek ?? int.tryParse(day.field('_dayOfWeek') ?? '') ?? 0;
  return completoriumId(period, weekday, day);
}

bool cachedCompletoriumAvailable(LiturgicalDay? day) {
  final id = completoriumRecordIdForDay(day);
  if (id.isEmpty) return false;
  try {
    return HiveService.completoriumsBox.containsKey(id);
  } catch (_) {
    return false;
  }
}

bool isHourAvailable(
  LiturgicalDay? day,
  HoraItem hour, {
  bool? completoriumAvailable,
}) {
  if (day == null) return false;
  if (hour.type == 'completorium') {
    return completoriumAvailable ?? cachedCompletoriumAvailable(day);
  }
  return hour.checkFields.any((field) => (day.field(field) ?? '').isNotEmpty);
}
