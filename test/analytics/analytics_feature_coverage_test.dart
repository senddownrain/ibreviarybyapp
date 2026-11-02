// feature_use coverage of the Flutter app against the 27 contract ids.
// Every id is either hooked to a successful state change through
// `analyticsFeature('<id>')` (no value, no text) or declared below with the
// reason it is not. Adding a button must not silently change this table.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/analytics/contract.dart';

/// id -> why there is no Flutter hook.
const _notHooked = <String, String>{
  'copy_use': 'NOT APPLICABLE: no copy-text action exists in the Flutter UI',
  'install_prompt_open': 'NOT APPLICABLE: web-only install prompt',
  'search_submit': 'excluded by contract: search input is never counted',
  'search_open':
      'DEFERRED: Bible/songbook/compendium search screens exist; the P04 scope '
      'excludes search input, owner to decide whether opening a search counts',
  'offline_update_apply':
      'DEFERRED: content updates apply automatically in the background, so '
      'no user action or screen can be attributed (manual check is a separate decision)',
};

Map<String, Set<String>> _hooks() {
  final found = <String, Set<String>>{};
  final pattern = RegExp(r"analyticsFeature\(\s*'([a-z_]+)'\s*\)");
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    if (entity.path.replaceAll('\\', '/').startsWith('lib/analytics/')) {
      continue;
    }
    for (final m in pattern.allMatches(entity.readAsStringSync())) {
      found
          .putIfAbsent(m.group(1)!, () => {})
          .add(entity.path.replaceAll('\\', '/'));
    }
  }
  return found;
}

void main() {
  test(
    'every contract feature is hooked or declared, nothing unknown is reported',
    () {
      final hooks = _hooks();
      for (final id in hooks.keys) {
        expect(
          featureIds,
          contains(id),
          reason: 'hook for unknown feature $id',
        );
      }
      for (final id in featureIds) {
        expect(
          hooks.containsKey(id) || _notHooked.containsKey(id),
          isTrue,
          reason: '$id is neither hooked nor declared',
        );
        expect(
          hooks.containsKey(id) && _notHooked.containsKey(id),
          isFalse,
          reason: '$id is declared as not hooked but has a hook',
        );
      }
      expect(hooks.length, 22);
      expect(hooks.length + _notHooked.length, featureIds.length);
    },
  );

  test('the P04 hooks are present where the action really happens', () {
    final hooks = _hooks();
    const expected = {
      'date_pick': 'lib/widgets/liturgical_calendar_sheet.dart',
      'picker_open': 'lib/widgets/liturgical_calendar_sheet.dart',
      'hour_switch': 'lib/screens/ora_screen.dart',
      'hour_option_select': 'lib/widgets/hours_options_sheet.dart',
      'text_settings_open': 'lib/widgets/app_overflow_menu.dart',
      'chord_transpose': 'lib/screens/song_detail_screen.dart',
      'mass_section_nav': 'lib/screens/prayer_detail_screen.dart',
      'ordo_diocese_change': 'lib/providers/diocese_provider.dart',
    };
    expected.forEach((id, file) {
      expect(hooks[id], contains(file), reason: id);
    });
  });
}
