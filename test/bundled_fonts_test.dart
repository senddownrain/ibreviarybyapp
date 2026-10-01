// The reader faces must not depend on the network: google_fonts loads a
// variant from assets/google_fonts when a file with its exact name is bundled.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every reader face variant is bundled and declared', () {
    const variants = [
      'CormorantGaramond-Bold', // ReaderTheme.displayTitle (w700)
      'Literata-Regular', // ReaderTheme.body, default family
      'SourceSerif4-Regular', // ReaderTheme.body, Source Serif 4
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
}
