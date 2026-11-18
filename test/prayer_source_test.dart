import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/dev/devotional_office_harness.dart';
import '../tool/prayer_source_smoke.dart'
    show sourceSmokePrayer, sourceOfficeId;
import 'package:mybrev_flutter/models/prayer.dart';
import 'package:mybrev_flutter/widgets/prayer_content.dart';

void main() {
  test('old bundle without source still decodes', () {
    final prayer = Prayer.fromMap({'title': 'Малітва', 'text': 'Тэкст'}, 'old');
    expect(prayer.source, isNull);
    expect(prayer.displayText, 'Тэкст');
  });

  test('source survives bundle decode, copy and local serialization', () {
    for (final source in ['Бог добры', 'Літургія гадзін', 'Невядомая кніга']) {
      final prayer = Prayer.fromMap({
        'title': 'Малітва',
        'text': 'Пс 23, 1–6',
        'source': source,
      }, 'p');
      expect(prayer.copyWith(body: 'Тэкст').source, source);
      expect(Prayer.fromMap(prayer.toMap(), 'p').source, source);
      expect(prayer.displayText, 'Пс 23, 1–6');
    }
  });

  test('prayer pages survive decoding and serialization', () {
    final prayer = Prayer.fromMap({
      'title': 'Малітва',
      'pages': '34–36',
    }, 'p');
    expect(prayer.pages, '34–36');
    expect(prayer.copyWith(body: 'Іншы тэкст').pages, '34–36');
    expect(Prayer.fromMap(prayer.toMap(), 'p').pages, '34–36');
  });

  testWidgets('reader source note displays the canonical server value', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PrayerSourceNote(
            source: 'Бог добры',
            textStyle: TextStyle(fontSize: 18),
          ),
        ),
      ),
    );
    expect(find.text('Крыніца: Бог добры'), findsOneWidget);
  });

  testWidgets('legacy record without a source has no empty footer', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PrayerSourceNote(textStyle: TextStyle(fontSize: 18)),
        ),
      ),
    );
    expect(find.byKey(const Key('prayer-source')), findsNothing);
  });
  testWidgets('production ordinary reader preserves the source and Scripture', (
    tester,
  ) async {
    await tester.pumpWidget(
      DevotionalOfficeHarness(
        prayers: [sourceSmokePrayer.copyWith(pages: '26–27')],
        initialId: sourceSmokePrayer.id,
        systemFonts: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Крыніца: Бог добры'), findsOneWidget);
    expect(find.text('26–27'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('production devotional reader displays canonical source', (
    tester,
  ) async {
    final bundle = decodeContentCollection(
      (await rootBundle.load(
        'assets/content/prayers.json.gz',
      )).buffer.asUint8List(),
    );
    final office = Prayer.fromMap(
      bundle.docs[sourceOfficeId]!,
      sourceOfficeId,
    ).copyWith(source: 'Літургія гадзін', pages: '78–80');
    await tester.pumpWidget(
      DevotionalOfficeHarness(
        prayers: [office],
        initialId: sourceOfficeId,
        systemFonts: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Крыніца: Літургія гадзін'), findsOneWidget);
    expect(find.text('78–80'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
