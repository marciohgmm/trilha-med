import 'package:flutter/material.dart';
import '../../../application/platform/platform_registry.dart';
import '../../../application/platform/master_admin_diagnostics_service.dart';
import '../../../core/audit/audit_log_entry.dart';
import '../../../domain/platform/models/admin_dashboard_snapshot.dart';
import '../../../widgets/master_admin/master_admin_diagnostics_panel.dart';
import '../../../widgets/master_admin/master_admin_module_scaffold.dart';
import '../../../widgets/master_admin/master_admin_stat_card.dart';

class MasterAdminDashboardPage extends StatefulWidget {
  const MasterAdminDashboardPage({super.key});

  @override
  State<MasterAdminDashboardPage> createState() =>
      _MasterAdminDashboardPageState();
}

class _MasterAdminDashboardPageState extends State<MasterAdminDashboardPage> {
  AdminDashboardSnapshot? _snapshot;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snap =
          await PlatformRegistry.instance.masterAdminDashboard.loadSnapshot();
      if (mounted) {
        setState(() {
          _snapshot = snap;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MasterAdminModuleScaffold(
      title: 'Dashboard',
      subtitle: 'Visão geral da plataforma',
      actions: [
        IconButton(
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
          tooltip: 'Atualizar',
        ),
      ],
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      if (MasterAdminDiagnosticsService.isPermissionDenied(_error)) {
        return MasterAdminModuleErrorView(error: _error);
      }
      return Center(child: Text('Erro ao carregar: $_error'));
    }
    final s = _snapshot ?? AdminDashboardSnapshot.empty();
    String brl(double v) =>
        'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final cols = constraints.maxWidth > 900
                  ? 4
                  : constraints.maxWidth > 600
                      ? 2
                      : 1;
              final cards = [
                MasterAdminStatCard(
                  title: 'Total de usuários',
                  value: '${s.totalUsers}',
                  icon: Icons.people,
                ),
                MasterAdminStatCard(
                  title: 'Usuários ativos (30d)',
                  value: '${s.activeUsers}',
                  icon: Icons.person_pin,
                  accentColor: const Color(0xFF059669),
                ),
                MasterAdminStatCard(
                  title: 'Novos usuários (30d)',
                  value: '${s.newUsersLast30Days}',
                  icon: Icons.person_add,
                  accentColor: const Color(0xFF7C3AED),
                ),
                MasterAdminStatCard(
                  title: 'Administradores',
                  value: '${s.totalAdmins}',
                  icon: Icons.admin_panel_settings,
                ),
                MasterAdminStatCard(
                  title: 'Vendedores ativos',
                  value: '${s.totalSellers}',
                  icon: Icons.storefront,
                ),
                MasterAdminStatCard(
                  title: 'Afiliados ativos',
                  value: '${s.totalAffiliates}',
                  icon: Icons.hub,
                ),
                MasterAdminStatCard(
                  title: 'Total de assinaturas',
                  value: '${s.totalSubscriptions}',
                  icon: Icons.card_membership,
                  subtitle:
                      'Ativas: ${s.activeSubscriptions} · Trial: ${s.trialingSubscriptions}',
                ),
                MasterAdminStatCard(
                  title: 'Assinaturas expiradas',
                  value: '${s.expiredSubscriptions}',
                  icon: Icons.event_busy,
                  accentColor: const Color(0xFFB45309),
                ),
                MasterAdminStatCard(
                  title: 'Receita do mês',
                  value: brl(s.revenueMonth),
                  icon: Icons.payments,
                  accentColor: const Color(0xFF059669),
                  subtitle: 'Pagamentos succeeded (manual/gateway futuro)',
                ),
                MasterAdminStatCard(
                  title: 'Receita projetada / mês',
                  value: brl(s.projectedRevenueMonthly),
                  icon: Icons.trending_up,
                  accentColor: const Color(0xFFD97706),
                  subtitle: 'Baseada em planos das assinaturas ativas',
                ),
              ];
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.35,
                children: cards,
              );
            },
          ),
          const SizedBox(height: 24),
          const Text(
            'Conversão por vendedor',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A8A),
            ),
          ),
          const SizedBox(height: 8),
          if (s.sellerConversions.isEmpty)
            const Card(
              child: ListTile(title: Text('Nenhuma conversão registrada.')),
            )
          else
            ...s.sellerConversions.take(5).map(
                  (m) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.storefront),
                      title: Text(m.label),
                      trailing: Text('${m.conversions} vendas'),
                    ),
                  ),
                ),
          const SizedBox(height: 16),
          const Text(
            'Conversão por afiliado',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A8A),
            ),
          ),
          const SizedBox(height: 8),
          if (s.affiliateConversions.isEmpty)
            const Card(
              child: ListTile(title: Text('Nenhuma conversão registrada.')),
            )
          else
            ...s.affiliateConversions.take(5).map(
                  (m) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.hub),
                      title: Text(m.label),
                      trailing: Text('${m.conversions} conversões'),
                    ),
                  ),
                ),
          const SizedBox(height: 24),
          const Text(
            'Últimos eventos de auditoria',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A8A),
            ),
          ),
          const SizedBox(height: 8),
          if (s.recentAuditEvents.isEmpty)
            const Card(
              child: ListTile(
                title: Text('Nenhum evento registrado ainda.'),
              ),
            )
          else
            ...s.recentAuditEvents.map(_auditTile),
        ],
      ),
    );
  }

  Widget _auditTile(AuditLogEntry entry) {
    String fmt(DateTime dt) {
      final d = dt.day.toString().padLeft(2, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final h = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '$d/$m/${dt.year} $h:$min';
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.history, color: Color(0xFF1E3A8A)),
        title: Text(entry.eventType.key),
        subtitle: Text(
          '${entry.entityType ?? ''} ${entry.entityId ?? ''}\n'
          'Ator: ${entry.actorUserId}\n'
          '${fmt(entry.createdAt)}',
        ),
        isThreeLine: true,
      ),
    );
  }
}
