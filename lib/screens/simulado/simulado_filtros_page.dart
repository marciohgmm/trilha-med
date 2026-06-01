import 'package:flutter/material.dart';

import '../../core/analytics/analytics_feature_tracker.dart';
import '../../models/simulado_models.dart';
import '../../services/simulado_service.dart';
import '../../services/simulado_session_store.dart';
import '../../widgets/simulado/simulado_radio_section.dart';
import 'simulado_play_page.dart';

/// Tela obrigatória de filtros antes de iniciar o simulado.
class SimuladoFiltrosPage extends StatefulWidget {
  final String userId;

  const SimuladoFiltrosPage({super.key, required this.userId});

  @override
  State<SimuladoFiltrosPage> createState() => _SimuladoFiltrosPageState();
}

class _SimuladoFiltrosPageState extends State<SimuladoFiltrosPage> {
  final _service = SimuladoService();

  int _quantidade = 25;
  bool _todasMaterias = true;
  final Set<String> _materiasSelecionadas = {};
  SimuladoTipoQuestoes _tipo = SimuladoTipoQuestoes.todas;
  SimuladoStatusResolucao _status =
      SimuladoStatusResolucao.apenasNaoResolvidas;

  bool _carregandoMaterias = true;
  bool _iniciando = false;
  String? _erroMaterias;
  List<String> _materiasDisponiveis = [];

  @override
  void initState() {
    super.initState();
    _carregarMaterias();
  }

  Future<void> _carregarMaterias() async {
    setState(() {
      _carregandoMaterias = true;
      _erroMaterias = null;
    });
    try {
      final lista = await _service.listarMateriasDisponiveis();
      if (!mounted) return;
      setState(() {
        _materiasDisponiveis = lista;
        _carregandoMaterias = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erroMaterias = '$e';
        _carregandoMaterias = false;
      });
    }
  }

  SimuladoFiltros _filtrosAtuais() => SimuladoFiltros(
        quantidade: _quantidade,
        todasMaterias: _todasMaterias,
        materiasSelecionadas: _materiasSelecionadas.toList(),
        tipoQuestoes: _tipo,
        statusResolucao: _status,
      );

  Future<void> _iniciar() async {
    if (!_todasMaterias && _materiasSelecionadas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione ao menos uma matéria ou marque todas.'),
        ),
      );
      return;
    }

    if (_tipo == SimuladoTipoQuestoes.apenasErradas &&
        _status == SimuladoStatusResolucao.apenasNaoResolvidas) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '“Apenas erradas” exige incluir questões já resolvidas, '
            'pois questões não resolvidas ainda não têm acerto/erro.',
          ),
          duration: Duration(seconds: 5),
        ),
      );
      return;
    }

    setState(() => _iniciando = true);
    final filtros = _filtrosAtuais();
    final navigator = Navigator.of(context);

    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (ctx) => const PopScope(
        canPop: false,
        child: AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text(
                'Montando seu simulado...\nIsso pode levar alguns segundos.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );

    try {
      await SimuladoSessionStore.instance.limparRascunho();

      final questoes = await _service.montarSimulado(
        userId: widget.userId,
        filtros: filtros,
      );

      if (!mounted) return;
      navigator.pop();
      AnalyticsFeatures.simuladoStart(
        userId: widget.userId,
        questionCount: questoes.length,
      );
      navigator.pushReplacement(
        MaterialPageRoute(
          builder: (_) => SimuladoPlayPage(
            userId: widget.userId,
            questoes: questoes,
            filtros: filtros,
          ),
        ),
      );
    } on SimuladoInsufficientQuestionsException catch (e) {
      if (!mounted) return;
      navigator.pop();
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Questões insuficientes'),
          content: Text(
            e.disponiveis == 0
                ? 'Não encontramos questões com os filtros escolhidos.\n\n'
                    'Tente incluir mais matérias, questões já resolvidas '
                    'ou o tipo "todas as questões".'
                : 'Encontramos apenas ${e.disponiveis} questão(ões), '
                    'mas você pediu ${e.solicitadas}.\n\n'
                    'Ajuste os filtros ou reduza a quantidade.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Entendi'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      navigator.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Não foi possível carregar o simulado. Verifique sua conexão.\n$e',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      if (mounted) setState(() => _iniciando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Fazer Simulado'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                const Text(
                  'Configure seu simulado',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Novas questões no banco entram automaticamente nos simulados.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 24),
                _sectionTitle('1. Quantidade de questões'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: SimuladoService.quantidadesDisponiveis.map((q) {
                    final sel = _quantidade == q;
                    return ChoiceChip(
                      label: Text('$q'),
                      selected: sel,
                      onSelected: (_) => setState(() => _quantidade = q),
                      selectedColor:
                          const Color(0xFF1E3A8A).withValues(alpha: 0.2),
                      labelStyle: TextStyle(
                        fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                        color: sel ? const Color(0xFF1E3A8A) : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                _sectionTitle('2. Matérias'),
                const SizedBox(height: 4),
                SimuladoRadioSection<bool>(
                  groupValue: _todasMaterias,
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      _todasMaterias = v;
                      if (v) _materiasSelecionadas.clear();
                    });
                  },
                  options: const [
                    (value: true, label: 'Todas as matérias'),
                    (value: false, label: 'Selecionar matérias específicas'),
                  ],
                ),
                if (!_todasMaterias) ...[
                  const SizedBox(height: 8),
                  if (_carregandoMaterias)
                    const Center(child: CircularProgressIndicator())
                  else if (_erroMaterias != null)
                    Column(
                      children: [
                        Text(
                          'Erro ao carregar matérias: $_erroMaterias',
                          style: const TextStyle(color: Colors.red),
                        ),
                        TextButton(
                          onPressed: _carregarMaterias,
                          child: const Text('Tentar novamente'),
                        ),
                      ],
                    )
                  else if (_materiasDisponiveis.isEmpty)
                    const Text('Nenhuma matéria com questões ativas.')
                  else
                    ..._materiasDisponiveis.map((m) {
                      final checked = _materiasSelecionadas.contains(m);
                      return CheckboxListTile(
                        value: checked,
                        title: Text(m),
                        activeColor: const Color(0xFF1E3A8A),
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              _materiasSelecionadas.add(m);
                            } else {
                              _materiasSelecionadas.remove(m);
                            }
                          });
                        },
                      );
                    }),
                ],
                const SizedBox(height: 24),
                _sectionTitle('3. Tipo de questões'),
                SimuladoRadioSection<SimuladoTipoQuestoes>(
                  groupValue: _tipo,
                  onChanged: (v) {
                    if (v != null) setState(() => _tipo = v);
                  },
                  options: const [
                    (
                      value: SimuladoTipoQuestoes.todas,
                      label: 'Todas (acertadas e erradas)',
                    ),
                    (
                      value: SimuladoTipoQuestoes.apenasErradas,
                      label: 'Apenas respondidas incorretamente',
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _sectionTitle('4. Status de resolução'),
                SimuladoRadioSection<SimuladoStatusResolucao>(
                  groupValue: _status,
                  onChanged: (v) {
                    if (v != null) setState(() => _status = v);
                  },
                  options: const [
                    (
                      value: SimuladoStatusResolucao.apenasNaoResolvidas,
                      label: 'Apenas ainda não resolvidas',
                    ),
                    (
                      value: SimuladoStatusResolucao.incluirResolvidas,
                      label: 'Incluir também já resolvidas',
                    ),
                  ],
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _iniciando ? null : _iniciar,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                  child: _iniciando
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(color: Colors.white),
                        )
                      : const Text(
                          'INICIAR SIMULADO',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: Color(0xFF1E3A8A),
        ),
      );
}
