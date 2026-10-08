import 'package:mybrev_flutter/constants/hora_items.dart';
import 'package:mybrev_flutter/models/day.dart';
import 'package:mybrev_flutter/services/liturgical_content_service.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/utils/liturgical_office.dart';

/// The engine's PRIMARY of the primary diocese (the options are already
/// united and ordered; no priority logic lives here).
DayOption? resolvePrimaryLiturgicalOption(
  List<DayOption> options, {
  String? primaryDiocese,
}) =>
    options
        .where(
          (option) =>
              option.ordo?.role == 'primary' &&
              (primaryDiocese == null ||
                  option.contextDiocese == null ||
                  option.contextDiocese == primaryDiocese),
        )
        .firstOrNull ??
    options.firstOrNull;

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

  /// The diocese the selected Office belongs to (route context).
  String? get diocese => selected?.contextDiocese ?? selected?.ordo?.diocese;
  int get alternativesCount => primary == null ? 0 : sortedOptions.length - 1;

  bool get hasCelebrationAlternatives => alternativesCount > 0;
  bool get hasOfficeTemplates => (selected?.templates.length ?? 0) > 1;
  bool get hasLiturgicalChoices =>
      hasCelebrationAlternatives || hasOfficeTemplates;

  DayOption? get effectiveOption {
    final option = selected;
    final effectiveDay = day;
    if (option == null || effectiveDay == null || option.day == effectiveDay) {
      return option;
    }
    return option.copyWith(day: effectiveDay);
  }
}

HoursLiturgicalSelection resolveHoursLiturgicalSelection(
  List<DayOption> sortedOptions, {
  String? selectedDayId,
  String? selectedDiocese,
  String? primaryDiocese,
}) {
  final primary = resolvePrimaryLiturgicalOption(
    sortedOptions,
    primaryDiocese: primaryDiocese,
  );
  DayOption? selected = primary;
  DayTemplate? template;

  if (selectedDayId != null) {
    bool inDiocese(DayOption option) =>
        selectedDiocese == null ||
        option.dioceses.isEmpty ||
        option.dioceses.contains(selectedDiocese);
    final candidates = [
      ...sortedOptions.where(
        (o) => o.contextDiocese == selectedDiocese && selectedDiocese != null,
      ),
      ...sortedOptions,
    ];
    for (final option in candidates) {
      if (option.disabled || option.day == null || !inDiocese(option)) {
        continue;
      }
      final matchingTemplate = option.templates
          .where((candidate) => candidate.answers(selectedDayId))
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

/// The picker and the document footer share both ordering and availability.
HoraItem? nextAvailableHour(
  LiturgicalDay day,
  String currentType, {
  bool? completoriumAvailable,
}) {
  final index = kHoraItems.indexWhere((hour) => hour.type == currentType);
  if (index < 0) return null;
  return kHoraItems
      .skip(index + 1)
      .where(
        (hour) => isHourAvailable(
          day,
          hour,
          completoriumAvailable: completoriumAvailable,
        ),
      )
      .firstOrNull;
}
