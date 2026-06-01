import 'package:flutter/material.dart';



import '../../../application/platform/platform_registry.dart';

import '../../../domain/platform/models/advertisement.dart';

import '../../../widgets/master_admin/master_admin_commercial_forms.dart';

import '../../../widgets/master_admin/master_admin_diagnostics_panel.dart';

import '../../../widgets/master_admin/master_admin_empty_module.dart';

import '../../../widgets/master_admin/master_admin_module_scaffold.dart';



class MasterAdminAdsPage extends StatelessWidget {

  const MasterAdminAdsPage({super.key});



  @override

  Widget build(BuildContext context) {

    return MasterAdminModuleScaffold(

      title: 'Propagandas',

      subtitle: 'CRUD de anúncios (`platform_advertisements`)',

      floatingActionButton: FloatingActionButton(

        onPressed: () => _save(context, null),

        child: const Icon(Icons.add),

      ),

      body: StreamBuilder<List<Advertisement>>(

        stream: PlatformRegistry.instance.repositories.advertisements.watchAll(),

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

              title: 'Nenhuma propaganda',

              message: 'Configure placements para exibir anúncios quando ativados.',

              action: FilledButton.icon(

                onPressed: () => _save(context, null),

                icon: const Icon(Icons.add),

                label: const Text('Criar propaganda'),

              ),

            );

          }

          return ListView.separated(

            itemCount: items.length,

            separatorBuilder: (_, __) => const Divider(height: 1),

            itemBuilder: (context, i) {

              final ad = items[i];

              return ListTile(

                leading: const Icon(Icons.campaign),

                title: Text(ad.title),

                subtitle: Text(

                  'Placement: ${ad.placement.key}\n'

                  'Impressões: ${ad.impressions} · Cliques: ${ad.clicks}',

                ),

                isThreeLine: true,

                trailing: Row(

                  mainAxisSize: MainAxisSize.min,

                  children: [

                    ad.isActive

                        ? const Chip(label: Text('Ativo'))

                        : const Chip(label: Text('Inativo')),

                    PopupMenuButton<String>(

                      onSelected: (v) async {
                        if (v == 'edit') {
                          await _save(context, ad);
                        } else if (v == 'delete') {
                          await _delete(context, ad);
                        }
                      },

                      itemBuilder: (_) => const [

                        PopupMenuItem(value: 'edit', child: Text('Editar')),

                        PopupMenuItem(value: 'delete', child: Text('Excluir')),

                      ],

                    ),

                  ],

                ),

                onTap: () => _save(context, ad),

              );

            },

          );

        },

      ),

    );

  }



  Future<void> _save(BuildContext context, Advertisement? existing) async {

    final ad =

        await MasterAdminCommercialForms.advertisement(context, existing: existing);

    if (ad == null || !context.mounted) return;

    await PlatformRegistry.instance.repositories.advertisements.save(ad);

  }



  Future<void> _delete(BuildContext context, Advertisement ad) async {

    final ok = await MasterAdminCommercialForms.confirmDelete(context, ad.title);

    if (!ok || !context.mounted) return;

    await PlatformRegistry.instance.repositories.advertisements.delete(ad.id);

  }

}


