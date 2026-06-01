import '../rbac/rbac_catalog.dart';
import 'app_permission.dart';
import 'app_role.dart';
import 'permission_context.dart';

/// Verificação centralizada de permissões (estática + catálogo Firestore).
class PermissionChecker {
  PermissionChecker._();

  static RbacCatalog? _catalog;

  static void bindCatalog(RbacCatalog? catalog) => _catalog = catalog;

  static bool hasKey(PermissionContext ctx, String permissionKey) {
    if (permissionKey.isEmpty) return false;
    if (ctx.isFounder) return true;
    if (ctx.grantedPermissionKeys.contains(permissionKey)) return true;
    return false;
  }

  static bool has(PermissionContext ctx, AppPermission permission) =>
      hasKey(ctx, permission.key);

  /// Monta contexto a partir do documento `users/{uid}` e catálogo RBAC.
  static PermissionContext fromUserDoc({
    required String userId,
    required Map<String, dynamic>? userData,
    required bool isFounder,
    required bool isLegacyAdmin,
    RbacCatalog? catalog,
  }) {
    final cat = catalog ?? _catalog ?? RbacCatalog.fallback();

    final roles = _resolveRoles(
      userData: userData,
      isFounder: isFounder,
      isLegacyAdmin: isLegacyAdmin,
    );

    final extraKeys = _readStringList(userData?['extraPermissions']);
    final extraPerms = <AppPermission>{};
    for (final k in extraKeys) {
      for (final p in AppPermission.values) {
        if (p.key == k) extraPerms.add(p);
      }
    }

    final granted = cat.permissionsForRoles(roles);
    granted.addAll(extraKeys);
    if (isFounder) {
      granted.addAll(cat.allPermissionKeys);
    }

    return PermissionContext(
      userId: userId,
      roles: roles,
      extraPermissions: extraPerms,
      grantedPermissionKeys: granted,
      isFounder: isFounder,
      isLegacyAdmin: isLegacyAdmin,
      hasIsAdminDocumentFlag: userData?['isAdmin'] == true,
    );
  }

  static List<AppRole> _resolveRoles({
    required Map<String, dynamic>? userData,
    required bool isFounder,
    required bool isLegacyAdmin,
  }) {
    if (isFounder) {
      return const [AppRole.masterAdmin];
    }

    final rbacRoles = _readStringList(userData?['rbacRoles']);
    final legacyRoles = _readStringList(userData?['roles']);
    final keys = rbacRoles.isNotEmpty ? rbacRoles : legacyRoles;

    var roles = AppRole.fromKeys(keys);
    if (roles.isEmpty) {
      roles = isLegacyAdmin ? const [AppRole.admin] : const [AppRole.user];
    }
    return roles;
  }

  static List<String> _readStringList(dynamic raw) {
    if (raw is! List) return const [];
    return raw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
  }
}
