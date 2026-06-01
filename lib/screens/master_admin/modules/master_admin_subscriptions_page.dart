import 'package:flutter/material.dart';



import '../../../application/platform/platform_registry.dart';

import '../../../core/commercial/commercial_entitlement.dart';

import '../../../domain/platform/models/subscription.dart';

import '../../../widgets/master_admin/master_admin_diagnostics_panel.dart';

import '../../../widgets/master_admin/master_admin_empty_module.dart';

import '../../../widgets/master_admin/master_admin_grant_access_sheet.dart';

import '../../../widgets/master_admin/master_admin_module_scaffold.dart';



class MasterAdminSubscriptionsPage extends StatelessWidget {

  const MasterAdminSubscriptionsPage({super.key});



  @override

  Widget build(BuildContext context) {

    final repos = PlatformRegistry.instance.repositories;



    return MasterAdminModuleScaffold(

      title: 'Assinaturas',

      subtitle: 'Gestão manual + rastreamento comercial',

      floatingActionButton: FloatingActionButton.extended(

        onPressed: () => MasterAdminGrantAccessSheet.show(context),

        icon: const Icon(Icons.person_add_alt_1),

        label: const Text('Conceder acesso'),

      ),

      body: StreamBuilder<List<Subscription>>(

        stream: repos.subscriptions.watchAll(limit: 100),

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

              title: 'Sem assinaturas',

              message:

                  'Conceda acesso manualmente enquanto o checkout não está integrado.',

              nextSteps: const [

                'Conceder cortesia, vitalício, beta ou promocional',

                'Rastrear vendedor, afiliado e cupom',

              ],

              action: FilledButton.icon(

                onPressed: () => MasterAdminGrantAccessSheet.show(context),

                icon: const Icon(Icons.person_add_alt_1),

                label: const Text('Conceder acesso'),

              ),

            );

          }

          return ListView.separated(

            itemCount: items.length,

            separatorBuilder: (_, __) => const Divider(height: 1),

            itemBuilder: (context, i) {

              final s = items[i];

              return ListTile(

                leading: const Icon(Icons.card_membership),

                title: Text('Usuário: ${s.userId}'),

                subtitle: Text(

                  'Plano: ${s.planId}\n'

                  'Status: ${s.status.key}'

                  '${s.grantSource != null ? '\nOrigem: ${s.grantSource!.label}' : ''}'

                  '${s.sellerId != null ? '\nVendedor: ${s.sellerId}' : ''}'

                  '${s.affiliateId != null ? '\nAfiliado: ${s.affiliateId}' : ''}'

                  '${s.couponId != null ? '\nCupom: ${s.couponId}' : ''}',

                ),

                isThreeLine: true,

                trailing: _statusChip(s),

              );

            },

          );

        },

      ),

    );

  }



  Widget _statusChip(Subscription s) {

    if (s.grantSource == CommercialGrantSource.lifetime) {

      return const Chip(label: Text('Vitalício'));

    }

    if (s.grantSource == CommercialGrantSource.courtesy) {

      return const Chip(label: Text('Cortesia'));

    }

    if (s.isActive) return const Chip(label: Text('Ativo'));

    return const Chip(label: Text('Inativo'));

  }

}


