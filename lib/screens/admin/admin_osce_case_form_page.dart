import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/osce_models.dart';
import '../../models/osce_script_fields.dart';
import '../../services/osce/osce_case_admin_service.dart';
import '../../services/osce/osce_room_service.dart';
import '../../utils/osce_case_storage_upload.dart';
import '../../data/osce_default_evaluation_rubric.dart';
import '../../models/osce_evaluation_models.dart';
import '../../widgets/osce/evaluation/osce_evaluation_rubric_editor.dart';
import '../../widgets/osce/osce_admin_rich_field.dart';

class AdminOsceCaseFormPage extends StatefulWidget {
  final String? caseId;

  const AdminOsceCaseFormPage({super.key, this.caseId});

  @override
  State<AdminOsceCaseFormPage> createState() => _AdminOsceCaseFormPageState();
}

class _AdminOsceCaseFormPageState extends State<AdminOsceCaseFormPage>
    with SingleTickerProviderStateMixin {
  final _service = OsceCaseAdminService();
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();

  late final String _docId;
  late final TabController _tabController;
  bool _loading = true;
  bool _saving = false;
  bool _uploadingImage = false;

  String _specialty = OsceSpecialties.list.first;
  String? _imagingImageUrl;
  late OsceEvaluationRubric _evaluationRubric;

  final Map<String, String> _richValues = {};
  final Map<String, GlobalKey<OsceAdminRichFieldState>> _richFieldKeys = {};

  bool get _isNew => widget.caseId == null || widget.caseId!.isEmpty;

  @override
  void initState() {
    super.initState();
    _evaluationRubric = OsceDefaultEvaluationRubric.templateForAdmin();
    _tabController = TabController(length: 4, vsync: this);
    _docId = _isNew
        ? FirebaseFirestore.instance
            .collection(OsceRoomService.cases)
            .doc()
            .id
        : widget.caseId!;
    _initRichDefaults();
    _load();
  }

  void _initRichDefaults() {
    for (final k in [
      'scenario',
      'tasks',
      'caseDescription',
      'physicalExam',
      'laboratory',
      'imaging',
      'diagnosis',
    ]) {
      _richValues[k] = '';
    }
    for (final f in OsceScriptFields.fieldDefs) {
      _richValues[f.key] = '';
    }
    _ensureRichKeys();
  }

  void _ensureRichKeys() {
    for (final k in _richValues.keys) {
      _richFieldKeys.putIfAbsent(k, GlobalKey<OsceAdminRichFieldState>.new);
    }
  }

  void _flushRichFieldsFromEditors() {
    for (final e in _richFieldKeys.entries) {
      final state = e.value.currentState;
      if (state != null) {
        _richValues[e.key] = state.value;
      }
    }
  }

  Future<void> _load() async {
    if (_isNew) {
      setState(() => _loading = false);
      return;
    }
    try {
      final c = await _service.getById(widget.caseId!);
      if (c != null) _apply(c);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _apply(OsceCaseModel c) {
    _titleCtrl.text = c.title;
    if (OsceSpecialties.list.contains(c.specialty)) {
      _specialty = c.specialty;
    }
    _imagingImageUrl = c.imagingImageUrl;
    _evaluationRubric =
        OsceDefaultEvaluationRubric.templateForAdmin(c.evaluationRubric);
    _richValues['scenario'] = c.scenario;
    _richValues['tasks'] = c.tasks;
    _richValues['caseDescription'] = c.caseDescription;
    _richValues['physicalExam'] = c.physicalExamContent;
    _richValues['laboratory'] = c.laboratoryContent;
    _richValues['imaging'] = c.imagingContent;
    _richValues['diagnosis'] = c.hiddenDiagnosis;
    final script = OsceScriptFields.normalizeScript(c.actorScript);
    for (final f in OsceScriptFields.fieldDefs) {
      _richValues[f.key] = script[f.key] ?? '';
    }
    _richFieldKeys.clear();
    _ensureRichKeys();
  }

  Future<void> _importImagingImage() async {
    final file = await pickOsceImageFile();
    if (file == null) return;
    setState(() => _uploadingImage = true);
    try {
      final url = await uploadOsceCaseImage(caseId: _docId, file: file);
      _flushRichFieldsFromEditors();
      setState(() => _imagingImageUrl = url);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Imagem importada!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao enviar imagem: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  Future<void> _save() async {
    _flushRichFieldsFromEditors();

    final rubricaSalvar =
        OsceDefaultEvaluationRubric.templateForAdmin(_evaluationRubric);
    if (!osceRubricIsValidForSave(rubricaSalvar)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'A soma dos pesos dos critérios não pode ultrapassar 10 pontos. '
            'Ajuste na aba Avaliação.',
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final script = <String, String>{};
      for (final f in OsceScriptFields.fieldDefs) {
        script[f.key] = _richValues[f.key] ?? '';
      }

      final title = _titleCtrl.text.trim();
      final model = OsceCaseModel(
        id: _docId,
        title: title.isEmpty ? 'Caso OSCE' : title,
        specialty: _specialty,
        scenario: _richValues['scenario'] ?? '',
        caseDescription: _richValues['caseDescription'] ?? '',
        tasks: _richValues['tasks'] ?? '',
        actorScript: script,
        physicalExamContent: _richValues['physicalExam'] ?? '',
        laboratoryContent: _richValues['laboratory'] ?? '',
        imagingContent: _richValues['imaging'] ?? '',
        imagingImageUrl: _imagingImageUrl,
        hiddenDiagnosis: _richValues['diagnosis'] ?? '',
        evaluationRubric: rubricaSalvar,
      );

      await _service.save(id: _docId, model: model);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Caso salvo com sucesso!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString();
        final hint = msg.contains('permission-denied') ||
                msg.contains('PERMISSION_DENIED')
            ? '\n\nPublique as regras: firebase deploy --only firestore:rules,storage'
            : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar:$hint\n\n$e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleCtrl.dispose();
    super.dispose();
  }

  Widget _rich(String storageKey, String label, {double height = 120}) {
    final fieldKey = _richFieldKeys.putIfAbsent(
      storageKey,
      GlobalKey<OsceAdminRichFieldState>.new,
    );
    return OsceAdminRichField(
      key: fieldKey,
      label: label,
      initialValue: _richValues[storageKey] ?? '',
      minHeight: height,
      onChanged: (v) => _richValues[storageKey] = v,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Novo caso OSCE' : 'Editar caso'),
        backgroundColor: const Color(0xFF0D9488),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              // SingleChildScrollView mantém todos os Quill montados; ListView
              // destruía campos fora da tela e o texto “sumia” ao rolar.
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _titleCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Título do caso (opcional)',
                            hintText: 'Se vazio, será salvo como "Caso OSCE"',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          key: ValueKey<String>('osce_specialty_$_specialty'),
                          initialValue:
                              OsceSpecialties.list.contains(_specialty)
                                  ? _specialty
                                  : OsceSpecialties.list.first,
                          decoration: const InputDecoration(
                            labelText: 'Especialidade *',
                            border: OutlineInputBorder(),
                          ),
                          items: OsceSpecialties.list
                              .map((s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(s),
                                  ))
                              .toList(),
                          onChanged: (v) {
                            if (v == null) return;
                            _flushRichFieldsFromEditors();
                            setState(() => _specialty = v);
                          },
                        ),
                      ],
                    ),
                  ),
                  Material(
                    color: const Color(0xFF1E3A8A),
                    child: TabBar(
                      controller: _tabController,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white70,
                      indicatorColor: const Color(0xFF0D9488),
                      indicatorWeight: 3,
                      tabs: const [
                        Tab(text: 'Caso'),
                        Tab(text: 'Script'),
                        Tab(text: 'Avaliação'),
                        Tab(text: 'Exames'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const _SectionTitle(
                                'Visão do médico (antes da estação)',
                              ),
                              _rich('scenario', 'Cenário de atendimento',
                                  height: 140),
                              _rich('tasks', 'Tarefas', height: 140),
                              _rich('caseDescription',
                                  'Descrição extra (referência)',
                                  height: 80),
                            ],
                          ),
                        ),
                        SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const _SectionTitle(
                                'Script do avaliador (durante a estação)',
                              ),
                              for (final f in OsceScriptFields.fieldDefs)
                                _rich(f.key, f.label, height: 100),
                            ],
                          ),
                        ),
                        SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const _SectionTitle(
                                'Avaliação ao final da estação',
                              ),
                              const Text(
                                'Critérios pré-preenchidos (soma = 10 pts). '
                                'Edite textos e pontuações. O avaliador marca '
                                'Adequado / Parcial / Inadequado na correção.',
                                style: TextStyle(fontSize: 13),
                              ),
                              const SizedBox(height: 12),
                              OsceEvaluationRubricEditor(
                                rubric: _evaluationRubric,
                                onChanged: (r) =>
                                    setState(() => _evaluationRubric = r),
                              ),
                            ],
                          ),
                        ),
                        SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const _SectionTitle(
                                'Exames e diagnóstico (ocultos do médico)',
                              ),
                              _rich('physicalExam', 'Exame físico', height: 120),
                              _rich('laboratory', 'Laboratório', height: 120),
                              _rich('imaging',
                                  'Diagnóstico por imagem / laudo',
                                  height: 120),
                              Row(
                                children: [
                                  FilledButton.icon(
                                    onPressed: _uploadingImage
                                        ? null
                                        : _importImagingImage,
                                    icon: _uploadingImage
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(Icons.image_outlined),
                                    label: const Text('Importar imagem'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor:
                                          const Color(0xFF1E3A8A),
                                    ),
                                  ),
                                  if (_imagingImageUrl != null) ...[
                                    const SizedBox(width: 12),
                                    IconButton(
                                      tooltip: 'Remover imagem',
                                      onPressed: () {
                                        _flushRichFieldsFromEditors();
                                        setState(() => _imagingImageUrl = null);
                                      },
                                      icon: const Icon(Icons.delete_outline,
                                          color: Colors.red),
                                    ),
                                  ],
                                ],
                              ),
                              if (_imagingImageUrl != null) ...[
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    _imagingImageUrl!,
                                    height: 180,
                                    width: double.infinity,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) =>
                                        const Text('Prévia indisponível'),
                                  ),
                                ),
                              ],
                              _rich('diagnosis', 'Diagnóstico (oculto)',
                                  height: 80),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0D9488),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _saving
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Salvar caso'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: Color(0xFF1E3A8A),
        ),
      ),
    );
  }
}
