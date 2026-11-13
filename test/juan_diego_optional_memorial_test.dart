import 'package:flutter_test/flutter_test.dart';

import 'support/ordo_fixture.dart';

void main() {
  test(
    '9 December Juan Diego remains an optional memorial in bundled Ordo',
    () {
      final celebration = bundledCollection(
        'liturgicalCelebrations',
      )['sv-juan-diego'];
      expect(celebration, isNotNull);
      expect(celebration!['enabled'], isNot(false));
      expect(celebration['rank'], 'memoria-ad-libitum');
      expect(celebration['dateRule'], containsPair('month', 12));
      expect(celebration['dateRule'], containsPair('day', 9));

      final engine = bundledOrdoEngine();
      for (final diocese in ['minsk-mohilev', 'grodno', 'pinsk', 'vitebsk']) {
        for (final year in [2026, 2027]) {
          final date = '$year-12-09';
          final resolved = engine.resolve(date, diocese: diocese);
          final options = [
            resolved.primary,
            ...resolved.alternatives,
            ...resolved.commemorations,
          ];
          final matches = options.where(
            (option) => option.id == 'sv-juan-diego',
          );
          expect(matches, hasLength(1), reason: '$diocese/$date');
          expect(
            matches.single.title,
            'Св. Хуана Дыега Куаўтлатаацына',
            reason: '$diocese/$date',
          );
          expect(
            matches.single.rank,
            'memoria-ad-libitum',
            reason: '$diocese/$date',
          );
        }
      }
    },
  );
}
