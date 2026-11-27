/// A local novena session and its progress (shared contract §6). Pure.
///
/// Sessions never leave the device: no server, analytics or logs.
library;

import 'package:mybrev_flutter/ordo/dates.dart';

enum NovenaStatus { active, completed, stopped }

/// How one day of a session looks on a given civil date.
enum NovenaDayState { completed, today, missed, upcoming }

class NovenaSession {
  const NovenaSession({
    required this.sessionId,
    required this.novenaId,
    required this.title,
    required this.contentVersion,
    required this.startDate,
    required this.durationDays,
    this.completedDays = const {},
    this.status = NovenaStatus.active,
    this.finishedDate,
  });

  /// Null for a record this version cannot read.
  static NovenaSession? tryParse(Map data) {
    try {
      final duration = (data['durationDays'] as num).toInt();
      final start = data['startDate'] as String;
      if (duration < 1 || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(start)) {
        return null;
      }
      return NovenaSession(
        sessionId: data['sessionId'] as String,
        novenaId: data['novenaId'] as String,
        title: data['title'] as String,
        contentVersion: (data['contentVersion'] as num).toInt(),
        startDate: start,
        durationDays: duration,
        completedDays: {
          for (final day in data['completedDays'] as List)
            if ((day as num) >= 1 && day <= duration) day.toInt(),
        },
        status: NovenaStatus.values.byName(data['status'] as String),
        finishedDate: data['finishedDate'] as String?,
      );
    } on TypeError {
      return null;
    } on ArgumentError {
      return null;
    }
  }

  final String sessionId;
  final String novenaId;
  final String title;
  final int contentVersion;

  /// Civil date of day 1 (`YYYY-MM-DD`), independent of the time zone.
  final String startDate;
  final int durationDays;
  final Set<int> completedDays;
  final NovenaStatus status;

  /// Civil date the last day was marked or the session was stopped.
  final String? finishedDate;

  bool get isActive => status == NovenaStatus.active;
  int get completedCount => completedDays.length;
  int get remainingCount => durationDays - completedDays.length;

  Map<String, dynamic> toMap() => {
    'sessionId': sessionId,
    'novenaId': novenaId,
    'title': title,
    'contentVersion': contentVersion,
    'startDate': startDate,
    'durationDays': durationDays,
    'completedDays': completedDays.toList()..sort(),
    'status': status.name,
    if (finishedDate != null) 'finishedDate': finishedDate,
  };

  /// Calendar day number of [today]: 1 on the start date, below 1 before it,
  /// above [durationDays] after the last day (never wraps).
  int calendarDay(String today) => diffDays(today, startDate) + 1;

  String dateOfDay(int day) => addDays(startDate, day - 1);

  /// The calendar days are over; unmarked days stay unmarked.
  bool isOverdue(String today) =>
      isActive && calendarDay(today) > durationDays && remainingCount > 0;

  NovenaDayState dayState(int day, String today) {
    if (completedDays.contains(day)) return NovenaDayState.completed;
    final now = calendarDay(today);
    if (day == now) return NovenaDayState.today;
    return day < now ? NovenaDayState.missed : NovenaDayState.upcoming;
  }

  /// A past or current day; a future day is for reading only.
  bool canMark(int day, String today) =>
      status != NovenaStatus.stopped &&
      day >= 1 &&
      day <= durationDays &&
      day <= calendarDay(today);

  /// Today's prayer is open, or the days are over with some unmarked.
  bool needsActionOn(String today) {
    if (!isActive || remainingCount == 0) return false;
    final now = calendarDay(today);
    if (now < 1) return false;
    return now > durationDays || !completedDays.contains(now);
  }

  /// The day «Памаліцца навэнну» opens.
  int dayToPray(String today) {
    final now = calendarDay(today);
    if (now < 1) return 1;
    if (now <= durationDays) return now;
    for (var day = 1; day <= durationDays; day++) {
      if (!completedDays.contains(day)) return day;
    }
    return durationDays;
  }

  /// Marks or unmarks [day]; idempotent. Completion needs every day marked.
  /// Returns this session when the day cannot be changed.
  NovenaSession withDay(int day, bool done, String today) {
    if (!canMark(day, today) || completedDays.contains(day) == done) {
      return this;
    }
    final days = {...completedDays};
    done ? days.add(day) : days.remove(day);
    final complete = days.length == durationDays;
    return _copy(
      completedDays: days,
      status: complete ? NovenaStatus.completed : NovenaStatus.active,
      finishedDate: complete ? today : null,
    );
  }

  NovenaSession stopped(String today) => !isActive
      ? this
      : _copy(
          completedDays: completedDays,
          status: NovenaStatus.stopped,
          finishedDate: today,
        );

  NovenaSession _copy({
    required Set<int> completedDays,
    required NovenaStatus status,
    required String? finishedDate,
  }) => NovenaSession(
    sessionId: sessionId,
    novenaId: novenaId,
    title: title,
    contentVersion: contentVersion,
    startDate: startDate,
    durationDays: durationDays,
    completedDays: completedDays,
    status: status,
    finishedDate: finishedDate,
  );
}
