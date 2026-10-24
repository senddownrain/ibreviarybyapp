import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/analytics/collector.dart';
import 'package:mybrev_flutter/analytics/contract.dart';
import 'package:mybrev_flutter/analytics/transport.dart';

void main() {
  test('NoopTransport answers 204 without side effects', () async {
    final response = await const NoopTransport().send({'x': 1});
    expect(response.status, 204);
  });

  test(
    'RecordingTransport keeps packets and answers programmed statuses',
    () async {
      final transport = RecordingTransport(statuses: [400, 429]);
      expect((await transport.send({'a': 1})).status, 400);
      expect((await transport.send({'a': 2})).status, 429);
      expect((await transport.send({'a': 3})).status, 204);
      expect(transport.received.length, 3);
    },
  );

  test(
    'collecting never touches a transport: reading works with a failing one',
    () {
      final failing = RecordingTransport(throwError: true);
      final collector = AnalyticsCollector(
        platform: 'ios',
        appVersion: '1.0',
        enabled: true,
        now: () => 0,
      );
      collector.enterView(section: 'settings');
      collector.flush();
      expect(failing.received, isEmpty);
    },
  );

  test(
    'stage guard: only known files reach the analytics; calls carry feature ids only',
    () {
      const allowed = {
        'lib/main.dart',
        'lib/providers/settings_provider.dart',
        'lib/providers/songs_provider.dart',
        'lib/screens/prayer_detail_screen.dart',
        'lib/screens/bible_chapter_screen.dart',
        'lib/screens/reading_detail_screen.dart',
        'lib/widgets/reader/reader_scaffold.dart',
        'lib/providers/diocese_provider.dart',
        'lib/screens/ora_screen.dart',
        'lib/screens/readings_screen.dart',
        'lib/screens/song_detail_screen.dart',
        'lib/widgets/app_overflow_menu.dart',
        'lib/widgets/hours_options_sheet.dart',
        'lib/widgets/liturgical_calendar_sheet.dart',
      };
      final importers = <String>[];
      final featureCalls = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (entity.path.startsWith('lib/analytics/')) continue;
        final text = entity.readAsStringSync();
        if (text.contains('analytics/')) importers.add(entity.path);
        for (final m in RegExp(
          r'analyticsFeature\(([^)]*)\)',
        ).allMatches(text)) {
          featureCalls.add(m.group(1)!);
        }
      }
      expect(
        importers.toSet().difference(allowed).isEmpty,
        isTrue,
        reason: '$importers',
      );
      expect(
        featureCalls.length >= 14,
        isTrue,
        reason: '${featureCalls.length}',
      );
      for (final arg in featureCalls) {
        expect(RegExp(r"^'[a-z_]+'$").hasMatch(arg), isTrue, reason: arg);
        expect(
          featureIds.contains(arg.substring(1, arg.length - 1)),
          isTrue,
          reason: arg,
        );
      }

      final main = File('lib/main.dart').readAsStringSync();
      expect(
        RegExp(
          r'if \(kAnalyticsLocal\) unawaited\(LocalAnalytics\.start\(router\)\)',
        ).hasMatch(main),
        isTrue,
      );
      // Whitespace-normalised: the formatter may wrap these lines.
      final scaffold = File(
        'lib/widgets/reader/reader_scaffold.dart',
      ).readAsStringSync().replaceAll(RegExp(r'\s+'), ' ');
      expect(
        scaffold.contains(
          'kAnalyticsLocal ? AnalyticsTextMeter(child: content) : content',
        ),
        isTrue,
      );
      expect(
        scaffold.contains(
          'if (kAnalyticsLocal) { scrollView = AnalyticsReaderScroll(',
        ),
        isTrue,
      );

      for (final entity in Directory('lib/analytics').listSync()) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final code = entity
            .readAsStringSync()
            .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
            .split('\n')
            .where((l) => !l.trimLeft().startsWith('//'))
            .join('\n');
        expect(
          RegExp(
            r'dart:io|dart:html|package:http|package:dio|HttpClient|WebSocket|firebase_analytics|firebase_crashlytics|advertising|SharedPreferences|device_info|uuid',
          ).hasMatch(code),
          isFalse,
          reason: entity.path,
        );
      }
    },
  );

  test('pubspec has no analytics, crash-reporting or advertising packages', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final banned in [
      'firebase_analytics',
      'firebase_crashlytics',
      'sentry_flutter',
      'google_mobile_ads',
      'app_tracking_transparency',
      'advertising_id',
    ]) {
      expect(pubspec.contains(banned), isFalse, reason: banned);
    }
  });
}
