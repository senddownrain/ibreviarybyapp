// Maps a go_router location to the contract's (section, content_id) pair, or
// null when the screen must not be measured (lists, search, personal prayers,
// unknown routes). Pure Dart; the collector still checks content_id against
// the public inventory (fail closed). Port of the web `routeMapper.js`.
import 'contract.dart';

/// Either a material/section ([section], [contentId]) or a catalog screen
/// ([catalogId]); never both.
class AnalyticsTarget {
  const AnalyticsTarget(this.section, [this.contentId]) : catalogId = null;
  const AnalyticsTarget.catalog(this.catalogId)
    : section = null,
      contentId = null;

  final String? section;
  final String? contentId;
  final String? catalogId;

  @override
  bool operator ==(Object other) =>
      other is AnalyticsTarget &&
      other.section == section &&
      other.contentId == contentId &&
      other.catalogId == catalogId;

  @override
  int get hashCode => Object.hash(section, contentId, catalogId);

  @override
  String toString() => 'AnalyticsTarget($section, $contentId, $catalogId)';
}

/// Flutter names the evening hour `vespers`; the contract uses `vesper`.
String? _contractHour(String type) {
  final id = type == 'vespers' ? 'vesper' : type;
  return hourIds.contains(id) ? id : null;
}

AnalyticsTarget? mapLocation(Uri uri, {required String massOrderPrayerId}) {
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segments.isEmpty) return null;
  final first = segments.first;
  final count = segments.length;

  switch (first) {
    case 'hours':
      if (count == 1) return const AnalyticsTarget('today');
      if (segments[1] == 'ordo') return const AnalyticsTarget('ordo');
      if (segments[1] == 'picker') return const AnalyticsTarget('picker');
      if (segments[1] == 'hora' && count == 4) {
        return const AnalyticsTarget.catalog('hours_list');
      }
      if (segments[1] == 'ora' && count == 5) {
        final hour = _contractHour(segments[4]);
        return hour == null ? null : AnalyticsTarget('hours', 'hour:$hour');
      }
      return null;
    case 'readings':
      // The daily readings screen is one generic material: no date, no day id.
      if (count == 1 || (count == 3 && segments[1] == 'reading')) {
        return const AnalyticsTarget('readings', 'reading:day');
      }
      if (segments[1] == 'picker') return const AnalyticsTarget('picker');
      return null;
    case 'prayers':
      if (count == 1) return const AnalyticsTarget.catalog('prayers_home');
      if (count == 2) {
        switch (segments[1]) {
          case 'all':
            return const AnalyticsTarget.catalog('prayers_all');
          case 'favorites':
            return const AnalyticsTarget.catalog('favorites');
          case 'songs':
            return const AnalyticsTarget.catalog('songs');
          case 'compendium':
            return const AnalyticsTarget.catalog('compendium_home');
        }
      }
      // The reading unit of the compendium is a whole part (p1..p4).
      if (count == 4 && segments[1] == 'compendium' && segments[2] == 'part') {
        return AnalyticsTarget('compendium', 'comp:${segments[3]}');
      }
      if (count == 3 && segments[1] == 'prayer' && segments[2] != 'add') {
        final id = segments[2];
        return id == massOrderPrayerId
            ? const AnalyticsTarget('mass', 'mass:order')
            : AnalyticsTarget('prayers', 'prayer:$id');
      }
      if (count == 3 && segments[1] == 'songs') {
        return AnalyticsTarget('songs', 'song:${segments[2]}');
      }
      if (count == 4 && segments[1] == 'compendium' && segments[2] == 'node') {
        return AnalyticsTarget('compendium', 'comp:${segments[3]}');
      }
      return null;
    case 'bible':
      final query = uri.queryParameters;
      final version = query['version'];
      final book = query['book'];
      if (count == 1 && (book == null || book.isEmpty)) {
        return const AnalyticsTarget.catalog('bible_books');
      }
      if (count == 1 &&
          (version == 'bel' || version == 'ru') &&
          book != null &&
          book.isNotEmpty &&
          query['chapter'] != null) {
        return AnalyticsTarget('bible', 'bible:$version:$book');
      }
      return null;
    case 'settings':
      return count == 1 ? const AnalyticsTarget('settings') : null;
    case 'about':
      return count == 1 ? const AnalyticsTarget('about') : null;
  }
  return null;
}
