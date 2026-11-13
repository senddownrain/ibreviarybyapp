import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mybrev_flutter/feedback/feedback_models.dart';
import 'package:mybrev_flutter/feedback/feedback_service.dart';
import 'package:mybrev_flutter/screens/feedback_screen.dart';

void main() {
  group('summary, attempt id and Ordo location', () {
    test('summary is human readable', () {
      expect(
        const FeedbackContext(kind: 'prayer', title: 'Ойча наш').summary,
        'Малітва · Ойча наш',
      );
      expect(
        const FeedbackContext(
          kind: 'hour',
          date: '2026-11-13',
          hour: 'lauds',
        ).summary,
        'Літургія гадзінаў · 2026-11-13 · Ютрань',
      );
      expect(const FeedbackContext(id: 'x1').summary, 'ID: x1');
    });

    test('attempt keeps the id for the same payload only', () {
      var n = 0;
      final a = FeedbackAttempt(() => 'id-${++n}');
      final first = a.idFor(['text_error', 'one']);
      expect(a.idFor(['text_error', 'one']), first);
      final second = a.idFor(['text_error', 'one edited']);
      expect(second, isNot(first));
      a.reset();
      expect(a.idFor(['text_error', 'one edited']), isNot(second));
    });

    test('Ordo day gets a context, the month grid does not', () {
      final q = Uri.parse(
        feedbackLocationForUri(
              Uri.parse('/hours/ordo?date=2026-11-13&dayId=d1'),
            ) ??
            '',
      ).queryParameters;
      expect(q, {'ctx_kind': 'day', 'ctx_id': 'd1', 'ctx_date': '2026-11-13'});
      expect(feedbackLocationForUri(Uri.parse('/hours/ordo/month')), isNull);
    });
  });

  group('context', () {
    test('keeps only whitelisted safe values', () {
      expect(FeedbackContext.fromQuery({}), isNull);
      expect(
        FeedbackContext.fromQuery({'ctx_kind': 'evil', 'ctx_id': '<x>'}),
        isNull,
      );
      final c = FeedbackContext.fromQuery({
        'ctx_kind': 'prayer',
        'ctx_id': 'abc-1',
        'ctx_date': '2026-11-06',
        'token': 'SECRET',
        'ctx_title': ' Ойча наш ',
      })!;
      expect(c.toJson(), {
        'kind': 'prayer',
        'id': 'abc-1',
        'date': '2026-11-06',
        'title': 'Ойча наш',
        'lang': 'be',
      });
      expect(jsonEncode(c.toJson()).contains('SECRET'), isFalse);
    });
    test('location round-trips through the query parser', () {
      final uri = Uri.parse(
        feedbackLocation(kind: 'prayer', id: 'p-1', title: 'Ойча наш'),
      );
      expect(uri.path, '/settings/feedback');
      expect(FeedbackContext.fromQuery(uri.queryParameters)!.id, 'p-1');
    });
  });

  test('validation', () {
    expect(validateFeedbackBody('  '), isNotNull);
    expect(validateFeedbackBody('x' * 4001), isNotNull);
    expect(validateFeedbackBody('Памылка'), isNull);
    expect(validateFeedbackEmail(''), isNull);
    expect(validateFeedbackEmail('nope'), isNotNull);
    expect(validateFeedbackEmail('a@b.by'), isNull);
  });

  group('service', () {
    FeedbackService svc(MockClient c) => FeedbackService(
      client: c,
      baseUrl: 'https://w.test/',
      platform: 'android',
    );
    Future<String> send(FeedbackService s) => s.submit(
      category: FeedbackCategory.textError,
      body: ' ТЭСТ ',
      requestId: '123e4567-e89b-12d3-a456-426614174000',
    );
    test(
      '201 returns id and payload carries only the contract fields',
      () async {
        late Map<String, dynamic> sent;
        final s = svc(
          MockClient((r) async {
            expect(r.url.toString(), 'https://w.test/api/feedback');
            sent = jsonDecode(r.body) as Map<String, dynamic>;
            return http.Response('{"id":"abc"}', 201);
          }),
        );
        expect(await send(s), 'abc');
        expect(sent['platform'], 'android');
        expect(sent['body'], 'ТЭСТ');
        expect(sent['sourceApp'], 'ibreviary_flutter');
        expect(sent.containsKey('email'), isFalse);
      },
    );
    test('failures map to explicit types and never auto-retry', () async {
      var calls = 0;
      FeedbackFailure? got;
      Future<void> run(int status) async {
        final s = svc(
          MockClient((r) async {
            calls++;
            return http.Response('{}', status);
          }),
        );
        try {
          await send(s);
        } on FeedbackException catch (e) {
          got = e.failure;
        }
      }

      await run(429);
      expect(got, FeedbackFailure.rateLimited);
      await run(503);
      expect(got, FeedbackFailure.unavailable);
      await run(400);
      expect(got, FeedbackFailure.rejected);
      expect(calls, 3);
      final offline = svc(
        MockClient((r) async => throw http.ClientException('offline')),
      );
      await expectLater(send(offline), throwsA(isA<FeedbackException>()));
      await expectLater(
        send(FeedbackService(baseUrl: '')),
        throwsA(isA<FeedbackException>()),
      );
    });
  });

  group('screen', () {
    void tall(WidgetTester t) {
      t.view.physicalSize = const Size(800, 2400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
    }

    Widget host(FeedbackService s, {FeedbackContext? ctx}) => MaterialApp(
      home: Scaffold(
        body: FeedbackScreen(service: s, context: ctx),
      ),
    );

    testWidgets(
      'validation, error keeps text, manual retry reuses request id, success shows ticket',
      (t) async {
        tall(t);
        final ids = <String>[];
        var fail = true;
        final s = FeedbackService(
          baseUrl: 'https://w.test',
          platform: 'ios',
          client: MockClient((r) async {
            ids.add((jsonDecode(r.body) as Map)['requestId'] as String);
            return fail
                ? http.Response('{}', 503)
                : http.Response('{"id":"T-1"}', 201);
          }),
        );
        await t.pumpWidget(
          host(
            s,
            ctx: const FeedbackContext(
              kind: 'prayer',
              id: 'p1',
              title: 'Ойча наш',
            ),
          ),
        );
        expect(find.byKey(const Key('feedback-context')), findsOneWidget);
        await tapSubmit(t);
        await t.pump();
        expect(find.text('Напішыце хаця б некалькі слоў.'), findsOneWidget);
        expect(ids, isEmpty);
        await t.enterText(
          find.byKey(const Key('feedback-body')),
          'ТЭСТ ANDROID ТЭКСТ',
        );
        await tapSubmit(t);
        await t.pumpAndSettle();
        expect(find.byKey(const Key('feedback-error')), findsOneWidget);
        expect(find.text('ТЭСТ ANDROID ТЭКСТ'), findsOneWidget);
        await t.pump(const Duration(seconds: 3));
        expect(ids.length, 1, reason: 'no automatic retry');
        fail = false;
        await tapSubmit(t);
        await t.pumpAndSettle();
        expect(ids.length, 2);
        expect(ids[0], ids[1]);
        expect(find.byKey(const Key('feedback-success')), findsOneWidget);
        expect(find.textContaining('T-1'), findsOneWidget);
      },
    );

    testWidgets(
      'an edited message after a failed attempt gets a new request id; an identical retry keeps it',
      (t) async {
        tall(t);
        final ids = <String>[];
        var attempt = 0;
        final s = FeedbackService(
          baseUrl: 'https://w.test',
          platform: 'android',
          client: MockClient((r) async {
            ids.add((jsonDecode(r.body) as Map)['requestId'] as String);
            attempt++;
            return attempt < 3
                ? http.Response('{}', 503)
                : http.Response('{"id":"T-2"}', 201);
          }),
        );
        await t.pumpWidget(host(s));
        await t.enterText(find.byKey(const Key('feedback-body')), 'first text');
        await tapSubmit(t);
        await t.pumpAndSettle();
        await tapSubmit(t); // identical retry
        await t.pumpAndSettle();
        expect(ids[0], ids[1], reason: 'identical retry stays idempotent');
        await t.enterText(
          find.byKey(const Key('feedback-body')),
          'first text, corrected',
        );
        await tapSubmit(t);
        await t.pumpAndSettle();
        expect(
          ids[2],
          isNot(ids[1]),
          reason: 'edited text must not reuse the id',
        );
        expect(find.byKey(const Key('feedback-success')), findsOneWidget);
      },
    );

    testWidgets('a 409 request_id_reused is retried once with a fresh id', (
      t,
    ) async {
      tall(t);
      final ids = <String>[];
      final s = FeedbackService(
        baseUrl: 'https://w.test',
        platform: 'ios',
        client: MockClient((r) async {
          ids.add((jsonDecode(r.body) as Map)['requestId'] as String);
          return ids.length == 1
              ? http.Response('{"error":"request_id_reused"}', 409)
              : http.Response('{"id":"T-3"}', 201);
        }),
      );
      await t.pumpWidget(host(s));
      await t.enterText(find.byKey(const Key('feedback-body')), 'some text');
      await tapSubmit(t);
      await t.pumpAndSettle();
      expect(ids.length, 2);
      expect(ids[0], isNot(ids[1]));
      expect(find.byKey(const Key('feedback-success')), findsOneWidget);
    });

    testWidgets('success screen: copyable id, return and write another', (
      t,
    ) async {
      tall(t);
      final clip = <String>[];
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clip.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(
        () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final s = FeedbackService(
        baseUrl: 'https://w.test',
        platform: 'android',
        client: MockClient((r) async => http.Response('{"id":"T-4"}', 201)),
      );
      await t.pumpWidget(
        host(
          s,
          ctx: const FeedbackContext(kind: 'song', id: 's1'),
        ),
      );
      await t.enterText(find.byKey(const Key('feedback-body')), 'good text');
      await tapSubmit(t);
      await t.pumpAndSettle();
      expect(find.byKey(const Key('feedback-id')), findsOneWidget);
      expect(find.byKey(const Key('feedback-return')), findsOneWidget);
      await t.tap(find.byKey(const Key('feedback-copy')));
      await t.pump();
      expect(clip, ['T-4']);
      expect(find.text('Скапіявана'), findsOneWidget);
      await t.tap(find.byKey(const Key('feedback-again')));
      await t.pump();
      expect(find.byKey(const Key('feedback-body')), findsOneWidget);
      expect(find.byKey(const Key('feedback-context')), findsNothing);
    });

    testWidgets(
      'a screen opened without context starts on the neutral category',
      (t) async {
        tall(t);
        await t.pumpWidget(host(FeedbackService(baseUrl: 'https://w.test')));
        await t.scrollUntilVisible(
          find.byKey(const Key('feedback-category-other')),
          100,
          scrollable: find.descendant(
            of: find.byKey(const Key('feedback-categories')),
            matching: find.byType(Scrollable),
          ),
        );
        final chip = t.widget<ChoiceChip>(
          find.byKey(const Key('feedback-category-other')),
        );
        expect(chip.selected, isTrue);
      },
    );

    testWidgets('context can be removed; not configured disables sending', (
      t,
    ) async {
      tall(t);
      await t.pumpWidget(
        host(
          FeedbackService(baseUrl: ''),
          ctx: const FeedbackContext(kind: 'song', id: 's1'),
        ),
      );
      await t.tap(find.byKey(const Key('feedback-context-remove')));
      await t.pump();
      expect(find.byKey(const Key('feedback-context')), findsNothing);
      expect(find.byKey(const Key('feedback-not-configured')), findsOneWidget);
      expect(tester(t), isTrue);
    });
  });
}

Future<void> tapSubmit(WidgetTester t) async {
  await t.tap(find.byKey(const Key('feedback-submit')));
}

bool tester(WidgetTester t) =>
    t
        .widget<FilledButton>(find.byKey(const Key('feedback-submit')))
        .onPressed ==
    null;
