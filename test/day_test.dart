import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/models/day.dart';

void main() {
  test('dynamic liturgical fields accept Firestore numbers', () {
    final day = LiturgicalDay.fromMap({
      'id': 'ordinary-24-4',
      '_periodWeekNumber': '24',
      '_dayOfWeek': 4,
    });

    expect(day.periodWeekNumber, 24);
    expect(day.dayOfWeek, 4);
    expect(day.field('_dayOfWeek'), '4');
  });
}
