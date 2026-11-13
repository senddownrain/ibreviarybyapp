import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/feedback/feedback_models.dart';

Map<String, String>? ctx(String uri) {
  final location = feedbackLocationForUri(Uri.parse(uri));
  return location == null ? null : Uri.parse(location).queryParameters;
}

void main() {
  test('materials get an automatic context from the route', () {
    expect(ctx('/prayers/prayer/abc-1'), {
      'ctx_kind': 'prayer',
      'ctx_id': 'abc-1',
    });
    expect(ctx('/prayer/abc-1'), {'ctx_kind': 'prayer', 'ctx_id': 'abc-1'});
    expect(ctx('/prayers/songs/s42'), {'ctx_kind': 'song', 'ctx_id': 's42'});
    expect(ctx('/readings?date=2026-11-13'), {
      'ctx_kind': 'reading',
      'ctx_date': '2026-11-13',
    });
    expect(ctx('/readings/reading/r9'), {
      'ctx_kind': 'reading',
      'ctx_id': 'r9',
    });
    expect(ctx('/hours/ora/2026-11-13/day-1/lauds'), {
      'ctx_kind': 'hour',
      'ctx_id': 'day-1',
      'ctx_date': '2026-11-13',
      'ctx_hour': 'lauds',
    });
    expect(ctx('/ora/2026-11-13/day-1/unknown')?['ctx_hour'], 'other');
    expect(ctx('/hours/hora/2026-11-13/day-1'), {
      'ctx_kind': 'day',
      'ctx_id': 'day-1',
      'ctx_date': '2026-11-13',
    });
    expect(ctx('/bible/ru/jn/3'), {'ctx_kind': 'bible', 'ctx_id': 'ru-jn-3'});
    expect(ctx('/prayers/compendium/question/12'), {
      'ctx_kind': 'compendium',
      'ctx_id': '12',
    });
  });

  test('non-material screens and editors get no report entry', () {
    for (final uri in [
      '/',
      '/hours',
      '/hours/picker',
      '/readings/picker',
      '/prayers',
      '/prayers/all',
      '/prayers/categories',
      '/prayers/prayer/add',
      '/prayers/prayer/x/edit',
      '/prayer/edit/x',
      '/bible',
      '/bible/search',
      '/settings',
      '/settings/feedback',
      '/about',
    ]) {
      expect(feedbackLocationForUri(Uri.parse(uri)), isNull, reason: uri);
    }
  });

  test('unsafe route values are dropped, not forwarded', () {
    final q = ctx('/prayers/prayer/a%20b%3Cscript%3E');
    expect(q?.containsKey('ctx_id'), isFalse);
  });
}
