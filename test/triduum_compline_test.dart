import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/models/day.dart';
import 'package:mybrev_flutter/utils/hours_liturgical_options.dart';
import 'package:mybrev_flutter/utils/triduum_compline.dart';

LiturgicalDay litDay(int weekday, String officeKind, {int? complineDay}) =>
    LiturgicalDay.fromMap({
      'id': 'day',
      '_periodType': 'holyweek',
      '_dayOfWeek': weekday,
      '_ordoOfficeKind': officeKind,
      if (complineDay != null) '_ordoComplineDay': complineDay,
    });

void main() {
  test('three different Triduum antiphons match the printed breviary', () {
    final a = triduumAntiphon(litDay(5, 'triduum'));
    final b = triduumAntiphon(litDay(6, 'triduum'));
    final c = triduumAntiphon(litDay(7, 'triduum'));
    expect({a, b, c}.length, 3);
    expect(a, contains('ажно да смерці'));
    expect(b, contains('смерці крыжовай'));
    expect(c, contains('Таму Бог узвысіў Яго'));
    expect(triduumAntiphon(litDay(4, 'weekday')), isEmpty);
  });

  test('Vespers and Compline rubrics occur only on their own days', () {
    expect(triduumVespersNotice(litDay(5, 'triduum')), contains('Вячэры Пана'));
    expect(triduumVespersNotice(litDay(6, 'triduum')), contains('Літургіі Мукі Пана'));
    expect(triduumComplineNotice(litDay(7, 'triduum')), contains('Пасхальнай вігіліі'));
    expect(goodFridayIntercessionsRubric(litDay(6, 'triduum')), contains('Імшале'));
    expect(goodFridayIntercessionsRubric(litDay(5, 'triduum')), isEmpty);
  });

  test('Ordo Compline template weekday is preserved through the local day', () {
    expect(
      completoriumRecordIdForDay(litDay(6, 'triduum', complineDay: 1)),
      'lent-d1',
    );
    final eveOfSolemnity = LiturgicalDay.fromMap({
      'id': 'eve',
      '_periodType': 'ordinary',
      '_dayOfWeek': 3,
      '_ordoComplineDay': 7,
    });
    expect(completoriumRecordIdForDay(eveOfSolemnity), 'ordinary-d7');
  });

  test('non-Sunday solemnities and Triduum use prayer number two', () {
    expect(specialComplinePrayer(litDay(6, 'triduum')), contains('наведай гэты дом'));
    final solemnity = LiturgicalDay.fromMap({
      'id': 'solemnity',
      '_periodType': 'ordinary',
      '_dayOfWeek': 3,
      '_ordoOfficeKind': 'solemnity',
    });
    expect(specialComplinePrayer(solemnity), contains('наведай гэты дом'));
    expect(specialComplinePrayer(litDay(1, 'sunday')), isEmpty);
  });
}
