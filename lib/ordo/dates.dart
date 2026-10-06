/// Civil-date helpers of the Ordo engine (port of mybrev
/// `src/utils/ordo/dates.js`).
///
/// Dates are ISO strings (`YYYY-MM-DD`) — civil days, never instants. All
/// arithmetic is UTC, so no result depends on the device time zone or a
/// daylight-saving change.
library;

String _pad2(int value) => value.toString().padLeft(2, '0');

/// ISO date of (year, month, day); month/day overflow rolls over like
/// `Date.UTC` (month 13 → January of the next year).
String isoFromParts(int year, int month, int day) {
  final date = DateTime.utc(year, month, day);
  return '${date.year.toString().padLeft(4, '0')}-${_pad2(date.month)}-${_pad2(date.day)}';
}

/// ISO date of a civil [date] (local fields).
String isoOf(DateTime date) => isoFromParts(date.year, date.month, date.day);

/// `(year, month, day)` of an ISO date.
({int year, int month, int day}) parseIso(String iso) => (
  year: int.parse(iso.substring(0, 4)),
  month: int.parse(iso.substring(5, 7)),
  day: int.parse(iso.substring(8, 10)),
);

/// Local midnight of an ISO date (for the UI and the legacy helpers).
DateTime dateOfIso(String iso) {
  final p = parseIso(iso);
  return DateTime(p.year, p.month, p.day);
}

DateTime _utc(String iso) {
  final p = parseIso(iso);
  return DateTime.utc(p.year, p.month, p.day);
}

String addDays(String iso, int days) {
  final p = parseIso(iso);
  return isoFromParts(p.year, p.month, p.day + days);
}

/// Whole days from [b] to [a] (`a - b`).
int diffDays(String a, String b) => _utc(a).difference(_utc(b)).inDays;

/// ISO weekday: 1 = Monday … 7 = Sunday.
int isoWeekday(String iso) => _utc(iso).weekday;

/// MyBrev liturgical weekday: 1 = Sunday … 7 = Saturday.
int liturgicalDayOfWeek(String iso) => isoWeekday(iso) % 7 + 1;

bool isSundayIso(String iso) => isoWeekday(iso) == 7;

/// `DD.MM`, the key of fixed `days` / `readings` documents.
String fixedDateKey(String iso) {
  final p = parseIso(iso);
  return '${_pad2(p.day)}.${_pad2(p.month)}';
}

/// First Sunday strictly after [iso].
String nextSundayAfter(String iso) => addDays(iso, 7 - isoWeekday(iso) % 7);

/// The Sunday on or before [iso].
String sundayOnOrBefore(String iso) => addDays(iso, -(isoWeekday(iso) % 7));

List<String> daysOfYear(int year) {
  final result = <String>[];
  for (
    var iso = isoFromParts(year, 1, 1);
    iso.startsWith('${year.toString().padLeft(4, '0')}-');
    iso = addDays(iso, 1)
  ) {
    result.add(iso);
  }
  return result;
}

/// Stable sort (JavaScript `Array.prototype.sort` is stable; Dart's is not).
void stableSort<T>(List<T> list, int Function(T a, T b) compare) {
  final indexed = [for (var i = 0; i < list.length; i++) (i, list[i])];
  indexed.sort((a, b) {
    final result = compare(a.$2, b.$2);
    return result != 0 ? result : a.$1.compareTo(b.$1);
  });
  for (var i = 0; i < indexed.length; i++) {
    list[i] = indexed[i].$2;
  }
}

const _belarusianAlphabet = 'абвгґдеёжзіийклмнопрстуўфхцчшщъыьэюя';

/// Neutral title order of co-equal choices (approximates
/// `localeCompare(…, 'be')`: Belarusian alphabet, case and punctuation
/// ignored at the first level).
int compareBelarusian(String a, String b) {
  List<int> key(String value) => [
    for (final rune in value.toLowerCase().runes)
      if (RegExp(
        r'[\p{L}\p{N}]',
        unicode: true,
      ).hasMatch(String.fromCharCode(rune)))
        switch (_belarusianAlphabet.indexOf(String.fromCharCode(rune))) {
          -1 => 1000 + rune,
          final index => index,
        },
  ];
  final left = key(a);
  final right = key(b);
  for (var i = 0; i < left.length && i < right.length; i++) {
    if (left[i] != right[i]) return left[i].compareTo(right[i]);
  }
  final byLength = left.length.compareTo(right.length);
  return byLength != 0 ? byLength : a.compareTo(b);
}
