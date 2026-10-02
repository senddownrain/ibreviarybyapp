// Regenerates lib/models/mass_ritual_data.dart from the shared ritual JSON.
//
//   dart run tool/generate_mass_ritual_data.dart
//   dart format lib/models/mass_ritual_data.dart
import 'dart:convert';
import 'dart:io';

String _lit(Object? value) =>
    "'${(value as String).replaceAll(r'\', r'\\').replaceAll("'", r"\'").replaceAll(r'$', r'\$')}'";

String _list(Object? values) =>
    '[${((values as List?) ?? const []).map(_lit).join(', ')}]';

/// `{'key': 'value'}` for a JSON object of strings.
void _stringMap(StringBuffer out, String name, Object? value) {
  final map = (value as Map?) ?? const {};
  if (map.isEmpty) return;
  out.writeln('$name: {');
  map.forEach((k, v) => out.writeln('${_lit(k)}: ${_lit(v)},'));
  out.writeln('},');
}

/// `{'key': ['a', 'b']}` for a JSON object of string lists.
void _listMap(StringBuffer out, String name, Object? value) {
  final map = (value as Map?) ?? const {};
  if (map.isEmpty) return;
  out.writeln('$name: {');
  map.forEach((k, v) => out.writeln('${_lit(k)}: ${_list(v)},'));
  out.writeln('},');
}

void main() {
  final json =
      jsonDecode(
            File('assets/mass/order-of-mass.ritual.json').readAsStringSync(),
          )
          as Map<String, dynamic>;
  final out = StringBuffer()
    ..writeln(
      '// GENERATED from assets/mass/order-of-mass.ritual.json (shared with MyBrev)',
    )
    ..writeln('// by tool/generate_mass_ritual_data.dart. Do not edit by hand;')
    ..writeln('// test/mass_ritual_test.dart verifies that both match.')
    ..writeln("part of 'mass_ritual.dart';")
    ..writeln()
    ..writeln('const kMassRitual = MassRitual(')
    ..writeln('schemaVersion: ${json['schemaVersion']},')
    ..writeln('id: ${_lit(json['id'])},')
    ..writeln('primaryPrayerId: ${_lit(json['primaryPrayerId'])},')
    ..writeln('defaultLanguage: ${_lit(json['defaultLanguage'])},');
  final aliases = (json['aliases'] as Map?) ?? const {};
  if (aliases.isNotEmpty) {
    out.writeln('aliases: {');
    aliases.forEach((k, v) => out.writeln('${_lit(k)}: ${_lit(v)},'));
    out.writeln('},');
  }
  out.writeln('roles: ${_list(json['roles'])},');
  final policy = (json['rolePolicy'] as Map?) ?? const {};
  out
    ..writeln('rolePolicy: MassRolePolicy(')
    ..writeln('showSpeakerLabels: ${policy['showSpeakerLabels'] == true},');
  if (policy['labelPolicy'] != null) {
    out.writeln('labelPolicy: ${_lit(policy['labelPolicy'])},');
  }
  out
    ..writeln('responseRoles: ${_list(policy['responseRoles'])},')
    ..writeln('),')
    ..writeln('sections: [');
  for (final s in json['sections'] as List) {
    out.write(
      'MassSectionDef(id: ${_lit(s['id'])}, title: ${_lit(s['title'])}',
    );
    if (s['parent'] != null) out.write(', parent: ${_lit(s['parent'])}');
    out.writeln(',),');
  }
  out
    ..writeln('],')
    ..writeln('variants: [');
  for (final v in json['variants'] as List) {
    out
      ..writeln('MassVariant(')
      ..writeln('language: ${_lit(v['language'])},')
      ..writeln('label: ${_lit(v['label'])},')
      ..writeln('shortLabel: ${_lit(v['shortLabel'])},')
      ..writeln('prayerId: ${_lit(v['prayerId'])},')
      ..writeln('title: ${_lit(v['title'])},');
    if (v['bundledText'] != null) {
      out.writeln("bundledAsset: ${_lit('assets/mass/${v['bundledText']}')},");
    }
    if (v['strongMarksResponses'] == true) {
      out.writeln('strongMarksResponses: true,');
    }
    if (v['source'] != null) out.writeln('source: ${_lit(v['source'])},');
    if (v['callRole'] != null) out.writeln('callRole: ${_lit(v['callRole'])},');
    _listMap(out, 'markers', v['markers']);
    _listMap(out, 'anchors', v['anchors']);
    _listMap(out, 'classify', v['classify']);
    _stringMap(out, 'speakerLabels', v['speakerLabels']);
    _stringMap(out, 'roleLabels', v['roleLabels']);
    _listMap(out, 'roleMarkers', v['roleMarkers']);
    _listMap(out, 'roleCues', v['roleCues']);
    out.writeln('),');
  }
  out
    ..writeln('],')
    ..writeln(');');
  File('lib/models/mass_ritual_data.dart').writeAsStringSync(out.toString());
}
