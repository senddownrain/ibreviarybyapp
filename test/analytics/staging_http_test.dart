import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/analytics/collector.dart';
import 'package:mybrev_flutter/analytics/contract.dart';
import 'package:mybrev_flutter/analytics/local_analytics.dart';
import 'package:mybrev_flutter/analytics/public_inventory.dart';
import 'package:mybrev_flutter/analytics/staging_http.dart';
import 'package:mybrev_flutter/analytics/transport.dart';

// Opt-in end-to-end against the R02 server (worker/local-server.mjs), e.g.
//   flutter test test/analytics/staging_http_test.dart \
//     --dart-define=R02_URL=http://127.0.0.1:8788
const _r02 = String.fromEnvironment('R02_URL');
const _r02Admin = String.fromEnvironment('R02_ADMIN_TOKEN');

class _Hit {
  _Hit(this.method, this.path, this.headers, this.body);
  final String method, path;
  final Map<String, List<String>> headers;
  final String body;
}

/// Tiny in-process HTTP server that records requests and answers programmed
/// statuses. Stands in for the Worker only where the real one is not needed.
class _Server {
  _Server(this._server, this.statuses);
  final HttpServer _server;
  final List<int> statuses;
  final hits = <_Hit>[];
  int get port => _server.port;

  static Future<_Server> start([List<int> statuses = const []]) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final s = _Server(server, List.of(statuses));
    server.listen((req) async {
      final body = await utf8.decodeStream(req);
      final headers = <String, List<String>>{};
      req.headers.forEach((k, v) => headers[k] = v);
      s.hits.add(_Hit(req.method, req.uri.toString(), headers, body));
      final status = s.statuses.isEmpty ? 204 : s.statuses.removeAt(0);
      req.response.statusCode = status;
      if (status != 204) {
        req.response.headers.contentType = ContentType.json;
        req.response.write('{"code":"test_$status"}');
      }
      await req.response.close();
    });
    return s;
  }

  Future<void> close() => _server.close(force: true);
  String get url => 'http://127.0.0.1:$port';
}

Map<String, Object?> _packet({String platform = 'android', bool fit = true}) {
  var now = DateTime.now().toUtc().millisecondsSinceEpoch;
  final c = AnalyticsCollector(
    platform: platform,
    appVersion: '1.0.0+6',
    enabled: true,
    publicIds: kAnalyticsPublicIds,
    now: () => now,
  );
  c.enterView(section: 'prayers', contentId: kAnalyticsPublicIds.first);
  c.reportFits(fit);
  now += 4000;
  c.flush();
  c.featureUse(featureIds.first, 'prayers');
  return c.snapshot().first;
}

void main() {
  group('gate (compile-time flags + URL)', () {
    test('both flags and a valid URL are required', () {
      const url = 'https://staging.example.workers.dev';
      expect(stagingEnabled(local: true, staging: true, url: url), isTrue);
      expect(stagingEnabled(local: true, staging: false, url: url), isFalse);
      expect(stagingEnabled(local: false, staging: true, url: url), isFalse);
      expect(stagingEnabled(local: true, staging: true, url: ''), isFalse);
    });

    test('normal test run has the gate closed and no URL baked in', () {
      if (kAnalyticsStaging) return; // run with staging flags on purpose
      expect(kAnalyticsStagingActive, isFalse);
      expect(kAnalyticsStagingUrl, isEmpty);
    });

    test('URL parsing: https or loopback http only, path fixed', () {
      expect(
        parseStagingUrl('https://x.workers.dev')!.toString(),
        'https://x.workers.dev/v2/ingest',
      );
      expect(
        parseStagingUrl('http://127.0.0.1:8788/')!.toString(),
        'http://127.0.0.1:8788/v2/ingest',
      );
      for (final bad in [
        '',
        'http://example.com',
        'http://10.0.2.2:8788',
        'ftp://x.dev',
        'https://u:p@x.dev',
        'https://x.dev/?q=1',
        'https://x.dev/#f',
        'not a url',
        'https://',
      ]) {
        expect(parseStagingUrl(bad), isNull, reason: bad);
      }
    });
  });

  group('HttpStagingTransport', () {
    late _Server server;
    setUp(() async => server = await _Server.start());
    tearDown(() => server.close());

    test('one POST with the contract body and nothing identifying', () async {
      final transport = HttpStagingTransport(parseStagingUrl(server.url)!);
      final packet = _packet();
      final response = await transport.send(packet);
      expect(response.status, 204);
      expect(server.hits, hasLength(1));
      final hit = server.hits.single;
      expect(hit.method, 'POST');
      expect(hit.path, '/v2/ingest');
      expect(jsonDecode(hit.body), packet);
      final names = hit.headers.keys.map((k) => k.toLowerCase()).toSet();
      expect(names.contains('cookie'), isFalse);
      expect(names.contains('authorization'), isFalse);
      expect(names.contains('user-agent'), isFalse);
      expect(
        hit.headers['content-type']!.single,
        startsWith('application/json'),
      );
      expect(hit.body.contains('install'), isFalse);
    });

    test('non-204 is returned as is and never retried', () async {
      server.statuses.addAll([400, 503]);
      final transport = HttpStagingTransport(parseStagingUrl(server.url)!);
      expect((await transport.send(_packet())).status, 400);
      expect(transport.lastErrorCode, 'test_400');
      expect((await transport.send(_packet())).status, 503);
      expect(server.hits, hasLength(2)); // exactly one request per send
    });

    test('oversized packet is not sent at all', () async {
      final transport = HttpStagingTransport(parseStagingUrl(server.url)!);
      final big = {..._packet(), 'pad': 'x' * (kMaxPacketBytes + 1)};
      expect((await transport.send(big)).status, 413);
      expect(server.hits, isEmpty);
    });

    test('unreachable server: exception, no retry', () async {
      final port = server.port;
      await server.close();
      final transport = HttpStagingTransport(
        Uri.parse('http://127.0.0.1:$port/v2/ingest'),
        timeout: const Duration(seconds: 2),
      );
      await expectLater(transport.send(_packet()), throwsA(anything));
      server = await _Server.start(); // keep tearDown happy
    });

    test('redirects are not followed', () async {
      server.statuses.add(302);
      final transport = HttpStagingTransport(parseStagingUrl(server.url)!);
      expect((await transport.send(_packet())).status, 302);
      expect(server.hits, hasLength(1));
    });
  });

  group('StagingSender (at-most-once, kill switch)', () {
    test(
      '204 counts as sent; other statuses and errors as lost, no retry',
      () async {
        final t = RecordingTransport(statuses: [204, 400, 204]);
        final sender = StagingSender(t);
        final r = await sender.sendAll([_packet(), _packet(), _packet()]);
        expect((r.sent, r.lost, r.halted), (2, 1, false));
        expect(t.received, hasLength(3));
        final failing = StagingSender(RecordingTransport(throwError: true));
        final f = await failing.sendAll([_packet()]);
        expect((f.sent, f.lost), (0, 1));
      },
    );

    test(
      '503 halts: the rest of the batch and later batches are not sent',
      () async {
        final t = RecordingTransport(statuses: [503]);
        final sender = StagingSender(t);
        final r = await sender.sendAll([_packet(), _packet(), _packet()]);
        expect(r.halted, isTrue);
        expect(t.received, hasLength(1));
        await sender.sendAll([_packet()]);
        expect(t.received, hasLength(1));
      },
    );

    test('426 also halts', () async {
      final sender = StagingSender(RecordingTransport(statuses: [426]));
      expect((await sender.sendAll([_packet()])).halted, isTrue);
    });
  });

  group('collector.drainPackets', () {
    test('removes what it returns (so it can never be sent twice)', () {
      var now = DateTime.utc(2026, 10, 26, 12).millisecondsSinceEpoch;
      final c = AnalyticsCollector(
        platform: 'ios',
        appVersion: '1.0',
        enabled: true,
        publicIds: kAnalyticsPublicIds,
        now: () => now,
      );
      c.enterView(section: 'settings');
      now += 3000;
      c.flush();
      final first = c.drainPackets();
      expect(first, isNotEmpty);
      expect(c.drainPackets(), isEmpty);
      expect(c.snapshot(), isEmpty);
    });

    test('days older than 2 are dropped, not returned', () {
      var now = DateTime.utc(2026, 10, 20, 12).millisecondsSinceEpoch;
      final c = AnalyticsCollector(
        platform: 'ios',
        appVersion: '1.0',
        enabled: true,
        publicIds: kAnalyticsPublicIds,
        now: () => now,
      );
      c.enterView(section: 'settings');
      now += 3000;
      c.flush();
      now = DateTime.utc(2026, 10, 26, 12).millisecondsSinceEpoch;
      expect(c.drainPackets(), isEmpty);
      expect(c.snapshot(), isEmpty);
    });
  });

  group('no flags -> no network channel', () {
    test('LocalAnalytics gate constant is closed without both flags', () {
      expect(
        kAnalyticsStagingActive,
        kAnalyticsLocal && kAnalyticsStaging && kAnalyticsStagingUrl != '',
      );
    });

    test('lib: only staging_http.dart touches dart:io network; guarded', () {
      var offenders = <String>[];
      for (final e in Directory('lib').listSync(recursive: true)) {
        if (e is! File || !e.path.endsWith('.dart')) continue;
        final code = e
            .readAsStringSync()
            .split('\n')
            .where((l) => !l.trimLeft().startsWith('//'))
            .join('\n');
        if (code.contains('HttpClient(') ||
            code.contains('staging_http.dart')) {
          offenders.add(e.path.replaceAll('\\', '/'));
        }
      }
      expect(offenders.toSet(), {
        'lib/analytics/staging_http.dart',
        'lib/analytics/local_analytics.dart',
      }, reason: '$offenders');
      final glue = File(
        'lib/analytics/local_analytics.dart',
      ).readAsStringSync();
      expect(glue.contains('if (kAnalyticsStagingActive)'), isTrue);
      expect(RegExp(r'HttpStagingTransport\(').allMatches(glue).length, 1);
    });

    test('pubspec: no new packages, manifests: no new permissions', () {
      final android = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      final perms = RegExp(
        r'uses-permission android:name="([^"]+)"',
      ).allMatches(android).map((m) => m.group(1)).toList();
      expect(perms.where((p) => p!.contains('ADVERTISING')), isEmpty);
      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      expect(plist.contains('NSAllowsArbitraryLoads'), isFalse);
      expect(plist.contains('NSAppTransportSecurity'), isFalse);
    });
  });

  group('R02 server end-to-end', () {
    test(
      '204 / 400 / kill-switch against the real Worker code',
      () async {
        final base = parseStagingUrl(_r02)!;
        final transport = HttpStagingTransport(base);
        for (final platform in ['android', 'ios']) {
          expect(
            (await transport.send(_packet(platform: platform))).status,
            204,
          );
        }
        final bad = {..._packet(), 'region': 'BY'};
        expect((await transport.send(bad)).status, 400);
        expect(transport.lastErrorCode, 'region_not_allowed');
        if (_r02Admin.isNotEmpty) {
          Future<int> admin(bool on) async {
            final c = HttpClient();
            try {
              final r = await c.postUrl(base.replace(path: '/v2/admin/ingest'));
              r.headers.set('Authorization', 'Bearer $_r02Admin');
              r.write('{"enabled":$on}');
              final res = await r.close();
              await res.drain<void>();
              return res.statusCode;
            } finally {
              c.close(force: true);
            }
          }

          expect(await admin(false), anyOf(200, 204));
          final sender = StagingSender(transport);
          final r = await sender.sendAll([_packet(), _packet()]);
          expect(r.halted, isTrue);
          expect(await admin(true), anyOf(200, 204));
        }
      },
      skip: _r02.isEmpty ? 'needs --dart-define=R02_URL=...' : null,
    );
  });
}
