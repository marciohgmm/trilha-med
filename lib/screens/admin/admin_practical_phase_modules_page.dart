import 'package:flutter/material.dart';

import '../../models/practical_phase_module.dart';
import '../../services/practical_phase_module_service.dart';
import '../../widgets/practical_phase/practical_phase_constants.dart';

class AdminPracticalPhaseModulesPage extends StatelessWidget {
  const AdminPracticalPhaseModulesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final service = PracticalPhaseModuleService();

    return Scaffold(
      backgroundColor: PracticalPhaseColors.background,
      appBar: AppBar(
        title: const Text('Módulos — Fase Prática'),
        backgroundColor: PracticalPhaseColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Dados de exemplo',
            onPressed: () async {
              final n = await service.seedIfEmpty();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      n > 0 ? '$n módulos criados.' : 'Já existem módulos.',
                    ),
                  ),
                );
              }
            },
            icon: const Icon(Icons.science_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context, null),
        icon: const Icon(Icons.add),
        label: const Text('Novo módulo'),
        backgroundColor: PracticalPhaseColors.accent,
      ),
      body: StreamBuilder<List<PracticalPhaseModule>>(
        stream: service.streamAllAdmin(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snap.data!;
          if (list.isEmpty) {
            return const Center(child: Text('Nenhum módulo. Use + ou seed.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final m = list[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  title: Text(m.title),
                  subtitle: Text('${m.sectionLabel} • ordem ${m.order}'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'edit') {
                        _openEditor(context, m);
                      } else if (v == 'pub') {
                        await service.togglePublished(m.id, !m.isPublished);
                      } else if (v == 'act') {
                        await service.toggleActive(m.id, !m.isActive);
                      } else if (v == 'del') {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Excluir?'),
                            content: Text(m.title),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancelar'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Excluir'),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) await service.delete(m.id);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Text('Editar')),
                      PopupMenuItem(
                        value: 'pub',
                        child: Text(
                          m.isPublished ? 'Despublicar' : 'Publicar',
                        ),
                      ),
                      PopupMenuItem(
                        value: 'act',
                        child: Text(m.isActive ? 'Desativar' : 'Ativar'),
                      ),
                      const PopupMenuItem(
                        value: 'del',
                        child: Text('Excluir', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                  onTap: () => _openEditor(context, m),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _openEditor(BuildContext context, PracticalPhaseModule? existing) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _ModuleEditorSheet(existing: existing),
    );
  }
}

class _ModuleEditorSheet extends StatefulWidget {
  final PracticalPhaseModule? existing;

  const _ModuleEditorSheet({this.existing});

  @override
  State<_ModuleEditorSheet> createState() => _ModuleEditorSheetState();
}

class _ModuleEditorSheetState extends State<_ModuleEditorSheet> {
  final _service = PracticalPhaseModuleService();
  late final TextEditingController _title;
  late final TextEditingController _desc;
  late final TextEditingController _link;
  late String _section;
  late bool _published;
  late bool _active;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _desc = TextEditingController(text: e?.description ?? '');
    _link = TextEditingController(text: e?.linkUrl ?? '');
    _section = e?.sectionKey ?? 'simulados';
    _published = e?.isPublished ?? false;
    _active = e?.isActive ?? true;
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _link.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final module = PracticalPhaseModule(
      id: widget.existing?.id ?? '',
      sectionKey: _section,
      title: _title.text.trim(),
      description: _desc.text.trim(),
      linkUrl: _link.text.trim().isEmpty ? null : _link.text.trim(),
      isPublished: _published,
      isActive: _active,
      order: widget.existing?.order ?? 0,
    );
    await _service.save(module, isNew: widget.existing == null);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + pad),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.existing == null ? 'Novo módulo' : 'Editar módulo',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            DropdownMenu<String>(
              initialSelection: _section,
              label: const Text('Seção'),
              dropdownMenuEntries: PracticalPhaseModule.sectionLabels.entries
                  .map(
                    (e) => DropdownMenuEntry(
                      value: e.key,
                      label: e.value,
                    ),
                  )
                  .toList(),
              onSelected: (v) {
                if (v != null) setState(() => _section = v);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Título',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _desc,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Descrição',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _link,
              decoration: const InputDecoration(
                labelText: 'Link (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
            SwitchListTile(
              title: const Text('Publicado'),
              value: _published,
              onChanged: (v) => setState(() => _published = v),
            ),
            SwitchListTile(
              title: const Text('Ativo'),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _save,
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}
