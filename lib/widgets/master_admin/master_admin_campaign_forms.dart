import 'package:flutter/material.dart';

import '../../core/advertising/advertising_enums.dart';
import '../../domain/platform/models/ad_campaign.dart';

/// Formulários de campanhas publicitárias.
class MasterAdminCampaignForms {
  MasterAdminCampaignForms._();

  static Future<AdCampaign?> campaign(
    BuildContext context, {
    AdCampaign? existing,
  }) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final bodyCtrl = TextEditingController(text: existing?.bodyText ?? '');
    final imageCtrl = TextEditingController(text: existing?.imageUrl ?? '');
    final urlCtrl = TextEditingController(text: existing?.targetUrl ?? '');
    final partnerCtrl = TextEditingController(text: existing?.partnerName ?? '');
    final logoCtrl = TextEditingController(text: existing?.partnerLogoUrl ?? '');
    final couponCtrl = TextEditingController(text: existing?.promoCouponCode ?? '');
    final revenueCtrl = TextEditingController(
      text: '${existing?.estimatedRevenue ?? 0}',
    );
    final priorityCtrl = TextEditingController(text: '${existing?.priority ?? 0}');

    var format = existing?.format ?? AdFormat.banner;
    var audience = existing?.audienceSegment ?? AdAudienceSegment.all;
    var adminStatus = existing?.adminStatus ?? AdCampaignAdminStatus.draft;
    var selectedPlacements = Set<AdPlacement>.from(existing?.placements ?? []);
    DateTime? startsAt = existing?.startsAt;
    DateTime? endsAt = existing?.endsAt;

    return showDialog<AdCampaign>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(existing == null ? 'Nova campanha' : 'Editar campanha'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Nome da campanha'),
                  ),
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(labelText: 'Descrição interna'),
                    maxLines: 2,
                  ),
                  DropdownButtonFormField<AdFormat>(
                    initialValue: format,
                    decoration: const InputDecoration(labelText: 'Tipo de anúncio'),
                    items: AdFormat.values
                        .map((f) => DropdownMenuItem(value: f, child: Text(f.label)))
                        .toList(),
                    onChanged: (v) => setLocal(() => format = v!),
                  ),
                  DropdownButtonFormField<AdAudienceSegment>(
                    initialValue: audience,
                    decoration: const InputDecoration(labelText: 'Segmentação'),
                    items: AdAudienceSegment.values
                        .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                        .toList(),
                    onChanged: (v) => setLocal(() => audience = v!),
                  ),
                  DropdownButtonFormField<AdCampaignAdminStatus>(
                    initialValue: adminStatus,
                    decoration: const InputDecoration(labelText: 'Status admin'),
                    items: AdCampaignAdminStatus.values
                        .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                        .toList(),
                    onChanged: (v) => setLocal(() => adminStatus = v!),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Locais (placements)', style: Theme.of(ctx).textTheme.titleSmall),
                  ),
                  ...AdPlacement.values.map((p) {
                    return CheckboxListTile(
                      dense: true,
                      title: Text(p.label),
                      value: selectedPlacements.contains(p),
                      onChanged: (v) {
                        setLocal(() {
                          if (v == true) {
                            selectedPlacements.add(p);
                          } else {
                            selectedPlacements.remove(p);
                          }
                        });
                      },
                    );
                  }),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Início'),
                    subtitle: Text(startsAt == null
                        ? 'Imediato'
                        : '${startsAt!.day}/${startsAt!.month}/${startsAt!.year}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: startsAt ?? DateTime.now(),
                          firstDate: DateTime(2024),
                          lastDate: DateTime(2030),
                        );
                        if (d != null) setLocal(() => startsAt = d);
                      },
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Término'),
                    subtitle: Text(endsAt == null
                        ? 'Sem data'
                        : '${endsAt!.day}/${endsAt!.month}/${endsAt!.year}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: endsAt ?? DateTime.now().add(const Duration(days: 30)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2035),
                        );
                        if (d != null) setLocal(() => endsAt = d);
                      },
                    ),
                  ),
                  const Divider(),
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: 'Título do criativo'),
                  ),
                  TextField(
                    controller: bodyCtrl,
                    decoration: const InputDecoration(labelText: 'Texto (card/popup/institucional)'),
                    maxLines: 3,
                  ),
                  TextField(
                    controller: imageCtrl,
                    decoration: const InputDecoration(labelText: 'URL da imagem'),
                  ),
                  TextField(
                    controller: urlCtrl,
                    decoration: const InputDecoration(labelText: 'Link de destino'),
                  ),
                  TextField(
                    controller: partnerCtrl,
                    decoration: const InputDecoration(labelText: 'Nome do parceiro'),
                  ),
                  TextField(
                    controller: logoCtrl,
                    decoration: const InputDecoration(labelText: 'URL logo parceiro'),
                  ),
                  TextField(
                    controller: couponCtrl,
                    decoration: const InputDecoration(labelText: 'Cupom promocional'),
                  ),
                  TextField(
                    controller: revenueCtrl,
                    decoration: const InputDecoration(labelText: 'Receita estimada (R\$)'),
                    keyboardType: TextInputType.number,
                  ),
                  TextField(
                    controller: priorityCtrl,
                    decoration: const InputDecoration(labelText: 'Prioridade'),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  ctx,
                  AdCampaign(
                    id: existing?.id ?? '',
                    name: nameCtrl.text.trim(),
                    description: descCtrl.text.trim(),
                    format: format,
                    placements: selectedPlacements.toList(),
                    audienceSegment: audience,
                    adminStatus: adminStatus,
                    startsAt: startsAt,
                    endsAt: endsAt,
                    title: titleCtrl.text.trim(),
                    bodyText: bodyCtrl.text.trim().isEmpty ? null : bodyCtrl.text.trim(),
                    imageUrl: imageCtrl.text.trim(),
                    targetUrl: urlCtrl.text.trim().isEmpty ? null : urlCtrl.text.trim(),
                    partnerName: partnerCtrl.text.trim().isEmpty ? null : partnerCtrl.text.trim(),
                    partnerLogoUrl: logoCtrl.text.trim().isEmpty ? null : logoCtrl.text.trim(),
                    promoCouponCode: couponCtrl.text.trim().isEmpty ? null : couponCtrl.text.trim(),
                    estimatedRevenue: double.tryParse(revenueCtrl.text) ?? 0,
                    priority: int.tryParse(priorityCtrl.text) ?? 0,
                    impressions: existing?.impressions ?? 0,
                    clicks: existing?.clicks ?? 0,
                    conversions: existing?.conversions ?? 0,
                    partnershipId: existing?.partnershipId,
                  ),
                );
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}
