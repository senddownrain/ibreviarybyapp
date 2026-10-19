import 'package:intl/intl.dart';

/// Router compatibility adapter used until the four-tab AppShell owns reader
/// navigation. It keeps domain context out of route-string construction.
///
/// Route identity of a liturgical Office: the date, the document (assembly)
/// id in the path — old links keep working — and, in the query, the
/// diocese context of the option (`diocese`) and the engine option
/// (`option`). A route context never changes Settings.
String readingsRouteForContext({
  required DateTime date,
  String? dayId,
  String? diocese,
  String? optionId,
}) {
  final dateKey = DateFormat('yyyy-MM-dd').format(date);
  final normalizedDayId = dayId?.trim();
  return Uri(
    path: '/readings',
    queryParameters: {
      'date': dateKey,
      if (normalizedDayId != null && normalizedDayId.isNotEmpty)
        'dayId': normalizedDayId,
      if (optionId != null && optionId.isNotEmpty) 'option': optionId,
      if (diocese != null && diocese.isNotEmpty) 'diocese': diocese,
    },
  ).toString();
}

Map<String, String>? _context(String? diocese, String? optionId) {
  final query = {
    if (diocese != null && diocese.isNotEmpty) 'diocese': diocese,
    if (optionId != null && optionId.isNotEmpty) 'option': optionId,
  };
  return query.isEmpty ? null : query;
}

String oraRouteForContext({
  required DateTime date,
  required String dayId,
  required String oraType,
  String? diocese,
  String? optionId,
}) {
  final dateKey = DateFormat('yyyy-MM-dd').format(date);
  return Uri(
    pathSegments: ['', 'hours', 'ora', dateKey, dayId, oraType],
    queryParameters: _context(diocese, optionId),
  ).toString();
}
