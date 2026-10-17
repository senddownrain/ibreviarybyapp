// Analytics contract v2 (WEB + Flutter). Dart port of the web reference
// `src/utils/analytics/contract.js` (mybrev repository, docs/analytics-contract.md).
//
// Pure Dart: no Flutter imports, no I/O, no network. The web contract is the
// source of truth; any change must come from there as a new contract version
// and is verified here by test/analytics/analytics_contract_test.dart against
// the shared golden vectors.
import 'dart:convert';

const int schemaVersion = 2;

const List<String> platforms = ['web', 'android', 'ios'];
const List<String> regions = ['BY', 'OTHER', 'UNKNOWN'];

/// Public sections only. Admin, login, priest-only and personal prayers are not measurable.
const List<String> sections = [
  'today',
  'hours',
  'readings',
  'ordo',
  'prayers',
  'mass',
  'songs',
  'compendium',
  'bible',
  'picker',
  'settings',
  'about',
];

/// section -> content_id kind. Sections absent from the map carry no content_id.
const Map<String, String> sectionContentKind = {
  'readings': 'reading',
  'prayers': 'prayer',
  'mass': 'mass',
  'songs': 'song',
  'compendium': 'comp',
  'hours': 'hour',
  'bible': 'bible',
};

const List<String> hourIds = [
  'invitatorium',
  'morning',
  'lectionis',
  'laudes',
  'terz',
  'sext',
  'non',
  'vesper',
  'completorium',
];

final Map<String, RegExp> _contentIdPatterns = {
  // The daily readings screen as one generic material: no date, day id or text.
  'reading': RegExp(r'^reading:day$'),
  'prayer': RegExp(r'^prayer:[A-Za-z0-9][A-Za-z0-9_-]{5,100}$'),
  'song': RegExp(r'^song:holysongs-[0-9a-f]{20}$'),
  'comp': RegExp(r'^comp:[a-z0-9]+(?:-[a-z0-9]+){0,4}$'),
  'mass': RegExp(r'^mass:order$'),
  'hour': RegExp('^hour:(?:${hourIds.join('|')})\$'),
  'bible': RegExp(r'^bible:(?:bel|ru):[a-z0-9_-]{1,32}$', caseSensitive: false),
};

const List<String> featureIds = [
  'text_scale_change',
  'text_settings_open',
  'theme_change',
  'font_family_change',
  'keep_screen_on_toggle',
  'favorite_add',
  'favorite_remove',
  'share_use',
  'copy_use',
  'search_open',
  'search_submit',
  'date_pick',
  'picker_open',
  'hour_switch',
  'hour_option_select',
  'psalmody_layout_change',
  'chords_toggle',
  'chord_transpose',
  'chord_layout_change',
  'mass_language_change',
  'mass_section_nav',
  'ordo_diocese_change',
  'bible_language_change',
  'bible_chapter_nav',
  'back_to_top',
  'offline_update_apply',
  'install_prompt_open',
];

const List<String> errorIds = [
  'clock_anomaly',
  'storage_unavailable',
  'queue_overflow',
  'visibility_unsupported',
  'scroll_unmeasurable',
];

/// Catalog / landing screens that have no single material. Counted by
/// `catalog_open` (opens of the screen, not people).
const List<String> catalogIds = [
  'hours_list',
  'prayers_home',
  'prayers_all',
  'favorites',
  'songs',
  'bible_books',
  'compendium_home',
];

const List<String> events = [
  'screen_view',
  'text_read',
  'feature_use',
  'catalog_open',
  'measurement_error',
];
const List<String> textMetrics = ['fv', 'er', 'sd'];

const List<String> timeBuckets = [
  'lt5s',
  '5_15s',
  '15_60s',
  '60_180s',
  '180_600s',
  'gte600s',
];
const List<double> _timeBounds = [5, 15, 60, 180, 600];
const List<String> scrollBuckets = [
  'fit',
  'p0_25',
  'p25_50',
  'p50_75',
  'p75_99',
  'p100',
];

/// Hard cap on the foreground time of one visit; longer time is clamped.
const int maxVisitSeconds = 1800;

/// Visits shorter than this are navigation noise (redirects) and are discarded.
const int minCountedVisitSeconds = 1;

/// Visits with foreground time below this are "short opens": no er/sd rows.
const int shortOpenSeconds = 5;

/// Documented, NOT calibrated assumption for the rough estimate (see contract).
const int readingWordsPerMinute = 120;
const int charsPerWord = 6;

const int maxCellsPerPacket = 200;
const int maxCellCount = 10000;
const int maxPacketBytes = 16 * 1024;
const int maxLocalDays = 14;

const List<String> _packetKeys = [
  'schema_version',
  'day',
  'platform',
  'app_version',
  'region',
  'cells',
];
const Map<String, List<String>> _cellKeys = {
  'screen_view': ['e', 'section', 'content_id', 'n'],
  'text_read': ['e', 'section', 'content_id', 'metric', 'bucket', 'n'],
  'feature_use': ['e', 'feature_id', 'section', 'n'],
  'catalog_open': ['e', 'catalog_id', 'n'],
  'measurement_error': ['e', 'error_id', 'n'],
};

String? bucketVisibleSeconds(num seconds) {
  final value = seconds.toDouble();
  if (!value.isFinite || value < 0) return null;
  final s = value < maxVisitSeconds ? value : maxVisitSeconds.toDouble();
  final index = _timeBounds.indexWhere((bound) => s < bound);
  return timeBuckets[index == -1 ? timeBuckets.length - 1 : index];
}

/// [fraction]: furthest bottom edge of the viewport as a share of the scrollable
/// height (0..1). [fits]: the text needs no scrolling.
String? bucketScrollDepth(num fraction, {bool fits = false}) {
  if (fits) return 'fit';
  final value = fraction.toDouble();
  if (!value.isFinite || value < 0) return null;
  if (value >= 0.98) return 'p100';
  if (value >= 0.75) return 'p75_99';
  if (value >= 0.5) return 'p50_75';
  if (value >= 0.25) return 'p25_50';
  return 'p0_25';
}

/// Rough upper-bound estimate of reading time: never more than the foreground
/// time and never more than the time needed for the text the viewport reached.
/// Not proof of reading.
double? estimateReadingSeconds({
  required num visibleSeconds,
  required num totalChars,
  num maxScrollFraction = 1,
}) {
  final v = visibleSeconds.toDouble();
  final t = totalChars.toDouble();
  final f = maxScrollFraction.toDouble();
  if (!v.isFinite || !t.isFinite || !f.isFinite) return null;
  if (v < 0 || t < 0) return null;
  final visible = v < maxVisitSeconds ? v : maxVisitSeconds.toDouble();
  final reachedChars = t * f.clamp(0.0, 1.0);
  final needed = (reachedChars / charsPerWord) / readingWordsPerMinute * 60;
  return visible < needed ? visible : needed;
}

/// Validates one content_id. When [publicIds] is given the id must also be a
/// member: this is how closed material is kept out. Returns problems; empty = valid.
List<String> validateContentId(
  String section,
  Object? contentId, {
  Set<String>? publicIds,
}) {
  final kind = sectionContentKind[section];
  if (kind == null) {
    return contentId == null
        ? []
        : ['content_id is not allowed in section "$section"'];
  }
  if (contentId is! String) {
    return ['content_id is required in section "$section"'];
  }
  if (!_contentIdPatterns[kind]!.hasMatch(contentId)) {
    return ['content_id "$contentId" does not match kind "$kind"'];
  }
  if (publicIds != null && !publicIds.contains(contentId)) {
    return ['content_id "$contentId" is not in the public inventory'];
  }
  return [];
}

/// Returns a list of problems; empty means valid.
List<String> validateCell(Object? cell, {Set<String>? publicIds}) {
  if (cell is! Map) return ['cell must be an object'];
  final e = cell['e'];
  final keys = e is String ? _cellKeys[e] : null;
  if (keys == null) return ['unknown event "$e"'];
  final errors = <String>[];
  final extra = cell.keys.where((k) => !keys.contains(k)).toList();
  if (extra.isNotEmpty) {
    errors.add('event "$e" has non-whitelisted fields: ${extra.join(', ')}');
  }
  final n = cell['n'];
  if (n is! int || n < 1 || n > maxCellCount) {
    errors.add('n must be an integer 1..10000');
  }
  if (e == 'measurement_error') {
    if (!errorIds.contains(cell['error_id'])) {
      errors.add('unknown error_id "${cell['error_id']}"');
    }
    return errors;
  }
  if (e == 'catalog_open') {
    if (!catalogIds.contains(cell['catalog_id'])) {
      errors.add('unknown catalog_id "${cell['catalog_id']}"');
    }
    return errors;
  }
  final section = cell['section'];
  if (section is! String || !sections.contains(section)) {
    errors.add('unknown section "$section"');
    return errors;
  }
  if (e == 'feature_use') {
    if (!featureIds.contains(cell['feature_id'])) {
      errors.add('unknown feature_id "${cell['feature_id']}"');
    }
    return errors;
  }
  errors.addAll(
    validateContentId(section, cell['content_id'], publicIds: publicIds),
  );
  if (e == 'text_read') {
    if (!sectionContentKind.containsKey(section)) {
      errors.add('text_read requires a section with content_id');
    }
    final metric = cell['metric'];
    if (!textMetrics.contains(metric)) {
      errors.add('unknown metric "$metric"');
    } else {
      final allowed = metric == 'sd' ? scrollBuckets : timeBuckets;
      if (!allowed.contains(cell['bucket'])) {
        errors.add(
          'bucket "${cell['bucket']}" is invalid for metric "$metric"',
        );
      }
    }
  }
  return errors;
}

bool _isRealUtcDate(Object? day) {
  if (day is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(day)) {
    return false;
  }
  final parsed = DateTime.tryParse('${day}T00:00:00Z');
  return parsed != null && parsed.toIso8601String().substring(0, 10) == day;
}

/// Returns a list of problems; empty means valid.
List<String> validatePacket(Object? packet, {Set<String>? publicIds}) {
  if (packet is! Map) return ['packet must be an object'];
  final errors = <String>[];
  final extra = packet.keys.where((k) => !_packetKeys.contains(k)).toList();
  if (extra.isNotEmpty) {
    errors.add('packet has non-whitelisted fields: ${extra.join(', ')}');
  }
  if (packet['schema_version'] != schemaVersion) {
    errors.add('unsupported schema_version');
  }
  if (!_isRealUtcDate(packet['day'])) {
    errors.add('day must be a real UTC date YYYY-MM-DD');
  }
  if (!platforms.contains(packet['platform'])) {
    errors.add('unknown platform "${packet['platform']}"');
  }
  final version = packet['app_version'];
  if (version is! String || !RegExp(r'^\d{1,2}\.\d{1,2}$').hasMatch(version)) {
    errors.add('app_version must be coarse "major.minor"');
  }
  if (!regions.contains(packet['region'])) {
    errors.add('unknown region "${packet['region']}"');
  }
  final cells = packet['cells'];
  if (cells is! List) {
    errors.add('cells must be an array');
  } else {
    if (cells.isEmpty || cells.length > maxCellsPerPacket) {
      errors.add('cells must hold 1..$maxCellsPerPacket items');
    }
    final seen = <String>{};
    for (var i = 0; i < cells.length; i++) {
      for (final problem in validateCell(cells[i], publicIds: publicIds)) {
        errors.add('cells[$i]: $problem');
      }
      final cell = cells[i];
      if (cell is Map) {
        final key = cellKey(cell);
        if (!seen.add(key)) {
          errors.add('cells[$i]: duplicate cell (counts must be merged)');
        }
      }
    }
  }
  if (errors.isEmpty &&
      utf8.encode(jsonEncode(packet)).length > maxPacketBytes) {
    errors.add('packet exceeds maxPacketBytes');
  }
  return errors;
}

/// Deterministic identity of a cell without its count (sorted keys).
String cellKey(Map cell) {
  final keys =
      cell.keys.where((k) => k != 'n').map((k) => k.toString()).toList()
        ..sort();
  return jsonEncode({for (final k in keys) k: cell[k]});
}
