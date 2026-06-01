import 'package:flutter/material.dart';

import '../../models/practical_phase_model.dart';
import '../../services/practical_phase_service.dart';
import '../../widgets/practical_phase/practical_phase_constants.dart';
import '../../widgets/practical_phase/practical_phase_filters_bar.dart';
import 'admin_practical_phase_form_page.dart';

class AdminPracticalPhaseListPage extends StatefulWidget {
  const AdminPracticalPhaseListPage({super.key});

  @override
  State<AdminPracticalPhaseListPage> createState() =>
      _AdminPracticalPhaseListPageState();
}

class _AdminPracticalPhaseListPageState
    extends State<AdminPracticalPhaseListPage> {
  final _service = PracticalPhaseService();
  PracticalPhaseFilters _filters = const PracticalPhaseFilters();
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete(PracticalPhaseModel model) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir modelo?'),
        content: Text('“${model.title}” será removido permanentemente.'),
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
    if (ok != true || !mounted) return;
    await _service.deleteModel(model.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Modelo excluído.')),
      );
    }
  }

  Future<void> _seed() async {
    final count = await _service.seedMockIfEmpty(userId: 'admin');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          count > 0
              ? '$count modelos de exemplo criados.'
              : 'Já existem modelos cadastrados.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PracticalPhaseColors.background,
      appBar: AppBar(
        title: const Text('Modelos — Fase Prática'),
        backgroundColor: PracticalPhaseColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Dados de exemplo',
            onPressed: _seed,
            icon: const Icon(Icons.science_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AdminPracticalPhaseFormPage(),
            ),
          );
        },
        backgroundColor: PracticalPhaseColors.accent,
        icon: const Icon(Icons.add),
        label: const Text('Novo modelo'),
      ),
      body: StreamBuilder<List<PracticalPhaseModel>>(
        stream: _service.streamAllAdmin(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snapshot.data!;
          final filtered = _service.applyFilters(
            all,
            _filters,
            adminView: true,
          );

          final categories =
              _service.distinctValues(all, (m) => m.category).toList()..sort();
          final specialties =
              _service.distinctValues(all, (m) => m.specialty).toList()..sort();
          final difficulties = _service
              .distinctValues(all, (m) => m.difficulty)
              .toList()
            ..sort();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: PracticalPhaseFiltersBar(
                  filters: _filters,
                  categories: categories,
                  specialties: specialties,
                  difficulties: difficulties,
                  showStatusFilter: true,
                  onChanged: (f) => setState(() => _filters = f),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      '${filtered.length} modelo(s)',
                      style: const TextStyle(color: PracticalPhaseColors.muted),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: filtered.length < 2
                          ? null
                          : () => _service.reorder(filtered),
                      icon: const Icon(Icons.save_outlined, size: 18),
                      label: const Text('Salvar ordem da lista'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('Nenhum modelo.'))
                    : ReorderableListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                        itemCount: filtered.length,
                        onReorder: (oldIndex, newIndex) {
                          if (newIndex > oldIndex) newIndex--;
                          final list = List<PracticalPhaseModel>.from(filtered);
                          final item = list.removeAt(oldIndex);
                          list.insert(newIndex, item);
                          _service.reorder(list);
                        },
                        itemBuilder: (context, index) {
                          final m = filtered[index];
                          return _AdminModelTile(
                            key: ValueKey(m.id),
                            index: index,
                            model: m,
                            onEdit: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AdminPracticalPhaseFormPage(
                                    modelId: m.id,
                                  ),
                                ),
                              );
                            },
                            onDuplicate: () async {
                              final messenger =
                                  ScaffoldMessenger.of(context);
                              try {
                                await _service.duplicateModel(
                                  m.id,
                                  'admin',
                                );
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Modelo duplicado.'),
                                  ),
                                );
                              } catch (e) {
                                messenger.showSnackBar(
                                  SnackBar(content: Text('$e')),
                                );
                              }
                            },
                            onToggleActive: (v) =>
                                _service.setActive(m.id, v),
                            onTogglePublished: (v) =>
                                _service.setPublished(m.id, v),
                            onDelete: () => _confirmDelete(m),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AdminModelTile extends StatelessWidget {
  final int index;
  final PracticalPhaseModel model;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggleActive;
  final ValueChanged<bool> onTogglePublished;

  const _AdminModelTile({
    super.key,
    required this.index,
    required this.model,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
    required this.onToggleActive,
    required this.onTogglePublished,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      key: key,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: ReorderableDragStartListener(
          index: index,
          child: const Icon(Icons.drag_handle, color: PracticalPhaseColors.muted),
        ),
        title: Text(model.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          '${model.displayStatus} • ${model.category} • '
          '${model.sections.length} seções',
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            switch (v) {
              case 'edit':
                onEdit();
                break;
              case 'dup':
                onDuplicate();
                break;
              case 'pub':
                onTogglePublished(!model.isPublished);
                break;
              case 'act':
                onToggleActive(!model.isActive);
                break;
              case 'del':
                onDelete();
                break;
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('Editar')),
            const PopupMenuItem(value: 'dup', child: Text('Duplicar')),
            PopupMenuItem(
              value: 'pub',
              child: Text(model.isPublished ? 'Despublicar' : 'Publicar'),
            ),
            PopupMenuItem(
              value: 'act',
              child: Text(model.isActive ? 'Desativar' : 'Ativar'),
            ),
            const PopupMenuItem(
              value: 'del',
              child: Text('Excluir', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
        onTap: onEdit,
      ),
    );
  }
}
