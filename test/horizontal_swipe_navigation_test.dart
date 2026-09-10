import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/widgets/horizontal_swipe_navigation.dart';

void main() {
  testWidgets('left and right swipes navigate next and previous', (
    tester,
  ) async {
    var previous = 0;
    var next = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: HorizontalSwipeNavigation(
          onPrevious: () => previous++,
          onNext: () => next++,
          child: const Scaffold(body: SizedBox.expand()),
        ),
      ),
    );

    await tester.drag(
      find.byKey(const Key('horizontal-swipe-navigation')),
      const Offset(-120, 0),
    );
    await tester.pump();
    expect(next, 1);
    expect(previous, 0);

    await tester.drag(
      find.byKey(const Key('horizontal-swipe-navigation')),
      const Offset(120, 0),
    );
    await tester.pump();
    expect(next, 1);
    expect(previous, 1);
  });

  testWidgets('a short movement does not navigate', (tester) async {
    var navigations = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: HorizontalSwipeNavigation(
          onPrevious: () => navigations++,
          onNext: () => navigations++,
          child: const Scaffold(body: SizedBox.expand()),
        ),
      ),
    );

    final gesture = await tester.startGesture(const Offset(200, 200));
    await gesture.moveBy(
      const Offset(30, 2),
      timeStamp: const Duration(seconds: 1),
    );
    await gesture.up(timeStamp: const Duration(seconds: 2));
    await tester.pump();

    expect(navigations, 0);
  });
}
