import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/firestore_paths.dart';
import '../../../widgets/master_admin/master_admin_diagnostics_panel.dart';
import '../../../widgets/master_admin/master_admin_module_scaffold.dart';

class MasterAdminUsersPage extends StatelessWidget {
  const MasterAdminUsersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MasterAdminModuleScaffold(
      title: 'Usuários',
      subtitle: 'Contas registradas na plataforma (somente leitura)',
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection(FirestorePaths.users)
            .limit(100)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return MasterAdminModuleErrorView(error: snap.error);
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('Nenhum usuário encontrado.'));
          }
          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final d = docs[i];
              final data = d.data();
              final email = data['email']?.toString() ?? '—';
              final name = data['nome']?.toString() ??
                  data['displayName']?.toString() ??
                  'Sem nome';
              final roles = (data['rbacRoles'] as List?)
                      ?.map((e) => e.toString())
                      .join(', ') ??
                  '';
              final isAdmin = data['isAdmin'] == true;
              return ListTile(
                leading: CircleAvatar(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                  ),
                ),
                title: Text(name),
                subtitle: Text(
                  '$email\nUID: ${d.id}${roles.isNotEmpty ? '\nPapéis: $roles' : ''}${isAdmin ? '\nAdmin legado' : ''}',
                ),
                isThreeLine: true,
              );
            },
          );
        },
      ),
    );
  }
}
