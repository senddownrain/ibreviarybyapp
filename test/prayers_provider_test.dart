import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/models/prayer.dart';
import 'package:mybrev_flutter/providers/prayers_provider.dart';

void main() {
  const prayers = [
    Prayer(
      id: 'a',
      title: 'Альфа',
      body: '<p>Маці Божая</p>',
      tags: ['марыйныя'],
    ),
    Prayer(
      id: 'b',
      title: 'Бэта',
      body: 'Малітва ўвечары',
      tags: ['вечар', 'штодзённыя'],
    ),
    Prayer(id: 'c', title: '  Вітай, Марыя', tags: ['марыйныя']),
    Prayer(id: 'd', title: 'Ordo Missae'),
  ];

  test('selected tags match any selected tag', () {
    final result = filterAndSortPrayers(
      prayers,
      const PrayersFilter(selectedTags: {'вечар', 'марыйныя'}),
      const [],
    );

    expect(result.map((prayer) => prayer.id), ['a', 'b', 'c']);
  });

  test('search checks title and prayer text without HTML tags', () {
    final byTitle = filterAndSortPrayers(
      prayers,
      const PrayersFilter(searchQuery: 'марыя'),
      const [],
    );
    final byText = filterAndSortPrayers(
      prayers,
      const PrayersFilter(searchQuery: 'маці божая'),
      const [],
    );

    expect(byTitle.map((prayer) => prayer.id), ['c']);
    expect(byText.map((prayer) => prayer.id), ['a']);
  });

  test('search normalizes whitespace, HTML boundaries, and apostrophes', () {
    final acrossParagraphs = filterAndSortPrayers(
      const [
        Prayer(
          id: 'e',
          title: 'Апостальская малітва',
          body: '<p>Праз Езуса</p><p>Хрыста&nbsp;— нашага Пана.</p>',
        ),
      ],
      const PrayersFilter(searchQuery: 'езуса   хрыста'),
      const [],
    );
    final straightApostrophe = filterAndSortPrayers(
      const [
        Prayer(id: 'g', title: 'Марыя — Маці вернікаў', body: 'З’яднай нас'),
      ],
      const PrayersFilter(searchQuery: "з'яднай"),
      const [],
    );

    expect(acrossParagraphs.map((prayer) => prayer.id), ['e']);
    expect(straightApostrophe.map((prayer) => prayer.id), ['g']);
  });

  test('favorites are sorted first and titles ignore leading spaces', () {
    final result = filterAndSortPrayers(prayers, const PrayersFilter(), const [
      'b',
    ]);

    expect(result.map((prayer) => prayer.id), ['b', 'a', 'c', 'd']);
  });
}
