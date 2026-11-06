import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/dev/devotional_office_harness.dart';
import 'package:mybrev_flutter/models/prayer.dart';
import 'package:mybrev_flutter/models/psalmody_preferences.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/utils/devotional_office.dart';
import 'package:mybrev_flutter/widgets/devotional_office_reader.dart';
import 'package:mybrev_flutter/widgets/psalm_choir_html.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<Prayer> prayers;
  setUpAll(() async {
    final collection = decodeContentCollection(
      (await rootBundle.load(
        'assets/content/prayers.json.gz',
      )).buffer.asUint8List(),
    );
    prayers = [
      for (final id in devotionalOfficeProfiles.keys)
        Prayer.fromMap(collection.docs[id]!, id),
    ];
  });
  Future<void> open(
    WidgetTester tester,
    String id, {
    bool dark = false,
    double scale = 1,
  }) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      DevotionalOfficeHarness(
        key: ValueKey('$id-$dark-$scale'),
        prayers: prayers,
        initialId: id,
        dark: dark,
        scale: scale,
        systemFonts: true,
        settings: const SettingsState(
          psalmodyMode: PsalmodyMode.leftBreakIndent,
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Long book titles at 200% can keep the deferred content surface below
    // the viewport. Reach the document through the real reader scroll view.
    for (
      var i = 0;
      i < 5 && find.byType(DevotionalOfficeReader).evaluate().isEmpty;
      i++
    ) {
      await tester.drag(
        find.byType(CustomScrollView).first,
        const Offset(0, -600),
      );
      await tester.pumpAndSettle();
    }
  }

  String html(WidgetTester tester) => tester
      .widgetList<Html>(find.byType(Html))
      .map((w) => w.data ?? '')
      .join('\n');
  for (final id in devotionalOfficeProfiles.keys) {
    for (final dark in [false, true]) {
      testWidgets('$id: real screen 320px ${dark ? 'dark 200%' : 'light'}', (
        tester,
      ) async {
        await open(tester, id, dark: dark, scale: dark ? 2 : 1);
        expect(find.byType(DevotionalOfficeReader), findsOneWidget);
        expect(find.byType(SelectionArea), findsOneWidget);
        expect(html(tester), isNot(contains('Іншыя варыянты частак')));
        expect(html(tester), isNot(contains('Варыянт 2')));
        if (id.contains('for-dead')) {
          expect(find.byType(ChoiceChip), findsNWidgets(4));
          expect(
            tester
                .widgetList<ChoiceChip>(find.byType(ChoiceChip))
                .any((w) => w.selected),
            isFalse,
          );
          final chip = find.byKey(const ValueKey('devotional-intention-1'));
          await tester.ensureVisible(chip);
          await tester.pumpAndSettle();
          await tester.tap(chip);
          await tester.pumpAndSettle();
          expect(tester.widget<ChoiceChip>(chip).selected, isTrue);
          expect(
            html(tester),
            contains(
              id.endsWith('laudes')
                  ? 'Сястры, што спіць у спакоі'
                  : 'Ты пакліч сястру',
            ),
          );
          expect(html(tester), contains('N.'));
        } else if (id.contains('virgin')) {
          expect(find.byType(ChoiceChip), findsNWidgets(7));
          final chip = find.byKey(const ValueKey('devotional-intercessions-1'));
          final before = html(tester);
          await tester.ensureVisible(chip);
          await tester.pumpAndSettle();
          await tester.tap(chip);
          await tester.pumpAndSettle();
          expect(tester.widget<ChoiceChip>(chip).selected, isTrue);
          expect(html(tester), isNot(before));
        } else {
          expect(find.byType(ChoiceChip), findsNothing);
          expect(find.text('Гімн'), findsNWidgets(7));
          expect(html(tester), contains('Кантар:'));
        }
        if (!id.startsWith('catholicby')) {
          expect(find.byType(PsalmChoirHtml), findsNWidgets(4));
          final scope = PsalmodyScope.maybeOf(
            tester.element(find.byType(PsalmChoirHtml).first),
          )!;
          expect(scope.mode, PsalmodyMode.leftBreakIndent);
          expect(html(tester), contains('psalm-continuation'));
        }
        // Traverse to the original ending as well as the changed controls.
        final scroll = tester.state<ScrollableState>(
          find.byType(Scrollable).first,
        );
        scroll.position.jumpTo(scroll.position.maxScrollExtent);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets(
    'changing all four intentions updates both dependent sections, with no duplicate labels',
    (tester) async {
      final id = prayers.first.id;
      await open(tester, id);
      for (var i = 0; i < 4; i++) {
        final chip = find.byKey(ValueKey('devotional-intention-$i'));
        await tester.ensureVisible(chip);
        await tester.pumpAndSettle();
        await tester.tap(chip);
        await tester.pumpAndSettle();
        final doc = parseDevotionalOffice(prayers.first)!;
        final hymn = doc.sections.firstWhere((s) => s.type == 'hymn');
        final prayer = doc.sections.firstWhere((s) => s.type == 'prayer');
        final h = doc
            .selectedBlocks(hymn, intention: i)
            .last
            .source
            .split('\n')
            .first;
        final p = doc
            .selectedBlocks(prayer, intention: i)
            .last
            .source
            .substring(0, 35);
        expect(html(tester), contains(h));
        expect(html(tester), contains(p));
        expect(
          tester
              .widgetList<ChoiceChip>(find.byType(ChoiceChip))
              .where((w) => w.selected),
          hasLength(1),
        );
        expect(tester.takeException(), isNull);
      }
    },
  );
}
