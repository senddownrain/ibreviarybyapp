enum SyncTarget {
  days('days', 'Літургічныя дні'),
  readings('readings', 'Чытанні'),
  prayers('prayers', 'Малітвы'),
  bibleBel('bible_bel', 'Біблія · беларуская'),
  bibleRu('bible_ru', 'Біблія · руская'),
  years('yearOptions', 'Параметры літургічных гадоў'),
  invitatoriums('invitatoriums', 'Заклік'),
  completoriums('completoriums', 'Камплета'),
  prayerCategories('prayerCategories', 'Катэгорыі малітваў');

  const SyncTarget(this.collection, this.label);
  final String collection;
  final String label;
}

enum SyncPeriod {
  week('1 тыдзень', 7),
  fortnight('2 тыдні', 14),
  month('1 месяц', 30),
  quarter('3 месяцы', 90),
  halfYear('6 месяцаў', 180),
  year('Увесь каляндарны год', null),
  all('Уся калекцыя · усе гады', null);

  const SyncPeriod(this.label, this.days);
  final String label;
  final int? days;

  List<DateTime> dates(DateTime base) {
    final start = this == year
        ? DateTime(base.year)
        : DateTime(base.year, base.month, base.day);
    final months = switch (this) {
      month => 1,
      quarter => 3,
      halfYear => 6,
      _ => 0,
    };
    final monthStart = DateTime(start.year, start.month + months);
    final lastDay = DateTime(monthStart.year, monthStart.month + 1, 0).day;
    final end = months > 0
        ? DateTime(
            monthStart.year,
            monthStart.month,
            start.day.clamp(1, lastDay),
          )
        : this == year
        ? DateTime(base.year + 1)
        : DateTime(start.year, start.month, start.day + (days ?? 1));
    return [
      for (
        var date = start;
        date.isBefore(end);
        date = DateTime(date.year, date.month, date.day + 1)
      )
        date,
    ];
  }
}

class SyncPlan {
  const SyncPlan({
    required this.targets,
    this.period = SyncPeriod.fortnight,
    this.dates,
    this.baseDate,
    this.forceRefresh = true,
    this.background = false,
  });

  final Set<SyncTarget> targets;
  final SyncPeriod period;
  final List<DateTime>? dates;
  final DateTime? baseDate;
  final bool forceRefresh;
  final bool background;
}
