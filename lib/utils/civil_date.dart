/// Civil-date arithmetic for liturgical dates.
///
/// A liturgical date is a calendar day, not an instant. `add(Duration(days:
/// 1))` adds 24 hours and lands on the wrong day across a daylight-saving
/// change (EU: late March, late October); `difference().inDays` loses a day
/// the same way. These helpers count calendar days in any time zone.
library;

/// The calendar day of [date] (midnight, local).
DateTime civilDay(DateTime date) => DateTime(date.year, date.month, date.day);

/// [date] moved by [days] calendar days (midnight, local).
DateTime addCivilDays(DateTime date, int days) =>
    DateTime(date.year, date.month, date.day + days);

/// Calendar days from [from] to [to] (negative when [to] is earlier).
int civilDaysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;
