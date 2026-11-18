import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/ordo/engine.dart';

void main() {
  test('Holy Family calendar title uses the genitive with the installed older bundle', () {
    final option = OrdoOption({
      'id': 'holy-family',
      'title': 'Святая Сям’я: Езус, Марыя і Юзаф',
      'rank': 'festum',
    });
    expect(option.title, 'Святой Сям’і: Езуса, Марыі і Юзафа');
    expect(option.rank, 'festum');
    expect(option.id, 'holy-family');
  });

  test('other celebrations keep their own titles unchanged', () {
    final option = OrdoOption({
      'id': 'sv-patryk',
      'title': 'Св. Патрыка, біскупа',
      'rank': 'memoria-ad-libitum',
    });
    expect(option.title, 'Св. Патрыка, біскупа');
  });
}
