import '../../core/audit/audit_event_type.dart';
import '../../core/audit/audit_log_entry.dart';
import '../../domain/platform/repositories/platform_repository_contracts.dart';

/// Serviço de auditoria (append-only).
class PlatformAuditService {
  PlatformAuditService(this._auditRepo);

  final AuditLogRepository _auditRepo;

  Future<void> log({
    required AuditEventType eventType,
    required String actorUserId,
    String? targetUserId,
    String? entityType,
    String? entityId,
    Map<String, dynamic> metadata = const {},
  }) {
    return _auditRepo.append(
      AuditLogEntry(
        id: '',
        eventType: eventType,
        actorUserId: actorUserId,
        targetUserId: targetUserId,
        entityType: entityType,
        entityId: entityId,
        metadata: metadata,
        createdAt: DateTime.now(),
      ),
    );
  }
}
