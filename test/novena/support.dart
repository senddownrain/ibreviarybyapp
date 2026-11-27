import 'dart:convert';
import 'dart:io';

import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/novena/novena_definition.dart';

Map<String, dynamic> fixture(String name) =>
    jsonDecode(File('test/novena/fixtures/$name.json').readAsStringSync())
        as Map<String, dynamic>;

Map<String, NovenaPrayer> fixturePrayers(Map<String, dynamic> data) => {
  for (final item in data['prayers'] as List)
    (item as Map)['id'] as String: NovenaPrayer.fromMap(item),
};

Map<String, Map<String, dynamic>> bundledDocs(String name) =>
    decodeContentCollection(
      File('assets/content/$name.json.gz').readAsBytesSync(),
    ).docs;

Map<String, NovenaPrayer> bundledPrayers() => {
  for (final MapEntry(:key, :value) in bundledDocs('prayers').entries)
    key: NovenaPrayer.fromMap(value, key),
};

List<Map<String, dynamic>> readyDefinitions() =>
    (fixture('definitions_ready')['definitions'] as List)
        .cast<Map<String, dynamic>>();
