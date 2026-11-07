// The reader faces must not depend on the network: google_fonts loads a
// variant from assets/google_fonts when a file with its exact name is bundled.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every reader face variant is bundled and declared', () {
    const variants = [
      'CormorantGaramond-Bold', // ReaderTheme.displayTitle (w700)
      'Literata-Regular', // ReaderTheme.body, default family
      'SourceSerif4-Regular', // ReaderTheme.body, Source Serif 4
      'OldStandardTT-Regular',
      'Kurale-Regular',
    ];
    for (final name in variants) {
      expect(
        File('assets/google_fonts/$name.ttf').existsSync(),
        isTrue,
        reason: name,
      );
    }
    expect(
      File('pubspec.yaml').readAsStringSync(),
      contains('- assets/google_fonts/'),
    );
  });
  for (final (family, license) in [
    ('OldStandardTT', 'oldstandardtt'),
    ('Kurale', 'kurale'),
  ]) {
    test('$family contains real Belarusian glyphs and a bundled OFL', () {
      final bytes = File(
        'assets/google_fonts/$family-Regular.ttf',
      ).readAsBytesSync();
      final data = ByteData.sublistView(bytes);
      // TrueType cmap format 4, the BMP mapping used by both upstream fonts.
      var cmap = 0;
      for (var i = 0; i < data.getUint16(4); i++) {
        final record = 12 + i * 16;
        if (String.fromCharCodes(bytes.sublist(record, record + 4)) == 'cmap') {
          cmap = data.getUint32(record + 8);
        }
      }
      expect(cmap, greaterThan(0));
      var format4 = 0;
      for (var i = 0; i < data.getUint16(cmap + 2); i++) {
        final offset = cmap + data.getUint32(cmap + 4 + i * 8 + 4);
        if (data.getUint16(offset) == 4) {
          format4 = offset;
          break;
        }
      }
      expect(format4, greaterThan(0));
      final segments = data.getUint16(format4 + 6) ~/ 2;
      int glyph(int code) {
        for (var i = 0; i < segments; i++) {
          final end = data.getUint16(format4 + 14 + 2 * i);
          final start = data.getUint16(format4 + 16 + 2 * segments + 2 * i);
          if (code < start || code > end) continue;
          final delta = data.getInt16(format4 + 16 + 4 * segments + 2 * i);
          final rangeAt = format4 + 16 + 6 * segments + 2 * i;
          final range = data.getUint16(rangeAt);
          if (range == 0) return (code + delta) & 0xffff;
          final index = data.getUint16(rangeAt + range + 2 * (code - start));
          return index == 0 ? 0 : (index + delta) & 0xffff;
        }
        return 0;
      }

      for (final code in 'ўЎіІёЁ'.runes) {
        expect(glyph(code), isNot(0), reason: String.fromCharCode(code));
      }
      expect(
        File('assets/google_fonts/OFL-$license.txt').readAsStringSync(),
        contains('SIL OPEN FONT LICENSE'),
      );
      expect(File('lib/main.dart').readAsStringSync(), contains("'$license':"));
    });
  }
}
