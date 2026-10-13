// Web ↔ Flutter Lectionary parity: for every date 2025–2035 × four dioceses
// and every legal Mass option, the Readings screen of the app (the SAME
// loader and selection code as the screen, on the content an installed phone
// has after the published manifest) shows what the web Readings screen
// resolves: reading groups, canonical document, all set ids / contexts /
// defaults, selected set, cycles and the ordered structured sections with the
// hash of their full content.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/content/content_store.dart';
import 'package:mybrev_flutter/services/hive_service.dart';

import 'support/lectionary_fixture.dart';
import 'support/lectionary_run.dart';

/// Differences from the web the app keeps on purpose; each is named in
/// docs/flutter-lectionary-audit.md and waits for a web-side decision.
const kDocumentedDifferences = {
  // The Catholic.by page 4865 (and so the web document) prints the Gospel of
  // the XXVIII Sunday, year A, as «Мк 22, 1–10» under the title «паводле
  // Мацвея»: the app corrects the book on read (ParsedReading.fromMap).
  'local-citation-correction:ordinary-w28-d1--A': (
    kind: 'sections',
    doc: 'ordinary-w28-d1--A',
  ),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  setUpAll(() async {
    await initializeDateFormatting('be');
    directory = await Directory.systemTemp.createTemp('lectionary-parity-');
    await HiveService.init(path: directory.path, loadBundle: true);
    await ContentStore.instance.ensureLoaded(kContentCollections);
    final check = await applyPublishedReadings();
    expect(check.kind.name, 'patch');
  });
  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test(
    'Flutter Readings screen equals the web screen for every legal option',
    () {
      final fixture = lectionaryParityFixture();
      final tables = fixture['tables'] as Map<String, dynamic>;
      final screens = (tables['screens'] as List).cast<Map<String, dynamic>>();
      final views = tables['views'] as Map<String, dynamic>;
      final fromYear = int.tryParse(
        Platform.environment['LECTIONARY_FROM'] ?? '',
      );
      final toYear = int.tryParse(Platform.environment['LECTIONARY_TO'] ?? '');

      final mismatches = <Map<String, Object?>>[];
      final accepted = <Map<String, Object?>>[];
      final byKind = <String, int>{};
      var dates = 0;
      var options = 0;
      var sections = 0;
      var sets = 0;

      void miss(
        String diocese,
        String date,
        String option,
        String kind,
        Object? web,
        Object? app,
      ) {
        final record = {
          'diocese': diocese,
          'date': date,
          'option': option,
          'kind': kind,
          'web': web,
          'app': app,
        };
        // A difference the app keeps on purpose and the report names.
        final reason = kDocumentedDifferences.entries
            .where(
              (entry) =>
                  kind == entry.value.kind &&
                  '$web'.contains(entry.value.doc) &&
                  '$app'.contains(entry.value.doc),
            )
            .firstOrNull
            ?.key;
        if (reason != null) {
          accepted.add({...record, 'reason': reason});
          return;
        }
        byKind[kind] = (byKind[kind] ?? 0) + 1;
        mismatches.add(record);
      }

      void compare(
        String diocese,
        String date,
        String option,
        Map<String, dynamic> web,
        FlutterScreen? app,
      ) {
        if (app == null) {
          // No document at all: the web screen is empty as well.
          if ((web['g'] as List).isNotEmpty) {
            miss(diocese, date, option, 'no-screen', web['sd'], null);
          }
          return;
        }
        final webGroups = [
          for (final g in web['g'] as List)
            ((g as List)[0] as String, (g[1] as List).cast<String>()),
        ];
        final webKeys = webGroups.map((g) => g.$1).toList();
        final appKeys = app.groups.map((g) => g.$1).toList();
        if (jsonEncode(webKeys) != jsonEncode(appKeys)) {
          // Same documents grouped/ordered differently is its own class.
          final sameDocs =
              jsonEncode(webGroups.map((g) => g.$2.toList()..sort()).toList()
                    ..sort((a, b) => a.join().compareTo(b.join()))) ==
              jsonEncode(
                app.groups.map((g) => g.$2.toList()..sort()).toList()
                  ..sort((a, b) => a.join().compareTo(b.join())),
              );
          miss(
            diocese,
            date,
            option,
            sameDocs ? 'groups-order-or-key' : 'groups-documents',
            webGroups.map((g) => '${g.$1}=${g.$2.join('+')}').toList(),
            app.groups.map((g) => '${g.$1}=${g.$2.join('+')}').toList(),
          );
          return;
        }
        if (web['a'] != app.active) {
          miss(
            diocese,
            date,
            option,
            'active-group',
            webKeys.length > (web['a'] as int) && (web['a'] as int) >= 0
                ? webGroups[web['a'] as int].$2
                : null,
            app.active >= 0 ? app.groups[app.active].$2 : null,
          );
          return;
        }
        if (web['sd'] != app.setDoc) {
          miss(diocese, date, option, 'set-document', web['sd'], app.setDoc);
          return;
        }
        final webSets = [
          for (final s in web['st'] as List)
            [for (final x in s as List) x],
        ];
        sets += webSets.length;
        if (jsonEncode(webSets) != jsonEncode(app.sets)) {
          miss(diocese, date, option, 'sets', webSets, app.sets);
          return;
        }
        if (web['as'] != app.activeSet) {
          miss(
            diocese,
            date,
            option,
            'active-set',
            web['as'],
            app.activeSet,
          );
        }
        if (web['ac'] != app.cycles) {
          miss(diocese, date, option, 'cycles', web['ac'], app.cycles);
        }
        if (web['cy'] != app.cycle) {
          miss(diocese, date, option, 'active-cycle', web['cy'], app.cycle);
        }
        final webView = web['v'] == null
            ? null
            : views[web['v']] as Map<String, dynamic>;
        final appView = app.view;
        if (webView == null || appView == null) {
          if ((webView == null) != (appView == null)) {
            miss(diocese, date, option, 'view', webView?['doc'], appView?.docId);
          }
          return;
        }
        if (webView['doc'] != appView.docId) {
          miss(diocese, date, option, 'view-document', webView['doc'], appView.docId);
          return;
        }
        final webSections = [
          for (final s in webView['sections'] as List)
            '${(s as List)[1]}|${s[2]}|${s[3]}|${s[4]}',
        ];
        final appSections = [
          for (final s in appView.sections)
            '${s.kind}|${s.role}|${s.cycle}|${s.hash}',
        ];
        sections += webSections.length;
        if (jsonEncode(webSections) != jsonEncode(appSections)) {
          miss(
            diocese,
            date,
            option,
            'sections',
            '${webView['doc']}#${webView['set']}#${webView['cycle']}: ${webSections.join(' ; ')}',
            '${appView.docId}#${appView.setId}#${appView.cycle}: ${appSections.join(' ; ')}',
          );
        }
      }

      for (final MapEntry(key: diocese, value: list)
          in (fixture['days'] as Map).cast<String, dynamic>().entries) {
        for (final record in (list as List).cast<Map<String, dynamic>>()) {
          final iso = record['date'] as String;
          final year = int.parse(iso.substring(0, 4));
          if ((fromYear != null && year < fromYear) ||
              (toYear != null && year > toYear)) {
            continue;
          }
          dates++;
          final date = DateTime.parse(iso);
          for (final option
              in (record['o'] as List).cast<Map<String, dynamic>>()) {
            options++;
            final id = option['id'] as String;
            final webDayId = option['di'] as String?;
            final appDayId = routeDayIdOf(date, diocese, id);
            if (webDayId != appDayId) {
              miss(diocese, iso, id, 'route-day-id', webDayId, appDayId);
            }
            // The Flutter route carries the Hours day id: compare with the
            // web screen of that route (the option route when there is none).
            final webScreen = screens[(option['sd'] ?? option['so']) as int];
            compare(
              diocese,
              iso,
              id,
              webScreen,
              flutterScreenFor(date, diocese, id, dayId: appDayId),
            );
          }
        }
      }

      final report = {
        'dates': dates,
        'options': options,
        'sets': sets,
        'sections': sections,
        'mismatches': mismatches.length,
        'byKind': byKind,
        'documentedDifferences': accepted.length,
      };
      File('${directory.path}/lectionary-parity.json').writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert({
          ...report,
          'examples': mismatches,
          'accepted': accepted,
        }),
      );
      if (Platform.environment['LECTIONARY_REPORT'] != null) {
        File(Platform.environment['LECTIONARY_REPORT']!).writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert({
            ...report,
            'examples': mismatches,
            'accepted': accepted,
          }),
        );
      }
      // ignore: avoid_print
      print(jsonEncode(report));
      expect(
        mismatches,
        isEmpty,
        reason: mismatches.take(8).map(jsonEncode).join('\n'),
      );
    },
    timeout: const Timeout(Duration(minutes: 20)),
  );
}
