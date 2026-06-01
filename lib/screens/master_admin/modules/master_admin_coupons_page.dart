import 'package:flutter/material.dart';



import '../../../application/platform/platform_registry.dart';

import '../../../domain/platform/enums/platform_enums.dart';

import '../../../domain/platform/models/coupon.dart';

import '../../../widgets/master_admin/master_admin_commercial_forms.dart';

import '../../../widgets/master_admin/master_admin_diagnostics_panel.dart';

import '../../../widgets/master_admin/master_admin_empty_module.dart';

import '../../../widgets/master_admin/master_admin_module_scaffold.dart';



class MasterAdminCouponsPage extends StatelessWidget {

  const MasterAdminCouponsPage({super.key});



  @override

  Widget build(BuildContext context) {

    return MasterAdminModuleScaffold(

      title: 'Cupons',

      subtitle: 'CRUD de cupons (`platform_coupons`)',

      floatingActionButton: FloatingActionButton(

        onPressed: () => _save(context, null),

        child: const Icon(Icons.add),

      ),

      body: StreamBuilder<List<Coupon>>(

        stream: PlatformRegistry.instance.repositories.coupons.watchAll(),

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

              title: 'Nenhum cupom',

              message: 'Crie cupons para campanhas e concessão manual.',

              action: FilledButton.icon(

                onPressed: () => _save(context, null),

                icon: const Icon(Icons.add),

                label: const Text('Criar cupom'),

              ),

            );

          }

          return ListView.separated(

            itemCount: items.length,

            separatorBuilder: (_, __) => const Divider(height: 1),

            itemBuilder: (context, i) {

              final c = items[i];

              final discountLabel = c.discountType == CouponDiscountType.percent

                  ? '${c.discountValue}%'

                  : 'R\$ ${c.discountValue}';

              return ListTile(

                leading: const Icon(Icons.local_offer),

                title: Text(c.code),

                subtitle: Text(

                  'Desconto: $discountLabel · '

                  'Usos: ${c.usedCount}/${c.isUnlimited ? '∞' : c.maxUses}',

                ),

                trailing: PopupMenuButton<String>(

                  onSelected: (a) async {
                    if (a == 'edit') {
                      await _save(context, c);
                    } else if (a == 'delete') {
                      await _delete(context, c);
                    }
                  },

                  itemBuilder: (_) => const [

                    PopupMenuItem(value: 'edit', child: Text('Editar')),

                    PopupMenuItem(value: 'delete', child: Text('Excluir')),

                  ],

                ),

                onTap: () => _save(context, c),

              );

            },

          );

        },

      ),

    );

  }



  Future<void> _save(BuildContext context, Coupon? existing) async {

    final coupon = await MasterAdminCommercialForms.coupon(context, existing: existing);

    if (coupon == null || !context.mounted) return;

    try {

      await PlatformRegistry.instance.repositories.coupons.save(coupon);

    } catch (e) {

      if (context.mounted) {

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));

      }

    }

  }



  Future<void> _delete(BuildContext context, Coupon coupon) async {

    final ok = await MasterAdminCommercialForms.confirmDelete(context, coupon.code);

    if (!ok || !context.mounted) return;

    await PlatformRegistry.instance.repositories.coupons.delete(coupon.id);

  }

}


