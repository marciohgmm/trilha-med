import 'package:flutter/material.dart';

import '../../../application/platform/master_admin_diagnostics_service.dart';
import '../../../application/platform/platform_registry.dart';
import '../../../application/rbac/rbac_service.dart';
import '../../../core/permissions/app_permission.dart';
import '../../../core/permissions/permission_context.dart';
import '../../../widgets/master_admin/master_admin_diagnostics_dialog.dart';
import '../../../widgets/master_admin/master_admin_module_scaffold.dart';

class MasterAdminSettingsPage extends StatefulWidget {
  const MasterAdminSettingsPage({super.key});

  @override
  State<MasterAdminSettingsPage> createState() =>
      _MasterAdminSettingsPageState();
}

class _MasterAdminSettingsPageState extends State<MasterAdminSettingsPage> {
  PermissionContext? _ctx;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ctx = await RbacService.instance.resolveContext();
    if (mounted) {
      setState(() {
        _ctx = ctx;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const MasterAdminModuleScaffold(
        title: 'Configurações',
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final ctx = _ctx!;
    final canRbac = ctx.has(AppPermission.rbacManage) || ctx.isFounder;

    return MasterAdminModuleScaffold(
      title: 'Configurações',
      subtitle: 'RBAC, permissões dinâmicas e preparação para pagamentos',
      body: ListView(
        children: [
          const ListTile(
            leading: Icon(Icons.security),
            title: Text('RBAC via Firestore'),
            subtitle: Text(
              'Papéis: platform_rbac_roles\n'
              'Permissões: platform_rbac_permissions\n'
              'Usuário: users/{uid}.rbacRoles',
            ),
            isThreeLine: true,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Seu usuário'),
            subtitle: Text(
              'UID: ${ctx.userId}\n'
              'Papéis: ${ctx.roles.map((r) => r.key).join(', ')}\n'
              'Permissões: ${ctx.grantedPermissionKeys.length}',
            ),
            isThreeLine: true,
          ),
          if (canRbac) ...[
            const Divider(),
            ListTile(
              leading: const Icon(Icons.bug_report_outlined),
              title: const Text('Diagnóstico Firestore'),
              subtitle: const Text(
                'Verifica auth, isAppAdmin e sondas platform_*',
              ),
              onTap: () async {
                final report =
                    await MasterAdminDiagnosticsService().run();
                if (!context.mounted) return;
                await showMasterAdminDiagnosticsDialog(
                  context,
                  report: report,
                  onRefresh: () async {
                    final r = await MasterAdminDiagnosticsService().run();
                    if (context.mounted) {
                      await showMasterAdminDiagnosticsDialog(
                        context,
                        report: r,
                      );
                    }
                  },
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Recarregar catálogo RBAC'),
              subtitle: const Text('Força leitura do Firestore (cache 5 min)'),
              onTap: () async {
                await RbacService.instance.loadCatalog(forceRefresh: true);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Catálogo RBAC atualizado.')),
                );
                await _load();
              },
            ),
          ],
          const Divider(),
          const ListTile(
            leading: Icon(Icons.payment),
            title: Text('Pagamentos (em breve)'),
            subtitle: Text(
              'Coleções prontas: platform_payments, platform_subscriptions.\n'
              'Integração Stripe / Mercado Pago será plugada em PlatformRegistry '
              'sem alterar autenticação nem fluxo dos alunos.',
            ),
            isThreeLine: true,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('PlatformRegistry'),
            subtitle: Text(
              'Repositórios ativos: ${PlatformRegistry.instance.repositories.runtimeType}',
            ),
          ),
        ],
      ),
    );
  }
}
