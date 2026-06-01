import 'package:cloud_firestore/cloud_firestore.dart';

/// Contrato mínimo para entidades persistidas no Firestore.
abstract class FirestoreEntity {
  String get id;
  Map<String, dynamic> toMap();
}

/// Helpers comuns de serialização de datas.
class FirestoreDates {
  FirestoreDates._();

  static DateTime? from(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static Timestamp? to(DateTime? value) =>
      value == null ? null : Timestamp.fromDate(value);
}
