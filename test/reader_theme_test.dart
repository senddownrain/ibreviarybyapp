import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/theme/reader.dart';

void main() {
  testWidgets('book and system reader preferences resolve differently', (
    tester,
  ) async {
    late TextStyle book;
    late TextStyle system;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            final reader = ReaderTheme.of(context);
            book = reader.body(16, family: ReaderFontFamily.literata);
            system = reader.body(16, family: ReaderFontFamily.system);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(book.fontFamily, startsWith('Literata'));
    expect(system.fontFamily, isNull);
    expect(book.height, ReaderTheme.bodyHeight);
  });

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

    expect(heading.fontSize, greaterThanOrEqualTo(22));
    expect(heading.fontSize, greaterThan(16));
    expect(heading.fontWeight, FontWeight.w700);
    expect(heading.fontFamily, startsWith('CormorantGaramond'));
  });
}
