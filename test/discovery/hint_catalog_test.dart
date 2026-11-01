import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/discovery/discovery.dart';

void main() {
  const expectedIds = {
    'readings.day_variants',
    'readings.allowed_alternatives',
    'readings.other_year',
    'ordo.calendar_variants',
    'calendar.date_navigation',
    'calendar.more_periods',
    'display.font_scale',
    'hours.psalm_layout',
    'hours.next_hour',
    'readings.other_date',
    'bible.navigation',
    'app.search',
    'discover.prayers',
    'discover.songbook',
    'discover.catechism',
    'discover.bible',
  };

  test('the catalog carries the 16 stable IDs of the master spec', () {
    final ids = HintCatalog.standard().all.map((h) => h.id).toSet();
    expect(ids, expectedIds);
  });

  test('priorities follow the spec tiers and every hint is versioned', () {
    final catalog = HintCatalog.standard();
    for (final id in expectedIds.take(6)) {
      expect(catalog.byId(id)!.priority, HintPriority.p0, reason: id);
    }
    for (final id in expectedIds.skip(6).take(6)) {
      expect(catalog.byId(id)!.priority, HintPriority.p1, reason: id);
    }
    for (final id in expectedIds.skip(12)) {
      expect(catalog.byId(id)!.priority, HintPriority.p2, reason: id);
    }
    for (final hint in catalog.all) {
      expect(hint.version, greaterThanOrEqualTo(1));
      expect(hint.copyBe, isNotEmpty);
      expect(hint.anchorId, isNotEmpty);
    }
  });

  test('a duplicate hint_id is rejected', () {
    const hint = HintDefinition(
      id: 'x.y',
      version: 1,
      priority: HintPriority.p1,
      screenId: 's',
      anchorId: 'a',
      copyBe: 'c',
    );
    expect(() => HintCatalog([hint, hint]), throwsArgumentError);
  });

  test('an unknown ID is simply absent', () {
    expect(HintCatalog.standard().byId('nope'), isNull);
  });
}
