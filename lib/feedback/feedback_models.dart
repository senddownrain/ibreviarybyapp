/// Shared feedback contract (same Worker/D1 as MyBrev Web). Pure, no I/O.
library;

enum FeedbackCategory {
  textError('text_error', 'Памылка ў тэксце'),
  contentSuggestion('content_suggestion', 'Прапанова па тэкстах'),
  technicalBug('technical_bug', 'Тэхнічная праблема'),
  featureSuggestion('feature_suggestion', 'Прапанова па праграме'),
  other('other', 'Іншае пытанне');

  const FeedbackCategory(this.code, this.label);
  final String code;
  final String label;
}

const int kFeedbackMaxLength = 4000;
const int kFeedbackMinLength = 3;

final _safeId = RegExp(r'^[\p{L}\p{N}_\-.:]{1,128}$', unicode: true);
final _date = RegExp(r'^\d{4}-\d{2}-\d{2}$');
const _kinds = {
  'prayer',
  'song',
  'reading',
  'hour',
  'day',
  'bible',
  'compendium',
  'other',
};
const _hours = {
  'invitatory',
  'office_of_readings',
  'lauds',
  'daytime',
  'vespers',
  'compline',
  'mass',
  'other',
};

/// Safe automatic context: public ids/dates/names only. Anything else is dropped.
class FeedbackContext {
  const FeedbackContext({
    this.kind,
    this.id,
    this.date,
    this.hour,
    this.title,
    this.diocese,
    this.lang = 'be',
  });

  final String? kind;
  final String? id;
  final String? date;
  final String? hour;
  final String? title;
  final String? diocese;
  final String lang;

  /// Built from route query keys `ctx_kind`, `ctx_id`, `ctx_date`, `ctx_hour`,
  /// `ctx_title`; unknown or unsafe values are discarded. Null when empty.
  static FeedbackContext? fromQuery(Map<String, String> q, {String? diocese}) {
    final kind = _kinds.contains(q['ctx_kind']) ? q['ctx_kind'] : null;
    final id = q['ctx_id'] != null && _safeId.hasMatch(q['ctx_id']!)
        ? q['ctx_id']
        : null;
    final date = q['ctx_date'] != null && _date.hasMatch(q['ctx_date']!)
        ? q['ctx_date']
        : null;
    final hour = _hours.contains(q['ctx_hour']) ? q['ctx_hour'] : null;
    var title = q['ctx_title']?.trim();
    if (title != null && title.isEmpty) title = null;
    if (title != null && title.length > 120) title = title.substring(0, 120);
    if (kind == null &&
        id == null &&
        date == null &&
        hour == null &&
        title == null) {
      return null;
    }
    final safeDiocese =
        diocese != null && RegExp(r'^[a-z_]{2,24}$').hasMatch(diocese)
        ? diocese
        : null;
    return FeedbackContext(
      kind: kind,
      id: id,
      date: date,
      hour: hour,
      title: title,
      diocese: safeDiocese,
    );
  }

  Map<String, String> toJson() => {
    if (kind != null) 'kind': kind!,
    if (id != null) 'id': id!,
    if (date != null) 'date': date!,
    if (hour != null) 'hour': hour!,
    if (title != null) 'title': title!,
    if (diocese != null) 'diocese': diocese!,
    'lang': lang,
  };

  String get summary => [
    title,
    if (kind != null) 'тып: $kind',
    if (id != null) 'ID: $id',
    date,
    hour,
  ].whereType<String>().join(' · ');
}

/// Location of the "report an error" action for a material.
String feedbackLocation({
  required String kind,
  String? id,
  String? date,
  String? hour,
  String? title,
}) => Uri(
  path: '/settings/feedback',
  queryParameters: {
    'ctx_kind': kind,
    if (id != null) 'ctx_id': id,
    if (date != null) 'ctx_date': date,
    if (hour != null) 'ctx_hour': hour,
    if (title != null) 'ctx_title': title,
  },
).toString();

/// Label of the one "report an error" entry in the overflow menu of content screens.
const String kReportErrorLabel = 'Памылка';

const _hourByType = {
  'invitatorium': 'invitatory',
  'invitatory': 'invitatory',
  'office_of_readings': 'office_of_readings',
  'readings': 'office_of_readings',
  'lauds': 'lauds',
  'morning': 'lauds',
  'daytime': 'daytime',
  'terce': 'daytime',
  'sext': 'daytime',
  'none': 'daytime',
  'vespers': 'vespers',
  'evening': 'vespers',
  'compline': 'compline',
  'mass': 'mass',
};

/// Automatic "report an error" location for the screen at [uri], or null when
/// the screen is not a material (home, lists, settings, about, the form itself).
/// Only public ids, dates and hour codes from the route are used.
String? feedbackLocationForUri(Uri uri) {
  final segments = [
    for (final s in uri.pathSegments)
      if (s.isNotEmpty) s,
  ];
  if (segments.isEmpty) return null;
  final query = uri.queryParameters;
  String? safe(String? v) => v != null && _safeId.hasMatch(v) ? v : null;
  String? date(String? v) => v != null && _date.hasMatch(v) ? v : null;

  final rest = segments.first == 'hours' || segments.first == 'prayers'
      ? segments.sublist(1)
      : segments;
  if (rest.isEmpty) return null;
  final head = rest.first;
  final tail = rest.sublist(1);
  String? part(int i) => i < tail.length ? tail[i] : null;
  if (tail.contains('edit') || tail.contains('add')) return null;

  switch (head) {
    case 'ora':
      return feedbackLocation(
        kind: 'hour',
        id: safe(part(1)),
        date: date(part(0)),
        hour: _hourByType[part(2)] ?? 'other',
      );
    case 'hora':
      return feedbackLocation(
        kind: 'day',
        id: safe(part(1)),
        date: date(part(0)),
      );
    case 'readings':
    case 'reading':
      if (part(0) == 'picker' || part(0) == 'options') return null;
      final byId = head == 'reading' ? part(0) : null;
      return feedbackLocation(
        kind: 'reading',
        id: safe(byId ?? (part(0) == 'reading' ? part(1) : null)),
        date: date(query['date']) ?? date(part(0)),
      );
    case 'prayer':
      return part(0) == null
          ? null
          : feedbackLocation(kind: 'prayer', id: safe(part(0)));
    case 'songs':
      return part(0) == null
          ? null
          : feedbackLocation(kind: 'song', id: safe(part(0)));
    case 'compendium':
      return tail.isEmpty
          ? null
          : feedbackLocation(kind: 'compendium', id: safe(tail.last));
    case 'bible':
      return part(0) == null || part(0) == 'search'
          ? null
          : feedbackLocation(kind: 'bible', id: safe(tail.join('-')));
  }
  return null;
}

final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

/// Returns a Belarusian error text or null when valid.
String? validateFeedbackBody(String value) {
  final t = value.trim();
  if (t.length < kFeedbackMinLength) return 'Напішыце хаця б некалькі слоў.';
  if (t.length > kFeedbackMaxLength)
    return 'Занадта доўга (максімум $kFeedbackMaxLength).';
  return null;
}

String? validateFeedbackEmail(String value) {
  final t = value.trim();
  if (t.isEmpty) return null;
  return t.length <= 254 && _email.hasMatch(t) ? null : 'Праверце адрас email.';
}
