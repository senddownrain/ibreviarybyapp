import 'package:intl/intl.dart';

/// Router compatibility adapter used until the four-tab AppShell owns reader
/// navigation. It keeps domain context out of route-string construction.
String readingsRouteForContext({required DateTime date, String? dayId}) {
  final dateKey = DateFormat('yyyy-MM-dd').format(date);
  final normalizedDayId = dayId?.trim();
  if (normalizedDayId == null || normalizedDayId.isEmpty) {
    return Uri(
      path: '/readings',
      queryParameters: {'date': dateKey},
    ).toString();
  }
  return Uri(
    path: '/readings',
    queryParameters: {'date': dateKey, 'dayId': normalizedDayId},
  ).toString();
}

String oraRouteForContext({
  required DateTime date,
  required String dayId,
  required String oraType,
}) {
  final dateKey = DateFormat('yyyy-MM-dd').format(date);
  return Uri(
    pathSegments: ['', 'hours', 'ora', dateKey, dayId, oraType],
  ).toString();
}

String horaRouteForContext({required DateTime date, required String dayId}) {
  final dateKey = DateFormat('yyyy-MM-dd').format(date);
  return Uri(pathSegments: ['', 'hours', 'hora', dateKey, dayId]).toString();
}
