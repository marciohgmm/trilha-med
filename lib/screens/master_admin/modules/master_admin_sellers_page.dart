import 'package:flutter/material.dart';



import '../../../application/platform/platform_registry.dart';

import '../../../domain/platform/models/seller.dart';

import '../../../widgets/master_admin/master_admin_commercial_forms.dart';

import '../../../widgets/master_admin/master_admin_diagnostics_panel.dart';

import '../../../widgets/master_admin/master_admin_empty_module.dart';

import '../../../widgets/master_admin/master_admin_module_scaffold.dart';



class MasterAdminSellersPage extends StatelessWidget {

  const MasterAdminSellersPage({super.key});



  @override

  Widget build(BuildContext context) {

    return MasterAdminModuleScaffold(

      title: 'Vendedores',

      subtitle: 'CRUD da equipe comercial (`platform_sellers`)',

      floatingActionButton: FloatingActionButton(

        onPressed: () => _save(context, null),

        child: const Icon(Icons.add),

      ),

      body: StreamBuilder<List<Seller>>(

        stream: PlatformRegistry.instance.repositories.sellers

            .watchAll(activeOnly: false),

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

              title: 'Nenhum vendedor',

              message: 'Cadastre vendedores para rastrear conversões.',

              action: FilledButton.icon(

                onPressed: () => _save(context, null),

                icon: const Icon(Icons.add),

                label: const Text('Cadastrar vendedor'),

              ),

            );

          }

          return ListView.separated(

            itemCount: items.length,

            separatorBuilder: (_, __) => const Divider(height: 1),

            itemBuilder: (context, i) {

              final s = items[i];

              return ListTile(

                leading: const Icon(Icons.storefront),

                title: Text(s.displayName.isNotEmpty ? s.displayName : s.id),

                subtitle: Text(

                  'userId: ${s.userId}\n'

                  'Comissão: ${s.commissionPercent}% · Vendas: ${s.totalSales}',

                ),

                isThreeLine: true,

                trailing: Row(

                  mainAxisSize: MainAxisSize.min,

                  children: [

                    s.isActive

                        ? const Chip(label: Text('Ativo'))

                        : const Chip(label: Text('Inativo')),

                    PopupMenuButton<String>(

                      onSelected: (a) async {
                        if (a == 'edit') {
                          await _save(context, s);
                        } else if (a == 'delete') {
                          await _delete(context, s);
                        }
                      },

                      itemBuilder: (_) => const [

                        PopupMenuItem(value: 'edit', child: Text('Editar')),

                        PopupMenuItem(value: 'delete', child: Text('Excluir')),

                      ],

                    ),

                  ],

                ),

                onTap: () => _save(context, s),

              );

            },

          );

        },

      ),

    );

  }



  Future<void> _save(BuildContext context, Seller? existing) async {

    final seller = await MasterAdminCommercialForms.seller(context, existing: existing);

    if (seller == null || !context.mounted) return;

    await PlatformRegistry.instance.repositories.sellers.save(seller);

  }



  Future<void> _delete(BuildContext context, Seller seller) async {

    final ok = await MasterAdminCommercialForms.confirmDelete(

      context,

      seller.displayName.isNotEmpty ? seller.displayName : seller.id,

    );

    if (!ok || !context.mounted) return;

    await PlatformRegistry.instance.repositories.sellers.delete(seller.id);

  }

}


