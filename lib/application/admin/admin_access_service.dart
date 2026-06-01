import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../core/audit/audit_event_type.dart';
import '../../core/permissions/permission_context.dart';
import '../../services/auth/admin_auth_service.dart';
import '../platform/platform_registry.dart';
import '../rbac/rbac_service.dart';
import 'admin_legacy_compat.dart';

/// Resolução única de acesso administrativo — RBAC como fonte principal (R1 + F4).
class AdminAccessService {
  AdminAccessService({
    RbacService? rbac,
    AdminLegacyCompat? legacyCompat,
  })  : _rbac = rbac ?? RbacService.instance,
        _legacyCompat = legacyCompat ?? AdminLegacyCompat();

  static final AdminAccessService instance = AdminAccessService();

  final RbacService _rbac;
  final AdminLegacyCompat _legacyCompat;

  /// Ponto único: painel admin, home, AdminGate, compat legado.
  Future<AdminAccessResult> resolveAdminAccess({User? user}) async {
    final u = user ?? FirebaseAuth.instance.currentUser;
    if (u == null) {
      return const AdminAccessResult(
        allowed: false,
        isFounder: false,
        listedInAdmins: false,
      );
    }

    final founder = AdminAuthService.isFounderUser(u);
    final listed = founder || await _legacyCompat.isListedInAdminsCollection(u.uid);

    final ctx = await _rbac.resolveContext(user: u);
    final allowed = ctx.canAccessAdminPanel;

    if (kDebugMode) {
      debugPrint(
        '[AdminAccess] uid=${u.uid} founder=$founder listed=$listed '
        'legacyAdmin=${ctx.isLegacyAdmin} roles=${ctx.roles.map((r) => r.key)} '
        'allowed=$allowed',
      );
    }

    return AdminAccessResult(
      allowed: allowed,
      isFounder: founder,
      listedInAdmins: listed,
      hasIsAdminFlag: ctx.hasIsAdminDocumentFlag,
      email: AdminAuthService.normalizeEmail(u.email),
      uid: u.uid,
      permissionContext: ctx,
    );
  }

  Future<bool> canAccessAdminPanel({User? user}) async {
    final r = await resolveAdminAccess(user: user);
    return r.allowed;
  }

  Future<PermissionContext> resolvePermissionContext({User? user}) async {
    final r = await resolveAdminAccess(user: user);
    return r.permissionContext ?? await _rbac.resolveContext(user: user);
  }

  Future<void> logAdminAccessGranted({
    required String actorUserId,
    required String targetUserId,
    required String source,
    Map<String, dynamic> metadata = const {},
  }) async {
    await _logAdminPermissionChange(
      actorUserId: actorUserId,
      targetUserId: targetUserId,
      metadata: {
        'action': 'admin.access.granted',
        'source': source,
        ...metadata,
      },
    );
  }

  Future<void> logAdminAccessRevoked({
    required String actorUserId,
    required String targetUserId,
    required String source,
    Map<String, dynamic> metadata = const {},
  }) async {
    await _logAdminPermissionChange(
      actorUserId: actorUserId,
      targetUserId: targetUserId,
      metadata: {
        'action': 'admin.access.revoked',
        'source': source,
        ...metadata,
      },
    );
  }

  Future<void> _logAdminPermissionChange({
    required String actorUserId,
    required String targetUserId,
    required Map<String, dynamic> metadata,
  }) async {
    try {
      await PlatformRegistry.instance.audit.log(
        eventType: AuditEventType.permissionChanged,
        actorUserId: actorUserId,
        targetUserId: targetUserId,
        entityType: 'user',
        entityId: targetUserId,
        metadata: metadata,
      );
    } catch (e) {
      debugPrint('[AdminAccess] audit failed: $e');
    }
  }
}
