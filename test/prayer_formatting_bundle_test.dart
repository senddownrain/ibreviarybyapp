import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' show parseFragment;
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/models/prayer.dart';
import 'package:mybrev_flutter/services/priest_access_policy.dart';
import 'package:mybrev_flutter/utils/prayer_markdown.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'real bundled short prayer and litany render offline without source changes',
    () async {
      final prayers = decodeContentCollection(
        (await rootBundle.load(
          'assets/content/prayers.json.gz',
        )).buffer.asUint8List(),
      );
      final categories = decodeContentCollection(
        (await rootBundle.load(
          'assets/content/prayerCategories.json.gz',
        )).buffer.asUint8List(),
      );
      final policy = PriestAccessPolicy(categories.docs);
      final public = [
        for (final entry in prayers.docs.entries)
          if (!policy.prayerRestricted(entry.value))
            Prayer.fromMap(entry.value, entry.key),
      ];
      final litany = public.firstWhere(
        (prayer) => prayer.id == 'YYn88Cm7zbOelAtb03aQ',
      );
      final short = public.firstWhere(
        (prayer) =>
            prayer.isMarkdown &&
            prayer.displayText.length > 40 &&
            prayer.displayText.length < 600,
      );
      for (final prayer in [short, litany]) {
        final source = prayer.displayText;
        final doc = parseFragment(prayerMarkdownToHtml(source));
        expect(doc.text!.trim(), isNotEmpty);
        expect(doc.querySelectorAll('script, iframe, img'), isEmpty);
        expect(prayer.toMap()['text'], source);
      }
      final doc = parseFragment(prayerMarkdownToHtml(litany.displayText));
      expect(doc.text, contains('Святы Міхале, слаўны князю,'));
      expect(doc.querySelectorAll('br').length, greaterThan(20));
      expect(
        doc.querySelectorAll('.prayer-speaker').map((e) => e.text),
        contains('С.:'),
      );
      expect(doc.querySelectorAll('em'), isNotEmpty);
    },
  );
}
