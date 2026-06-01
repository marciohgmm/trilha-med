import '../permissions/app_permission.dart';
import '../permissions/app_role.dart';

/// Catálogo RBAC em memória (origem: Firestore ou fallback estático).
class RbacCatalog {
  final Map<String, RbacRoleSnapshot> rolesByKey;
  final Map<String, String> permissionLabels;

  const RbacCatalog({
    required this.rolesByKey,
    this.permissionLabels = const {},
  });

  Set<String> get allPermissionKeys {
    final keys = <String>{};
    for (final r in rolesByKey.values) {
      keys.addAll(r.permissionKeys);
    }
    keys.addAll(permissionLabels.keys);
    return keys;
  }

  Set<String> permissionsForRoles(Iterable<AppRole> roles) {
    final out = <String>{};
    for (final role in roles) {
      final snap = rolesByKey[role.key];
      if (snap != null) out.addAll(snap.permissionKeys);
    }
    if (out.isEmpty) {
      for (final role in roles) {
        final fallback = RolePermissionMatrix.defaults[role];
        if (fallback != null) {
          out.addAll(fallback.map((p) => p.key));
        }
      }
    }
    return out;
  }

  /// Fallback quando Firestore ainda não foi carregado.
  factory RbacCatalog.fallback() {
    final roles = <String, RbacRoleSnapshot>{};
    for (final entry in RolePermissionMatrix.defaults.entries) {
      roles[entry.key.key] = RbacRoleSnapshot(
        roleKey: entry.key.key,
        label: entry.key.label,
        permissionKeys: entry.value.map((p) => p.key).toSet(),
        isSystem: true,
      );
    }
    final labels = {
      for (final p in AppPermission.values) p.key: p.key,
    };
    return RbacCatalog(rolesByKey: roles, permissionLabels: labels);
  }
}

class RbacRoleSnapshot {
  final String roleKey;
  final String label;
  final Set<String> permissionKeys;
  final bool isSystem;
  final int priority;

  const RbacRoleSnapshot({
    required this.roleKey,
    required this.label,
    required this.permissionKeys,
    this.isSystem = false,
    this.priority = 0,
  });
}
