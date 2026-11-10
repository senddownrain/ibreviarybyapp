import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mybrev_flutter/widgets/liturgical_date_navigation_row.dart';

void main() {
  setUpAll(() async => initializeDateFormatting('be'));

  for (final width in <double>[320, 390]) {
    for (final scale in <double>[1, 2]) {
      for (final brightness in Brightness.values) {
        testWidgets(
          'date pill keeps Today slot stable at $width, scale $scale, $brightness',
          (tester) async {
            await tester.binding.setSurfaceSize(Size(width, 800));
            addTearDown(() => tester.binding.setSurfaceSize(null));
            var date = DateUtils.dateOnly(DateTime.now());
            var calendarOpens = 0;

            await tester.pumpWidget(
              MaterialApp(
                theme: ThemeData(
                  useMaterial3: true,
                  brightness: brightness,
                ),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: child!,
                ),
                home: Scaffold(
                  body: Padding(
                    padding: const EdgeInsets.all(22),
                    child: StatefulBuilder(
                      builder: (context, refresh) =>
                          LiturgicalDateNavigationRow(
                            date: date,
                            keyPrefix: 'test',
                            onDateTap: () => calendarOpens++,
                            onPrevious: () => refresh(
                              () => date = date.subtract(const Duration(days: 1)),
                            ),
                            onNext: () => refresh(
                              () => date = date.add(const Duration(days: 1)),
                            ),
                            onToday: () => refresh(
                              () => date = DateUtils.dateOnly(DateTime.now()),
                            ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();

            final action = find.byKey(const Key('test-date-action'));
            final originalX = tester.getCenter(action).dx;
            expect(find.byKey(const Key('test-date-control')), findsOneWidget);
            expect(find.byKey(const Key('test-today')), findsNothing);

            await tester.tap(find.byKey(const Key('test-previous-day')));
            await tester.pumpAndSettle();
            expect(find.byKey(const Key('test-today')), findsOneWidget);
            expect(find.byTooltip('Вярнуцца на сёння'), findsOneWidget);
            expect(find.text('Сёння'), findsNothing);
            expect(tester.getCenter(action).dx, closeTo(originalX, 0.1));

            await tester.tap(action);
            expect(calendarOpens, 1);

            await tester.tap(find.byKey(const Key('test-today')));
            await tester.pumpAndSettle();
            expect(DateUtils.isSameDay(date, DateTime.now()), isTrue);
            expect(find.byKey(const Key('test-today')), findsNothing);
            expect(tester.getCenter(action).dx, closeTo(originalX, 0.1));
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
