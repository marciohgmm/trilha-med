import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../core/audit/audit_event_type.dart';
import '../../core/constants/firestore_paths.dart';
import '../../core/permissions/app_permission.dart';
import '../../core/permissions/app_role.dart';
import '../../core/permissions/permission_checker.dart';
import '../../core/permissions/permission_context.dart';
import '../../core/rbac/rbac_catalog.dart';
import '../../domain/platform/repositories/rbac_repository.dart';
import '../../infrastructure/firestore/platform/firestore_rbac_repository.dart';
import '../../services/auth/admin_auth_service.dart';
import '../admin/admin_legacy_compat.dart';
import '../platform/platform_registry.dart';

/// Serviço central de RBAC — resolve papéis, permissões e auditoria.
class RbacService {
  RbacService({
    RbacRepository? repository,
    AdminLegacyCompat? legacyCompat,
  })  : _repository = repository ?? FirestoreRbacRepository(),
        _legacyCompat = legacyCompat ?? AdminLegacyCompat();

  static final RbacService instance = RbacService();

  final RbacRepository _repository;
  final AdminLegacyCompat _legacyCompat;

  RbacCatalog? _cachedCatalog;
  DateTime? _catalogLoadedAt;
  static const _catalogTtl = Duration(minutes: 5);

  /// Carrega catálogo (com cache curto) e registra no [PermissionChecker].
  Future<RbacCatalog> loadCatalog({bool forceRefresh = false}) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _cachedCatalog != null &&
        _catalogLoadedAt != null &&
        now.difference(_catalogLoadedAt!) < _catalogTtl) {
      return _cachedCatalog!;
    }
    try {
      await _repository.ensureDefaultSeed();
      _cachedCatalog = await _repository.loadCatalog();
    } catch (e) {
      debugPrint('[RbacService] loadCatalog fallback: $e');
      _cachedCatalog = RbacCatalog.fallback();
    }
    _catalogLoadedAt = now;
    PermissionChecker.bindCatalog(_cachedCatalog);
    return _cachedCatalog!;
  }

  /// Resolve contexto completo do usuário (sem alterar Auth).
  Future<PermissionContext> resolveContext({User? user}) async {
    final u = user ?? FirebaseAuth.instance.currentUser;
    if (u == null) {
      return const PermissionContext(userId: '');
    }

    final catalog = await loadCatalog();
    final founder = AdminAuthService.isFounderUser(u);

    Map<String, dynamic>? userData;
    try {
      final doc = await FirebaseFirestore.instance
          .collection(FirestorePaths.users)
          .doc(u.uid)
          .get();
      userData = doc.data();
    } catch (e) {
      debugPrint('[RbacService] erro lendo users/${u.uid}: $e');
    }

    final listedInAdmins =
        founder || await _legacyCompat.isListedInAdminsCollection(u.uid);
    final isAdminFlag = userData?['isAdmin'] == true;

    await _legacyCompat.ensureRbacRolesPersisted(
      userId: u.uid,
      isFounder: founder,
      listedInAdmins: listedInAdmins,
      isAdminFlag: isAdminFlag,
      userData: userData,
    );

    if (userData != null &&
        (userData['rbacRoles'] == null ||
            (userData['rbacRoles'] is List && (userData['rbacRoles'] as List).isEmpty))) {
      try {
        final refreshed = await FirebaseFirestore.instance
            .collection(FirestorePaths.users)
            .doc(u.uid)
            .get();
        userData = refreshed.data();
      } catch (_) {}
    }

    final legacyAdmin = founder || listedInAdmins || isAdminFlag;

    return PermissionChecker.fromUserDoc(
      userId: u.uid,
      userData: userData,
      isFounder: founder,
      isLegacyAdmin: legacyAdmin && !founder,
      catalog: catalog,
    );
  }

  Future<bool> canAccessAdminPanel({User? user}) async {
    final ctx = await resolveContext(user: user);
    return ctx.canAccessAdminPanel;
  }

  Future<bool> hasPermission(
    String permissionKey, {
    User? user,
    PermissionContext? context,
  }) async {
    final ctx = context ?? await resolveContext(user: user);
    return ctx.hasKey(permissionKey);
  }

  Future<bool> hasAppPermission(
    AppPermission permission, {
    User? user,
    PermissionContext? context,
  }) async {
    return hasPermission(permission.key, user: user, context: context);
  }

  /// Registra acesso concedido ou negado (auditoria).
  Future<void> logAccessAttempt({
    required bool granted,
    required String routeName,
    String? permissionKey,
    AppRole? requiredRole,
    User? user,
  }) async {
    final u = user ?? FirebaseAuth.instance.currentUser;
    if (u == null) return;

    try {
      await PlatformRegistry.instance.audit.log(
        eventType: granted ? AuditEventType.accessGranted : AuditEventType.accessDenied,
        actorUserId: u.uid,
        entityType: 'route',
        entityId: routeName,
        metadata: {
          'permissionKey': permissionKey ?? '',
          'requiredRole': requiredRole?.key ?? '',
          'granted': granted,
        },
      );
    } catch (e) {
      debugPrint('[RbacService] audit log failed: $e');
    }
  }

  /// Atribui papéis RBAC ao usuário (admin com rbac.manage).
  Future<void> assignRolesToUser({
    required String targetUserId,
    required List<AppRole> roles,
    required PermissionContext actor,
  }) async {
    if (!actor.has(AppPermission.rbacManage) && !actor.isFounder) {
      throw StateError('Sem permissão rbac.manage');
    }
    await FirebaseFirestore.instance
        .collection(FirestorePaths.users)
        .doc(targetUserId)
        .set({
      'rbacRoles': roles.map((r) => r.key).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await PlatformRegistry.instance.audit.log(
      eventType: AuditEventType.permissionChanged,
      actorUserId: actor.userId,
      targetUserId: targetUserId,
      entityType: 'user',
      entityId: targetUserId,
      metadata: {
        'action': 'rbac.roles.assigned',
        'source': 'rbac.assignRolesToUser',
        'rbacRoles': roles.map((r) => r.key).toList(),
      },
    );
  }
}
