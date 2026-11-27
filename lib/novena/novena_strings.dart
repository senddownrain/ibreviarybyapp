/// Belarusian forms used by the novena screens.
library;

import 'package:mybrev_flutter/ordo/dates.dart';

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

/// «12 сакавіка».
String novenaDate(String iso) {
  final date = parseIso(iso);
  return '${date.day} ${_months[date.month - 1]}';
}

bool _one(int n) => n % 10 == 1 && n % 100 != 11;

/// 1 дзень, 2 дні, 5 дзён, 21 дзень.
String daysWord(int n) {
  if (_one(n)) return 'дзень';
  final few = n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 12 || n % 100 > 14);
  return few ? 'дні' : 'дзён';
}

String novenaDayOf(int day, int total) => 'Дзень $day з $total';

String novenaRemaining(int n) =>
    '${_one(n) ? 'Застаўся' : 'Засталося'} $n ${daysWord(n)}';

String novenaDoneOf(int done, int total) =>
    'Завершана $done з $total ${_one(total) ? 'дня' : 'дзён'}';
