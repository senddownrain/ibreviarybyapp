import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/widgets/reader/reader_navigation.dart';

void main() {
  test('readings route preserves the Ora date and selected day context', () {
    final route = readingsRouteForContext(
      date: DateTime(2026, 9, 9),
      dayId: 'fixed/peter claver',
    );
    final uri = Uri.parse(route);

    expect(uri.path, '/readings');
    expect(uri.queryParameters['date'], '2026-09-09');
    expect(uri.queryParameters['dayId'], 'fixed/peter claver');
  });

  test('readings route omits an empty optional day context', () {
    expect(
      readingsRouteForContext(date: DateTime(2026, 9, 9), dayId: '  '),
      '/readings?date=2026-09-09',
    );
  });

  test('Ora route safely carries the selected day and hour', () {
    final route = oraRouteForContext(
      date: DateTime(2026, 9, 9),
      dayId: 'fixed/peter claver',
      oraType: 'laudes',
    );
    final uri = Uri.parse(route);

    expect(uri.pathSegments, [
      'hours',
      'ora',
      '2026-09-09',
      'fixed/peter claver',
      'laudes',
    ]);
  });

  test('Hora route encodes a day id as one path segment', () {
    final route = horaRouteForContext(
      date: DateTime(2026, 9, 9),
      dayId: 'fixed/peter claver',
    );

    expect(Uri.parse(route).pathSegments, [
      'hours',
      'hora',
      '2026-09-09',
      'fixed/peter claver',
    ]);
  });
}
