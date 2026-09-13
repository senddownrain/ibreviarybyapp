import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/utils/readings_index.dart';

Map<String, dynamic> firestoreToStorable(Map<String, dynamic> data) =>
    data.map((k, v) => MapEntry(k, _convertValue(v)));

dynamic _convertValue(dynamic v) {
  if (v is Timestamp) return v.millisecondsSinceEpoch;
  if (v is DocumentReference) return v.path;
  if (v is GeoPoint) return {'lat': v.latitude, 'lng': v.longitude};
  if (v is Map) {
    return (v as Map<Object?, Object?>).map(
      (k, val) => MapEntry(k.toString(), _convertValue(val)),
    );
  }
  if (v is List) return v.map(_convertValue).toList();
  return v;
}

Future<void> cacheDayDoc(String id, Map<String, dynamic> data) async {
  await HiveService.putCached(
    'days',
    id,
    firestoreToStorable({...data, 'id': id}),
  );
}

Future<void> _readingWrites = Future.value();

Future<void> cacheReadingDoc(String id, Map<String, dynamic> data) {
  final next = _readingWrites.then((_) => _cacheReadingDoc(id, data));
  _readingWrites = next.catchError((Object _) {});
  return next;
}

Future<void> _cacheReadingDoc(String id, Map<String, dynamic> data) async {
  final storable = firestoreToStorable({...data, 'id': id});
  final previous = HiveService.readingsBox.get(id);
  if (previous is Map) {
    await ReadingsIndex.removeDoc(id, Map<String, dynamic>.from(previous));
  }
  await HiveService.putCached('readings', id, storable);
  await ReadingsIndex.indexDoc(id, storable);
}

Future<void> cacheYearOptionsDoc(String id, Map<String, dynamic> data) async {
  final year = data['year'];
  await HiveService.putCached(
    'yearOptions',
    year?.toString() ?? id,
    firestoreToStorable({...data, 'id': id}),
  );
}
