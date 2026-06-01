import 'package:flutter/material.dart';

import '../../../application/platform/platform_registry.dart';
import '../../../domain/platform/models/ad_campaign.dart';
import '../../../widgets/master_admin/master_admin_diagnostics_panel.dart';
import '../../../widgets/master_admin/master_admin_module_scaffold.dart';
import '../../../widgets/master_admin/master_admin_stat_card.dart';

class MasterAdminCampaignDashboardPage extends StatelessWidget {
  const MasterAdminCampaignDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final service = PlatformRegistry.instance.advertisingCampaigns;

    return MasterAdminModuleScaffold(
      title: 'Dashboard de campanhas',
      subtitle: 'Métricas agregadas · exibição no app desligada por padrão',
      body: StreamBuilder(
        stream: service.watchDashboard(),
        builder: (context, snap) {
          if (snap.hasError) {
            return MasterAdminModuleErrorView(error: snap.error);
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final d = snap.data!;
          String brl(double v) =>
              'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';

          return ListView(
            children: [
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.4,
                children: [
                  MasterAdminStatCard(
                    title: 'Campanhas ativas',
                    value: '${d.active.length}',
                    icon: Icons.play_circle_outline,
                    accentColor: const Color(0xFF059669),
                  ),
                  MasterAdminStatCard(
                    title: 'Agendadas',
                    value: '${d.scheduled.length}',
                    icon: Icons.schedule,
                    accentColor: const Color(0xFF1D4ED8),
                  ),
                  MasterAdminStatCard(
                    title: 'Encerradas / expiradas',
                    value: '${d.endedOrExpired.length}',
                    icon: Icons.stop_circle_outlined,
                  ),
                  MasterAdminStatCard(
                    title: 'CTR médio',
                    value: '${d.averageCtr.toStringAsFixed(1)}%',
                    icon: Icons.ads_click,
                  ),
                  MasterAdminStatCard(
                    title: 'Impressões',
                    value: '${d.totalImpressions}',
                    icon: Icons.visibility,
                  ),
                  MasterAdminStatCard(
                    title: 'Cliques',
                    value: '${d.totalClicks}',
                    icon: Icons.touch_app,
                  ),
                  MasterAdminStatCard(
                    title: 'Conversões',
                    value: '${d.totalConversions}',
                    icon: Icons.trending_up,
                  ),
                  MasterAdminStatCard(
                    title: 'Receita estimada',
                    value: brl(d.totalEstimatedRevenue),
                    icon: Icons.attach_money,
                    accentColor: const Color(0xFFD97706),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _section('Campanhas ativas', d.active),
              const SizedBox(height: 16),
              _section('Campanhas futuras (agendadas)', d.scheduled),
              const SizedBox(height: 16),
              _section('Campanhas encerradas / expiradas', d.endedOrExpired),
            ],
          );
        },
      ),
    );
  }

  Widget _section(String title, List<AdCampaign> campaigns) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3A8A),
          ),
        ),
        const SizedBox(height: 8),
        if (campaigns.isEmpty)
          const Card(
            child: ListTile(title: Text('Nenhuma campanha nesta categoria.')),
          )
        else
          ...campaigns.map(
            (c) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(c.name),
                subtitle: Text(
                  '${c.lifecycle.label} · ${c.format.label}\n'
                  'CTR: ${c.ctr.toStringAsFixed(1)}% · '
                  'Conv: ${c.conversions}',
                ),
                isThreeLine: true,
                trailing: Chip(label: Text(c.audienceSegment.label)),
              ),
            ),
          ),
      ],
    );
  }
}
