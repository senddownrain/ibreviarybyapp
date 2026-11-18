import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/theme/ib_colors.dart';
import 'package:mybrev_flutter/theme/liturgical_document.dart';
import 'package:mybrev_flutter/theme/reader.dart';

void main() {
  for (final width in [320.0, 390.0, 768.0, 1440.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final colors in [IbColors.light, IbColors.dark, IbColors.marian]) {
        testWidgets(
          'reading reference wraps right, normal weight at $width/$scale/${colors.rubric}',
          (tester) async {
            tester.view.physicalSize = Size(width, 900);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            await tester.pumpWidget(
              ReaderTypographyScope(
                useSystemFonts: true,
                child: MaterialApp(
                  theme: ThemeData(extensions: [colors]),
                  home: MediaQuery(
                    data: MediaQueryData(
                      size: Size(width, 900),
                      textScaler: TextScaler.linear(scale),
                    ),
                    child: const Scaffold(
                      body: Padding(
                        padding: EdgeInsets.all(20),
                        child: LiturgicalHeadingReferenceRow(
                          title: 'Кароткае чытанне',
                          reference: 'Рым 13, 11б. 12–13а',
                          bodySize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            final title = find.text('КАРОТКАЕ ЧЫТАННЕ'),
                ref = find.text('Рым 13, 11б. 12–13а');
            final text = tester.widget<Text>(ref);
            expect(text.style!.fontWeight, FontWeight.normal);
            expect(text.style!.color, colors.rubric);
            expect(text.textAlign, TextAlign.right);
            expect(tester.getTopRight(ref).dx, closeTo(width - 20, 1));
            if (width == 320 && scale == 2) {
              expect(
                tester.getTopLeft(ref).dy,
                greaterThanOrEqualTo(tester.getBottomLeft(title).dy),
              );
            }
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
