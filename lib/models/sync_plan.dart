enum SyncTarget {
  days('days', 'Літургічныя дні'),
  readings('readings', 'Чытанні'),
  prayers('prayers', 'Малітвы'),
  /// The Bible collections are large; download them only when explicitly
  /// requested from the cache settings instead of during startup sync.
  bibleBel('bible_bel', 'Біблія · беларуская', automatic: false),
  bibleRu('bible_ru', 'Біблія · руская', automatic: false),

  /// Legacy collection. The calendar is computed on the device
  /// (`computeYearOptions`), so it is downloaded only on explicit request.
  years('yearOptions', 'Параметры літургічных гадоў', automatic: false),
  invitatoriums('invitatoriums', 'Заклік'),
  completoriums('completoriums', 'Камплета'),
  prayerCategories('prayerCategories', 'Катэгорыі малітваў'),

  /// Commons and the Sunday week I psalter used by sparse feast documents.
  templates('liturgicalTemplates', 'Агульныя тэксты'),

  /// Optional songbook content. The app ships a bundled seed, so songs are
  /// synced only on request, from «Загрузіць усю базу» or when the songbook
  /// is opened — never as part of the automatic startup/background window.
  songs('songs', 'Спеўнік', automatic: false),

  /// Optional Compendium of the Catechism. A validated dataset ships with the
  /// app; `compendiumMeta/current` is compared first and the `compendium`
  /// units are downloaded only when Firestore has a strictly newer, valid
  /// version. Never part of the automatic startup/background window.
  compendium('compendium', 'Кампендый Катэхізіса', automatic: false);

  const SyncTarget(this.collection, this.label, {this.automatic = true});
  final String collection;
  final String label;

  /// Whether the automatic background window downloads this collection.
  final bool automatic;
}

/// Collections that are large enough to wait for Wi-Fi when the user asks
/// for it (both Bible translations, the songbook and the Compendium).
const Set<SyncTarget> kLargeSyncTargets = {
  SyncTarget.bibleBel,
  SyncTarget.bibleRu,
  SyncTarget.songs,
  SyncTarget.compendium,
};

/// Targets refreshed by the automatic background synchronization.
final Set<SyncTarget> kAutomaticSyncTargets = {
  for (final target in SyncTarget.values)
    if (target.automatic) target,
};

enum SyncPeriod {
  week('1 тыдзень', 7),
  fortnight('2 тыдні', 14),
  month('1 месяц', 30),
  twoMonths('2 месяцы', 60),
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
      twoMonths => 2,
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
