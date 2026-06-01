import 'package:flutter/material.dart';

import '../../application/rbac/rbac_service.dart';
import '../../core/permissions/app_permission.dart';
import '../../core/permissions/app_role.dart';

/// Guarda reutilizável: exige permissão ou papel antes de renderizar [child].
class RbacGate extends StatefulWidget {
  final Widget child;
  final String? requiredPermissionKey;
  final AppPermission? requiredPermission;
  final AppRole? requiredRole;
  final String routeName;
  final Widget? deniedChild;

  const RbacGate({
    super.key,
    required this.child,
    this.requiredPermissionKey,
    this.requiredPermission,
    this.requiredRole,
    this.routeName = 'unknown',
    this.deniedChild,
  });

  @override
  State<RbacGate> createState() => _RbacGateState();
}

class _RbacGateState extends State<RbacGate> {
  final _rbac = RbacService.instance;
  bool? _allowed;

  @override
  void initState() {
    super.initState();
    _evaluate();
  }

  Future<void> _evaluate() async {
    final ctx = await _rbac.resolveContext();
    var allowed = true;

    if (widget.requiredRole != null) {
      allowed = ctx.hasRole(widget.requiredRole!);
    }
    final permKey =
        widget.requiredPermissionKey ?? widget.requiredPermission?.key;
    if (permKey != null && permKey.isNotEmpty) {
      allowed = allowed && ctx.hasKey(permKey);
    }

    await _rbac.logAccessAttempt(
      granted: allowed,
      routeName: widget.routeName,
      permissionKey: permKey,
      requiredRole: widget.requiredRole,
    );

    if (mounted) setState(() => _allowed = allowed);
  }

  @override
  Widget build(BuildContext context) {
    if (_allowed == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_allowed == false) {
      return widget.deniedChild ?? _DefaultDenied(routeName: widget.routeName);
    }
    return widget.child;
  }
}

class _DefaultDenied extends StatelessWidget {
  final String routeName;

  const _DefaultDenied({required this.routeName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Acesso negado')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.block, size: 56, color: Color(0xFFDC2626)),
              const SizedBox(height: 16),
              Text(
                'Você não tem permissão para acessar:\n$routeName',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Voltar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
