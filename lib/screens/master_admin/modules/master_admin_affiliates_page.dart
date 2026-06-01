import 'package:flutter/material.dart';



import '../../../application/platform/platform_registry.dart';

import '../../../domain/platform/models/affiliate.dart';

import '../../../widgets/master_admin/master_admin_commercial_forms.dart';

import '../../../widgets/master_admin/master_admin_diagnostics_panel.dart';

import '../../../widgets/master_admin/master_admin_empty_module.dart';

import '../../../widgets/master_admin/master_admin_module_scaffold.dart';



class MasterAdminAffiliatesPage extends StatelessWidget {

  const MasterAdminAffiliatesPage({super.key});



  @override

  Widget build(BuildContext context) {

    return MasterAdminModuleScaffold(

      title: 'Afiliados',

      subtitle: 'CRUD do programa de afiliados (`platform_affiliates`)',

      floatingActionButton: FloatingActionButton(

        onPressed: () => _save(context, null),

        child: const Icon(Icons.add),

      ),

      body: StreamBuilder<List<Affiliate>>(

        stream: PlatformRegistry.instance.repositories.affiliates

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

              title: 'Nenhum afiliado',

              message: 'Cadastre afiliados para rastrear conversões por código.',

              action: FilledButton.icon(

                onPressed: () => _save(context, null),

                icon: const Icon(Icons.add),

                label: const Text('Cadastrar afiliado'),

              ),

            );

          }

          return ListView.separated(

            itemCount: items.length,

            separatorBuilder: (_, __) => const Divider(height: 1),

            itemBuilder: (context, i) {

              final a = items[i];

              return ListTile(

                leading: const Icon(Icons.hub),

                title: Text(a.code),

                subtitle: Text(

                  '${a.displayName}\n'

                  'userId: ${a.userId} · Comissão: ${a.commissionPercent}%\n'

                  'Conversões: ${a.conversions}',

                ),

                isThreeLine: true,

                trailing: Row(

                  mainAxisSize: MainAxisSize.min,

                  children: [

                    a.isActive

                        ? const Chip(label: Text('Ativo'))

                        : const Chip(label: Text('Inativo')),

                    PopupMenuButton<String>(

                      onSelected: (v) async {
                        if (v == 'edit') {
                          await _save(context, a);
                        } else if (v == 'delete') {
                          await _delete(context, a);
                        }
                      },

                      itemBuilder: (_) => const [

                        PopupMenuItem(value: 'edit', child: Text('Editar')),

                        PopupMenuItem(value: 'delete', child: Text('Excluir')),

                      ],

                    ),

                  ],

                ),

                onTap: () => _save(context, a),

              );

            },

          );

        },

      ),

    );

  }



  Future<void> _save(BuildContext context, Affiliate? existing) async {

    final affiliate =

        await MasterAdminCommercialForms.affiliate(context, existing: existing);

    if (affiliate == null || !context.mounted) return;

    await PlatformRegistry.instance.repositories.affiliates.save(affiliate);

  }



  Future<void> _delete(BuildContext context, Affiliate affiliate) async {

    final ok = await MasterAdminCommercialForms.confirmDelete(context, affiliate.code);

    if (!ok || !context.mounted) return;

    await PlatformRegistry.instance.repositories.affiliates.delete(affiliate.id);

  }

}


