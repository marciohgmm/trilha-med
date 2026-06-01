import 'package:flutter/material.dart';

import '../../application/rbac/rbac_service.dart';
import '../../core/permissions/app_permission.dart';
import '../../core/permissions/app_role.dart';
import '../../core/permissions/permission_context.dart';

/// Middlewares/helpers imperativos para checagem de permissão em ações e rotas.
class RbacGuard {
  RbacGuard._();

  static final _rbac = RbacService.instance;

  /// Verifica permissão; retorna `false` e registra auditoria se negado.
  static Future<bool> check({
    required BuildContext context,
    String? permissionKey,
    AppPermission? permission,
    AppRole? role,
    required String routeName,
    PermissionContext? existingContext,
  }) async {
    final ctx = existingContext ?? await _rbac.resolveContext();
    var ok = true;
    if (role != null) ok = ctx.hasRole(role);
    final key = permissionKey ?? permission?.key;
    if (key != null && key.isNotEmpty) ok = ok && ctx.hasKey(key);

    await _rbac.logAccessAttempt(
      granted: ok,
      routeName: routeName,
      permissionKey: key,
      requiredRole: role,
    );

    if (!ok && context.mounted) {
      _showDeniedSnackBar(context, routeName: routeName, permissionKey: key);
    }
    return ok;
  }

  /// Navega apenas se permitido; caso contrário exibe feedback.
  static Future<void> pushIfAllowed({
    required BuildContext context,
    required Widget page,
    String? permissionKey,
    AppPermission? permission,
    AppRole? role,
    required String routeName,
  }) async {
    final ok = await check(
      context: context,
      permissionKey: permissionKey,
      permission: permission,
      role: role,
      routeName: routeName,
    );
    if (!ok || !context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  static void _showDeniedSnackBar(
    BuildContext context, {
    required String routeName,
    String? permissionKey,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFFDC2626),
        content: Text(
          permissionKey != null && permissionKey.isNotEmpty
              ? 'Acesso negado ($permissionKey)'
              : 'Acesso negado: $routeName',
        ),
      ),
    );
  }
}
