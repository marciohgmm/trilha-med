import '../base/firestore_entity.dart';
import 'audit_event_type.dart';

/// Registro imutável de auditoria (`platform_audit_logs`).
class AuditLogEntry implements FirestoreEntity {
  @override
  final String id;
  final AuditEventType eventType;
  final String actorUserId;
  final String? targetUserId;
  final String? entityType;
  final String? entityId;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  const AuditLogEntry({
    required this.id,
    required this.eventType,
    required this.actorUserId,
    this.targetUserId,
    this.entityType,
    this.entityId,
    this.metadata = const {},
    required this.createdAt,
  });

  factory AuditLogEntry.fromDoc(
    String id,
    Map<String, dynamic> data,
  ) {
    return AuditLogEntry(
      id: id,
      eventType: AuditEventType.fromKey(data['eventType']?.toString()) ??
          AuditEventType.adminAction,
      actorUserId: data['actorUserId']?.toString() ?? '',
      targetUserId: data['targetUserId']?.toString(),
      entityType: data['entityType']?.toString(),
      entityId: data['entityId']?.toString(),
      metadata: Map<String, dynamic>.from(data['metadata'] as Map? ?? {}),
      createdAt: FirestoreDates.from(data['createdAt']) ?? DateTime.now(),
    );
  }

  @override
  Map<String, dynamic> toMap() => {
        'eventType': eventType.key,
        'actorUserId': actorUserId,
        if (targetUserId != null) 'targetUserId': targetUserId,
        if (entityType != null) 'entityType': entityType,
        if (entityId != null) 'entityId': entityId,
        'metadata': metadata,
        'createdAt': FirestoreDates.to(createdAt),
      };

  AuditLogEntry copyWith({String? id}) => AuditLogEntry(
        id: id ?? this.id,
        eventType: eventType,
        actorUserId: actorUserId,
        targetUserId: targetUserId,
        entityType: entityType,
        entityId: entityId,
        metadata: metadata,
        createdAt: createdAt,
      );
}
