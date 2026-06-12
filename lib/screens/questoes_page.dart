import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/questao_service.dart';
import '../core/analytics/analytics_events.dart';
import '../core/analytics/analytics_feature_tracker.dart';
import '../application/platform/platform_registry.dart';
import '../models/access_usage_stats.dart';
import '../widgets/questao_card.dart';
import 'login_page.dart';

class QuestoesPage extends StatefulWidget {
  final String userId;
  final String materia;
  final String subtema;

  const QuestoesPage({
    super.key,
    required this.userId,
    required this.materia,
    required this.subtema,
  });

  @override
  State<QuestoesPage> createState() => _QuestoesPageState();
}

class _QuestoesPageState extends State<QuestoesPage> with AnalyticsFeatureTracker {
  final QuestaoService _service = QuestaoService();
  late bool _modoProxima;
  bool _mobileDefaultApplied = false;
  final PageController _pageController = PageController();
  int _paginaAtual = 0;

  Future<void> _fazerLogout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  void initState() {
    super.initState();
    _modoProxima = false;
    trackFeatureOnce(
      AnalyticsEvents.questionsStudyStart,
      userId: widget.userId,
      parameters: {
        AnalyticsParams.materia: widget.materia,
        AnalyticsParams.subtema: widget.subtema,
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_mobileDefaultApplied) return;
    _mobileDefaultApplied = true;
    // No celular, modo “uma por vez” evita conflito de scroll com PageView.
    if (MediaQuery.sizeOf(context).shortestSide < 600) {
      _modoProxima = true;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool get _isMobileLayout => MediaQuery.sizeOf(context).shortestSide < 600;

  Future<ConsumeResult> _onBeforeAnswer(String questionId) {
    return PlatformRegistry.instance.contentAccess.tryConsumeQuestion(
      userId: widget.userId,
      questionId: questionId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: Text(
          '${widget.subtema} — ${widget.materia}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: _modoProxima ? 'Modo rolagem' : 'Modo próxima',
            onPressed: () {
              setState(() {
                _modoProxima = !_modoProxima;
              });
              if (_modoProxima) {
                _pageController.jumpToPage(0);
              }
            },
            icon: Icon(_modoProxima ? Icons.view_agenda : Icons.swipe),
          ),
          IconButton(
            onPressed: _fazerLogout,
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
          ),
        ],
      ),
      body: StreamBuilder(
        stream: _service.getQuestoesPorSubtema(
          materia: widget.materia,
          subtema: widget.subtema,
          somenteAtivas: true,
        ),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Erro ao carregar questões: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final questoes = snapshot.data!;

          if (questoes.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Nenhuma questão encontrada para este subtema.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Voltar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          if (!_modoProxima) {
            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: questoes.length,
              itemBuilder: (context, index) {
                return QuestaoCard(
                  questao: questoes[index],
                  userId: widget.userId,
                  onBeforeAnswer: _onBeforeAnswer,
                );
              },
            );
          }

          return Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  physics: _isMobileLayout
                      ? const NeverScrollableScrollPhysics()
                      : const ClampingScrollPhysics(),
                  onPageChanged: (i) => setState(() => _paginaAtual = i),
                  itemCount: questoes.length,
                  itemBuilder: (context, index) {
                    return SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        children: [
                          QuestaoCard(
                            questao: questoes[index],
                            userId: widget.userId,
                            showNextButton: index < questoes.length - 1,
                            onBeforeAnswer: _onBeforeAnswer,
                            onNext: () {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOut,
                              );
                            },
                          ),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'Questão ${index + 1} de ${questoes.length}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.black54),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              if (questoes.length > 1)
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
                                      duration:
                                          const Duration(milliseconds: 250),
                                      curve: Curves.easeOut,
                                    );
                                  }
                                : null,
                            icon: const Icon(Icons.chevron_left),
                            label: const Text('Anterior'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _paginaAtual < questoes.length - 1
                                ? () {
                                    _pageController.nextPage(
                                      duration:
                                          const Duration(milliseconds: 250),
                                      curve: Curves.easeOut,
                                    );
                                  }
                                : null,
                            icon: const Icon(Icons.chevron_right),
                            label: const Text('Próxima'),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF1E3A8A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
