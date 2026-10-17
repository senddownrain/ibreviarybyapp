import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/analytics/contract.dart';
import 'package:mybrev_flutter/analytics/public_inventory.dart';
import 'package:mybrev_flutter/analytics/route_mapper.dart';

AnalyticsTarget? _map(String location) =>
    mapLocation(Uri.parse(location), massOrderPrayerId: 'eMmCtxwyJ75ogmL5rwye');

void main() {
  test('public routes map to contract sections', () {
    expect(_map('/hours'), const AnalyticsTarget('today'));
    expect(_map('/hours/ordo'), const AnalyticsTarget('ordo'));
    expect(_map('/hours/ordo/month'), const AnalyticsTarget('ordo'));
    expect(_map('/hours/picker/options'), const AnalyticsTarget('picker'));
    expect(_map('/readings'), const AnalyticsTarget('readings', 'reading:day'));
    expect(
      _map('/readings/reading/abc'),
      const AnalyticsTarget('readings', 'reading:day'),
    );
    expect(_map('/readings/picker'), const AnalyticsTarget('picker'));
    expect(_map('/settings'), const AnalyticsTarget('settings'));
    expect(_map('/about'), const AnalyticsTarget('about'));
  });

  test('hour routes map to contract hour ids, vespers becomes vesper', () {
    expect(
      _map('/hours/ora/2026-10-15/15-10-sv-teresa-of-jesus/laudes'),
      const AnalyticsTarget('hours', 'hour:laudes'),
    );
    expect(
      _map('/hours/ora/2026-10-15/15-10-sv-teresa-of-jesus/vespers'),
      const AnalyticsTarget('hours', 'hour:vesper'),
    );
    expect(_map('/hours/ora/2026-10-15/x/unknown'), isNull);
    expect(
      _map('/hours/hora/2026-10-15/x'),
      const AnalyticsTarget.catalog('hours_list'),
    );
  });

  test('prayers, mass, songs, compendium and Bible map to content ids', () {
    expect(
      _map('/prayers/prayer/import-15-malitvy-za-semi'),
      const AnalyticsTarget('prayers', 'prayer:import-15-malitvy-za-semi'),
    );
    expect(
      _map('/prayers/prayer/eMmCtxwyJ75ogmL5rwye?lang=la'),
      const AnalyticsTarget('mass', 'mass:order'),
    );
    expect(
      _map('/prayers/songs/holysongs-0027665fbaf1422fd4dc'),
      const AnalyticsTarget('songs', 'song:holysongs-0027665fbaf1422fd4dc'),
    );
    expect(
      _map('/prayers/compendium/node/p1-s1-ch1'),
      const AnalyticsTarget('compendium', 'comp:p1-s1-ch1'),
    );
    expect(
      _map('/bible?version=bel&book=gn&chapter=1'),
      const AnalyticsTarget('bible', 'bible:bel:gn'),
    );
  });

  test(
    'lists, search, personal prayers and incomplete routes are not measured',
    () {
      for (final location in [
        '/',
        '/prayers/search',
        '/prayers/my',
        '/prayers/prayer/add',
        '/prayers/prayer/abc123def/edit',
        '/prayers/compendium/question/5',
        '/prayers/category/abc',
        '/bible/search',
        '/bible?version=xx&book=gn&chapter=1',
        '/bible?version=bel&book=gn',
        '/unknown',
      ]) {
        expect(_map(location), isNull, reason: location);
      }
    },
  );

  test(
    'every mapped id is shaped for its section; unknown ids fail the inventory',
    () {
      final song = _map('/prayers/songs/holysongs-0027665fbaf1422fd4dc')!;
      expect(
        validateContentId(
          song.section!,
          song.contentId,
          publicIds: kAnalyticsPublicIds,
        ),
        isEmpty,
      );
      final stranger = _map('/prayers/prayer/someClosedPriestPrayer1')!;
      expect(
        validateContentId(
          stranger.section!,
          stranger.contentId,
          publicIds: kAnalyticsPublicIds,
        ),
        isNotEmpty,
      );
    },
  );
}
