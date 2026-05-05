import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_1/models/questao_model.dart';
import 'package:flutter_application_1/services/questao_service.dart';

class CriarQuestaoPage extends StatefulWidget {
  final QuestaoModel? questao;
  final String? initialMateria;
  final String? initialTema;
  final String? initialSubtema;

  const CriarQuestaoPage({
    super.key,
    this.questao,
    this.initialMateria,
    this.initialTema,
    this.initialSubtema,
  });

  @override
  State<CriarQuestaoPage> createState() => _CriarQuestaoPageState();
}

class _CriarQuestaoPageState extends State<CriarQuestaoPage> {
  final QuestaoService _service = QuestaoService();

  final _formKey = GlobalKey<FormState>();

  final _enunciadoController = TextEditingController();

  // Matéria/Tema/Subtema reaproveitados dos flashcards (com opção de criar novo)
  List<String> _materias = [];
  List<String> _temas = [];
  List<String> _subtemas = [];
  String? _materiaSelecionada;
  String? _temaSelecionado;
  String? _subtemaSelecionado;
  bool _carregandoOpcoes = true;

  // A alternativa A é sempre a correta (na UI do admin).
  static const String _corretaId = 'A';
  bool _ativo = true;
  bool _salvando = false;

  // Alternativas A-D por padrão
  final Map<String, TextEditingController> _altControllers = {
    'A': TextEditingController(),
    'B': TextEditingController(),
    'C': TextEditingController(),
    'D': TextEditingController(),
  };

  final Map<String, TextEditingController> _justControllers = {
    'A': TextEditingController(),
    'B': TextEditingController(),
    'C': TextEditingController(),
    'D': TextEditingController(),
  };

  bool get _modoEdicao => widget.questao != null;

  @override
  void initState() {
    super.initState();

    _carregarMateriasDosFlashcards();

    final q = widget.questao;
    if (q != null) {
      _materiaSelecionada = q.materia.trim().isEmpty ? null : q.materia;
      _temaSelecionado = q.tema.trim().isEmpty ? null : q.tema;
      _subtemaSelecionado = q.subtema.trim().isEmpty ? null : q.subtema;
      _enunciadoController.text = q.enunciado;
      _ativo = q.ativo;

      for (final alt in q.alternativas) {
        final c = _altControllers[alt.id];
        if (c != null) c.text = alt.texto;
      }
      for (final entry in q.justificativasPorAlternativa.entries) {
        final c = _justControllers[entry.key];
        if (c != null) c.text = entry.value;
      }
    } else {
      // Criando dentro do fluxo admin (matéria/tema/subtema já escolhidos)
      _materiaSelecionada = widget.initialMateria;
      _temaSelecionado = widget.initialTema;
      _subtemaSelecionado = widget.initialSubtema;
    }
  }

  Future<void> _carregarMateriasDosFlashcards() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('flashcards').get();
      final set = <String>{};
      for (final doc in snapshot.docs) {
        final materia = (doc.data()['materia'] ?? '').toString().trim();
        if (materia.isNotEmpty) set.add(materia);
      }
      final lista = set.toList()..sort();

      if (!mounted) return;
      setState(() {
        _materias = lista;
        _carregandoOpcoes = false;
      });

      // Em modo edição, tenta carregar temas/subtemas correspondentes.
      if (_materiaSelecionada != null && _materiaSelecionada!.isNotEmpty) {
        await _carregarTemasDaMateria(_materiaSelecionada!);
      }
      if (_materiaSelecionada != null &&
          _temaSelecionado != null &&
          _temaSelecionado!.isNotEmpty) {
        await _carregarSubtemas(_materiaSelecionada!, _temaSelecionado!);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _carregandoOpcoes = false;
      });
    }
  }

  Future<void> _carregarTemasDaMateria(String materia) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('flashcards')
        .where('materia', isEqualTo: materia)
        .get();

    final set = <String>{};
    for (final doc in snapshot.docs) {
      final tema = (doc.data()['tema'] ?? '').toString().trim();
      if (tema.isNotEmpty) set.add(tema);
    }
    final lista = set.toList()..sort();
    if (!mounted) return;
    setState(() {
      _temas = lista;
      _subtemas = [];
    });
  }

  Future<void> _carregarSubtemas(String materia, String tema) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('flashcards')
        .where('materia', isEqualTo: materia)
        .where('tema', isEqualTo: tema)
        .get();

    final set = <String>{};
    for (final doc in snapshot.docs) {
      final subtema = (doc.data()['subtema'] ?? '').toString().trim();
      if (subtema.isNotEmpty) set.add(subtema);
    }
    final lista = set.toList()..sort();
    if (!mounted) return;
    setState(() {
      _subtemas = lista;
    });
  }

  Future<String?> _mostrarDialogNovoValor({
    required String titulo,
    required String hint,
  }) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(titulo),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _enunciadoController.dispose();
    for (final c in _altControllers.values) {
      c.dispose();
    }
    for (final c in _justControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _salvar() async {
    if (_salvando) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _salvando = true;
    });

    try {
      final agora = DateTime.now();
      final materia = (_materiaSelecionada ?? '').trim();
      final tema = (_temaSelecionado ?? '').trim();
      final subtema = (_subtemaSelecionado ?? '').trim();

      if (materia.isEmpty || tema.isEmpty || subtema.isEmpty) {
        throw Exception('Selecione matéria, tema e subtema.');
      }

      final temaSlug = QuestaoModel.slugify(tema);

      final alternativas = _altControllers.entries
          .map(
            (e) => QuestaoAlternativa(
              id: e.key,
              texto: e.value.text.trim(),
            ),
          )
          .where((a) => a.texto.isNotEmpty)
          .toList();

      if (alternativas.length < 2) {
        throw Exception('Informe pelo menos 2 alternativas.');
      }

      final justificativas = <String, String>{};
      for (final entry in _justControllers.entries) {
        final v = entry.value.text.trim();
        if (v.isNotEmpty) {
          justificativas[entry.key] = v;
        }
      }

      final q = QuestaoModel(
        id: _modoEdicao ? widget.questao!.id : '',
        temaId: widget.questao?.temaId ?? '',
        temaSlug: temaSlug,
        materiaId: widget.questao?.materiaId ?? '',
        materia: materia,
        tema: tema,
        subtema: subtema,
        flashcardId: null,
        enunciado: _enunciadoController.text.trim(),
        alternativas: alternativas,
        corretaId: _corretaId,
        explicacaoGeral: '',
        explicacaoCorreta: '',
        explicacoesErradas: const {},
        justificativasPorAlternativa: justificativas,
        dificuldade: widget.questao?.dificuldade ?? 'médio',
        status: _ativo ? 'ativo' : 'inativo',
        tags: const [],
        ativo: _ativo,
        createdAt: _modoEdicao ? widget.questao!.createdAt : agora,
        updatedAt: agora,
        ordem: 0,
      );

      final ok = await _service.salvarQuestaoModel(q, criar: !_modoEdicao);

      if (!mounted) return;
      if (!ok) throw Exception('Falha ao salvar no Firestore.');

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao salvar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _salvando = false;
        });
      }
    }
  }

  InputDecoration _dec(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: Colors.white,
    );
  }

  InputDecoration _decVerde(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.green.shade600, width: 1.8),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.green.shade700, width: 2.4),
      ),
      filled: true,
      fillColor: Colors.green.withValues(alpha: 0.06),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _modoEdicao ? 'Editar questão' : 'Criar questão';

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: Text(title),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_carregandoOpcoes)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                DropdownButtonFormField<String>(
                  initialValue: _materias.contains(_materiaSelecionada)
                      ? _materiaSelecionada
                      : null,
                  decoration: _dec('Matéria'),
                  items: [
                    ..._materias.map(
                      (m) => DropdownMenuItem(value: m, child: Text(m)),
                    ),
                    const DropdownMenuItem(
                      value: '__nova_materia__',
                      child: Text('➕ Nova Matéria'),
                    ),
                  ],
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Selecione a matéria'
                      : null,
                  onChanged: (value) async {
                    if (value == '__nova_materia__') {
                      final novo = await _mostrarDialogNovoValor(
                        titulo: 'Nova Matéria',
                        hint: 'Digite o nome da matéria',
                      );
                      if (novo == null || novo.isEmpty || !mounted) return;
                      setState(() {
                        if (!_materias.contains(novo)) {
                          _materias.add(novo);
                          _materias.sort();
                        }
                        _materiaSelecionada = novo;
                        _temaSelecionado = null;
                        _subtemaSelecionado = null;
                        _temas = [];
                        _subtemas = [];
                      });
                      await _carregarTemasDaMateria(novo);
                      return;
                    }

                    setState(() {
                      _materiaSelecionada = value;
                      _temaSelecionado = null;
                      _subtemaSelecionado = null;
                      _temas = [];
                      _subtemas = [];
                    });
                    if (value != null && value.isNotEmpty) {
                      await _carregarTemasDaMateria(value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _temas.contains(_temaSelecionado)
                      ? _temaSelecionado
                      : null,
                  decoration: _dec('Tema'),
                  items: [
                    ..._temas.map(
                      (t) => DropdownMenuItem(value: t, child: Text(t)),
                    ),
                    const DropdownMenuItem(
                      value: '__novo_tema__',
                      child: Text('➕ Novo Tema'),
                    ),
                  ],
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Selecione o tema'
                      : null,
                  onChanged: (value) async {
                    final materia = _materiaSelecionada;
                    if (materia == null || materia.isEmpty) return;

                    if (value == '__novo_tema__') {
                      final novo = await _mostrarDialogNovoValor(
                        titulo: 'Novo Tema',
                        hint: 'Digite o nome do tema',
                      );
                      if (novo == null || novo.isEmpty || !mounted) return;
                      setState(() {
                        if (!_temas.contains(novo)) {
                          _temas.add(novo);
                          _temas.sort();
                        }
                        _temaSelecionado = novo;
                        _subtemaSelecionado = null;
                        _subtemas = [];
                      });
                      await _carregarSubtemas(materia, novo);
                      return;
                    }

                    setState(() {
                      _temaSelecionado = value;
                      _subtemaSelecionado = null;
                      _subtemas = [];
                    });
                    if (value != null && value.isNotEmpty) {
                      await _carregarSubtemas(materia, value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _subtemas.contains(_subtemaSelecionado)
                      ? _subtemaSelecionado
                      : null,
                  decoration: _dec('Subtema'),
                  items: [
                    ..._subtemas.map(
                      (s) => DropdownMenuItem(value: s, child: Text(s)),
                    ),
                    const DropdownMenuItem(
                      value: '__novo_subtema__',
                      child: Text('➕ Novo Subtema'),
                    ),
                  ],
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Selecione o subtema'
                      : null,
                  onChanged: (value) async {
                    if (value == '__novo_subtema__') {
                      final novo = await _mostrarDialogNovoValor(
                        titulo: 'Novo Subtema',
                        hint: 'Digite o nome do subtema',
                      );
                      if (novo == null || novo.isEmpty || !mounted) return;
                      setState(() {
                        if (!_subtemas.contains(novo)) {
                          _subtemas.add(novo);
                          _subtemas.sort();
                        }
                        _subtemaSelecionado = novo;
                      });
                      return;
                    }
                    setState(() {
                      _subtemaSelecionado = value;
                    });
                  },
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _enunciadoController,
                decoration: _dec('Enunciado'),
                maxLines: 4,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Informe o enunciado'
                    : null,
              ),
              const SizedBox(height: 16),
              const Text(
                'Alternativas',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A8A),
                ),
              ),
              const SizedBox(height: 10),
              ..._altControllers.entries.map((e) {
                final isCorreta = e.key == 'A';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TextFormField(
                    controller: e.value,
                    decoration: isCorreta
                        ? _decVerde('Alternativa ${e.key} (correta)')
                        : _dec('Alternativa ${e.key}'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Informe o texto da alternativa ${e.key}'
                        : null,
                  ),
                );
              }),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.35)),
                ),
                child: const Text(
                  'Gabarito: alternativa A (padrão). As alternativas serão embaralhadas para o aluno.',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Justificativas por alternativa (opcional)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A8A),
                ),
              ),
              const SizedBox(height: 10),
              ..._justControllers.entries.map((e) {
                final isCorreta = e.key == 'A';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TextFormField(
                    controller: e.value,
                    decoration: isCorreta
                        ? _decVerde('Justificativa ${e.key} (correta)')
                        : _dec('Justificativa ${e.key}'),
                    maxLines: 2,
                  ),
                );
              }),
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ativo/publicado'),
                value: _ativo,
                onChanged: (v) {
                  setState(() {
                    _ativo = v;
                  });
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _salvando ? null : _salvar,
                  icon: _salvando
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(_salvando ? 'Salvando...' : 'Salvar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

