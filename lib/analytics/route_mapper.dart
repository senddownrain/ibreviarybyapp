// Maps a go_router location to the contract's (section, content_id) pair, or
// null when the screen must not be measured (lists, search, personal prayers,
// unknown routes). Pure Dart; the collector still checks content_id against
// the public inventory (fail closed). Port of the web `routeMapper.js`.
import 'contract.dart';

class AnalyticsTarget {
  const AnalyticsTarget(this.section, [this.contentId]);

  final String section;
  final String? contentId;

  @override
  bool operator ==(Object other) =>
      other is AnalyticsTarget &&
      other.section == section &&
      other.contentId == contentId;

  @override
  int get hashCode => Object.hash(section, contentId);

  @override
  String toString() => 'AnalyticsTarget($section, $contentId)';
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
      if (segments[1] == 'ora' && count == 5) {
        final hour = _contractHour(segments[4]);
        return hour == null ? null : AnalyticsTarget('hours', 'hour:$hour');
      }
      return null;
    case 'readings':
      if (count == 1 || (count == 3 && segments[1] == 'reading')) {
        return const AnalyticsTarget('readings');
      }
      if (segments[1] == 'picker') return const AnalyticsTarget('picker');
      return null;
    case 'prayers':
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
