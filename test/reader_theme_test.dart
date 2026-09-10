import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/theme/reader.dart';

void main() {
  testWidgets('liturgical block headings are larger than reader body text', (
    tester,
  ) async {
    late TextStyle heading;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            heading = ReaderTheme.of(context).blockHeading(16);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(heading.fontSize, 18);
    expect(heading.fontSize, greaterThan(16));
    expect(heading.fontWeight, FontWeight.w600);
  });
}
