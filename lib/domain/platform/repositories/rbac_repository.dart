import '../../../core/rbac/rbac_catalog.dart';
import '../models/rbac_permission_definition.dart';
import '../models/rbac_role_definition.dart';

abstract class RbacRepository {
  Stream<RbacCatalog> watchCatalog();

  Future<RbacCatalog> loadCatalog();

  Future<int> ensureDefaultSeed();

  Future<void> saveRole(RbacRoleDefinition role);

  Future<void> savePermission(RbacPermissionDefinition permission);

  Future<List<RbacRoleDefinition>> listRoles();

  Future<List<RbacPermissionDefinition>> listPermissions();
}
