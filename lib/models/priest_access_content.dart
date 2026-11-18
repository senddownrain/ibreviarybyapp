import 'package:mybrev_flutter/services/priest_access_policy.dart';

class PrayerAccessContent {
  const PrayerAccessContent(this.prayers, this.categories);
  final Map<String, Map<String, dynamic>> prayers;
  final Map<String, Map<String, dynamic>> categories;

  PrayerAccessContent get publicOnly {
    final policy = PriestAccessPolicy(categories);
    return PrayerAccessContent(
      {
        for (final entry in prayers.entries)
          if (!policy.prayerRestricted(entry.value, id: entry.key))
            entry.key: entry.value,
      },
      {
        for (final entry in categories.entries)
          if (!policy.categoryRestricted(entry.key)) entry.key: entry.value,
      },
    );
  }

  /// Protected storage wins a cross-snapshot race and is always annotated.
  PrayerAccessContent mergeProtected(PrayerAccessContent private) =>
      PrayerAccessContent(
        {
          ...prayers,
          for (final entry in private.prayers.entries)
            entry.key: {...entry.value, 'effectivePriestOnly': true},
        },
        {
          ...categories,
          for (final entry in private.categories.entries)
            entry.key: {...entry.value, 'effectivePriestOnly': true},
        },
      );
}
