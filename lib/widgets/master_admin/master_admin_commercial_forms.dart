import 'package:flutter/material.dart';

import '../../core/commercial/commercial_entitlement.dart';
import '../../domain/platform/enums/platform_enums.dart';
import '../../domain/platform/models/advertisement.dart';
import '../../domain/platform/models/affiliate.dart';
import '../../domain/platform/models/coupon.dart';
import '../../domain/platform/models/partnership.dart';
import '../../domain/platform/models/seller.dart';
import '../../domain/platform/models/subscription_plan.dart';

/// Diálogos de formulário reutilizáveis para CRUD comercial do Painel Mestre.
class MasterAdminCommercialForms {
  MasterAdminCommercialForms._();

  static Future<SubscriptionPlan?> plan(
    BuildContext context, {
    SubscriptionPlan? existing,
  }) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final monthlyCtrl = TextEditingController(
      text: existing?.priceMonthly.toString() ?? '0',
    );
    final yearlyCtrl = TextEditingController(
      text: existing?.priceYearly.toString() ?? '0',
    );
    final sortCtrl = TextEditingController(
      text: '${existing?.sortOrder ?? 0}',
    );
    var tier = existing?.tier ?? PlanTier.premium;
    var isActive = existing?.isActive ?? true;
    final benefitsCtrl = TextEditingController(
      text: (existing?.benefitLabels ?? []).join('\n'),
    );

    return showDialog<SubscriptionPlan>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(existing == null ? 'Novo plano' : 'Editar plano'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nome'),
                ),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Descrição'),
                  maxLines: 2,
                ),
                TextField(
                  controller: monthlyCtrl,
                  decoration: const InputDecoration(labelText: 'Preço mensal (R\$)'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: yearlyCtrl,
                  decoration: const InputDecoration(labelText: 'Preço anual (R\$)'),
                  keyboardType: TextInputType.number,
                ),
                DropdownButtonFormField<PlanTier>(
                  initialValue: tier,
                  decoration: const InputDecoration(labelText: 'Tier'),
                  items: PlanTier.values
                      .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                      .toList(),
                  onChanged: (v) => setLocal(() => tier = v!),
                ),
                TextField(
                  controller: sortCtrl,
                  decoration: const InputDecoration(labelText: 'Ordem'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: benefitsCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Benefícios (um por linha)',
                  ),
                  maxLines: 4,
                ),
                SwitchListTile(
                  title: const Text('Ativo'),
                  value: isActive,
                  onChanged: (v) => setLocal(() => isActive = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  ctx,
                  SubscriptionPlan(
                    id: existing?.id ?? '',
                    name: nameCtrl.text.trim(),
                    description: descCtrl.text.trim(),
                    priceMonthly: double.tryParse(monthlyCtrl.text) ?? 0,
                    priceYearly: double.tryParse(yearlyCtrl.text) ?? 0,
                    tier: tier,
                    benefitLabels: benefitsCtrl.text
                        .split('\n')
                        .map((e) => e.trim())
                        .where((e) => e.isNotEmpty)
                        .toList(),
                    isActive: isActive,
                    sortOrder: int.tryParse(sortCtrl.text) ?? 0,
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

  static Future<Coupon?> coupon(BuildContext context, {Coupon? existing}) {
    final codeCtrl = TextEditingController(text: existing?.code ?? '');
    final valueCtrl = TextEditingController(
      text: existing?.discountValue.toString() ?? '10',
    );
    final maxUsesCtrl = TextEditingController(
      text: '${existing?.maxUses ?? 0}',
    );
    var discountType = existing?.discountType ?? CouponDiscountType.percent;
    var isActive = existing?.isActive ?? true;

    return showDialog<Coupon>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(existing == null ? 'Novo cupom' : 'Editar cupom'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: codeCtrl,
                  decoration: const InputDecoration(labelText: 'Código'),
                  textCapitalization: TextCapitalization.characters,
                ),
                DropdownButtonFormField<CouponDiscountType>(
                  initialValue: discountType,
                  decoration: const InputDecoration(labelText: 'Tipo de desconto'),
                  items: CouponDiscountType.values
                      .map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(t.key == 'percent' ? 'Percentual' : 'Fixo'),
                          ))
                      .toList(),
                  onChanged: (v) => setLocal(() => discountType = v!),
                ),
                TextField(
                  controller: valueCtrl,
                  decoration: const InputDecoration(labelText: 'Valor do desconto'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: maxUsesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Máximo de usos (0 = ilimitado)',
                  ),
                  keyboardType: TextInputType.number,
                ),
                SwitchListTile(
                  title: const Text('Ativo'),
                  value: isActive,
                  onChanged: (v) => setLocal(() => isActive = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  ctx,
                  Coupon(
                    id: existing?.id ?? '',
                    code: codeCtrl.text.trim(),
                    discountType: discountType,
                    discountValue: double.tryParse(valueCtrl.text) ?? 0,
                    maxUses: int.tryParse(maxUsesCtrl.text) ?? 0,
                    usedCount: existing?.usedCount ?? 0,
                    isActive: isActive,
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

  static Future<Seller?> seller(BuildContext context, {Seller? existing}) {
    final userIdCtrl = TextEditingController(text: existing?.userId ?? '');
    final nameCtrl = TextEditingController(text: existing?.displayName ?? '');
    final emailCtrl = TextEditingController(text: existing?.email ?? '');
    final commissionCtrl = TextEditingController(
      text: '${existing?.commissionPercent ?? 10}',
    );
    var isActive = existing?.isActive ?? true;

    return showDialog<Seller>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(existing == null ? 'Novo vendedor' : 'Editar vendedor'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: userIdCtrl,
                  decoration: const InputDecoration(labelText: 'User ID'),
                ),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nome'),
                ),
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: 'E-mail'),
                ),
                TextField(
                  controller: commissionCtrl,
                  decoration: const InputDecoration(labelText: 'Comissão (%)'),
                  keyboardType: TextInputType.number,
                ),
                SwitchListTile(
                  title: const Text('Ativo'),
                  value: isActive,
                  onChanged: (v) => setLocal(() => isActive = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  ctx,
                  Seller(
                    id: existing?.id ?? '',
                    userId: userIdCtrl.text.trim(),
                    displayName: nameCtrl.text.trim(),
                    email: emailCtrl.text.trim(),
                    commissionPercent: double.tryParse(commissionCtrl.text) ?? 10,
                    isActive: isActive,
                    totalSales: existing?.totalSales ?? 0,
                    totalRevenue: existing?.totalRevenue ?? 0,
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

  static Future<Affiliate?> affiliate(BuildContext context, {Affiliate? existing}) {
    final userIdCtrl = TextEditingController(text: existing?.userId ?? '');
    final codeCtrl = TextEditingController(text: existing?.code ?? '');
    final nameCtrl = TextEditingController(text: existing?.displayName ?? '');
    final commissionCtrl = TextEditingController(
      text: '${existing?.commissionPercent ?? 15}',
    );
    var isActive = existing?.isActive ?? true;

    return showDialog<Affiliate>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(existing == null ? 'Novo afiliado' : 'Editar afiliado'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: userIdCtrl,
                  decoration: const InputDecoration(labelText: 'User ID'),
                ),
                TextField(
                  controller: codeCtrl,
                  decoration: const InputDecoration(labelText: 'Código'),
                  textCapitalization: TextCapitalization.characters,
                ),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nome'),
                ),
                TextField(
                  controller: commissionCtrl,
                  decoration: const InputDecoration(labelText: 'Comissão (%)'),
                  keyboardType: TextInputType.number,
                ),
                SwitchListTile(
                  title: const Text('Ativo'),
                  value: isActive,
                  onChanged: (v) => setLocal(() => isActive = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  ctx,
                  Affiliate(
                    id: existing?.id ?? '',
                    userId: userIdCtrl.text.trim(),
                    code: codeCtrl.text.trim(),
                    displayName: nameCtrl.text.trim(),
                    commissionPercent: double.tryParse(commissionCtrl.text) ?? 15,
                    isActive: isActive,
                    clicks: existing?.clicks ?? 0,
                    conversions: existing?.conversions ?? 0,
                    totalCommission: existing?.totalCommission ?? 0,
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

  static Future<Partnership?> partnership(
    BuildContext context, {
    Partnership? existing,
  }) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final emailCtrl = TextEditingController(text: existing?.contactEmail ?? '');
    final logoCtrl = TextEditingController(text: existing?.logoUrl ?? '');
    final linkCtrl = TextEditingController(text: existing?.linkUrl ?? '');
    final couponCtrl = TextEditingController(text: existing?.promoCouponCode ?? '');
    final shareCtrl = TextEditingController(
      text: '${existing?.revenueSharePercent ?? 0}',
    );
    var status = existing?.status ?? PartnershipStatus.draft;
    DateTime? startsAt = existing?.startsAt;
    DateTime? endsAt = existing?.endsAt;

    return showDialog<Partnership>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(existing == null ? 'Novo parceiro' : 'Editar parceiro'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nome'),
                ),
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: 'E-mail de contato'),
                ),
                TextField(
                  controller: logoCtrl,
                  decoration: const InputDecoration(labelText: 'URL do logo'),
                ),
                TextField(
                  controller: linkCtrl,
                  decoration: const InputDecoration(labelText: 'Link do parceiro'),
                ),
                TextField(
                  controller: couponCtrl,
                  decoration: const InputDecoration(labelText: 'Cupom promocional'),
                ),
                TextField(
                  controller: shareCtrl,
                  decoration: const InputDecoration(labelText: 'Repasse (%)'),
                  keyboardType: TextInputType.number,
                ),
                DropdownButtonFormField<PartnershipStatus>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: PartnershipStatus.values
                      .map((s) => DropdownMenuItem(value: s, child: Text(s.key)))
                      .toList(),
                  onChanged: (v) => setLocal(() => status = v!),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Data de início'),
                  subtitle: Text(startsAt == null
                      ? '—'
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
                  title: const Text('Data de término'),
                  subtitle: Text(endsAt == null
                      ? '—'
                      : '${endsAt!.day}/${endsAt!.month}/${endsAt!.year}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: endsAt ?? DateTime.now().add(const Duration(days: 90)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2035),
                      );
                      if (d != null) setLocal(() => endsAt = d);
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  ctx,
                  Partnership(
                    id: existing?.id ?? '',
                    name: nameCtrl.text.trim(),
                    contactEmail: emailCtrl.text.trim(),
                    status: status,
                    revenueSharePercent: double.tryParse(shareCtrl.text) ?? 0,
                    logoUrl: logoCtrl.text.trim().isEmpty ? null : logoCtrl.text.trim(),
                    linkUrl: linkCtrl.text.trim().isEmpty ? null : linkCtrl.text.trim(),
                    promoCouponCode:
                        couponCtrl.text.trim().isEmpty ? null : couponCtrl.text.trim(),
                    startsAt: startsAt,
                    endsAt: endsAt,
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

  static Future<Advertisement?> advertisement(
    BuildContext context, {
    Advertisement? existing,
  }) {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final imageCtrl = TextEditingController(text: existing?.imageUrl ?? '');
    final urlCtrl = TextEditingController(text: existing?.targetUrl ?? '');
    var placement = existing?.placement ?? AdvertisementPlacement.homeBanner;
    var isActive = existing?.isActive ?? false;

    return showDialog<Advertisement>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(existing == null ? 'Nova propaganda' : 'Editar propaganda'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Título'),
                ),
                DropdownButtonFormField<AdvertisementPlacement>(
                  initialValue: placement,
                  decoration: const InputDecoration(labelText: 'Placement'),
                  items: AdvertisementPlacement.values
                      .map((p) => DropdownMenuItem(value: p, child: Text(p.key)))
                      .toList(),
                  onChanged: (v) => setLocal(() => placement = v!),
                ),
                TextField(
                  controller: imageCtrl,
                  decoration: const InputDecoration(labelText: 'URL da imagem'),
                ),
                TextField(
                  controller: urlCtrl,
                  decoration: const InputDecoration(labelText: 'URL de destino'),
                ),
                SwitchListTile(
                  title: const Text('Ativo'),
                  value: isActive,
                  onChanged: (v) => setLocal(() => isActive = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  ctx,
                  Advertisement(
                    id: existing?.id ?? '',
                    title: titleCtrl.text.trim(),
                    placement: placement,
                    imageUrl: imageCtrl.text.trim(),
                    targetUrl: urlCtrl.text.trim().isEmpty ? null : urlCtrl.text.trim(),
                    isActive: isActive,
                    impressions: existing?.impressions ?? 0,
                    clicks: existing?.clicks ?? 0,
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

  static Future<bool> confirmDelete(BuildContext context, String label) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: Text('Excluir "$label"? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }
}
