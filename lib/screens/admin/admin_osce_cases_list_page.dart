import 'package:flutter/material.dart';

import '../../models/osce_models.dart';
import '../../services/osce/osce_case_admin_service.dart';
import 'admin_osce_case_form_page.dart';

class AdminOsceCasesListPage extends StatefulWidget {
  const AdminOsceCasesListPage({super.key});

  @override
  State<AdminOsceCasesListPage> createState() => _AdminOsceCasesListPageState();
}

class _AdminOsceCasesListPageState extends State<AdminOsceCasesListPage> {
  final _service = OsceCaseAdminService();

  Future<void> _seed() async {
    final n = await _service.seedDefaultIfEmpty();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          n > 0 ? 'Caso exemplo importado.' : 'Já existem casos cadastrados.',
        ),
      ),
    );
  }

  Future<void> _delete(OsceCaseModel c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir caso?'),
        content: Text('“${c.title}” será removido.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _service.delete(c.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Caso excluído.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Casos — Fase Prática'),
        backgroundColor: const Color(0xFF0D9488),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Caso exemplo',
            onPressed: _seed,
            icon: const Icon(Icons.download),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AdminOsceCaseFormPage(),
            ),
          );
        },
        backgroundColor: const Color(0xFF0D9488),
        icon: const Icon(Icons.add),
        label: const Text('Novo caso'),
      ),
      body: StreamBuilder<List<OsceCaseModel>>(
        stream: _service.streamAll(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snap.data ?? [];
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Nenhum caso cadastrado.\nCrie temas para as salas da Fase Prática.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _seed,
                      icon: const Icon(Icons.download),
                      label: const Text('Importar caso exemplo'),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final c = list[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  title: Text(c.title),
                  subtitle: Text(c.specialty),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'edit') {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AdminOsceCaseFormPage(caseId: c.id),
                          ),
                        );
                      } else if (v == 'delete') {
                        await _delete(c);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Editar')),
                      PopupMenuItem(value: 'delete', child: Text('Excluir')),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AdminOsceCaseFormPage(caseId: c.id),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
