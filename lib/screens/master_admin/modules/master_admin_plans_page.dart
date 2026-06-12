import 'package:flutter/material.dart';



import '../../../application/platform/platform_registry.dart';
import '../../../core/commercial/commercial_entitlement.dart';
import '../../../domain/platform/models/subscription_plan.dart';

import '../../../widgets/master_admin/master_admin_commercial_forms.dart';

import '../../../widgets/master_admin/master_admin_diagnostics_panel.dart';

import '../../../widgets/master_admin/master_admin_empty_module.dart';

import '../../../widgets/master_admin/master_admin_module_scaffold.dart';



class MasterAdminPlansPage extends StatelessWidget {

  const MasterAdminPlansPage({super.key});



  @override

  Widget build(BuildContext context) {

    String brl(double v) =>

        'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';

    final repos = PlatformRegistry.instance.repositories;



    return MasterAdminModuleScaffold(

      title: 'Planos',

      subtitle: 'CRUD de planos (`platform_subscription_plans`)',

      floatingActionButton: FloatingActionButton(

        onPressed: () => _savePlan(context, null),

        child: const Icon(Icons.add),

      ),

      body: StreamBuilder<List<SubscriptionPlan>>(

        stream: repos.subscriptionPlans.watchAllPlans(),

        builder: (context, snap) {

          if (snap.hasError) {

            return MasterAdminModuleErrorView(error: snap.error);

          }

          if (!snap.hasData) {

            return const Center(child: CircularProgressIndicator());

          }

          final plans = snap.data!;

          if (plans.isEmpty) {

            return MasterAdminEmptyModule(

              title: 'Nenhum plano cadastrado',

              message: 'Crie o plano Premium para uso manual e futuro checkout.',

              nextSteps: const [

                'Toque em + para criar plano',

                'Gateway de pagamento (fase posterior)',

              ],

              action: FilledButton.icon(

                onPressed: () => _savePlan(context, null),

                icon: const Icon(Icons.add),

                label: const Text('Criar plano'),

              ),

            );

          }

          return ListView.separated(

            itemCount: plans.length,

            separatorBuilder: (_, __) => const Divider(height: 1),

            itemBuilder: (context, i) {

              final p = plans[i];

              return ListTile(

                leading: const Icon(Icons.layers, color: Color(0xFF1E3A8A)),

                title: Text(p.name),

                subtitle: Text(

                  '${p.description}\n'

                  'ID Firestore: ${p.id}\n'

                  'Mensal: ${brl(p.priceMonthly)} · Anual: ${brl(p.priceYearly)}\n'

                  'Tier: ${p.tier.label}',

                ),

                isThreeLine: true,

                trailing: Row(

                  mainAxisSize: MainAxisSize.min,

                  children: [

                    p.isActive

                        ? const Chip(label: Text('Ativo'))

                        : const Chip(label: Text('Inativo')),

                    PopupMenuButton<String>(

                      onSelected: (action) async {

                        if (action == 'edit') {

                          await _savePlan(context, p);

                        } else if (action == 'activate') {

                          await _activateForSale(context, p);

                        } else if (action == 'delete') {

                          await _deletePlan(context, p);

                        }

                      },

                      itemBuilder: (_) => [

                        const PopupMenuItem(value: 'edit', child: Text('Editar')),

                        if (!p.isActive)

                          const PopupMenuItem(

                            value: 'activate',

                            child: Text('Ativar para venda no app'),

                          ),

                        const PopupMenuItem(value: 'delete', child: Text('Excluir')),

                      ],

                    ),

                  ],

                ),

                onTap: () => _savePlan(context, p),

              );

            },

          );

        },

      ),

    );

  }



  Future<void> _savePlan(BuildContext context, SubscriptionPlan? existing) async {

    final plan = await MasterAdminCommercialForms.plan(context, existing: existing);

    if (plan == null || !context.mounted) return;

    try {

      await PlatformRegistry.instance.repositories.subscriptionPlans.save(plan);

      if (context.mounted) {

        ScaffoldMessenger.of(context).showSnackBar(

          const SnackBar(content: Text('Plano salvo.')),

        );

      }

    } catch (e) {

      if (context.mounted) {

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));

      }

    }

  }



  Future<void> _activateForSale(BuildContext context, SubscriptionPlan plan) async {
    try {
      await PlatformRegistry.instance.repositories.subscriptionPlans.save(
        SubscriptionPlan(
          id: plan.id,
          name: plan.name,
          description: plan.description,
          priceMonthly: plan.priceMonthly,
          priceYearly: plan.priceYearly,
          currency: plan.currency,
          featureKeys: plan.featureKeys,
          tier: PlanTier.premium,
          benefitLabels: plan.benefitLabels,
          isActive: true,
          sortOrder: plan.sortOrder,
        ),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Plano "${plan.name}" ativo (ID: ${plan.id}). Alunos já podem comprar.',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao ativar: $e')),
        );
      }
    }
  }

  Future<void> _deletePlan(BuildContext context, SubscriptionPlan plan) async {

    final ok = await MasterAdminCommercialForms.confirmDelete(context, plan.name);

    if (!ok || !context.mounted) return;

    try {

      await PlatformRegistry.instance.repositories.subscriptionPlans.delete(plan.id);

    } catch (e) {

      if (context.mounted) {

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));

      }

    }

  }

}


