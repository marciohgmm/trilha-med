import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/revalida_official/revalida_official_config.dart';
import '../../models/questao_model.dart';
import '../../services/revalida_official/revalida_official_service.dart';
import '../../widgets/revalida_official/revalida_exam_question_card.dart';
import 'revalida_official_review_page.dart';

class RevalidaOfficialPlayPage extends StatefulWidget {
  const RevalidaOfficialPlayPage({
    super.key,
    required this.userId,
    required this.questoes,
  });

  final String userId;
  final List<QuestaoModel> questoes;

  @override
  State<RevalidaOfficialPlayPage> createState() =>
      _RevalidaOfficialPlayPageState();
}

class _RevalidaOfficialPlayPageState extends State<RevalidaOfficialPlayPage> {
  final PageController _pageController = PageController();
  final Map<String, String> _selecoes = {};
  late DateTime _startedAt;
  late int _remainingSeconds;
  Timer? _countdown;
  int _paginaAtual = 0;
  bool _draftChecked = false;

  List<String> get _questaoIds =>
      widget.questoes.map((q) => q.id).toList(growable: false);

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    _remainingSeconds = RevalidaOfficialConfig.defaultDurationSeconds;
    _countdown = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_remainingSeconds > 0) _remainingSeconds--;
      });
      if (_remainingSeconds <= 0) {
        _countdown?.cancel();
        _irParaRevisao(auto: true);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkDraft());
  }

  Future<void> _checkDraft() async {
    if (_draftChecked) return;
    _draftChecked = true;
    final store = RevalidaOfficialSessionStore.instance;
    final draft = await store.load(widget.userId);
    if (draft == null || !mounted) return;
    if (!store.compatible(draft, _questaoIds)) {
      await store.clear();
      return;
    }

    final restore = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Continuar prova?'),
        content: Text(
          'Encontramos uma prova em andamento '
          '(${draft.selecoes.length} marcações). Continuar?',
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
    if (restore == true) {
      setState(() {
        _selecoes
          ..clear()
          ..addAll(draft.selecoes);
        _paginaAtual = draft.paginaAtual.clamp(0, widget.questoes.length - 1);
        _startedAt = draft.startedAt;
        _remainingSeconds = draft.remainingSeconds;
      });
      _pageController.jumpToPage(_paginaAtual);
    } else {
      await store.clear();
    }
  }

  Future<void> _saveDraft() async {
    await RevalidaOfficialSessionStore.instance.save(
      RevalidaOfficialDraft(
        userId: widget.userId,
        questaoIds: _questaoIds,
        selecoes: Map<String, String>.from(_selecoes),
        paginaAtual: _paginaAtual,
        startedAt: _startedAt,
        remainingSeconds: _remainingSeconds,
        salvoEm: DateTime.now(),
      ),
    );
  }

  int get _durationUsed =>
      RevalidaOfficialConfig.defaultDurationSeconds - _remainingSeconds;

  bool _isAnswered(int index) {
    final id = widget.questoes[index].id;
    final sel = _selecoes[id];
    return sel != null && sel.isNotEmpty;
  }

  void _openNavigator() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => RevalidaQuestionNavigatorSheet(
        total: widget.questoes.length,
        currentIndex: _paginaAtual,
        isAnswered: _isAnswered,
        onSelect: (index) {
          _pageController.jumpToPage(index);
          setState(() => _paginaAtual = index);
          unawaited(_saveDraft());
        },
      ),
    );
  }

  Future<void> _confirmExit() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sair da prova?'),
        content: const Text(
          'Seu progresso será salvo localmente. Deseja sair?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Continuar prova'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await _saveDraft();
      if (mounted) Navigator.pop(context);
    }
  }

  void _irParaRevisao({bool auto = false}) {
    if (auto) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tempo esgotado — revise e entregue.')),
      );
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RevalidaOfficialReviewPage(
          userId: widget.userId,
          questoes: widget.questoes,
          selecoes: Map<String, String>.from(_selecoes),
          startedAt: _startedAt,
          durationSeconds: _durationUsed,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _countdown?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.questoes.length;
    final answeredCount =
        widget.questoes.where((q) => _selecoes[q.id]?.isNotEmpty == true).length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _confirmExit();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F4F8),
        appBar: AppBar(
          title: const Text('Prova Oficial'),
          backgroundColor: const Color(0xFF1E3A8A),
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _confirmExit,
          ),
          actions: [
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Row(
                  children: [
                    Icon(
                      _remainingSeconds < 600 ? Icons.warning_amber : Icons.timer,
                      size: 18,
                      color: _remainingSeconds < 600 ? Colors.amber : Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      formatRevalidaDuration(_remainingSeconds),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _remainingSeconds < 600 ? Colors.amber : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: 'Mapa de questões',
              icon: const Icon(Icons.grid_view),
              onPressed: _openNavigator,
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
                    '$answeredCount marcadas',
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
                onPageChanged: (i) {
                  setState(() => _paginaAtual = i);
                  unawaited(_saveDraft());
                },
                itemCount: total,
                itemBuilder: (context, index) {
                  final q = widget.questoes[index];
                  return SingleChildScrollView(
                    child: RevalidaExamQuestionCard(
                      key: ValueKey(q.id),
                      questao: q,
                      questionNumber: index + 1,
                      selectedAlternativaId: _selecoes[q.id],
                      onSelected: (altId) {
                        setState(() => _selecoes[q.id] = altId);
                        unawaited(_saveDraft());
                      },
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
                            ? () => _pageController.previousPage(
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeOut,
                                )
                            : null,
                        icon: const Icon(Icons.chevron_left),
                        label: const Text('Anterior'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _paginaAtual < total - 1
                            ? () => _pageController.nextPage(
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeOut,
                                )
                            : null,
                        icon: const Icon(Icons.chevron_right),
                        label: const Text('Próxima'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => _irParaRevisao(),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0D9488),
                        ),
                        child: const Text('Revisar'),
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
