import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mybrev_flutter/models/compendium.dart';
import 'package:mybrev_flutter/models/prayer.dart';
import 'package:mybrev_flutter/models/song.dart';
import 'package:mybrev_flutter/navigation/app_navigation.dart';
import 'package:mybrev_flutter/providers/compendium_provider.dart';
import 'package:mybrev_flutter/providers/prayers_provider.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/providers/songs_provider.dart';
import 'package:mybrev_flutter/screens/library_search_screen.dart';
import 'package:mybrev_flutter/utils/compendium_search.dart';
import 'package:mybrev_flutter/widgets/reader/reader_scaffold.dart';

class _Settings extends SettingsNotifier {
  @override
  SettingsState build() => const SettingsState();
}

const _question = CompendiumQuestion(
  id: 'q42',
  number: 42,
  order: 42,
  question: 'Хто такая Марыя?',
  answer: 'Маці Езуса.',
  unitId: 'unit',
  partId: 'part',
  partNumber: 1,
  partLabel: 'Першая частка',
  partTitle: 'Вера',
  sectionTitle: 'Сімвал веры',
);

Widget _app(
  LibrarySearchScope scope, {
  double textScale = 1,
  TargetPlatform platform = TargetPlatform.android,
  String initialQuery = '',
}) => ProviderScope(
  overrides: [
    settingsProvider.overrideWith(_Settings.new),
    prayerCatalogProvider.overrideWithValue(const [
      Prayer(id: 'p', title: 'Марыя, маліся за нас'),
    ]),
    songsProvider.overrideWithValue(
      const AsyncData([Song(id: 's', title: 'Марыя, Маці наша')]),
    ),
    compendiumSearchIndexProvider.overrideWithValue(
      CompendiumSearchIndex(const [_question]),
    ),
  ],
  child: MaterialApp(
    theme: ThemeData(platform: platform),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: LibrarySearchScreen(initialScope: scope, initialQuery: initialQuery),
  ),
);

void main() {
  testWidgets('Library Search owns the contextual bottom slot', (tester) async {
    const descriptor = AppRouteDescriptor(
      id: 'library-search-test',
      branch: AppBranch.prayerbook,
      defaultChromeMode: ReaderChromeMode.full,
      topChromeOwner: TopChromeOwner.legacy,
    );
    const entry = AppRouteEntry(
      id: 'library-search-entry',
      descriptor: descriptor,
    );
    final controller = BranchShellController(AppBranch.prayerbook, descriptor)
      ..activate(entry);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: AppRouteEntryScope(
            entry: entry,
            controller: controller,
            child: const LibrarySearchScreen(
              initialScope: LibrarySearchScope.prayers,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(controller.navigationDockSuppressed, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(controller.navigationDockSuppressed, isFalse);
    controller.dispose();
  });

  testWidgets('entry context selects the corresponding search scope', (
    tester,
  ) async {
    for (final scope in LibrarySearchScope.values) {
      await tester.pumpWidget(_app(scope));
      await tester.pumpAndSettle();
      final chip = tester.widget<ChoiceChip>(
        find.byKey(Key('library-scope-${scope.name}')),
      );
      expect(chip.selected, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('entry query is carried into a contextual scope', (tester) async {
    await tester.pumpWidget(
      _app(LibrarySearchScope.songs, initialQuery: 'Марыя'),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('song-row-s')), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('library-search-field')))
          .controller!
          .text,
      'Марыя',
    );
  });

  testWidgets('search uses glass on iOS and tonal chrome on Android', (
    tester,
  ) async {
    for (final (platform, surfaceKey) in [
      (TargetPlatform.iOS, 'adaptive-chrome-glass'),
      (TargetPlatform.android, 'adaptive-chrome-ambient'),
    ]) {
      await tester.pumpWidget(
        _app(LibrarySearchScope.prayers, platform: platform),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const Key('library-search-dock')),
          matching: find.byKey(Key(surfaceKey)),
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('one query survives switching between three result sources', (
    tester,
  ) async {
    await tester.pumpWidget(_app(LibrarySearchScope.prayers));
    await tester.enterText(
      find.byKey(const Key('library-search-field')),
      'Марыя',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('prayer-row-p')), findsOneWidget);
    expect(find.byKey(const Key('song-row-s')), findsNothing);

    await tester.tap(find.byKey(const Key('library-scope-songs')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('song-row-s')), findsOneWidget);
    expect(find.byKey(const Key('prayer-row-p')), findsNothing);

    await tester.tap(find.byKey(const Key('library-scope-compendium')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('library-question-42')), findsOneWidget);
    expect(find.byKey(const Key('song-row-s')), findsNothing);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('library-search-field')))
          .controller!
          .text,
      'Марыя',
    );
  });

  testWidgets('search controls fit width and system text matrix', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final width in [320.0, 360.0, 390.0, 700.0]) {
      for (final scale in [1.0, 1.5, 2.0]) {
        tester.view.physicalSize = Size(width, 720);
        await tester.pumpWidget(
          _app(LibrarySearchScope.prayers, textScale: scale),
        );
        await tester.pumpAndSettle();
        final dock = tester.getRect(
          find.byKey(const Key('library-search-dock')),
        );
        expect(dock.left, greaterThanOrEqualTo(0));
        expect(dock.right, lessThanOrEqualTo(width));
        for (final scope in LibrarySearchScope.values) {
          expect(
            tester
                .getSize(find.byKey(Key('library-scope-${scope.name}')))
                .height,
            greaterThanOrEqualTo(48),
          );
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    }
  });
}
