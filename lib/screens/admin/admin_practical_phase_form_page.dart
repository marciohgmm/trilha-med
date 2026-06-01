import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/practical_phase_model.dart';
import '../../repositories/practical_phase_repository.dart';
import '../../services/practical_phase_service.dart';
import '../../widgets/practical_phase/practical_phase_constants.dart';

class AdminPracticalPhaseFormPage extends StatefulWidget {
  final String? modelId;

  const AdminPracticalPhaseFormPage({super.key, this.modelId});

  @override
  State<AdminPracticalPhaseFormPage> createState() =>
      _AdminPracticalPhaseFormPageState();
}

class _AdminPracticalPhaseFormPageState
    extends State<AdminPracticalPhaseFormPage> {
  final _service = PracticalPhaseService();
  final _formKey = GlobalKey<FormState>();

  late final String _docId;
  bool _loading = true;
  bool _saving = false;
  double? _uploadProgress;

  final _titleCtrl = TextEditingController();
  final _slugCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _specialtyCtrl = TextEditingController();

  String _difficulty = 'Intermediário';
  String _thumbnailUrl = '';
  bool _isActive = true;
  bool _isPublished = false;
  List<PracticalPhaseAttachment> _attachments = [];
  List<PracticalPhaseSection> _sections = [];
  int _order = 0;
  DateTime? _originalCreatedAt;
  String _originalCreatedBy = 'admin';

  static const _difficulties = ['Básico', 'Intermediário', 'Avançado'];

  bool get _isNew => widget.modelId == null || widget.modelId!.isEmpty;

  @override
  void initState() {
    super.initState();
    _docId = widget.modelId ??
        FirebaseFirestore.instance
            .collection(PracticalPhaseRepository.collectionName)
            .doc()
            .id;
    _load();
  }

  Future<void> _load() async {
    if (_isNew) {
      setState(() => _loading = false);
      return;
    }
    try {
      final m = await _service.getById(widget.modelId!);
      if (m != null) _applyModel(m);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyModel(PracticalPhaseModel m) {
    _titleCtrl.text = m.title;
    _slugCtrl.text = m.slug;
    _descCtrl.text = m.description;
    _categoryCtrl.text = m.category;
    _specialtyCtrl.text = m.specialty;
    _difficulty = m.difficulty;
    _thumbnailUrl = m.thumbnailUrl;
    _isActive = m.isActive;
    _isPublished = m.isPublished;
    _attachments = List.from(m.attachments);
    _sections = List.from(m.sections);
    _order = m.order;
    _originalCreatedAt = m.createdAt;
    _originalCreatedBy = m.createdBy;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _slugCtrl.dispose();
    _descCtrl.dispose();
    _categoryCtrl.dispose();
    _specialtyCtrl.dispose();
    super.dispose();
  }

  void _onTitleChanged(String v) {
    if (_slugCtrl.text.isEmpty ||
        _slugCtrl.text == PracticalPhaseModel.slugify(_titleCtrl.text)) {
      _slugCtrl.text = PracticalPhaseModel.slugify(v);
    }
  }

  PracticalPhaseModel _buildModel() {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? 'admin';
    final now = DateTime.now();
    return PracticalPhaseModel(
      id: _docId,
      title: _titleCtrl.text.trim(),
      slug: _slugCtrl.text.trim().isEmpty
          ? PracticalPhaseModel.slugify(_titleCtrl.text)
          : _slugCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      category: _categoryCtrl.text.trim(),
      specialty: _specialtyCtrl.text.trim(),
      difficulty: _difficulty,
      thumbnailUrl: _thumbnailUrl,
      isActive: _isActive,
      isPublished: _isPublished,
      order: _order,
      createdAt: _originalCreatedAt ?? now,
      updatedAt: now,
      createdBy: _isNew ? userId : _originalCreatedBy,
      attachments: _attachments,
      sections: _sections,
    );
  }

  String _saveErrorMessage(Object e) {
    final msg = e.toString();
    if (msg.contains('permission-denied')) {
      return 'Sem permissão no Firebase. Confirme que sua conta é admin '
          '(users.isAdmin ou coleção admins) e publique as regras do Firestore.';
    }
    if (msg.contains('not-found')) {
      return 'Documento não encontrado. Tente criar um novo modelo.';
    }
    return 'Erro ao salvar: $e';
  }

  Future<void> _save({required bool publish}) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _isPublished = publish ? true : _isPublished;
      if (publish) _isActive = true;
    });
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid ?? 'admin';
      var model = _buildModel().copyWith(
        isPublished: publish ? true : _isPublished,
        isActive: _isActive,
      );
      if (_isNew) {
        await _service.saveModel(
          model: model.copyWith(id: _docId),
          userId: userId,
          isNew: true,
        );
      } else {
        await _service.saveModel(
          model: model,
          userId: userId,
          isNew: false,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            publish ? 'Modelo publicado!' : 'Rascunho salvo.',
          ),
        ),
      );
      Navigator.pop(context, true);
    } catch (e, st) {
      debugPrint('[AdminPracticalPhaseForm] save failed: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_saveErrorMessage(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickThumbnail() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final file = result?.files.single;
    if (file == null) return;
    setState(() => _uploadProgress = 0.3);
    try {
      final url = await _service.uploadThumbnail(
        modelId: _docId,
        file: file,
      );
      setState(() {
        _thumbnailUrl = url;
        _uploadProgress = null;
      });
    } catch (e) {
      setState(() => _uploadProgress = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _addAttachment() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'doc', 'docx', 'txt'],
    );
    final file = result?.files.single;
    if (file == null) return;
    setState(() => _uploadProgress = 0.2);
    try {
      final att = await _service.uploadAttachment(
        modelId: _docId,
        file: file,
        onProgress: (p) => setState(() => _uploadProgress = p),
      );
      setState(() {
        _attachments = [..._attachments, att];
        _uploadProgress = null;
      });
    } catch (e) {
      setState(() => _uploadProgress = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _addSection() {
    setState(() {
      _sections = [
        ..._sections,
        PracticalPhaseSection(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: 'Nova seção',
          description: '',
          order: _sections.length,
          items: const [],
        ),
      ];
    });
  }

  void _addItem(int sectionIndex) {
    final section = _sections[sectionIndex];
    final items = [
      ...section.items,
      PracticalPhaseItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: 'Novo item',
        content: '',
        order: section.items.length,
      ),
    ];
    final updated = section.copyWith(items: items);
    setState(() {
      _sections = List.from(_sections)..[sectionIndex] = updated;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: PracticalPhaseColors.background,
      appBar: AppBar(
        title: Text(_isNew ? 'Novo modelo' : 'Editar modelo'),
        backgroundColor: PracticalPhaseColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (_uploadProgress != null)
              LinearProgressIndicator(value: _uploadProgress),
            _card(
              child: Column(
                children: [
                  TextFormField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Título *',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: _onTitleChanged,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _slugCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Slug (URL)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Descrição',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _categoryCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Categoria',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _specialtyCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Especialidade',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownMenu<String>(
                    initialSelection: _difficulty,
                    label: const Text('Dificuldade'),
                    dropdownMenuEntries: _difficulties
                        .map((d) => DropdownMenuEntry(value: d, label: d))
                        .toList(),
                    onSelected: (v) {
                      if (v != null) setState(() => _difficulty = v);
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Ativo'),
                    value: _isActive,
                    onChanged: (v) => setState(() => _isActive = v),
                  ),
                  SwitchListTile(
                    title: const Text('Publicado'),
                    value: _isPublished,
                    onChanged: (v) => setState(() => _isPublished = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Capa / thumbnail',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (_thumbnailUrl.isNotEmpty)
                    Text(
                      _thumbnailUrl,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  OutlinedButton.icon(
                    onPressed: _pickThumbnail,
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('Enviar imagem'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Anexos',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _addAttachment,
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Adicionar'),
                      ),
                    ],
                  ),
                  if (_attachments.isEmpty)
                    const Text('Nenhum anexo.'),
                  ..._attachments.map(
                    (a) => ListTile(
                      title: Text(a.name),
                      subtitle: Text(a.url, maxLines: 1),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => setState(() {
                          _attachments =
                              _attachments.where((x) => x.id != a.id).toList();
                        }),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text(
                  'Seções e itens',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: PracticalPhaseColors.primary,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _addSection,
                  icon: const Icon(Icons.add),
                  label: const Text('Seção'),
                ),
              ],
            ),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _sections.length,
              onReorder: (oldIndex, newIndex) {
                if (newIndex > oldIndex) newIndex--;
                setState(() {
                  final list = List<PracticalPhaseSection>.from(_sections);
                  final item = list.removeAt(oldIndex);
                  list.insert(newIndex, item);
                  _sections = list
                      .asMap()
                      .entries
                      .map((e) => e.value.copyWith(order: e.key))
                      .toList();
                });
              },
              itemBuilder: (context, si) {
                final section = _sections[si];
                return Card(
                  key: ValueKey(section.id),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            ReorderableDragStartListener(
                              index: si,
                              child: const Icon(Icons.drag_handle),
                            ),
                            Expanded(
                              child: TextFormField(
                                initialValue: section.title,
                                decoration: const InputDecoration(
                                  labelText: 'Título da seção',
                                ),
                                onChanged: (v) {
                                  _sections[si] =
                                      section.copyWith(title: v);
                                },
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.red),
                              onPressed: () => setState(() {
                                _sections = List.from(_sections)..removeAt(si);
                              }),
                            ),
                          ],
                        ),
                        TextFormField(
                          initialValue: section.description,
                          decoration: const InputDecoration(
                            labelText: 'Descrição da seção',
                          ),
                          onChanged: (v) {
                            _sections[si] = section.copyWith(description: v);
                          },
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => _addItem(si),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Item'),
                          ),
                        ),
                        ...section.items.asMap().entries.map((entry) {
                          final ii = entry.key;
                          final item = entry.value;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Column(
                              children: [
                                TextFormField(
                                  initialValue: item.title,
                                  decoration: InputDecoration(
                                    labelText: 'Item ${ii + 1}',
                                    isDense: true,
                                  ),
                                  onChanged: (v) {
                                    final items = List<PracticalPhaseItem>.from(
                                      section.items,
                                    );
                                    items[ii] = item.copyWith(title: v);
                                    _sections[si] =
                                        section.copyWith(items: items);
                                  },
                                ),
                                TextFormField(
                                  initialValue: item.content,
                                  maxLines: 3,
                                  decoration: const InputDecoration(
                                    labelText: 'Conteúdo',
                                  ),
                                  onChanged: (v) {
                                    final items = List<PracticalPhaseItem>.from(
                                      section.items,
                                    );
                                    items[ii] = item.copyWith(content: v);
                                    _sections[si] =
                                        section.copyWith(items: items);
                                  },
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            if (_saving)
              const Center(child: CircularProgressIndicator())
            else ...[
              FilledButton(
                onPressed: () => _save(publish: false),
                style: FilledButton.styleFrom(
                  backgroundColor: PracticalPhaseColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Salvar rascunho'),
              ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: () => _save(publish: true),
                style: FilledButton.styleFrom(
                  backgroundColor: PracticalPhaseColors.success,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Publicar'),
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}
