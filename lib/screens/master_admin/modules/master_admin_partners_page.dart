import 'package:flutter/material.dart';



import '../../../application/platform/platform_registry.dart';

import '../../../domain/platform/models/partnership.dart';

import '../../../widgets/master_admin/master_admin_commercial_forms.dart';

import '../../../widgets/master_admin/master_admin_diagnostics_panel.dart';

import '../../../widgets/master_admin/master_admin_empty_module.dart';

import '../../../widgets/master_admin/master_admin_module_scaffold.dart';



class MasterAdminPartnersPage extends StatelessWidget {

  const MasterAdminPartnersPage({super.key});



  @override

  Widget build(BuildContext context) {

    return MasterAdminModuleScaffold(

      title: 'Parceiros',

      subtitle: 'CRUD de parcerias (`platform_partnerships`)',

      floatingActionButton: FloatingActionButton(

        onPressed: () => _save(context, null),

        child: const Icon(Icons.add),

      ),

      body: StreamBuilder<List<Partnership>>(

        stream: PlatformRegistry.instance.repositories.partnerships.watchAll(),

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

              title: 'Nenhuma parceria',

              message: 'Registre parceiros institucionais e acordos comerciais.',

              action: FilledButton.icon(

                onPressed: () => _save(context, null),

                icon: const Icon(Icons.add),

                label: const Text('Cadastrar parceiro'),

              ),

            );

          }

          return ListView.separated(

            itemCount: items.length,

            separatorBuilder: (_, __) => const Divider(height: 1),

            itemBuilder: (context, i) {

              final p = items[i];

              return ListTile(

                leading: const Icon(Icons.handshake),

                title: Text(p.name),

                subtitle: Text(

                  '${p.contactEmail}\n'

                  'Status: ${p.status.key} · Repasse: ${p.revenueSharePercent}%',

                ),

                isThreeLine: true,

                trailing: PopupMenuButton<String>(

                  onSelected: (v) async {
                    if (v == 'edit') {
                      await _save(context, p);
                    } else if (v == 'delete') {
                      await _delete(context, p);
                    }
                  },

                  itemBuilder: (_) => const [

                    PopupMenuItem(value: 'edit', child: Text('Editar')),

                    PopupMenuItem(value: 'delete', child: Text('Excluir')),

                  ],

                ),

                onTap: () => _save(context, p),

              );

            },

          );

        },

      ),

    );

  }



  Future<void> _save(BuildContext context, Partnership? existing) async {

    final partnership =

        await MasterAdminCommercialForms.partnership(context, existing: existing);

    if (partnership == null || !context.mounted) return;

    await PlatformRegistry.instance.repositories.partnerships.save(partnership);

  }



  Future<void> _delete(BuildContext context, Partnership partnership) async {

    final ok = await MasterAdminCommercialForms.confirmDelete(context, partnership.name);

    if (!ok || !context.mounted) return;

    await PlatformRegistry.instance.repositories.partnerships.delete(partnership.id);

  }

}


