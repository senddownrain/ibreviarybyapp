import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final directory = Directory('audit-evidence/liturgical-selector-redesign');
  await directory.create(recursive: true);
  await runZoned(
    () => integrationDriver(
      onScreenshot: (name, bytes, [args]) async {
        if (bytes.length < 24 ||
            bytes[0] != 137 ||
            bytes[1] != 80 ||
            bytes[2] != 78 ||
            bytes[3] != 71) {
          return false;
        }
        await File('${directory.path}/$name.png').writeAsBytes(bytes);
        return true;
      },
      responseDataCallback: (data) async {
        final states = <String, Object?>{
          ...?(data?['selector_states'] as Map?)?.cast<String, Object?>(),
        };
        for (final screenshot
            in (data?['screenshots'] as List? ?? const []).whereType<Map>()) {
          final name = '${screenshot['screenshotName']}';
          states[name] =
              (data?['selector_states'] as Map?)?[name] ?? screenshot['args'];
        }
        final prefix = states.keys.first.split(RegExp('-light-|-dark-')).first;
        await File('${directory.path}/$prefix-result.json').writeAsString(
          const JsonEncoder.withIndent('  ').convert({
            'passed': true,
            'preferencesRestored': data?['preferences_restored'],
            'states': states,
          }),
        );
      },
    ),
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) {
        // Native reports contain PNG bytes. Keep logs concise; save PNG separately.
        parent.print(
          zone,
          line.startsWith('result ')
              ? 'Integration result received; screenshots saved separately.'
              : line,
        );
      },
    ),
  );
}
