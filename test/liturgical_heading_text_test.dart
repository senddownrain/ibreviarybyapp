import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mybrev_flutter/widgets/liturgical_date_navigation_row.dart';
import 'package:mybrev_flutter/widgets/liturgical_heading_text.dart';

void main() {
  setUpAll(() => initializeDateFormatting('be'));

  testWidgets(
    'celebration heading keeps words intact inside an intrinsic band row',
    (tester) async {
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(320, 844),
              textScaler: TextScaler.linear(2),
            ),
            child: Scaffold(
              body: Padding(
                padding: EdgeInsets.all(20),
                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      SizedBox(width: 16),
                      Expanded(
                        child: LiturgicalHeadingText(
                          'XXVII звычайны тыдзень',
                          maxWidth: 264,
                          style: TextStyle(fontSize: 29),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final paragraph = tester.renderObject<RenderParagraph>(
        find.text('XXVII звычайны тыдзень'),
      );
      expect(
        paragraph.getBoxesForSelection(
          const TextSelection(baseOffset: 6, extentOffset: 14),
        ),
        hasLength(1),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('320 dp at 200 percent keeps whole Belarusian heading words', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var opens = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 844),
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const LiturgicalHeadingText(
                    'Літургічны дзень',
                    style: TextStyle(fontSize: 33),
                  ),
                  LiturgicalDateNavigationRow(
                    date: DateTime(2026, 10, 13),
                    keyPrefix: 'date',
                    onDateTap: () => opens++,
                    onPrevious: () {},
                    onNext: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    final title = find.text('Літургічны дзень');
    final paragraph = tester.renderObject<RenderParagraph>(title);
    expect(
      paragraph.getBoxesForSelection(
        const TextSelection(baseOffset: 0, extentOffset: 10),
      ),
      hasLength(1),
    );
    expect(tester.widget<Text>(title).style!.fontSize, 33);
    final dateText = find.byWidgetPredicate(
      (widget) =>
          widget is Text && (widget.data?.contains('кастрычніка') ?? false),
    );
    final text = tester.widget<Text>(dateText).data!;
    final start = text.indexOf('кастрычніка');
    final dateParagraph = tester.renderObject<RenderParagraph>(dateText);
    expect(
      dateParagraph.getBoxesForSelection(
        TextSelection(
          baseOffset: start,
          extentOffset: start + 'кастрычніка'.length,
        ),
      ),
      hasLength(1),
    );
    // The full date, including the year, is now a single calendar action.
    expect(find.textContaining('2026'), findsWidgets);
    await tester.tap(find.byKey(const Key('date-date-action')));
    expect(opens, 1);
    expect(tester.takeException(), isNull);
  });
}
