import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore values in the form the app stores (Timestamp → epoch ms).
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
