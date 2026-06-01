import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/analytics/analytics_feature_tracker.dart';
import '../../models/questao_model.dart';
import '../../models/simulado_models.dart';
import '../../services/simulado_service.dart';
import '../../services/simulado_session_store.dart';
import '../../widgets/questao_card.dart';
import 'simulado_resultado_page.dart';

class SimuladoPlayPage extends StatefulWidget {
  final String userId;
  final List<QuestaoModel> questoes;
  final SimuladoFiltros filtros;

  const SimuladoPlayPage({
    super.key,
    required this.userId,
    required this.questoes,
    required this.filtros,
  });

  @override
  State<SimuladoPlayPage> createState() => _SimuladoPlayPageState();
}

class _SimuladoPlayPageState extends State<SimuladoPlayPage> {
  final _service = SimuladoService();
  final PageController _pageController = PageController();
  final Map<String, bool> _respostas = {};
  final Set<String> _respondidas = {};

  late DateTime _inicio;
  Timer? _timerTick;
  int _segundos = 0;
  int _paginaAtual = 0;
  bool _finalizando = false;
  bool _rascunhoVerificado = false;

  List<String> get _questaoIds =>
      widget.questoes.map((q) => q.id).toList(growable: false);

  @override
  void initState() {
    super.initState();
    _inicio = DateTime.now();
    _timerTick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _segundos = DateTime.now().difference(_inicio).inSeconds;
        });
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _verificarRascunho());
  }

  @override
  void dispose() {
    _timerTick?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  int get _acertos => _respostas.values.where((a) => a).length;

  int get _erros => _respostas.values.where((a) => !a).length;

  int get _naoRespondidas => widget.questoes.length - _respondidas.length;

  String _formatarTempo(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _salvarRascunhoLocal() async {
    await SimuladoSessionStore.instance.salvarRascunho(
      SimuladoRascunho(
        userId: widget.userId,
        questaoIds: _questaoIds,
        respostas: Map<String, bool>.from(_respostas),
        paginaAtual: _paginaAtual,
        segundosDecorridos: _segundos,
        filtros: widget.filtros,
        salvoEm: DateTime.now(),
      ),
    );
  }

  Future<void> _limparRascunhoLocal() async {
    await SimuladoSessionStore.instance.limparRascunho();
  }

  Future<void> _verificarRascunho() async {
    if (_rascunhoVerificado) return;
    _rascunhoVerificado = true;

    final store = SimuladoSessionStore.instance;
    final rascunho =
        await store.carregarRascunho(widget.userId);
    if (rascunho == null || !mounted) return;

    if (!store.rascunhoCompativel(rascunho, _questaoIds)) {
      await store.limparRascunho();
      return;
    }

    if (rascunho.respostas.isEmpty && rascunho.paginaAtual == 0) {
      return;
    }

    final restaurar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Continuar simulado?'),
        content: Text(
          'Encontramos um simulado em andamento '
          '(${rascunho.respostas.length} resposta(s)). '
          'Deseja continuar de onde parou?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Começar do zero'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (restaurar == true) {
      final maxPage = widget.questoes.length - 1;
      final pagina = rascunho.paginaAtual.clamp(0, maxPage);
      setState(() {
        _respostas
          ..clear()
          ..addAll(rascunho.respostas);
        _respondidas
          ..clear()
          ..addAll(rascunho.respostas.keys);
        _paginaAtual = pagina;
        _segundos = rascunho.segundosDecorridos;
        _inicio = DateTime.now().subtract(Duration(seconds: _segundos));
      });
      if (_pageController.hasClients) {
        _pageController.jumpToPage(pagina);
      }
    } else {
      await store.limparRascunho();
    }
  }

  Future<bool> _confirmarSaida() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sair do simulado?'),
        content: const Text(
          'Seu progresso nesta sessão será perdido. Deseja realmente sair?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Continuar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _sairSimulado() async {
    final sair = await _confirmarSaida();
    if (!mounted) return;
    if (sair) {
      await _limparRascunhoLocal();
      if (!mounted) return;
      Navigator.pop(context);
    }
  }

  Future<void> _finalizar() async {
    final pendentes = _naoRespondidas;
    if (pendentes > 0) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Finalizar simulado?'),
          content: Text(
            'Você ainda não respondeu $pendentes questão(ões). '
            'Deseja finalizar mesmo assim?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Continuar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Finalizar'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    setState(() => _finalizando = true);

    try {
      await _service.salvarHistorico(
        userId: widget.userId,
        filtros: widget.filtros,
        questoes: widget.questoes,
        acertos: _acertos,
        erros: _erros,
        naoRespondidas: _naoRespondidas,
        tempoSegundos: _segundos,
      );

      await _limparRascunhoLocal();

      final respondidas = _acertos + _erros;
      final scorePercent =
          respondidas > 0 ? _acertos / respondidas * 100 : 0.0;
      AnalyticsFeatures.simuladoComplete(
        userId: widget.userId,
        scorePercent: scorePercent,
        questionCount: widget.questoes.length,
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SimuladoResultadoPage(
            userId: widget.userId,
            totalQuestoes: widget.questoes.length,
            acertos: _acertos,
            erros: _erros,
            naoRespondidas: _naoRespondidas,
            tempoSegundos: _segundos,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao salvar resultado: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _finalizando = false);
    }
  }

  void _aoResponder(String questaoId, bool acertou) {
    setState(() {
      _respondidas.add(questaoId);
      _respostas[questaoId] = acertou;
    });
    unawaited(_salvarRascunhoLocal());
  }

  void _aoMudarPagina(int index) {
    setState(() => _paginaAtual = index);
    unawaited(_salvarRascunhoLocal());
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.questoes.length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _sairSimulado();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F4F8),
        appBar: AppBar(
          title: const Text('Simulado'),
          backgroundColor: const Color(0xFF1E3A8A),
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _sairSimulado,
          ),
          actions: [
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Row(
                  children: [
                    const Icon(Icons.timer_outlined, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      _formatarTempo(_segundos),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: total > 0 ? (_paginaAtual + 1) / total : 0,
                    backgroundColor: Colors.grey.shade200,
                    color: const Color(0xFF1E3A8A),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Questão ${_paginaAtual + 1} de $total · '
                    '$_acertos acertos · $_erros erros',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: _aoMudarPagina,
                itemCount: total,
                itemBuilder: (context, index) {
                  final questao = widget.questoes[index];
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: QuestaoCard(
                      key: ValueKey(questao.id),
                      questao: questao,
                      userId: widget.userId,
                      showNextButton: index < total - 1,
                      onNext: () {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                        );
                      },
                      onAnswered: (_, acertou) =>
                          _aoResponder(questao.id, acertou),
                    ),
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _paginaAtual > 0
                            ? () {
                                _pageController.previousPage(
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeOut,
                                );
                              }
                            : null,
                        icon: const Icon(Icons.chevron_left),
                        label: const Text('Anterior'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _paginaAtual < total - 1
                            ? () {
                                _pageController.nextPage(
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeOut,
                                );
                              }
                            : null,
                        icon: const Icon(Icons.chevron_right),
                        label: const Text('Próxima'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: _finalizando ? null : _finalizar,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0D9488),
                        ),
                        child: _finalizando
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Finalizar'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
