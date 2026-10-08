import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/constants/liturgical.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/services/liturgical_content_service.dart';
import 'package:mybrev_flutter/utils/hours_liturgical_options.dart';
import 'package:mybrev_flutter/utils/liturgical_theme.dart';
import 'package:mybrev_flutter/utils/liturgical_titles.dart';

/// Presentation of the selected celebration, independent of its reading set.
final liturgicalDayPresentationProvider = Provider((ref) {
  return LiturgicalDayPresentation.fromSelection(
    ref.watch(selectedDateProvider),
    ref.watch(hoursLiturgicalSelectionProvider),
  );
});

class LiturgicalDayPresentation {
  const LiturgicalDayPresentation({
    required this.date,
    required this.title,
    required this.rank,
    required this.accent,
    this.variantCount = 0,
    this.place = '',
    this.badges = const [],
  });

  factory LiturgicalDayPresentation.fromSelection(
    DateTime date,
    HoursLiturgicalSelection selection,
  ) {
    final option = selection.selected;
    final weekday = weekdayLabelMap[date.weekday % 7 + 1]!;
    final title = (option?.title ?? 'Літургічны дзень').replaceFirst(
      RegExp(',\\s*${RegExp.escape(weekday)}\$', caseSensitive: false),
      '',
    );
    return LiturgicalDayPresentation(
      date: date,
      title: title,
      rank: option == null ? '' : liturgicalOptionRank(option),
      accent: liturgicalColorForDay(
        selection.day,
        fallbackPeriodType: option?.contextPeriodType ?? 'ordinary',
      ),
      // Assemblies are choices too, but do not duplicate the celebration.
      variantCount: selection.sortedOptions
          .where((o) => !o.disabled && o.day != null)
          .fold(
            0,
            (count, o) =>
                count + (o.templates.isEmpty ? 1 : o.templates.length),
          ),
      place: option?.day == null ? '' : liturgicalDayPlaceLabel(option!.day!),
      badges: option?.badges ?? const [],
    );
  }

  final DateTime date;
  final String title;
  final String rank;
  final Color accent;
  final int variantCount;
  final String place;
  final List<String> badges;
  String get dateLabel => '${date.day} ${_months[date.month - 1]} ${date.year}';
  String get weekday => weekdayLabelMap[date.weekday % 7 + 1]!;

  String get metadata => [
    weekday,
    if (rank.toLowerCase() != weekday.toLowerCase()) rank.toLowerCase(),
  ].where((s) => s.isNotEmpty).join(' · ');
}

const _months = [
  'студзеня',
  'лютага',
  'сакавіка',
  'красавіка',
  'мая',
  'чэрвеня',
  'ліпеня',
  'жніўня',
  'верасня',
  'кастрычніка',
  'лістапада',
  'снежня',
];

String liturgicalOptionRank(DayOption option) {
  final rank = option.ordo?.rank ?? option.day?.rank;
  return kRankLabels[rank] ??
      switch (rank) {
        'feria' => 'Будні дзень',
        'dominica' => 'Нядзеля',
        _ =>
          option.source == LiturgicalOptionSource.period
              ? 'Будні дзень'
              : (option.subtitle?.split(' · ').first ?? ''),
      };
}
