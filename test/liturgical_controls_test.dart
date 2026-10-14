import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mybrev_flutter/constants/liturgical.dart';
import 'package:mybrev_flutter/widgets/liturgical_calendar_disclosure.dart';
import 'package:mybrev_flutter/widgets/liturgical_date_navigation_row.dart';

void main() {
  setUpAll(() => initializeDateFormatting('be'));

  for (final date in [
    DateTime(2026, 4, 4),
    DateTime(2026, 10, 9),
    DateTime(2026, 10, 11),
  ]) {
    for (final scale in [1.0, 2.0]) {
      for (final dark in [false, true]) {
        testWidgets(
          'date $date at 320dp scale $scale dark $dark has aligned, reachable controls',
          (tester) async {
            tester.view.physicalSize = const Size(320, 844);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            final events = <String>[];
            await tester.pumpWidget(
              MaterialApp(
                theme: ThemeData(
                  brightness: dark ? Brightness.dark : Brightness.light,
                ),
                home: MediaQuery(
                  data: MediaQueryData(
                    size: const Size(320, 844),
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: Scaffold(
                    body: LiturgicalDateNavigationRow(
                      date: date,
                      keyPrefix: 'day',
                      onDateTap: () => events.add('date'),
                      onPrevious: () => events.add('previous'),
                      onNext: () => events.add('next'),
                    ),
                  ),
                ),
              ),
            );
            final dateControl = find.byKey(const Key('day-date-action'));
            final previous = find.byKey(const Key('day-previous-day'));
            final next = find.byKey(const Key('day-next-day'));
            expect(
              tester.getSize(dateControl).height,
              greaterThanOrEqualTo(48),
            );
            expect(tester.getSize(previous), const Size(48, 48));
            expect(tester.getSize(next), const Size(48, 48));
            expect(tester.getCenter(previous).dy, tester.getCenter(next).dy);
            expect(tester.getCenter(dateControl).dx, 160);
            await tester.tap(dateControl);
            await tester.tap(previous);
            await tester.tap(next);
            expect(events, ['date', 'previous', 'next']);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  testWidgets('date bounds disable only the unavailable day arrow', (
    tester,
  ) async {
    for (final date in [kCalendarFirstDate, kCalendarLastDate]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LiturgicalDateNavigationRow(
              date: date,
              keyPrefix: 'day',
              onDateTap: () {},
              onPrevious: () {},
              onNext: () {},
            ),
          ),
        ),
      );
      expect(
        tester
                .widget<IconButton>(find.byKey(const Key('day-previous-day')))
                .onPressed ==
            null,
        date == kCalendarFirstDate,
      );
      expect(
        tester
                .widget<IconButton>(find.byKey(const Key('day-next-day')))
                .onPressed ==
            null,
        date == kCalendarLastDate,
      );
    }
  });

  for (final initiallyExpanded in [false, true]) {
    testWidgets(
      'calendar disclosure announces and retains its toggled state from $initiallyExpanded',
      (tester) async {
        var expanded = initiallyExpanded;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) => LiturgicalCalendarDisclosure(
                  controlKey: const Key('calendar-toggle'),
                  expanded: expanded,
                  date: DateTime(2026, 10, 13),
                  onChanged: (value) => setState(() => expanded = value),
                  calendar: const Text('Calendar content'),
                ),
              ),
            ),
          ),
        );
        expect(find.text('Каляндар'), findsOneWidget);
        expect(find.text('13 кастрычніка 2026'), findsOneWidget);
        expect(
          tester.getSize(find.byKey(const Key('calendar-toggle'))).height,
          greaterThanOrEqualTo(48),
        );
        for (var i = 0; i < 2; i++) {
          await tester.tap(find.byKey(const Key('calendar-toggle')));
          await tester.pumpAndSettle();
          expect(find.text('Каляндар'), findsOneWidget);
          expect(
            find.byWidgetPredicate(
              (widget) =>
                  widget is Semantics && widget.properties.expanded == expanded,
            ),
            findsOneWidget,
          );
          expect(
            find.text('Calendar content'),
            expanded ? findsOneWidget : findsNothing,
          );
          expect(tester.takeException(), isNull);
        }
      },
    );
  }
}
