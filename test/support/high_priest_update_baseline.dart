// Historical one-document fixture from main6ef0ba8. Not a second content bundle.
import 'dart:convert';
import 'dart:io';
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/content/content_store.dart';

Future<void> useHistoricalHighPriestUpdateBaseline() async {
  const id = 'feast-christthehighpriest';
  final old = Map<String, dynamic>.from(
    jsonDecode(
          utf8.decode(
            gzip.decode(
              File(
                'test/fixtures/high_priest_before_patch.json.gz',
              ).readAsBytesSync(),
            ),
          ),
        )
        as Map,
  );
  if (documentHash(old) != '702d908c1157bb74') {
    throw StateError('Historical pre-patch fixture integrity failed');
  }
  final collection = ContentStore.instance.collection('days');
  final docs = <String, Map<String, dynamic>>{
    for (final key in collection.keys)
      key: key == id
          ? old
          : Map<String, dynamic>.from(collection.get(key) as Map),
  };
  await collection.debugReplaceBaseline(docs, {
    for (final e in docs.entries) e.key: documentHash(e.value),
  }, collection.baselineVersion);
}
