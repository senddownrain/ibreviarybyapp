/// One date of the Ordo for several dioceses (port of the web Ordo union):
/// each diocese is resolved on its own; shared rows are shown once, the
/// differences carry diocesan badges. Suppressed candidates are never rows.
library;

import 'package:mybrev_flutter/ordo/engine.dart';
import 'package:mybrev_flutter/providers/diocese_provider.dart';
import 'package:mybrev_flutter/utils/liturgical_visual.dart';

class OrdoUnionRow {
  OrdoUnionRow(this.option, this.role, this.dioceses);

  final OrdoOption option;

  /// `primary`, `alternative` or `commemoration`.
  final String role;
  final List<String> dioceses;
  int _all = 1;

  bool get shared => dioceses.length == _all;
  List<String> get badges =>
      shared ? const [] : [for (final id in dioceses) kDioceseBadges[id] ?? id];
}

class OrdoDayUnion {
  OrdoDayUnion(this.days, this.rows);

  /// One resolved day per selected diocese (primary first).
  final List<OrdoDay> days;
  final List<OrdoUnionRow> rows;

  OrdoDay get first => days.first;

  /// The selected dioceses do not agree on this date.
  bool get differs => rows.any((row) => !row.shared);

  /// Legal vestment colours of every diocese, primary first (max 3).
  List<String> get colors {
    final colors = <String>[];
    for (final day in days) {
      for (final color in day.legalColors) {
        if (!colors.contains(color)) colors.add(color);
      }
    }
    return colors.take(3).toList();
  }

  OrdoDay dayOf(String diocese) =>
      days.firstWhere((day) => day.diocese == diocese, orElse: () => first);
}

OrdoDayUnion buildOrdoDayUnion(List<OrdoDay> days) {
  final rows = <String, OrdoUnionRow>{};
  void add(OrdoOption option, String role, String diocese) {
    final key = '${option.id}|${option.rank}|$role';
    (rows[key] ??= OrdoUnionRow(option, role, [])).dioceses.add(diocese);
  }

  for (final day in days) {
    add(day.primary, 'primary', day.diocese);
    for (final option in day.alternatives) {
      add(option, 'alternative', day.diocese);
    }
    for (final option in day.commemorations) {
      add(option, 'commemoration', day.diocese);
    }
  }
  const order = {'primary': 0, 'alternative': 1, 'commemoration': 2};
  final list = rows.values.toList()
    ..sort((a, b) => order[a.role]!.compareTo(order[b.role]!));
  for (final row in list) {
    row._all = days.length;
  }
  return OrdoDayUnion(days, list);
}

const _officeKindLabels = {
  'solemnity': 'Урачыстасць',
  'feast': 'Свята',
  'memorial': 'Успамін',
  'optional-memorial': 'Неабавязковы ўспамін',
  'sunday': 'Нядзеля',
  'weekday': 'Будзень',
  'christmas-octave': 'Дзень Актавы Нараджэння Пана',
  'easter-octave': 'Дзень Велікоднай актавы',
  'triduum': 'Пасхальнае Трыдуум',
  'all-souls': 'Успамін усіх памерлых вернікаў',
};

const _rankLabels = {
  'solemnitas': 'Урачыстасць',
  'festum': 'Свята',
  'memoria': 'Успамін',
  'memoria-ad-libitum': 'Неабавязковы ўспамін',
  'commemoratio-defunctorum': 'Успамін усіх памерлых вернікаў',
};

/// Rank label of a resolved option (engine rank, else its Office kind).
String ordoRankLabel(OrdoOption option) {
  if (option.isTemporal) {
    return _officeKindLabels[option.officeKind] ??
        _officeKindLabels[option.rankKind] ??
        '';
  }
  return _rankLabels[option.rank] ?? _officeKindLabels[option.officeKind] ?? '';
}

String ordoOfficeKindLabel(String kind) => _officeKindLabels[kind] ?? '';

/// «Белы» or «Фіялетавы або Чорны».
String vestmentColorsLabel(OrdoOption option) {
  final colors = [option.color, ...option.colorAlternatives];
  return colors.map(vestmentLabel).where((l) => l.isNotEmpty).join(' або ');
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

/// «6 кастрычніка» of an ISO date.
String dayMonthLabel(String iso) {
  final month = int.parse(iso.substring(5, 7));
  final day = int.parse(iso.substring(8, 10));
  return '$day ${_months[month - 1]}';
}

/// Short badges of an option: transfer, demotion, Belarus layer.
List<String> ordoOptionNotes(OrdoOption option) => [
  if (option.transferredFrom != null)
    'Перанесена з ${dayMonthLabel(option.transferredFrom!)}',
  if (option.movedFrom != null)
    'Перанесена з ${dayMonthLabel(option.movedFrom!)}',
  if (option.demotedFrom != null) 'Абодва ўспаміны неабавязковыя',
  if (option.layer == 'belarus') 'Уласны каляндар Беларусі',
];
