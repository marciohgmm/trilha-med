import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../application/platform/platform_registry.dart';
import '../../../core/advertising/advertising_enums.dart';
import '../../../domain/platform/models/ad_campaign.dart';
import '../../../widgets/master_admin/master_admin_campaign_forms.dart';
import '../../../widgets/master_admin/master_admin_commercial_forms.dart';
import '../../../widgets/master_admin/master_admin_diagnostics_panel.dart';
import '../../../widgets/master_admin/master_admin_empty_module.dart';
import '../../../widgets/master_admin/master_admin_module_scaffold.dart';

class MasterAdminCampaignsPage extends StatelessWidget {
  const MasterAdminCampaignsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MasterAdminModuleScaffold(
      title: 'Campanhas',
      subtitle: 'CRUD · `platform_ad_campaigns`',
      floatingActionButton: FloatingActionButton(
        onPressed: () => _save(context, null),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<AdCampaign>>(
        stream: PlatformRegistry.instance.repositories.adCampaigns.watchAll(),
        builder: (context, snap) {
          if (snap.hasError) {
            return MasterAdminModuleErrorView(error: snap.error);
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data!;
          if (items.isEmpty) {
            return MasterAdminEmptyModule(
              title: 'Nenhuma campanha',
              message:
                  'Crie campanhas com segmentação e placements. '
                  'Exibição no app permanece desligada até ativar feature flag.',
              action: FilledButton.icon(
                onPressed: () => _save(context, null),
                icon: const Icon(Icons.add),
                label: const Text('Criar campanha'),
              ),
            );
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) => _CampaignTile(campaign: items[i]),
          );
        },
      ),
    );
  }

  Future<void> _save(BuildContext context, AdCampaign? existing) async {
    final campaign =
        await MasterAdminCampaignForms.campaign(context, existing: existing);
    if (campaign == null || !context.mounted) return;
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'admin';
    await PlatformRegistry.instance.adCampaignAdmin.save(
      actorUserId: uid,
      campaign: campaign,
    );
  }
}

class _CampaignTile extends StatelessWidget {
  const _CampaignTile({required this.campaign});

  final AdCampaign campaign;

  @override
  Widget build(BuildContext context) {
    final admin = PlatformRegistry.instance.adCampaignAdmin;
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'admin';

    return ListTile(
      leading: Icon(_iconForFormat(campaign.format)),
      title: Text(campaign.name),
      subtitle: Text(
        '${campaign.format.label} · ${campaign.lifecycle.label}\n'
        'Audiência: ${campaign.audienceSegment.label}\n'
        'Placements: ${campaign.placements.map((p) => p.label).join(', ')}\n'
        'Impressões: ${campaign.impressions} · Cliques: ${campaign.clicks} · '
        'CTR: ${campaign.ctr.toStringAsFixed(1)}%',
      ),
      isThreeLine: true,
      trailing: PopupMenuButton<String>(
        onSelected: (action) async {
          switch (action) {
            case 'edit':
              final updated = await MasterAdminCampaignForms.campaign(
                context,
                existing: campaign,
              );
              if (updated != null && context.mounted) {
                await admin.save(actorUserId: uid, campaign: updated);
              }
            case 'pause':
              await admin.pause(actorUserId: uid, campaign: campaign);
            case 'resume':
              await admin.resume(actorUserId: uid, campaign: campaign);
            case 'end':
              await admin.end(actorUserId: uid, campaign: campaign);
            case 'delete':
              final ok = await MasterAdminCommercialForms.confirmDelete(
                context,
                campaign.name,
              );
              if (ok && context.mounted) {
                await admin.delete(actorUserId: uid, campaignId: campaign.id);
              }
          }
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'edit', child: Text('Editar')),
          if (campaign.adminStatus == AdCampaignAdminStatus.active)
            const PopupMenuItem(value: 'pause', child: Text('Pausar')),
          if (campaign.adminStatus == AdCampaignAdminStatus.paused)
            const PopupMenuItem(value: 'resume', child: Text('Retomar')),
          const PopupMenuItem(value: 'end', child: Text('Encerrar')),
          const PopupMenuItem(value: 'delete', child: Text('Excluir')),
        ],
      ),
    );
  }

  IconData _iconForFormat(AdFormat format) {
    switch (format) {
      case AdFormat.banner:
        return Icons.view_day;
      case AdFormat.nativeCard:
        return Icons.article;
      case AdFormat.popup:
        return Icons.open_in_new;
      case AdFormat.fullscreen:
        return Icons.fullscreen;
      case AdFormat.institutional:
        return Icons.info;
    }
  }
}
