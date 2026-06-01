import '../base/firestore_entity.dart';

/// Evento espelhado em `platform_analytics_events` para dashboard admin.
class AnalyticsEventRecord implements FirestoreEntity {
  @override
  final String id;
  final String eventName;
  final String? userId;
  final Map<String, dynamic> parameters;
  final DateTime createdAt;

  const AnalyticsEventRecord({
    required this.id,
    required this.eventName,
    this.userId,
    this.parameters = const {},
    required this.createdAt,
  });

  factory AnalyticsEventRecord.fromDoc(String id, Map<String, dynamic>? d) {
    if (d == null) {
      return AnalyticsEventRecord(
        id: id,
        eventName: '',
        createdAt: DateTime.now(),
      );
    }
    return AnalyticsEventRecord(
      id: id,
      eventName: d['eventName']?.toString() ?? '',
      userId: d['userId']?.toString(),
      parameters: Map<String, dynamic>.from(d['parameters'] as Map? ?? {}),
      createdAt: FirestoreDates.from(d['createdAt']) ?? DateTime.now(),
    );
  }

  @override
  Map<String, dynamic> toMap() => {
        'eventName': eventName,
        if (userId != null) 'userId': userId,
        'parameters': parameters,
        'createdAt': FirestoreDates.to(createdAt),
      };
}
