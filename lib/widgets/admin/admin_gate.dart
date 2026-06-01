import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../application/admin/admin_access_service.dart';
import '../../application/rbac/rbac_service.dart';
import '../../services/auth/admin_auth_service.dart';

/// Bloqueia rotas administrativas via [AdminAccessService] (RBAC + compat legado).
class AdminGate extends StatefulWidget {
  final Widget child;
  final bool skipForFounder;
  final String routeName;

  const AdminGate({
    super.key,
    required this.child,
    this.skipForFounder = true,
    this.routeName = 'admin.panel',
  });

  @override
  State<AdminGate> createState() => _AdminGateState();
}

class _AdminGateState extends State<AdminGate> {
  final _adminAccess = AdminAccessService.instance;
  bool? _allowed;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('[AdminGate] sem usuário logado');
      await RbacService.instance.logAccessAttempt(
        granted: false,
        routeName: widget.routeName,
      );
      if (mounted) setState(() => _allowed = false);
      return;
    }

    if (widget.skipForFounder && AdminAuthService.isFounderUser(user)) {
      debugPrint('[AdminGate] founder bypass — liberando imediatamente');
      await RbacService.instance.logAccessAttempt(
        granted: true,
        routeName: widget.routeName,
      );
      if (mounted) setState(() => _allowed = true);
      return;
    }

    debugPrint('[AdminGate] verificando acesso (AdminAccessService)…');
    final result = await _adminAccess.resolveAdminAccess(user: user);
    final allowed = result.allowed;

    debugPrint(
      '[AdminGate] allowed=$allowed founder=${result.isFounder} '
      'listed=${result.listedInAdmins} legacyFlag=${result.hasIsAdminFlag}',
    );

    await RbacService.instance.logAccessAttempt(
      granted: allowed,
      routeName: widget.routeName,
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
      return Scaffold(
        appBar: AppBar(title: const Text('Acesso restrito')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 56, color: Color(0xFF1E3A8A)),
                const SizedBox(height: 16),
                const Text(
                  'Área exclusiva para administradores.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
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
    debugPrint('[AdminGate] AdminPage liberada');
    return widget.child;
  }
}

/// AppBar com título oculto do admin: TRILHA MED / Bom estudo.
class TrilhaMedAdminTitle extends StatelessWidget {
  final VoidCallback? onAdminPressStart;
  final VoidCallback? onAdminPressEnd;

  const TrilhaMedAdminTitle({
    super.key,
    this.onAdminPressStart,
    this.onAdminPressEnd,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => onAdminPressStart?.call(),
      onTapUp: (_) => onAdminPressEnd?.call(),
      onTapCancel: () => onAdminPressEnd?.call(),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'TRILHA MED',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 17,
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: 2),
          Text(
            'Bom estudo',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
