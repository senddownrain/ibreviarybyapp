import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The QA harness must stay out of every release build. A Dart library that
/// nothing imports is not compiled into the app, so isolation is a matter of
/// the import graph; this test keeps it that way.
void main() {
  final lib = Directory('lib');
  final dartFiles = lib
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  String norm(String path) => path.replaceAll(r'\', '/');

  test('no file outside lib/discovery/qa imports the QA harness', () {
    final offenders = [
      for (final file in dartFiles)
        if (!norm(file.path).startsWith('lib/discovery/qa/') &&
            file.readAsStringSync().contains('discovery/qa/'))
          file.path,
    ];
    expect(offenders, isEmpty);
  });

  test('main.dart and the router do not reach the QA harness', () {
    for (final path in ['lib/main.dart', 'lib/router/router.dart']) {
      // main.dart installs the engine (Stage 3), never the QA harness.
      expect(File(path).readAsStringSync(), isNot(contains('discovery/qa')));
    }
  });

  test('the QA entrypoint refuses to run in release', () {
    final main = File(
      'lib/discovery/qa/discovery_qa_main.dart',
    ).readAsStringSync();
    expect(main, contains('kReleaseMode'));
    expect(main, contains('throw StateError'));
  });

  test('the engine has no network, Firebase or analytics dependency', () {
    const banned = [
      'dart:io',
      'dart:html',
      'package:http',
      'cloud_firestore',
      'firebase_',
      'analytics/',
      'package:go_router',
    ];
    for (final file in dartFiles.where(
      (f) => norm(f.path).startsWith('lib/discovery/'),
    )) {
      final source = file.readAsStringSync();
      for (final token in banned) {
        expect(
          source.contains("import '$token") ||
              source.contains('import "$token') ||
              (token.contains('/') &&
                  source.contains("import 'package:mybrev_flutter/$token")),
          isFalse,
          reason: '${file.path} imports $token',
        );
      }
    }
  });

  test('the only QA define is release-proof and in one file', () {
    const qaMode = 'lib/discovery/discovery_qa_mode.dart';
    final mode = File(qaMode).readAsStringSync();
    expect(mode, contains('kDiscoveryQaDefine && !kReleaseMode'));
    for (final file in dartFiles.where(
      (f) =>
          norm(f.path).startsWith('lib/') &&
          norm(f.path) != qaMode &&
          !norm(f.path).startsWith('lib/discovery/qa/'),
    )) {
      expect(
        file.readAsStringSync(),
        isNot(contains('DISCOVERY_QA')),
        reason: file.path,
      );
    }
  });
}
