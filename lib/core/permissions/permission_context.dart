import 'app_permission.dart';
import 'app_role.dart';
import 'permission_checker.dart';

/// Contexto de permissão do usuário logado.
class PermissionContext {
  final String userId;
  final List<AppRole> roles;
  final Set<AppPermission> extraPermissions;

  /// União de chaves (enum + dinâmicas do Firestore).
  final Set<String> grantedPermissionKeys;

  final bool isFounder;
  final bool isLegacyAdmin;

  /// Campo `users.isAdmin` no Firestore (sinal legado F4).
  final bool hasIsAdminDocumentFlag;

  const PermissionContext({
    required this.userId,
    this.roles = const [AppRole.user],
    this.extraPermissions = const {},
    this.grantedPermissionKeys = const {},
    this.isFounder = false,
    this.isLegacyAdmin = false,
    this.hasIsAdminDocumentFlag = false,
  });

  bool has(AppPermission permission) => hasKey(permission.key);

  /// Permissão dinâmica (criada só no Firestore, sem alterar o app).
  bool hasKey(String permissionKey) =>
      PermissionChecker.hasKey(this, permissionKey);

  bool hasAnyRole(Iterable<AppRole> required) {
    if (isFounder) return true;
    if (isLegacyAdmin &&
        required.any((r) => r == AppRole.admin || r == AppRole.masterAdmin)) {
      return true;
    }
    return required.any(roles.contains);
  }

  bool hasRole(AppRole role) => hasAnyRole([role]);

  bool get canAccessAdminPanel =>
      isFounder ||
      isLegacyAdmin ||
      hasRole(AppRole.masterAdmin) ||
      hasRole(AppRole.admin) ||
      hasKey(AppPermission.adminPanelAccess.key);
}
