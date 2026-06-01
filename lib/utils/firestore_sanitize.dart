import 'package:cloud_firestore/cloud_firestore.dart';

/// Remove valores inválidos para gravação no Firestore (null, tipos não suportados).
Map<String, dynamic> sanitizeForFirestore(Map<String, dynamic> input) {
  final out = <String, dynamic>{};
  input.forEach((key, value) {
    final v = _sanitizeValue(value);
    if (v != null) out[key] = v;
  });
  return out;
}

dynamic _sanitizeValue(dynamic value) {
  if (value == null) return null;
  if (value is String || value is bool || value is num) return value;
  if (value is Timestamp || value is DateTime) {
    return value is DateTime ? Timestamp.fromDate(value) : value;
  }
  if (value is List) {
    return value.map(_sanitizeValue).where((e) => e != null).toList();
  }
  if (value is Map) {
    final m = <String, dynamic>{};
    value.forEach((k, v) {
      final key = k.toString();
      final sv = _sanitizeValue(v);
      if (sv != null) m[key] = sv;
    });
    return m;
  }
  return value.toString();
}
