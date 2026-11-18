import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/ordo/definitions.dart';
import 'support/ordo_fixture.dart';

void main() {
  test(
    'approved BY PDF excludes Juan Diego from selection and retains its source and canonical alias',
    () {
      final doc = bundledCollection('liturgicalCelebrations')['sv-juan-diego']!;
      expect(doc['enabled'], isFalse);
      expect(doc['dateRule'], containsPair('month', 12));
      expect(doc['dateRule'], containsPair('day', 9));
      final retained = bundledCollection('liturgicalProperTexts');
      expect(retained.keys.any((id) => id.contains('juan-diego')), isTrue);
      final isolated = OrdoDefinitions.fromDocuments(
        celebrations: [
          {...doc, 'enabled': true},
        ],
      );
      expect(
        isolated.celebrations.single['title'],
        'Св. Хуана Дыега Куаўтлатаацына',
      );
      for (final diocese in kDioceses) {
        for (var year = 2025; year <= 2035; year++) {
          final day = bundledOrdoEngine().resolve(
            '$year-12-09',
            diocese: diocese,
          );
          expect(
            [
              ...day.options,
              ...day.commemorations,
              ...day.suppressed,
            ].map((o) => o.id),
            isNot(contains('sv-juan-diego')),
          );
        }
      }
    },
  );
}
