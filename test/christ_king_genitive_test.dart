import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/models/day.dart';
import 'package:mybrev_flutter/ordo/definitions.dart';
import 'package:mybrev_flutter/utils/liturgical_titles.dart';
import 'package:mybrev_flutter/models/parsed_reading.dart';
import 'package:mybrev_flutter/utils/reading_groups.dart';
import 'support/ordo_fixture.dart';

const title = 'Пана нашага Езуса Хрыста, Валадара Сусвету';
const dioceses = ['minsk-mohilev', 'vitebsk', 'grodno', 'pinsk'];
const dates = ['2026-11-22', '2027-11-21', '2028-11-26'];

void main() {
  test('Christ the King has the canonical genitive title in every diocese', () {
    final engine = bundledOrdoEngine();
    for (final date in dates) {
      for (final diocese in dioceses) {
        final day = engine.resolve(date, diocese: diocese);
        expect(day.primary.id, 'christ-king', reason: '$date/$diocese');
        expect(day.primary.title, title, reason: '$date/$diocese');
      }
    }
  });

  test('old bundled or updated calendar title is normalized by stable ID', () {
    final previous = bundledCollection('liturgicalCelebrations')['christ-king']!;
    final defs = OrdoDefinitions.fromDocuments(celebrations: [
      {...previous, 'id': 'christ-king', 'title': 'Езус Хрыстус, Валадар Сусвету'},
    ]);
    expect(defs.warnings, isEmpty);
    expect(defs.celebrations.single['title'], title);
  });

  test('legacy feast data cannot show the obsolete Office heading', () {
    for (final identity in [
      {'id': 'feast-christking', '_feastName': 'Езус Хрыстус, Валадар Сусвету'},
      {'id': 'legacy', '_feast': 'feast-christking', '_feastName': 'Езус Хрыстус, Валадар Сусвету'},
      {'id': 'legacy', '_celebrationId': 'christ-king', '_title': 'Езус Хрыстус, Валадар Сусвету'},
    ]) {
      final day = LiturgicalDay.fromMap(identity);
      expect(liturgicalDayDisplayTitle(day, DateTime(2026, 11, 22)), title);
    }
  });
}
