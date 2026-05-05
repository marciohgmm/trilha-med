import 'package:flutter/material.dart';

import '../services/questao_service.dart';
import '../widgets/questao_card.dart';

class QuestoesPage extends StatefulWidget {
  final String userId;
  final String? materia;
  final String tema;
  final String subtema;

  const QuestoesPage({
    super.key,
    required this.userId,
    this.materia,
    required this.tema,
    required this.subtema,
  });

  @override
  State<QuestoesPage> createState() => _QuestoesPageState();
}

class _QuestoesPageState extends State<QuestoesPage> {
  final QuestaoService _service = QuestaoService();
  bool _modoProxima = false;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: Text(
          widget.materia != null
              ? '${widget.subtema} - ${widget.tema}'
              : '${widget.subtema} - ${widget.tema}',
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
        ],
      ),
      body: StreamBuilder(
        stream: _service.getQuestoesPorTema(
          materia: widget.materia,
          tema: widget.tema,
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
                );
              },
            );
          }

          return PageView.builder(
            controller: _pageController,
            itemCount: questoes.length,
            itemBuilder: (context, index) {
              return ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  QuestaoCard(
                    questao: questoes[index],
                    userId: widget.userId,
                    showNextButton: index < questoes.length - 1,
                    onNext: () {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                      );
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Questão ${index + 1} de ${questoes.length}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}