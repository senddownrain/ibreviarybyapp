import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/models/day.dart';
import 'package:mybrev_flutter/utils/liturgical_vespers.dart';

LiturgicalDay day(String id, Map<String, dynamic> fields) =>
    LiturgicalDay.fromMap({'id': id, ...fields});

void main() {
  test('I Vespers uses Saturday source, never Sunday II Vespers', () {
    final sunday = day('ordinary-w11-d1', {
      'vesperHymn': 'II hymn',
      'vesperPs1': 'II psalm',
      'vesperAntMag': 'II Magnificat',
    });
    final saturday = day('ordinary-w10-d7', {
      'vesperHymn': 'I hymn',
      'vesperPs1': 'I psalm',
      'vesperAntMag': 'I Magnificat',
    });
    final first = assembleOrdinarySundayFirstVespers(sunday, saturday);
    expect(first.id, sunday.id);
    expect(first.field('vesperHymn'), 'I hymn');
    expect(first.field('vesperPs1'), 'I psalm');
    expect(first.field('vesperAntMag'), 'I Magnificat');
    expect(first.field('vesperHymn'), isNot(sunday.field('vesperHymn')));
    expect(first.data['_firstVespersSource'], 'saturday-psalter');
    expect((first.data['_missingFirstVespersFields'] as List), contains('Pr'));
    expect(first.field('vesperPr'), isEmpty);
  });

  test('explicit I Vespers Proper has precedence over Saturday psalter', () {
    final sunday = day('sunday', {
      'vesper1AntMag': 'I Sunday Proper',
      'vesper1Hymn': '  ',
      'vesperAntMag': 'wrong II Sunday',
      'vesperHymn': 'wrong II hymn',
    });
    final saturday = day('saturday', {
      'vesperHymn': 'Saturday hymn',
      'vesperAntMag': 'Saturday antiphon',
    });
    final first = assembleOrdinarySundayFirstVespers(sunday, saturday);
    expect(first.field('vesperHymn'), 'Saturday hymn');
    expect(first.field('vesperAntMag'), 'I Sunday Proper');
    expect(first.data['_firstVespersSource'], 'vesper1+saturday-psalter');
    expect(first.field('vesperR'), isEmpty, reason: 'do not invent text');
  });

  test('celebrations other than ordinary Sundays keep their own Vespers fallback', () {
    final feast = day('solemnity', {
      'vesperHymn': 'celebration hymn',
      'vesper1AntMag': 'own first antiphon',
      'vesperAntMag': 'second antiphon',
    });
    final first = assembleFirstVespers(feast);
    expect(first.field('vesperHymn'), 'celebration hymn');
    expect(first.field('vesperAntMag'), 'own first antiphon');
    expect(first.data['_firstVespersSource'], 'vesper1+proper');
  });
}
