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

  test('pages field survives Firestore and local serialization', () {
    for (final (raw, expected) in [
      ('34–36', '34–36'),
      (42, '42'),
    ]) {
      final prayer = Prayer.fromMap({
        'title': 'Малітва',
        'text': 'Тэкст',
        'pages': raw,
      }, 'p');
      expect(prayer.pages, expected);
      expect(prayer.copyWith(body: 'Іншы тэкст').pages, expected);
      expect(Prayer.fromMap(prayer.toMap(), 'p').pages, expected);
    }
    expect(Prayer.fromMap({'title': 'Малітва'}, 'old').pages, isNull);
  });

  testWidgets('pages note is modest and omitted for blank values', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              PrayerPagesNote(pages: ' 12–14 ', textStyle: TextStyle(fontSize: 18)),
              PrayerPagesNote(pages: ' ', textStyle: TextStyle(fontSize: 18)),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Старонкі: 12–14'), findsOneWidget);
    expect(find.byKey(const Key('prayer-pages')), findsOneWidget);
    final note = tester.widget<Text>(find.byKey(const Key('prayer-pages')));
    expect(note.style!.fontSize, lessThan(18));
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
    expect(find.text('Старонкі: 26–27'), findsOneWidget);
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
    expect(find.text('Старонкі: 78–80'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
