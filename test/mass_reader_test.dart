import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mybrev_flutter/models/prayer.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/providers/local_prayers_provider.dart';
import 'package:mybrev_flutter/providers/mass_ritual_provider.dart';
import 'package:mybrev_flutter/providers/prayers_provider.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/screens/prayer_detail_screen.dart';

const _massId = 'eMmCtxwyJ75ogmL5rwye';
const _latinId = 'zdro66KYVuQ9p2KbqizD';

String _long(String label) =>
    List.generate(14, (i) => '$label $i.').join('\n\n');

final _belarusian = Prayer(
  id: _massId,
  title: 'Парадак святой Імшы',
  textFormat: 'mybrev-markdown',
  body:
      '### Уступныя абрады\n\n${_long('Уступ')}\n\n'
      '### Літургія слова\n\n${_long('Слова')}\n\n'
      '**Вызнанне веры**\n\n${_long('Вера')}\n\n'
      '### Эўхарыстычная літургія\n\n${_long('Эўх')}',
);

final _latin = Prayer(
  id: _latinId,
  title: 'Ordo Missae',
  textFormat: 'mybrev-markdown',
  body:
      ':::rubric\nВступительные обряды\n:::\n\n${_long('Intro')}\n\n'
      ':::rubric\nЛитургия Слова\n:::\n\n${_long('Verbum')}\n\n'
      ':::rubric\nИсповедание веры\n:::\n\n${_long('Credo')}\n\n'
      ':::rubric\nЕвхаристическая Литургия\n:::\n\n${_long('Euch')}',
);

final _englishBundled =
    '## The Introductory Rites\n\n${_long('Intro')}\n\n'
    '## The Liturgy of the Word\n\n${_long('Word')}\n\n'
    '### Gospel\n\nThe Gospel of the Lord.\n**Praise to you, Lord Jesus Christ.**\n\n${_long('Gospel')}\n\n'
    '### The Creed\n\n**I believe in one God,**\n\n${_long('Creed')}\n\n'
    '## The Liturgy of the Eucharist\n\n${_long('Eucharist')}';

Widget _app(
  Widget child, {
  List<Prayer>? prayers,
  TargetPlatform platform = TargetPlatform.android,
}) => ProviderScope(
  overrides: [
    settingsProvider.overrideWith(_TestSettingsNotifier.new),
    liturgicalSeasonColorProvider.overrideWithValue(Colors.indigo),
    allPrayersProvider.overrideWithValue(prayers ?? [_belarusian, _latin]),
    localPrayersProvider.overrideWith(_TestLocalPrayersNotifier.new),
    massBundledTextProvider.overrideWith((ref, asset) async => _englishBundled),
  ],
  child: MaterialApp(
    theme: ThemeData(platform: platform),
    home: child,
  ),
);

Future<void> _openSheetAndPick(WidgetTester tester, String sectionId) async {
  await tester.tap(find.byKey(const Key('mass-section-selector')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('mass-section-$sectionId')));
  await tester.pumpAndSettle();
}

String _barTitle(WidgetTester tester) {
  final texts = tester.widgetList<Text>(
    find.descendant(
      of: find.byKey(const Key('mass-section-selector')),
      matching: find.byType(Text),
    ),
  );
  return texts.first.data!;
}

void main() {
  testWidgets('Holy Mass opens in Belarusian with a compact section bar', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const PrayerDetailScreen(prayerId: _massId)));
    await tester.pumpAndSettle();

    expect(find.text('Парадак святой Імшы'), findsOneWidget);
    expect(find.byKey(const Key('mass-navigator-bar')), findsOneWidget);
    expect(find.text('Перайсці да раздзела'), findsNothing);
    expect(_barTitle(tester), 'Уступныя абрады');
  });

  testWidgets('sections sheet lists hierarchy and jumps to a section', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const PrayerDetailScreen(prayerId: _massId)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('mass-section-selector')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mass-sections-sheet')), findsOneWidget);
    for (final id in [
      'introductory-rites',
      'liturgy-of-the-word',
      'creed',
      'liturgy-of-the-eucharist',
    ]) {
      expect(find.byKey(ValueKey('mass-section-$id')), findsOneWidget);
    }
    await tester.tap(find.byKey(const ValueKey('mass-section-creed')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mass-sections-sheet')), findsNothing);
    expect(_barTitle(tester), 'Вызнанне веры');
    expect(find.text('Вера 0.'), findsOneWidget);
  });

  testWidgets('scrolling updates the current section', (tester) async {
    await tester.pumpWidget(_app(const PrayerDetailScreen(prayerId: _massId)));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -1900));
    await tester.pumpAndSettle();
    expect(_barTitle(tester), 'Эўхарыстычная літургія');
  });

  testWidgets('switching language keeps the semantic section', (tester) async {
    await tester.pumpWidget(
      _app(const PrayerDetailScreen(prayerId: _massId, massLanguage: 'la')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ordo Missae'), findsOneWidget);

    await _openSheetAndPick(tester, 'creed');
    expect(_barTitle(tester), 'Исповедание веры');

    await tester.tap(find.byKey(const Key('mass-language-en')));
    await tester.pumpAndSettle();
    expect(_barTitle(tester), 'The Creed');
    expect(find.text('I believe in one God,'), findsOneWidget);
  });

  testWidgets('missing section falls back to its parent', (tester) async {
    await tester.pumpWidget(
      _app(const PrayerDetailScreen(prayerId: _massId, massLanguage: 'en')),
    );
    await tester.pumpAndSettle();
    await _openSheetAndPick(tester, 'gospel');
    expect(_barTitle(tester), 'Gospel');

    await tester.tap(find.byKey(const Key('mass-language-be')));
    await tester.pumpAndSettle();
    expect(_barTitle(tester), 'Літургія слова');
  });

  testWidgets('legacy Latin prayer id opens the Mass reader in Latin', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const PrayerDetailScreen(prayerId: _latinId)));
    await tester.pumpAndSettle();
    expect(find.text('Ordo Missae'), findsOneWidget);
    expect(find.byKey(const Key('mass-navigator-bar')), findsOneWidget);
    expect(_barTitle(tester), 'Вступительные обряды');
  });

  testWidgets('English works offline from the bundled asset', (tester) async {
    await tester.pumpWidget(
      _app(const PrayerDetailScreen(prayerId: _massId, massLanguage: 'en')),
    );
    await tester.pumpAndSettle();
    expect(find.text('The Order of Mass'), findsOneWidget);
    expect(find.byKey(const Key('mass-variant-source')), findsOneWidget);
  });

  testWidgets('system back closes the sections sheet before the reader', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const PrayerDetailScreen(prayerId: _massId)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mass-section-selector')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mass-sections-sheet')), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mass-sections-sheet')), findsNothing);
    expect(find.byKey(const Key('mass-navigator-bar')), findsOneWidget);
  });

  for (final (platform, key) in [
    (TargetPlatform.android, 'adaptive-chrome-ambient'),
    (TargetPlatform.iOS, 'adaptive-chrome-glass'),
  ]) {
    testWidgets('section bar uses the $platform chrome surface', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(const PrayerDetailScreen(prayerId: _massId), platform: platform),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const Key('mass-navigator-bar')),
          matching: find.byKey(Key(key)),
        ),
        findsOneWidget,
      );
    });
  }

  testWidgets('ordinary prayers keep the regular reader', (tester) async {
    await tester.pumpWidget(
      _app(
        const PrayerDetailScreen(prayerId: 'morning'),
        prayers: const [
          Prayer(id: 'morning', title: 'Ранішняя', body: '<p>Добры Божа</p>'),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mass-navigator-bar')), findsNothing);
  });
}

class _TestSettingsNotifier extends SettingsNotifier {
  @override
  SettingsState build() => const SettingsState();

  @override
  Future<void> toggleFavorite(String id) async {}
}

class _TestLocalPrayersNotifier extends LocalPrayersNotifier {
  @override
  List<Prayer> build() => const [];
}
