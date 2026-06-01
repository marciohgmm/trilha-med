import '../core/permissions/app_permission.dart';
import '../core/permissions/app_role.dart';
import '../domain/platform/models/rbac_permission_definition.dart';
import '../domain/platform/models/rbac_role_definition.dart';

/// Seed inicial RBAC — gravado uma vez se as coleções estiverem vazias.
class RbacDefaultSeed {
  RbacDefaultSeed._();

  static List<RbacPermissionDefinition> permissions() {
    return RolePermissionMatrix.allKeys.map((key) {
      return RbacPermissionDefinition(
        id: key,
        label: _labelFor(key),
        description: 'Permissão do sistema: $key',
        isActive: true,
        category: _categoryFor(key),
      );
    }).toList();
  }

  static List<RbacRoleDefinition> roles() {
    final matrix = RolePermissionMatrix.defaults;
    return AppRole.primaryProfiles.map((role) {
      final perms = matrix[role] ?? const <AppPermission>{};
      return RbacRoleDefinition(
        id: role.key,
        label: role.label,
        permissionKeys: perms.map((p) => p.key).toList(),
        isSystem: true,
        priority: _priorityFor(role),
      );
    }).toList();
  }

  static int _priorityFor(AppRole role) {
    switch (role) {
      case AppRole.masterAdmin:
        return 100;
      case AppRole.admin:
        return 80;
      case AppRole.support:
        return 60;
      case AppRole.seller:
        return 40;
      default:
        return 10;
    }
  }

  static String _categoryFor(String key) {
    if (key.startsWith('admin.') || key.startsWith('rbac.') || key.startsWith('feature_flags.')) {
      return 'admin';
    }
    if (key.contains('payment') || key.contains('subscription')) {
      return 'commerce';
    }
    if (key.contains('content')) return 'content';
    return 'general';
  }

  static String _labelFor(String key) {
    switch (key) {
      case 'admin.panel.access':
        return 'Acessar painel administrativo';
      case 'rbac.manage':
        return 'Gerenciar papéis e permissões';
      case 'content.read':
        return 'Ler conteúdo';
      case 'content.write':
        return 'Editar conteúdo';
      case 'platform.settings':
        return 'Configurações da plataforma';
      case 'feature_flags.manage':
        return 'Gerenciar feature flags';
      case 'dashboard.view':
        return 'Ver dashboard mestre';
      default:
        return key;
    }
  }
}
