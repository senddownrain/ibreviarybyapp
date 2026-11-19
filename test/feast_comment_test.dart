import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/models/day.dart';

void main() {
  group('LiturgicalDay feast comment', () {
    test('solemnity-only comment is not repeated under the day header', () {
      final christKing = LiturgicalDay.fromMap({
        'id': 'christ-king',
        'rank': 'solemnitas',
        'feastComment': ' Урачыстасць ',
      });
      final christmas = LiturgicalDay.fromMap({
        'id': 'christmas',
        'rank': 'solemnitas',
        'feastComment': '<p>Урачыстасць</p>',
      });

      expect(christKing.feastComment, isNull);
      expect(christmas.feastComment, isNull);
    });

    test('other standalone rank labels are also treated as metadata', () {
      for (final text in ['Свята', 'Успамін', 'Неабавязковы ўспамін']) {
        final day = LiturgicalDay.fromMap({
          'id': 'test',
          'comment': text,
        });
        expect(day.feastComment, isNull, reason: text);
      }
    });

    test('substantive comments remain intact', () {
      for (final text in [
        'Урачыстасць Пана нашага Езуса Хрыста.',
        'Заўтра',
        '<p>Урачыстасць. Адпуст у святыні.</p>',
      ]) {
        final day = LiturgicalDay.fromMap({
          'id': 'test',
          'feastComment': text,
        });
        expect(day.feastComment, text);
      }
    });
  });
}
