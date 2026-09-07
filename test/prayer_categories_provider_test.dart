import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/providers/prayer_categories_provider.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';

void main() {
  test('combines global and personal categories without duplicate names', () {
    const globals = [
      PrayerMenuCategory(
        id: 'mary',
        name: 'Марыйныя',
        tags: ['Марыя'],
        isGlobal: true,
      ),
      PrayerMenuCategory(
        id: 'litanies',
        name: 'Літаніі',
        tags: ['Літанія'],
        isGlobal: true,
      ),
    ];
    const personal = [
      UserCategory(id: 'local-1', name: 'марыйныя', tags: ['іншы']),
      UserCategory(id: 'local-2', name: 'Маё', tags: ['асабістае']),
    ];

    final result = buildPrayerCategoryMenu(globals, personal, const []);

    expect(result.map((category) => category.id), [
      'mary',
      'litanies',
      'local-2',
    ]);
  });

  test('hidden global category can be replaced by a personal one', () {
    const globals = [
      PrayerMenuCategory(
        id: 'mary',
        name: 'Марыйныя',
        tags: ['Марыя'],
        isGlobal: true,
      ),
    ];
    const personal = [
      UserCategory(id: 'local', name: 'Марыйныя', tags: ['мая Марыя']),
    ];

    final result = buildPrayerCategoryMenu(globals, personal, const ['mary']);

    expect(result, hasLength(1));
    expect(result.single.id, 'local');
    expect(result.single.isGlobal, isFalse);
  });
}
