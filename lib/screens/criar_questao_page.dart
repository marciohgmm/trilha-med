import 'package:flutter/material.dart';
import 'package:flutter_application_1/models/questao_model.dart';
import 'package:flutter_application_1/services/flashcard_create_session_defaults.dart';
import 'package:flutter_application_1/services/flashcard_materia_stats_service.dart';
import 'package:flutter_application_1/services/flashcard_subtema_catalog_service.dart';
import 'package:flutter_application_1/services/questao_service.dart';
import 'package:flutter_application_1/utils/content_hierarchy_utils.dart';
import 'package:flutter_application_1/widgets/subtema_search_field.dart';

class CriarQuestaoPage extends StatefulWidget {
  final QuestaoModel? questao;
  final String? initialMateria;
  final String? initialSubtema;

  const CriarQuestaoPage({
    super.key,
    this.questao,
    this.initialMateria,
    this.initialSubtema,
  });

  @override
  State<CriarQuestaoPage> createState() => _CriarQuestaoPageState();
}

class _CriarQuestaoPageState extends State<CriarQuestaoPage> {
  final QuestaoService _service = QuestaoService();

  final _formKey = GlobalKey<FormState>();

  final _enunciadoController = TextEditingController();

  // Matéria/Subtema reaproveitados dos flashcards (com opção de criar novo)
  List<String> _materias = [];
  List<String> _subtemas = [];
  String? _materiaSelecionada;
  String? _subtemaSelecionado;
  bool _carregandoOpcoes = true;

  // A alternativa A é sempre a correta (na UI do admin).
  static const String _corretaId = 'A';
  bool _ativo = true;
  bool _salvando = false;

  // Alternativas A-D por padrão (com opção de adicionar E)
  final List<String> _altOrdem = ['A', 'B', 'C', 'D'];
  final Map<String, TextEditingController> _altControllers = {};
  final Map<String, TextEditingController> _justControllers = {};

  static const List<String> _idsPermitidos = ['A', 'B', 'C', 'D', 'E'];

  void _ensureControllers(String id) {
    _altControllers.putIfAbsent(id, () => TextEditingController());
    _justControllers.putIfAbsent(id, () => TextEditingController());
  }

  bool get _podeAdicionarAlternativa =>
      _altOrdem.length < _idsPermitidos.length;

  void _adicionarAlternativa() {
    if (!_podeAdicionarAlternativa) return;
    final proximoId = _idsPermitidos[_altOrdem.length];
    setState(() {
      _altOrdem.add(proximoId);
      _ensureControllers(proximoId);
    });
  }

  String _normalizarJustificativa(String raw) {
    var t = raw.trimLeft();
    if (t.isEmpty) return '';
    // Remove prefixos como "A)", "A.", "A -", "A:" etc.
    t = t.replaceFirst(
      RegExp(r'^[A-Ea-e]\s*[\)\.\:\-]\s*'),
      '',
    );
    // Remove prefixos como "Alternativa A:" (qualquer letra A-E).
    t = t.replaceFirst(
      RegExp(r'^(Alternativa|Op[cç][aã]o)\s+[A-Ea-e]\s*[\)\.\:\-]?\s*',
          caseSensitive: false),
      '',
    );
    return t.trimLeft();
  }

  bool get _modoEdicao => widget.questao != null;

  @override
  void initState() {
    super.initState();

    // inicializa controllers padrão
    for (final id in _altOrdem) {
      _ensureControllers(id);
    }

    _carregarMateriasDosFlashcards();

    final q = widget.questao;
    if (q != null) {
      _materiaSelecionada = q.materia.trim().isEmpty ? null : q.materia;
      _subtemaSelecionado = q.subtema.trim().isEmpty ? null : q.subtema;
      _enunciadoController.text = q.enunciado;
      _ativo = q.ativo;

      for (final alt in q.alternativas) {
        final id = alt.id.trim();
        if (id.isEmpty) continue;
        if (!_altOrdem.contains(id) && _idsPermitidos.contains(id)) {
          _altOrdem.add(id);
        }
        _ensureControllers(id);
        _altControllers[id]!.text = alt.texto;
      }
      for (final entry in q.justificativasPorAlternativa.entries) {
        final id = entry.key.trim();
        if (id.isEmpty) continue;
        if (!_altOrdem.contains(id) && _idsPermitidos.contains(id)) {
          _altOrdem.add(id);
        }
        _ensureControllers(id);
        _justControllers[id]!.text = entry.value;
      }
    }
    // Matéria/subtema ao criar: preenchidos após carregar opções
    // ([_aplicarDefaultsDaSessao] ou fallback de [initialMateria]/[initialSubtema]).
  }

  Future<void> _carregarMateriasDosFlashcards() async {
    try {
      final stats =
          await FlashcardMateriaStatsService.instance.fetchMateriaStats();
      final lista = stats.map((s) => s.name).toList()..sort();

      if (!mounted) return;
      setState(() {
        _materias = lista;
        _carregandoOpcoes = false;
      });

      if (_materiaSelecionada != null && _materiaSelecionada!.isNotEmpty) {
        await _carregarSubtemasDaMateria(_materiaSelecionada!);
      } else if (!_modoEdicao) {
        await _aplicarDefaultsDaSessao();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _carregandoOpcoes = false;
      });
    }
  }

  /// Reaplica matéria/subtema da sessão (mesmo padrão de criar flashcard).
  Future<void> _aplicarDefaultsDaSessao() async {
    if (FlashcardCreateSessionDefaults.hasPair) {
      final m = FlashcardCreateSessionDefaults.ultimaMateriaSelecionada!.trim();
      final s = FlashcardCreateSessionDefaults.ultimoSubtemaSelecionado!.trim();
      if (m.isNotEmpty && s.isNotEmpty && _materias.contains(m)) {
        setState(() {
          _materiaSelecionada = m;
          _subtemaSelecionado = null;
          _subtemas = [];
        });
        await _carregarSubtemasDaMateria(m);
        if (!mounted) return;
        setState(() {
          _subtemaSelecionado = s;
        });
        return;
      }
    }

    final m = widget.initialMateria?.trim() ?? '';
    final s = widget.initialSubtema?.trim() ?? '';
    if (m.isEmpty) return;
    if (!_materias.contains(m)) return;

    setState(() {
      _materiaSelecionada = m;
      _subtemaSelecionado = s.isEmpty ? null : s;
      _subtemas = [];
    });
    await _carregarSubtemasDaMateria(m);
    if (!mounted || s.isEmpty) return;
    setState(() {
      _subtemaSelecionado = s;
    });
  }

  Future<void> _carregarSubtemasDaMateria(String materia) async {
    final lista =
        await FlashcardSubtemaCatalogService.instance.fetchSubtemasByMateria(
      materia,
    );
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
      final subtema = (_subtemaSelecionado ?? '').trim();

      if (materia.isEmpty || subtema.isEmpty) {
        throw Exception('Selecione matéria e subtema.');
      }

      final temaSlug = QuestaoModel.slugify(subtema);

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
        final v = _normalizarJustificativa(entry.value.text);
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
        tema: '',
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

      FlashcardCreateSessionDefaults.setFromForm(materia, subtema);

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
        actions: [
          if (!_modoEdicao)
            IconButton(
              tooltip: 'Limpar assunto padrão da sessão',
              icon: const Icon(Icons.restart_alt_rounded),
              onPressed: () {
                FlashcardCreateSessionDefaults.clear();
                setState(() {
                  _materiaSelecionada = null;
                  _subtemaSelecionado = null;
                  _subtemas = [];
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Seleção padrão da sessão limpa.'),
                  ),
                );
              },
            ),
        ],
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
                  key: ValueKey<String>(
                    'q_dd_materia_${_materias.length}_${_materiaSelecionada ?? ''}',
                  ),
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
                        _subtemaSelecionado = null;
                        _subtemas = [];
                      });
                      await _carregarSubtemasDaMateria(novo);
                      return;
                    }

                    setState(() {
                      _materiaSelecionada = value;
                      _subtemaSelecionado = null;
                      _subtemas = [];
                    });
                    if (value != null && value.isNotEmpty) {
                      await _carregarSubtemasDaMateria(value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                if (_materiaSelecionada != null &&
                    _materiaSelecionada!.isNotEmpty)
                  SubtemaSearchField(
                    key: ValueKey(
                      'q_sub_${_materiaSelecionada}_${_subtemas.length}_${_subtemaSelecionado ?? ''}',
                    ),
                    subtemas: _subtemas,
                    selectedSubtema: _subtemaSelecionado,
                    onCreateNew: () async {
                      final novo = await _mostrarDialogNovoValor(
                        titulo: 'Novo Subtema',
                        hint: 'Digite o nome do subtema',
                      );
                      if (novo == null || novo.isEmpty || !mounted) return;
                      setState(() {
                        _subtemas = ContentHierarchyUtils.sortAlphabetically({
                          ..._subtemas,
                          novo,
                        });
                        _subtemaSelecionado = novo;
                      });
                    },
                    onSelected: (value) {
                      setState(() {
                        _subtemaSelecionado = value?.trim().isEmpty == true
                            ? null
                            : value?.trim();
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
              ..._altOrdem.map((id) {
                final controller = _altControllers[id]!;
                final isCorreta = id == 'A';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TextFormField(
                    controller: controller,
                    decoration: isCorreta
                        ? _decVerde('Alternativa $id (correta)')
                        : _dec('Alternativa $id'),
                    validator: (v) {
                      // Mantemos A-D obrigatórias; E é opcional.
                      final obrigatoria = id != 'E';
                      if (!obrigatoria) return null;
                      return (v == null || v.trim().isEmpty)
                          ? 'Informe o texto da alternativa $id'
                          : null;
                    },
                  ),
                );
              }),
              if (_podeAdicionarAlternativa) ...[
                const SizedBox(height: 2),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _adicionarAlternativa,
                    icon: const Icon(Icons.add),
                    label: const Text('Adicionar alternativa'),
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: Colors.green.withValues(alpha: 0.35)),
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
              ..._altOrdem.map((id) {
                final controller = _justControllers[id]!;
                final isCorreta = id == 'A';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TextFormField(
                    controller: controller,
                    decoration: isCorreta
                        ? _decVerde('Justificativa $id (correta)')
                        : _dec('Justificativa $id'),
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
