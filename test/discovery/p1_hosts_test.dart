import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/discovery/discovery.dart';
import 'package:mybrev_flutter/discovery/ui/coachmark.dart';
import 'package:mybrev_flutter/dev/discovery_qa_flags.dart';
import 'package:mybrev_flutter/discovery/ui/p1_hint_hosts.dart';
import 'package:mybrev_flutter/models/prayer.dart';
import 'package:mybrev_flutter/models/psalmody_preferences.dart';
import 'package:mybrev_flutter/providers/prayers_provider.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/widgets/text_scale_control.dart';

/// Stand-ins carry the very keys of the real controls; the hosts under test
/// are the production ones from `p1_hint_hosts.dart`.
const _hint = Key('discovery-hint');
const _card = Key('discovery-hint-card');

class _Settings extends SettingsNotifier {
  @override
  SettingsState build() => const SettingsState();

  @override
  Future<void> setPsalmMarkerBreakMode(PsalmMarkerBreakMode value) async =>
      state = state.copyWith(psalmMarkerBreakMode: value);

  @override
  Future<void> setPsalmVerseLayout(PsalmVerseLayout value) async =>
      state = state.copyWith(psalmVerseLayout: value);
}

Widget _app(
  MemoryDiscoveryStorage storage,
  Widget home, {
  List<Override> extra = const [],
}) => ProviderScope(
  overrides: [
    discoveryStorageProvider.overrideWithValue(storage),
    discoveryPolicyConfigProvider.overrideWithValue(
      const DiscoveryPolicyConfig(minInterval: Duration.zero),
    ),
    hintPresenterProvider.overrideWith(
      (ref) => ref.watch(coachmarkPresenterProvider),
    ),
    settingsProvider.overrideWith(_Settings.new),
    ...extra,
  ],
  child: MaterialApp(home: home),
);

Future<void> _wait(WidgetTester tester, [int seconds = 4]) async {
  for (var i = 0; i < seconds * 2; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
}

Widget _hoursScreen({VoidCallback? onMenu, int lines = 80}) => HoursHintHost(
  child: Scaffold(
    appBar: AppBar(
      actions: [
        SizedBox.square(
          dimension: 48,
          key: const Key('reader-chrome-overflow'),
          child: IconButton(
            key: const Key('app-overflow-open'),
            onPressed: onMenu ?? () {},
            icon: const Icon(Icons.more_horiz),
          ),
        ),
      ],
    ),
    body: ListView(
      key: const Key('doc'),
      children: [
        for (var i = 0; i < lines; i++) ListTile(title: Text('Радок $i')),
        OutlinedButton(
          key: const Key('ora-next-hour'),
          onPressed: () {},
          child: const Text('Далей: Апоўдні'),
        ),
        const SizedBox(height: 40),
      ],
    ),
  ),
);

void main() {
  test('QA switches are off in a normal build', () {
    expect(kDiscoveryQa, isFalse);
    expect(discoveryQaResetRequested(), isFalse);
    expect(
      discoveryPolicyForBuild().minInterval,
      const DiscoveryPolicyConfig().minInterval,
    );
  });

  group('display.font_scale', () {
    testWidgets('shows at the ⋯ anchor once, with its copy and three answers', (
      tester,
    ) async {
      final storage = MemoryDiscoveryStorage();
      await tester.pumpWidget(_app(storage, _hoursScreen()));
      expect(find.byKey(_hint), findsNothing);
      await _wait(tester);
      expect(find.byKey(_hint), findsOneWidget);
      expect(find.text('Памер тэксту — у меню ⋯'), findsOneWidget);
      expect(find.text('Паказаць'), findsOneWidget);
      expect(find.text('Пазней'), findsOneWidget);
      expect(find.text('Не паказваць'), findsOneWidget);
      final card = tester.getRect(find.byKey(_card));
      final anchor = tester.getRect(
        find.byKey(const Key('reader-chrome-overflow')),
      );
      expect(card.top, greaterThanOrEqualTo(anchor.bottom));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('«Паказаць» opens the real menu and is never repeated', (
      tester,
    ) async {
      final storage = MemoryDiscoveryStorage();
      var opened = 0;
      await tester.pumpWidget(
        _app(storage, _hoursScreen(onMenu: () => opened++)),
      );
      await _wait(tester);
      await tester.tap(find.byKey(const Key('discovery-hint-show')));
      await tester.pump();
      expect(opened, 1);
      expect(find.byKey(_hint), findsNothing);
      await tester.pumpWidget(const SizedBox());
      // New launch with the same storage.
      await tester.pumpWidget(_app(storage, _hoursScreen()));
      await _wait(tester, 6);
      expect(find.byKey(_hint), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('tapping the real ⋯ counts as learned', (tester) async {
      final storage = MemoryDiscoveryStorage();
      await tester.pumpWidget(_app(storage, _hoursScreen()));
      await _wait(tester);
      await tester.tap(find.byKey(const Key('app-overflow-open')));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_app(storage, _hoursScreen()));
      await _wait(tester, 6);
      expect(find.byKey(_hint), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('does not appear while the text is being scrolled', (
      tester,
    ) async {
      await tester.pumpWidget(_app(MemoryDiscoveryStorage(), _hoursScreen()));
      final gesture = await tester.startGesture(const Offset(200, 400));
      await gesture.moveBy(const Offset(0, -60));
      await _wait(tester, 4);
      expect(find.byKey(_hint), findsNothing);
      await gesture.up();
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('hours.next_hour', () {
    testWidgets('only at the real button after the end, not on the text', (
      tester,
    ) async {
      final storage = MemoryDiscoveryStorage();
      // Font hint already finished: «Не паказваць».
      await tester.pumpWidget(_app(storage, _hoursScreen()));
      await _wait(tester);
      await tester.tap(find.byKey(const Key('discovery-hint-never')));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());

      await tester.pumpWidget(_app(storage, _hoursScreen()));
      await _wait(tester, 4);
      // Middle of the document: the button is off screen, no hint.
      expect(find.byKey(_hint), findsNothing);
      await tester.drag(find.byKey(const Key('doc')), const Offset(0, -20000));
      await _wait(tester, 4);
      expect(find.byKey(_hint), findsOneWidget);
      expect(
        find.text('Перайсці да наступнай гадзіны можна адсюль'),
        findsOneWidget,
      );
      expect(find.text('Зразумела'), findsOneWidget);
      expect(find.text('Пазней'), findsNothing);
      final card = tester.getRect(find.byKey(_card));
      final button = tester.getRect(find.byKey(const Key('ora-next-hour')));
      expect(card.overlaps(button), isFalse);

      // Starting to scroll again hides it.
      final gesture = await tester.startGesture(const Offset(200, 300));
      await gesture.moveBy(const Offset(0, 30));
      await tester.pump();
      expect(find.byKey(_hint), findsNothing);
      await gesture.up();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('«Зразумела» is not repeated after a restart', (tester) async {
      final storage = MemoryDiscoveryStorage();
      for (final hintId in ['display.font_scale']) {
        final repository = await DiscoveryRepository.open(
          storage: storage,
          clock: const SystemDiscoveryClock(),
        );
        await repository.dismiss(hintId);
        await repository.flush();
      }
      await tester.pumpWidget(_app(storage, _hoursScreen()));
      await _wait(tester);
      await tester.drag(find.byKey(const Key('doc')), const Offset(0, -20000));
      await _wait(tester, 4);
      await tester.tap(find.byKey(const Key('discovery-hint-ack')));
      await tester.pump();
      expect(find.byKey(_hint), findsNothing);
      await tester.pumpWidget(const SizedBox());

      await tester.pumpWidget(_app(storage, _hoursScreen()));
      await _wait(tester);
      await tester.drag(find.byKey(const Key('doc')), const Offset(0, -20000));
      await _wait(tester, 6);
      expect(find.byKey(_hint), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('hours.psalm_layout (inside the font panel)', () {
    Widget panelHome() => Scaffold(
      body: Consumer(
        builder: (context, ref, _) => TextButton(
          key: const Key('open-hours-panel'),
          onPressed: () => showTextScalePanel(context, showPsalmody: true),
          child: const Text('Шрыфт'),
        ),
      ),
    );

    testWidgets('appears in the panel; both chips stay independent', (
      tester,
    ) async {
      final storage = MemoryDiscoveryStorage();
      await tester.pumpWidget(_app(storage, panelHome()));
      await tester.tap(find.byKey(const Key('open-hours-panel')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('discovery-hint-hours.psalm_layout')),
        findsNothing,
      );
      await _wait(tester, 3);
      expect(
        find.text('Можна наладзіць перанос радкоў і размяшчэнне вершаў'),
        findsOneWidget,
      );
      expect(find.text('Зразумела'), findsOneWidget);
      expect(find.text('Не паказваць'), findsOneWidget);

      bool selected(String key) =>
          tester.widget<FilterChip>(find.byKey(Key(key))).selected;
      // The hint changed neither chip.
      expect(selected('text-scale-psalm-marker-break'), isFalse);
      expect(selected('text-scale-psalm-aligned-left'), isFalse);

      await tester.ensureVisible(
        find.byKey(const Key('text-scale-psalm-marker-break')),
      );
      await tester.tap(find.byKey(const Key('text-scale-psalm-marker-break')));
      await tester.pump();
      expect(selected('text-scale-psalm-marker-break'), isTrue);
      expect(selected('text-scale-psalm-aligned-left'), isFalse);
      await tester.tap(find.byKey(const Key('text-scale-psalm-aligned-left')));
      await tester.pump();
      expect(selected('text-scale-psalm-marker-break'), isTrue);
      expect(selected('text-scale-psalm-aligned-left'), isTrue);
      await tester.tap(find.byKey(const Key('text-scale-psalm-marker-break')));
      await tester.pump();
      expect(selected('text-scale-psalm-marker-break'), isFalse);
      expect(selected('text-scale-psalm-aligned-left'), isTrue);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('«Зразумела» closes it and it does not return', (tester) async {
      final storage = MemoryDiscoveryStorage();
      await tester.pumpWidget(_app(storage, panelHome()));
      await tester.tap(find.byKey(const Key('open-hours-panel')));
      await tester.pumpAndSettle();
      await _wait(tester, 3);
      await tester.ensureVisible(find.byKey(const Key('discovery-hint-ack')));
      await tester.tap(find.byKey(const Key('discovery-hint-ack')));
      await tester.pump();
      expect(
        find.byKey(const Key('discovery-hint-hours.psalm_layout')),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox());

      await tester.pumpWidget(_app(storage, panelHome()));
      await tester.tap(find.byKey(const Key('open-hours-panel')));
      await tester.pumpAndSettle();
      await _wait(tester, 4);
      expect(
        find.byKey(const Key('discovery-hint-hours.psalm_layout')),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a panel without psalmody (readings) never shows it', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          MemoryDiscoveryStorage(),
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                key: const Key('open-plain-panel'),
                onPressed: () => showTextScalePanel(context),
                child: const Text('Шрыфт'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('open-plain-panel')));
      await tester.pumpAndSettle();
      await _wait(tester, 4);
      expect(find.byType(HintCard), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('bible.navigation', () {
    Widget bible({bool selecting = false}) => BibleHintHost(
      child: Scaffold(
        body: Stack(
          children: [
            const Center(child: Text('Быццё 1')),
            Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                height: 60,
                child: TextButton(
                  key: const Key('bible-book-chapter-picker'),
                  onPressed: () {},
                  child: const Text('Быццё 1'),
                ),
              ),
            ),
            if (selecting) const SizedBox(key: Key('bible-highlight-palette')),
          ],
        ),
      ),
    );

    testWidgets('points at the chapter picker', (tester) async {
      await tester.pumpWidget(_app(MemoryDiscoveryStorage(), bible()));
      await _wait(tester);
      expect(
        find.text('Выберыце кнігу і раздзел Святога Пісання'),
        findsOneWidget,
      );
      expect(find.text('Паказаць'), findsOneWidget);
      expect(find.text('Пазней'), findsOneWidget);
      final card = tester.getRect(find.byKey(_card));
      final anchor = tester.getRect(
        find.byKey(const Key('bible-book-chapter-picker')),
      );
      expect(card.bottom, lessThanOrEqualTo(anchor.top));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('silent while verses are being selected', (tester) async {
      await tester.pumpWidget(
        _app(MemoryDiscoveryStorage(), bible(selecting: true)),
      );
      await _wait(tester, 5);
      expect(find.byKey(_hint), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('app.search (prayers only)', () {
    Widget prayers() => PrayersHintHost(
      child: Scaffold(
        appBar: AppBar(
          actions: [
            IconButton(
              key: const Key('prayerbook-search-action'),
              tooltip: 'Пошук малітваў',
              onPressed: () {},
              icon: const Icon(Icons.search),
            ),
          ],
        ),
      ),
    );

    testWidgets('narrow copy at the prayer search button', (tester) async {
      await tester.pumpWidget(
        _app(
          MemoryDiscoveryStorage(),
          prayers(),
          extra: [
            prayerCatalogProvider.overrideWithValue(const [
              Prayer(id: 'p1', title: 'Ойча наш'),
            ]),
          ],
        ),
      );
      await _wait(tester);
      expect(
        find.text('Шукаеце малітву? Скарыстайцеся пошукам'),
        findsOneWidget,
      );
      expect(find.textContaining('тэкст'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('silent when the prayer catalog is empty', (tester) async {
      await tester.pumpWidget(
        _app(
          MemoryDiscoveryStorage(),
          prayers(),
          extra: [prayerCatalogProvider.overrideWithValue(const [])],
        ),
      );
      await _wait(tester, 5);
      expect(find.byKey(_hint), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
