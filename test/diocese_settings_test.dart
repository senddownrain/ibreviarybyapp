// Settings «Літургічны каляндар» and the Hours for several dioceses.
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/content/content_store.dart';
import 'package:mybrev_flutter/providers/diocese_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/services/liturgical_content_service.dart';
import 'package:mybrev_flutter/utils/day_options_union.dart';
import 'package:mybrev_flutter/utils/hours_liturgical_options.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('dioceses-');
    await HiveService.init(path: directory.path, loadBundle: true);
    await ContentStore.instance.ensureLoaded(kContentCollections);
  });
  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });
  setUp(() async {
    final box = HiveService.settingsBox;
    for (final key in [
      DioceseSelectionNotifier.selectedKey,
      DioceseSelectionNotifier.primaryKey,
      ...DioceseSelectionNotifier.legacyKeys,
    ]) {
      await box.delete(key);
    }
  });

  group('settings', () {
    test('default: one diocese, the web default', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final selection = container.read(dioceseSelectionProvider);
      expect(selection.selected, ['minsk-mohilev']);
      expect(selection.primary, 'minsk-mohilev');
    });

    test('several dioceses; the last one cannot be deselected; persisted', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(dioceseSelectionProvider.notifier);
      expect(notifier.toggle('vitebsk'), isTrue);
      expect(notifier.toggle('pinsk'), isTrue);
      expect(container.read(dioceseSelectionProvider).selected, [
        'minsk-mohilev',
        'pinsk',
        'vitebsk',
      ]);
      expect(notifier.toggle('minsk-mohilev'), isTrue);
      // The primary moved to the next selected diocese, deterministically.
      expect(container.read(dioceseSelectionProvider).primary, 'pinsk');
      expect(notifier.toggle('pinsk'), isTrue);
      expect(notifier.toggle('vitebsk'), isFalse);
      expect(container.read(dioceseSelectionProvider).selected, ['vitebsk']);

      final reopened = ProviderContainer();
      addTearDown(reopened.dispose);
      expect(reopened.read(dioceseSelectionProvider).selected, ['vitebsk']);
      expect(reopened.read(dioceseSelectionProvider).primary, 'vitebsk');
    });

    test('a former single-diocese key is migrated', () async {
      await HiveService.settingsBox.put('diocese', 'Hrodna');
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(dioceseSelectionProvider).selected, ['grodno']);
    });
  });

  group('Hours union', () {
    final service = LiturgicalContentService();
    test(
      'Settings replaces an old route context, while new links still work',
      () {
        final date = DateTime(2026, 10, 9);
        final container = ProviderContainer(
          overrides: [selectedDateProvider.overrideWith((ref) => date)],
        );
        addTearDown(container.dispose);
        final dayId = container.read(dayOptionsProvider).first.dayId!;
        final choices = container.read(
          hoursLiturgicalOverridesProvider.notifier,
        );
        choices.select(date, dayId, diocese: 'minsk-mohilev');
        final settings = container.read(dioceseSelectionProvider.notifier);
        settings.toggle('vitebsk');
        settings.toggle('minsk-mohilev');
        expect(
          container.read(dayContentsProvider).map((day) => day.ordo.diocese),
          ['vitebsk'],
        );
        expect(
          container.read(hoursLiturgicalOverridesProvider)['2026-10-09'],
          HoursChoice(dayId),
        );
        expect(
          container.read(hoursLiturgicalSelectionProvider).selected?.dayId,
          dayId,
        );

        choices.select(date, dayId, diocese: 'minsk-mohilev');
        expect(
          container.read(hoursLiturgicalSelectionProvider).diocese,
          'minsk-mohilev',
        );
        expect(container.read(dioceseSelectionProvider).selected, ['vitebsk']);
      },
    );
    List<DayOption> union(DateTime date, List<String> dioceses) =>
        unionDayOptions([
          for (final diocese in dioceses)
            (diocese, service.contentForDate(date, diocese: diocese).options),
        ], primary: dioceses.first);

    test('one diocese: no badges', () {
      final options = union(DateTime(2026, 8, 26), ['vitebsk']);
      expect(options.every((o) => o.badges.isEmpty), isTrue);
      expect(options.first.ordo!.optionId, 'temporal:ordinary-w21-d4');
    });

    test('shared celebration: one row without badges', () {
      final options = union(DateTime(2026, 10, 2), ['minsk-mohilev', 'pinsk']);
      final angels = options.where(
        (o) => o.ordo?.optionId == 'holy-guardian-angels',
      );
      expect(angels, hasLength(1));
      expect(angels.single.badges, isEmpty);
      expect(angels.single.dioceses, ['minsk-mohilev', 'pinsk']);
    });

    test('a diocesan option carries its badge and opens in its diocese', () {
      final options = union(DateTime(2026, 8, 26), ['vitebsk', 'grodno']);
      final czestochowa = options.firstWhere(
        (o) => o.ordo?.optionId == 'our-lady-czestochowa',
      );
      expect(czestochowa.badges, ['Гродна']);
      expect(czestochowa.contextDiocese, 'grodno');
      final weekday = options.firstWhere(
        (o) => o.ordo?.optionId == 'temporal:ordinary-w21-d4',
      );
      expect(weekday.badges, ['Віцебск']);
      final selection = resolveHoursLiturgicalSelection(
        options,
        selectedDayId: czestochowa.dayId,
        selectedDiocese: 'grodno',
        primaryDiocese: 'vitebsk',
      );
      expect(selection.primary?.contextDiocese, 'vitebsk');
      expect(selection.selected?.ordo?.optionId, 'our-lady-czestochowa');
      expect(selection.diocese, 'grodno');
    });

    test('the same celebration with another rank is a distinct row', () {
      final options = union(DateTime(2026, 7, 2), [
        'minsk-mohilev',
        'grodno',
        'pinsk',
        'vitebsk',
      ]);
      final budslav = options
          .where((o) => o.ordo?.optionId == 'our-lady-budslav')
          .toList();
      expect(budslav.map((o) => o.ordo!.rank).toSet().length, greaterThan(1));
      expect(budslav.every((o) => o.badges.isNotEmpty), isTrue);
    });

    test('a temporary route context never changes Settings', () {
      final container = ProviderContainer(
        overrides: [
          selectedDateProvider.overrideWith((ref) => DateTime(2026, 8, 26)),
        ],
      );
      addTearDown(container.dispose);
      container.read(dioceseSelectionProvider.notifier).toggle('vitebsk');
      final options = container.read(dayOptionsProvider);
      final czestochowa = options.firstWhere(
        (o) => o.ordo?.optionId == 'our-lady-czestochowa',
      );
      container
          .read(hoursLiturgicalOverridesProvider.notifier)
          .select(
            DateTime(2026, 8, 26),
            czestochowa.dayId!,
            diocese: 'minsk-mohilev',
          );
      expect(
        container.read(hoursLiturgicalSelectionProvider).diocese,
        'minsk-mohilev',
      );
      expect(container.read(dioceseSelectionProvider).selected, [
        'minsk-mohilev',
        'vitebsk',
      ]);
    });
  });
}
