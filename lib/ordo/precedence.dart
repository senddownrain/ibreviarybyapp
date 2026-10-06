/// Table of Liturgical Days according to their order of precedence (GNLYC 59)
/// — port of mybrev `src/utils/ordo/precedence.js`.
///
/// ```text
///  1 Paschal Triduum
///  2 Christmas, Epiphany, Ascension, Pentecost; Sundays of Advent, Lent,
///    Easter; Ash Wednesday; Holy Week Mon–Thu; days of the Easter octave
///  3 Solemnities of the General Calendar; All Souls
///  4 Proper solemnities
///  5 Feasts of the Lord in the General Calendar
///  6 Sundays of Christmas and Ordinary Time
///  7 Feasts of the BVM and saints in the General Calendar
///  8 Proper feasts
///  9 Advent weekdays 17–24 Dec; Christmas octave; Lent weekdays
/// 10 Obligatory memorials of the General Calendar
/// 11 Proper obligatory memorials
/// 12 Optional memorials
/// 13 Other weekdays
/// ```
library;

import 'package:mybrev_flutter/ordo/definitions.dart';

const _rankKinds = {
  'solemnitas': 'solemnity',
  'festum': 'feast',
  'memoria': 'memorial',
  'memoria-ad-libitum': 'optional-memorial',
  'commemoratio-defunctorum': 'all-souls',
  'dies-liturgicus': 'liturgical-day',
};

String rankKind(Object? rank) => _rankKinds[rank] ?? 'optional-memorial';

bool isProperLayer(Json celebration) {
  final layer = celebration['layer'];
  return layer is String && layer.isNotEmpty && layer != 'universal';
}

int? _integer(Object? value) =>
    value is num && value == value.toInt() ? value.toInt() : null;

/// Row of the Table for a (non-temporal) celebration.
int celebrationPrecedence(Json celebration) {
  final pinned = _integer(celebration['precedence']);
  if (pinned != null) return pinned;
  final kind = rankKind(celebration['rank']);
  final proper = isProperLayer(celebration);
  if (kind == 'all-souls') return 3;
  if (kind == 'solemnity') return proper ? 4 : 3;
  if (kind == 'feast') {
    if (celebration['category'] == 'lord' && !proper) return 5;
    return proper ? 8 : 7;
  }
  if (kind == 'memorial') return proper ? 11 : 10;
  return 12;
}

const _categoryOrder = {
  'lord': 0,
  'season': 0,
  'mary': 1,
  'dead': 2,
  'dedication': 2,
  'saint': 3,
};
const _layerOrder = {
  'local': 0,
  'diocese': 1,
  'belarus': 2,
  'universal': 3,
  'override': 0,
};

/// Stable ordering: Table row, then Lord > BVM > saints, then the more
/// specific layer, then the original order.
int compareCandidates(Json a, Json b) {
  int n(Object? value) => (value as num?)?.toInt() ?? 0;
  var result = n(a['precedence']).compareTo(n(b['precedence']));
  if (result != 0) return result;
  result = (_categoryOrder[a['category']] ?? 4).compareTo(
    _categoryOrder[b['category']] ?? 4,
  );
  if (result != 0) return result;
  result = (_layerOrder[a['layer']] ?? 4).compareTo(
    _layerOrder[b['layer']] ?? 4,
  );
  if (result != 0) return result;
  return n(a['order']).compareTo(n(b['order']));
}

/// Rows 1–8: days that impede a transferred solemnity and exclude memorials.
bool isImpedingPrecedence(int precedence) => precedence <= 8;
