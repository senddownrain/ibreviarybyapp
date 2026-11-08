import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
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

  testWidgets('all five reader families resolve offline in every theme', (
    tester,
  ) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    for (final brightness in Brightness.values) {
      final styles = <String, TextStyle>{};
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: Builder(
            builder: (context) {
              for (final option in kAvailableReaderFonts) {
                styles[option.id] = ReaderTheme.of(
                  context,
                ).body(28.8, family: option.id);
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(
        styles[ReaderFontFamily.oldStandardTT]!.fontFamily,
        startsWith('OldStandardTT'),
      );
      expect(styles[ReaderFontFamily.kurale]!.fontFamily, startsWith('Kurale'));
      expect(styles[ReaderFontFamily.system]!.fontFamily, isNull);
      expect(
        styles.values.every(
          (s) => s.fontSize == 28.8 && s.height == ReaderTheme.bodyHeight,
        ),
        isTrue,
      );
      await tester.runAsync(() => GoogleFonts.pendingFonts());
    }
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

  testWidgets('document roles keep meaning in light and dark themes', (
    tester,
  ) async {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      late ReaderTheme reader;
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey(brightness),
          theme: ThemeData(brightness: brightness),
          home: Builder(
            builder: (context) {
              reader = ReaderTheme.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      final title = reader.documentTitle();
      final body = reader.body(18, family: ReaderFontFamily.sourceSerif4);
      final major = reader.majorHeading(18);
      final block = reader.blockHeading(18);
      final rubric = reader.rubricBlock(18);
      final reference = reader.referenceStyle(18);
      final source = reader.sourceStyle(18);

      expect(title.fontFamily, startsWith('CormorantGaramond'));
      expect(title.fontSize, ReaderTheme.documentTitleSize);
      expect(title.color, reader.ink);
      expect(body.fontFamily, startsWith('SourceSerif4'));
      expect(major.fontSize, greaterThan(block.fontSize!));
      expect(major.color, reader.rubric);
      expect(rubric.color, reader.rubric);
      expect(rubric.fontStyle, FontStyle.normal);
      expect(rubric.fontSize, 16.2);
      expect(rubric.height, ReaderTheme.rubricHeight);
      expect(reference.color, reader.muted);
      expect(reference.height, ReaderTheme.referenceHeight);
      expect(source.color, reader.muted);
      expect(source.height, ReaderTheme.metadataHeight);
    }
  });
}
